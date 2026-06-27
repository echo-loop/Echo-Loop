import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../database/providers.dart';
import '../../models/audio_engine_state.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../services/app_logger.dart';
import '../../services/study_event_recorder.dart';
import '../../services/subtitle_parser.dart';

part 'foreground_audio_engine_provider.g.dart';

/// 前台音频引擎——录音/复习类任务专用，**不接入 `audio_service`**。
///
/// 与媒体引擎 [AudioEngine]（接 `audio_service`，带锁屏/后台/静音保活）相对：
/// 本引擎自持一个**裸 [ja.AudioPlayer]**，物理上碰不到系统媒体会话
/// （`MPNowPlayingInfoCenter` / 前台通知），故播放原句/原段时永不弹锁屏卡片。
///
/// 服务于：难句跟读 / 段落复述 / 难句补练 / 收藏句复习 / 收藏词复习(闪卡)。
/// 这些任务只在前台播放，不需要后台续播与锁屏控制（见 PLAN.md ADR-7）。
///
/// 播放子集逐方法照抄 [AudioEngine]，仅把 `_handler.xxx` 换成裸 `_player.xxx`，
/// 保证 session 守卫、clip 语义、await-完成等行为与 commit 578f8829 一致；
/// 不实现 `setMediaSessionSuppressed` / `setLogicalPlaying` / 保活 / 锁屏回调 /
/// `playToEnd`（媒体会话/整篇循环专属）。
@Riverpod(keepAlive: true)
class ForegroundAudioEngine extends _$ForegroundAudioEngine {
  /// 学习事件记录器（由各前台任务进入时注入，退出时传 null）
  StudyEventRecorder? _recorder;

  /// 设置学习事件记录器。
  void setRecorder(StudyEventRecorder? recorder) {
    _recorder = recorder;
  }

  /// 裸播放器——独立实例，从不注册到 `audio_service`。
  final ja.AudioPlayer _player = ja.AudioPlayer();

  @override
  AudioEngineState build() {
    ref.onDispose(() {
      _player.dispose();
    });
    return const AudioEngineState();
  }

  ja.AudioPlayer get audioPlayer => _player;

  // --- Streams ---
  Stream<Duration> get absolutePositionStream =>
      _player.positionStream.map((rel) => state.clipStart + rel);

  Stream<ja.PlayerState> get playerStateStream => _player.playerStateStream;

  bool get isPlaying => _player.playing;
  ja.ProcessingState get processingState => _player.processingState;
  Duration get currentPosition => _player.position;

  /// 已解析的音频总时长（loadAudio 时写入）。
  Duration? get totalDuration => state.totalDuration;
  Duration get absoluteCurrentPosition => state.clipStart + _player.position;

  /// 当前 session id。
  int get currentSessionId => state.sessionId;

  // --- 音频加载 ---
  /// 加载音频文件到裸播放器。
  ///
  /// 与 [AudioEngine.loadAudio] 等价，但不经 handler、不设 MediaItem/封面
  /// （前台引擎不上锁屏）。[subtitle] 参数保留以对齐调用签名，本引擎忽略。
  Future<Duration?> loadAudio(
    AudioItem item,
    double speed, {
    String? subtitle,
  }) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final fullAudioPath = await item.getFullAudioPath();
      if (fullAudioPath == null) {
        state = state.copyWith(isLoading: false, errorMessage: '音频文件不可用（未下载）');
        return null;
      }
      final fileExists = File(fullAudioPath).existsSync();
      AppLogger.log(
        'ForegroundAudioEngine',
        '🔊 loadAudio: id=${item.id}, path=$fullAudioPath, '
            'exists=$fileExists, sessionId=${state.sessionId}',
      );
      final duration = await _player.setFilePath(fullAudioPath);
      await _player.setSpeed(speed);
      var resolvedDuration = duration ?? _player.duration;
      if (resolvedDuration == null) {
        await _player.durationStream.first;
        resolvedDuration = _player.duration;
      }

      state = state.copyWith(
        totalDuration: resolvedDuration,
        clipStart: Duration.zero,
        isClipActive: false,
        currentAudioId: item.id,
        isLoading: false,
      );

      return resolvedDuration;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  // --- 字幕加载 ---
  /// 字幕内容唯一真相源是 DB 的 transcript_srt 列；列空时读遗留文件并回填。
  /// 与 [AudioEngine.loadTranscript] 一致（纯 DB + 解析，与 player 无关）。
  Future<List<Sentence>> loadTranscript(AudioItem audioItem) async {
    if (!audioItem.hasTranscript) {
      return [];
    }

    try {
      final dao = ref.read(audioItemDaoProvider);
      final srt = await dao.getTranscriptSrt(audioItem.id);
      if (srt != null && srt.isNotEmpty) {
        return await SubtitleParser.parseSubtitleString(srt);
      }

      final fullTranscriptPath = await audioItem.getFullTranscriptPath();
      if (fullTranscriptPath != null) {
        final file = File(fullTranscriptPath);
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            await dao.updateTranscriptSrt(audioItem.id, content);
            return await SubtitleParser.parseSubtitleString(content);
          }
        }
      }
      return [];
    } catch (e) {
      AppLogger.log('ForegroundAudioEngine', '✗ loadTranscript 失败: $e');
      return [];
    }
  }

  // --- 基础控制 ---
  Future<void> play() async => await _player.play();

  Future<void> pause() async {
    state = state.copyWith(sessionId: state.sessionId + 1);
    await _player.pause();
  }

  /// 暂停但不递增 sessionId（边界监听回卷、进度条拖动续播用）。
  Future<void> pauseKeepSession() async {
    await _player.pause();
  }

  Future<void> stop() async {
    final oldId = state.sessionId;
    state = state.copyWith(sessionId: state.sessionId + 1);
    AppLogger.log(
      'ForegroundAudioEngine',
      '⏹ stop(): sessionId $oldId → ${state.sessionId}',
    );
    await _player.stop();
  }

  /// 停止播放（不改变 sessionId）。
  Future<void> stopPlayback() async {
    await _player.stop();
  }

  Future<void> seek(Duration pos) async => await _player.seek(pos);

  /// 按绝对音频时间跳转，自动转换为当前 clip 的相对位置（同 [AudioEngine.seekToAbsolute]）。
  Future<void> seekToAbsolute(Duration absolute) async {
    final relative = absolute - state.clipStart;
    await _player.seek(relative.isNegative ? Duration.zero : relative);
  }

  Future<void> setSpeed(double speed) async => await _player.setSpeed(speed);

  // --- Clip 管理 ---
  Future<void> setClip(Duration start, Duration end) async {
    state = state.copyWith(clipStart: start, isClipActive: true);
    await _player.setClip(start: start, end: end);
  }

  Future<void> clearClip() async {
    if (!state.isClipActive) return;
    state = state.copyWith(clipStart: Duration.zero, isClipActive: false);
    await _player.setClip(start: null, end: null);
  }

  // --- 句子级播放基元 ---
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;

    AppLogger.log(
      'ForegroundAudioEngine',
      '▶ playClip: loadedAudio=${state.currentAudioId}, '
          'clip=${sentence.startTime.inMilliseconds}-${sentence.endTime.inMilliseconds}ms',
    );
    state = state.copyWith(clipStart: sentence.startTime, isClipActive: true);
    await _player.setClip(start: sentence.startTime, end: sentence.endTime);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playClipOnce SKIPPED after setClip: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // 每次设置片段后显式回到 clip 相对起点，避免 just_audio 沿用旧 position。
    await _player.seek(Duration.zero);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playClipOnce SKIPPED after seek: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    await _player.play();
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playClipOnce: session $sessionId 在 play() 后已过期，主动 pause',
      );
      await _player.pause();
      return;
    }

    await _player.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed,
    );

    if (isActiveSession(sessionId)) {
      _recorder?.onSentencePlayed(sentence);
    }
  }

  /// 按句播放若干遍（同 [AudioEngine.playClipWithLoops]）。
  Future<void> playClipWithLoops(
    Sentence sentence,
    int sessionId, {
    required int loopCount,
    required Duration interval,
  }) async {
    for (int loop = 0; loop < loopCount; loop++) {
      if (!isActiveSession(sessionId)) return;

      await playClipOnce(sentence, sessionId);

      if (!isActiveSession(sessionId)) return;
      if (loop < loopCount - 1 && interval > Duration.zero) {
        await Future.delayed(interval);
      }
    }
  }

  // --- 区间播放（段落级） ---
  /// 播放指定时间区间一次（段落播放用，同 [AudioEngine.playRangeOnce]）。
  ///
  /// [onClipReady] 在 clip+seek(0) 落定、`play()` 之前回调一次（session 仍有效时），
  /// 供调用方在此刻才订阅 [absolutePositionStream]，避免 setClip/seek 过渡期的
  /// 陈旧 position 被误映射成错误句子。
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {
    AppLogger.log(
      'ForegroundAudioEngine',
      '▶ playRangeOnce: range=${start.inMilliseconds}-${end.inMilliseconds}ms, '
          'sessionId=$sessionId, currentSessionId=${state.sessionId}, '
          'isActive=${isActiveSession(sessionId)}, audioId=${state.currentAudioId}',
    );
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playRangeOnce SKIPPED: session $sessionId 已过期 (current=${state.sessionId})',
      );
      return;
    }

    state = state.copyWith(clipStart: start, isClipActive: true);
    await _player.setClip(start: start, end: end);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playRangeOnce SKIPPED after setClip: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // 显式 seek 到 clip 相对起点，保证从目标段开始播放。
    await _player.seek(Duration.zero);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playRangeOnce SKIPPED after seek: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // clip+seek(0) 已落定，位置流此刻起发出的是新位置——通知调用方安全订阅。
    onClipReady?.call();

    await _player.play();
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playRangeOnce: session $sessionId 在 play() 后已过期，主动 pause',
      );
      await _player.pause();
      return;
    }

    await _player.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed,
    );
    AppLogger.log(
      'ForegroundAudioEngine',
      '✓ playRangeOnce done: sessionStillActive=${isActiveSession(sessionId)}, '
          'processingState=${_player.processingState.name}',
    );
  }

  // --- Session 管理 ---
  int newSession() {
    final oldId = state.sessionId;
    state = state.copyWith(sessionId: state.sessionId + 1);
    AppLogger.log(
      'ForegroundAudioEngine',
      '🔄 newSession(): sessionId $oldId → ${state.sessionId}',
    );
    return state.sessionId;
  }

  bool isActiveSession(int id) => id == state.sessionId;
}
