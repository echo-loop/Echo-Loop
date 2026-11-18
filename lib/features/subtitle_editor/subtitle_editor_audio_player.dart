import 'dart:async';

import 'package:path/path.dart' as p;

import '../../services/app_logger.dart';
import '../../services/media_player_backend.dart';

/// 区间播放结束的原因，只用于日志诊断。
///
/// media_kit（mpv keep-open）播到原生终点时先报暂停、再报自然结束，所以
/// [paused] 通常就是到达句尾；外部暂停（如来电打断）也归入此类。
enum _RangeEndReason { completed, paused, cancelled }

/// 字幕编辑器的声音播放：独占一个 media_kit 播放器，只开音轨。
///
/// 与剪辑页一致，编辑器不接入全局播放引擎和系统媒体会话：页面打开时创建、
/// 关闭时释放，不会改动其它页面共享的播放状态。media_kit 能解封装 mkv/webm
/// 等 AVPlayer 打不开的容器，视频材料在 iOS/macOS 上也能直接出声。
///
/// 视频画面由 [SubtitleEditorVideoPreview] 的独立播放器负责，这里关闭视频轨，
/// 避免同一文件被解码两次画面。
///
/// 播放按会话隔离：[newSession] 使旧会话的区间播放立即返回，迟到的回调据
/// [isActiveSession] 自行丢弃。
class SubtitleEditorAudioPlayer {
  SubtitleEditorAudioPlayer(this._backend);

  static const String _logTag = 'SubtitleEditorAudio';

  /// 打开媒体后等待时长上报的上限；超过视为无法解码。
  static const Duration _durationTimeout = Duration(seconds: 10);

  /// 音频输出缓冲。播到原生终点时缓冲里未播出的声音会被丢弃：默认 0.2 秒会把
  /// 单词 / 句尾截掉约 200ms，误导边界对齐；50ms 实测播放时长与区间一致。
  static const Duration _audioOutputBuffer = Duration(milliseconds: 50);

  final MediaPlayerBackend _backend;
  int _sessionId = 0;
  int _rangeRequestId = 0;
  Completer<_RangeEndReason>? _activeRange;
  bool _isDisposed = false;

  /// 绝对播放位置（media_kit 没有 clip 概念，位置即媒体时间轴）。
  Stream<Duration> get positionStream => _backend.positionStream;

  /// 打开媒体并返回时长。打不开或迟迟拿不到时长时抛出，由调用方展示错误。
  Future<Duration> open(String path) async {
    final stopwatch = Stopwatch()..start();
    final name = p.basename(path);
    AppLogger.log(_logTag, '打开媒体 begin file=$name');
    try {
      await _backend.setAudioOutputBuffer(_audioOutputBuffer);
      await _backend.open(path);
      await _backend.setVideoTrackEnabled(false);
      final duration =
          _backend.duration ??
          await _backend.durationStream
              .firstWhere((value) => value > Duration.zero)
              .timeout(_durationTimeout);
      AppLogger.log(
        _logTag,
        '打开媒体 complete file=$name duration=${duration.inMilliseconds}ms '
        'cost=${stopwatch.elapsedMilliseconds}ms',
      );
      return duration;
    } on Object catch (error) {
      AppLogger.log(
        _logTag,
        '打开媒体 failed file=$name cost=${stopwatch.elapsedMilliseconds}ms '
        'error=$error',
      );
      rethrow;
    }
  }

  /// 开启新的播放会话，使进行中的区间播放立即以取消结束。
  int newSession() {
    _sessionId += 1;
    _finishActiveRange(_RangeEndReason.cancelled);
    return _sessionId;
  }

  bool isActiveSession(int sessionId) =>
      !_isDisposed && sessionId == _sessionId;

  Future<void> setSpeed(double speed) => _backend.setRate(speed);

  /// 播放 [start]–[end] 一次，播到终点、被暂停或会话失效时返回。
  ///
  /// 句尾由播放器的原生终点在解码层裁切，不靠位置事件软停止（事件间隔与输出
  /// 缓冲会让软停止越过句尾，单词试听尤其明显）。结束判定只采信起播之后的
  /// 暂停 / 自然结束事件，忽略起播前上一段播放残留的事件。
  Future<void> playRange(Duration start, Duration end, int sessionId) async {
    if (!isActiveSession(sessionId) || end <= start) return;
    _finishActiveRange(_RangeEndReason.cancelled);
    final requestId = ++_rangeRequestId;
    final range = Completer<_RangeEndReason>();
    _activeRange = range;
    final stopwatch = Stopwatch()..start();
    var hasStarted = false;
    int? startedAtMs;
    void finish(_RangeEndReason reason) {
      if (!range.isCompleted) range.complete(reason);
    }

    final subscriptions = <StreamSubscription<Object?>>[
      _backend.playingStream.listen((isPlaying) {
        if (isPlaying) {
          if (startedAtMs == null) {
            startedAtMs = stopwatch.elapsedMilliseconds;
            // 起播时刻与位置：核对定位是否落在区间起点、实际播放时长是否完整。
            AppLogger.log(
              _logTag,
              '区间播放 started id=$requestId '
              'position=${_backend.position.inMilliseconds}ms '
              'targetStart=${start.inMilliseconds}ms '
              'elapsed=${startedAtMs}ms',
            );
          }
          hasStarted = true;
        } else if (hasStarted) {
          finish(_RangeEndReason.paused);
        }
      }),
      _backend.completedStream.listen((_) {
        if (hasStarted) finish(_RangeEndReason.completed);
      }),
    ];
    AppLogger.log(
      _logTag,
      '区间播放 request id=$requestId session=$sessionId '
      'range=${start.inMilliseconds}-${end.inMilliseconds}ms',
    );
    var reason = _RangeEndReason.cancelled;
    try {
      await _backend.pause();
      if (!isActiveSession(sessionId)) return;
      // 先撤销旧终点再定位：旧终点早于新起点时，带着它 seek 会立即触发结束。
      await _backend.setPlaybackEnd(null);
      await _backend.seek(start);
      if (!isActiveSession(sessionId)) return;
      await _backend.setPlaybackEnd(end);
      if (!isActiveSession(sessionId)) return;
      await _backend.play();
      hasStarted = true;
      reason = await range.future;
    } finally {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      if (identical(_activeRange, range)) _activeRange = null;
      final startedAt = startedAtMs;
      AppLogger.log(
        _logTag,
        '区间播放 return id=$requestId reason=${reason.name} '
        'position=${_isDisposed ? '-' : '${_backend.position.inMilliseconds}ms'} '
        'targetEnd=${end.inMilliseconds}ms '
        'played=${startedAt == null ? '-' : '${stopwatch.elapsedMilliseconds - startedAt}ms'} '
        'elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  /// 停止播放：暂停并撤销区间终点，播放位置保持不动。
  Future<void> stop() async {
    if (_isDisposed) return;
    _finishActiveRange(_RangeEndReason.cancelled);
    await _backend.pause();
    await _backend.setPlaybackEnd(null);
  }

  /// 定位到 [position]；先撤销区间终点，避免定位越过旧句尾后立即结束。
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;
    await _backend.setPlaybackEnd(null);
    await _backend.seek(position);
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _finishActiveRange(_RangeEndReason.cancelled);
    try {
      await _backend.dispose();
      AppLogger.log(_logTag, '播放器已释放');
    } on Object catch (error) {
      // 页面已经关闭，释放失败只能记录，不能再向界面报告。
      AppLogger.log(_logTag, '播放器释放失败: $error');
    }
  }

  void _finishActiveRange(_RangeEndReason reason) {
    final range = _activeRange;
    _activeRange = null;
    if (range != null && !range.isCompleted) range.complete(reason);
  }
}
