import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../services/media_player_backend.dart';

/// 字幕编辑页视频画面的加载状态。
enum SubtitleEditorVideoStatus { loading, ready, failed }

/// 字幕编辑页的视频画面：只出画面、不出声音，跟随编辑器的播放状态。
///
/// 字幕编辑的句 / 词级试听依赖音频引擎的精确区间播放，改走视频链路会牵动整个
/// 编辑器的播放与计时逻辑；因此画面用独立的 [MediaPlayerBackend] 并关闭音轨，
/// 只负责「暂停时停在播放头所在帧、播放时同速跟随」，声音仍由原链路负责。
/// 生命周期由页面持有：首次显示画面时才创建，离开页面时释放。
class SubtitleEditorVideoPreview {
  SubtitleEditorVideoPreview(this._backend);

  /// 播放中画面与播放头的允许偏差；超过才重新定位，避免频繁 seek 造成卡顿。
  /// 约 4 帧：再小容易在播放位置上报抖动时反复 seek。
  static const Duration _playingDriftTolerance = Duration(milliseconds: 150);

  /// 暂停时画面与播放头的允许偏差；小于一帧时不必再定位。
  static const Duration _pausedDriftTolerance = Duration(milliseconds: 40);

  final MediaPlayerBackend _backend;
  final ValueNotifier<SubtitleEditorVideoStatus> status = ValueNotifier(
    SubtitleEditorVideoStatus.loading,
  );
  final ValueNotifier<double?> aspectRatio = ValueNotifier(null);
  StreamSubscription<double?>? _aspectRatioSubscription;

  bool _isDisposed = false;

  /// 同步循环是否进行中；进行中再次请求只标记 [_needsResync]，由循环收尾时补跑。
  bool _isSyncing = false;
  bool _needsResync = false;

  bool _targetPlaying = false;
  Duration _targetPosition = Duration.zero;
  double _targetSpeed = 1.0;

  /// 打开视频并关闭音轨，画面停在 [initialPosition]；[path] 为 null 表示本地文件缺失。
  Future<void> open(String? path, {required Duration initialPosition}) async {
    _targetPosition = initialPosition;
    if (path == null) {
      AppLogger.log('SubtitleEditorVideo', '视频画面加载失败: 本地媒体文件缺失');
      status.value = SubtitleEditorVideoStatus.failed;
      return;
    }
    try {
      await _backend.open(path, initialPosition: initialPosition);
      await _backend.setAudioTrackEnabled(false);
      if (_isDisposed) return;
      aspectRatio.value = _backend.videoAspectRatio;
      _aspectRatioSubscription = _backend.videoAspectRatioStream.listen((
        ratio,
      ) {
        if (ratio != null && !_isDisposed) aspectRatio.value = ratio;
      });
      status.value = SubtitleEditorVideoStatus.ready;
      AppLogger.log(
        'SubtitleEditorVideo',
        '视频画面已加载 position=${initialPosition.inMilliseconds}ms',
      );
      _scheduleSync();
    } on Exception catch (error) {
      AppLogger.log('SubtitleEditorVideo', '视频画面加载失败: $error');
      if (!_isDisposed) status.value = SubtitleEditorVideoStatus.failed;
    }
  }

  /// 同步编辑器的播放状态：播放中同速跟随，暂停时停在 [position] 所在帧。
  void follow({
    required bool isPlaying,
    required Duration position,
    required double speed,
  }) {
    _targetPlaying = isPlaying;
    _targetPosition = position;
    _targetSpeed = speed;
    _scheduleSync();
  }

  /// 画面收起时暂停，避免看不见的视频继续解码。
  void suspend() {
    _targetPlaying = false;
    _scheduleSync();
  }

  Widget buildVideoView(Size viewportSize) =>
      _backend.buildVideoView(viewportSize: viewportSize);

  void _scheduleSync() {
    if (_isDisposed || status.value != SubtitleEditorVideoStatus.ready) return;
    if (_isSyncing) {
      _needsResync = true;
      return;
    }
    unawaited(_runSync());
  }

  Future<void> _runSync() async {
    _isSyncing = true;
    try {
      do {
        _needsResync = false;
        await _applyTarget();
      } while (_needsResync && !_isDisposed);
    } on Exception catch (error) {
      // 画面跟随只是辅助，失败不影响字幕编辑；记录后等下一次状态变化再同步。
      AppLogger.log('SubtitleEditorVideo', '画面同步失败: $error');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _applyTarget() async {
    if (_isDisposed) return;
    if (_backend.rate != _targetSpeed) await _backend.setRate(_targetSpeed);
    final drift = (_backend.position - _targetPosition).abs();
    if (_targetPlaying) {
      if (!_backend.playing) {
        await _backend.seek(_targetPosition);
        await _backend.play();
      } else if (drift > _playingDriftTolerance) {
        await _backend.seek(_targetPosition);
      }
      return;
    }
    if (_backend.playing) {
      // 暂停生效前画面还会再走几十毫秒，暂停前算的偏差已不准：停下后一律定位到
      // 播放头所在帧，保证停稳时画面与播放头、高亮单词是同一时刻。
      await _backend.pause();
      await _backend.seek(_targetPosition);
      return;
    }
    if (drift > _pausedDriftTolerance) await _backend.seek(_targetPosition);
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _aspectRatioSubscription?.cancel();
    status.dispose();
    aspectRatio.dispose();
    await _backend.dispose();
  }
}

/// 视频画面区域：按视频比例居中显示，加载中 / 失败时显示占位。
class SubtitleEditorVideoPanel extends StatelessWidget {
  const SubtitleEditorVideoPanel({super.key, required this.preview});

  /// 为 null 表示画面尚在创建（等待取得媒体路径）。
  final SubtitleEditorVideoPreview? preview;

  static const double _fallbackAspectRatio = 16 / 9;

  @override
  Widget build(BuildContext context) {
    final preview = this.preview;
    final frame = preview == null
        ? const _VideoPlaceholder(isFailed: false)
        : ValueListenableBuilder<SubtitleEditorVideoStatus>(
            valueListenable: preview.status,
            builder: (context, status, _) => switch (status) {
              SubtitleEditorVideoStatus.loading => const _VideoPlaceholder(
                isFailed: false,
              ),
              SubtitleEditorVideoStatus.failed => const _VideoPlaceholder(
                isFailed: true,
              ),
              SubtitleEditorVideoStatus.ready => LayoutBuilder(
                builder: (context, box) => preview.buildVideoView(box.biggest),
              ),
            },
          );
    final aspectRatio = preview?.aspectRatio;
    // 只占画面实际高度（heightFactor: 1），由外层布局决定画面上方或下方留白。
    Widget framed(double? ratio) => Center(
      heightFactor: 1,
      child: AspectRatio(
        aspectRatio: ratio ?? _fallbackAspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(color: Colors.black, child: frame),
        ),
      ),
    );
    return KeyedSubtree(
      key: const ValueKey('subtitle-editor-video'),
      child: aspectRatio == null
          ? framed(null)
          : ValueListenableBuilder<double?>(
              valueListenable: aspectRatio,
              builder: (context, ratio, _) => framed(ratio),
            ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.isFailed});

  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    if (!isFailed) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          AppLocalizations.of(context)!.subtitleEditorVideoLoadFailed,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ),
    );
  }
}
