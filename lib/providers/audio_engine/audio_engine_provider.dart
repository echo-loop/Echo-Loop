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

part 'audio_engine_provider.g.dart';

@Riverpod(keepAlive: true)
class AudioEngine extends _$AudioEngine {
  late final ja.AudioPlayer _audioPlayer;

  /// 学习事件记录器（由 StudyTaskControllerMixin 注入）
  StudyEventRecorder? _recorder;

  /// 设置学习事件记录器（进入学习模式时注入，退出时传 null）
  void setRecorder(StudyEventRecorder? recorder) {
    _recorder = recorder;
  }

  @override
  AudioEngineState build() {
    _audioPlayer = ja.AudioPlayer();
    ref.onDispose(() => _audioPlayer.dispose());
    return const AudioEngineState();
  }

  ja.AudioPlayer get audioPlayer => _audioPlayer;

  // --- Streams ---
  Stream<Duration> get absolutePositionStream =>
      _audioPlayer.positionStream.map((rel) => state.clipStart + rel);

  Stream<ja.PlayerState> get playerStateStream =>
      _audioPlayer.playerStateStream;

  bool get isPlaying => _audioPlayer.playing;
  ja.ProcessingState get processingState => _audioPlayer.processingState;
  Duration get currentPosition => _audioPlayer.position;
  Duration get absoluteCurrentPosition =>
      state.clipStart + _audioPlayer.position;

  /// 当前 session id。调用方据此判断「引擎是否仍停在自己上次驱动的 session」，
  /// 用于隔离讲解页等外来组件对共享引擎的旁路驱动。
  int get currentSessionId => state.sessionId;

  // --- 音频加载 ---
  Future<Duration?> loadAudio(AudioItem item, double speed) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final fullAudioPath = await item.getFullAudioPath();
      if (fullAudioPath == null) {
        state = state.copyWith(isLoading: false, errorMessage: '音频文件不可用（未下载）');
        return null;
      }
      final fileExists = File(fullAudioPath).existsSync();
      AppLogger.log(
        'AudioEngine',
        '🔊 loadAudio: id=${item.id}, path=$fullAudioPath, '
            'exists=$fileExists, sessionId=${state.sessionId}',
      );
      await _audioPlayer.setFilePath(fullAudioPath);
      await _audioPlayer.setSpeed(speed);

      Duration? duration = _audioPlayer.duration;
      if (duration == null) {
        await _audioPlayer.durationStream.first;
        duration = _audioPlayer.duration;
      }

      state = state.copyWith(
        totalDuration: duration,
        clipStart: Duration.zero,
        isClipActive: false,
        currentAudioId: item.id,
        isLoading: false,
      );

      return duration;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  // --- 字幕加载 ---
  ///
  /// 字幕内容唯一真相源是 DB 的 transcript_srt 列。优先读列；列为空且存在遗留文件
  /// 路径时读文件作防御兜底（全量 backfill 后正常不会触发），并顺手回填列。
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

      // 防御兜底：列空但有遗留文件 → 读文件并回填列。
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
      AppLogger.log('Player', '✗ loadTranscript 失败: $e');
      return [];
    }
  }

  // --- 基础控制 ---
  Future<void> play() async => await _audioPlayer.play();

  Future<void> pause() async {
    state = state.copyWith(sessionId: state.sessionId + 1);
    await _audioPlayer.pause();
  }

  /// 暂停但不递增 sessionId。
  ///
  /// 用于「暂停后仍要从同一 LP session 续播」的场景（边界监听回卷、进度条任意
  /// 拖动续播）。普通 [pause] 会 `sessionId++` 使调用方持有的 session 失效，
  /// 续播时会被误判为「被外来 session 顶掉」而走重新起播逻辑；本方法保留 session，
  /// 让调用方能从精确位置继续。
  Future<void> pauseKeepSession() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    final oldId = state.sessionId;
    state = state.copyWith(sessionId: state.sessionId + 1);
    AppLogger.log(
      'AudioEngine',
      '⏹ stop(): sessionId $oldId → ${state.sessionId}',
    );
    await _audioPlayer.stop();
  }

  /// 停止音频播放（不改变 sessionId）
  ///
  /// 用于 pause 场景：先通过 newSession() 使旧 session 失效，
  /// 再调用此方法真正停止底层播放器，避免额外递增 sessionId。
  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration pos) async => await _audioPlayer.seek(pos);

  /// 按绝对音频时间跳转，自动转换为当前 clip 的相对位置。
  ///
  /// just_audio 的 `seek` 在 `setClip` 之后以 clip 起点为 0 计算，
  /// 直接传绝对时间会跳到 `clipStart + absolute`，常常越过 clip 末尾
  /// 触发误 `completed`。本方法消除了调用方关心 clip 边界的必要。
  Future<void> seekToAbsolute(Duration absolute) async {
    final relative = absolute - state.clipStart;
    await _audioPlayer.seek(relative.isNegative ? Duration.zero : relative);
  }

  Future<void> setSpeed(double speed) async =>
      await _audioPlayer.setSpeed(speed);

  // --- Clip 管理 ---
  Future<void> setClip(Duration start, Duration end) async {
    state = state.copyWith(clipStart: start, isClipActive: true);
    await _audioPlayer.setClip(start: start, end: end);
  }

  Future<void> clearClip() async {
    if (!state.isClipActive) return;
    state = state.copyWith(clipStart: Duration.zero, isClipActive: false);
    await _audioPlayer.setClip(start: null, end: null);
  }

  // --- 句子级播放基元（所有业务模式共享） ---
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;

    AppLogger.log(
      'AudioEngine',
      '▶ playClip: loadedAudio=${state.currentAudioId}, '
          'clip=${sentence.startTime.inMilliseconds}-${sentence.endTime.inMilliseconds}ms',
    );
    state = state.copyWith(clipStart: sentence.startTime, isClipActive: true);
    await _audioPlayer.setClip(
      start: sentence.startTime,
      end: sentence.endTime,
    );

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playClipOnce SKIPPED after setClip: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // 标准 clip 播放流程：每次设置片段后显式回到 clip 相对起点。
    // just_audio 在连续切 clip 时可能保留旧相对 position；不 seek(0)
    // 会导致“点击句子却从句中间播放”的交互错误。
    await _audioPlayer.seek(Duration.zero);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playClipOnce SKIPPED after seek: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    await _audioPlayer.play();
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playClipOnce: session $sessionId 在 play() 后已过期，主动 pause',
      );
      await _audioPlayer.pause();
      return;
    }

    await _audioPlayer.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed,
    );

    // 播放成功后记录听力时长 + 词数 + 词形
    if (isActiveSession(sessionId)) {
      _recorder?.onSentencePlayed(sentence);
    }
  }

  /// 按句播放若干遍。
  ///
  /// Free Player 的单句循环/收藏跳播和学习模式共用这个低层基元：每一遍都重新
  /// setClip 并 seek 到 clip 相对起点，避免 just_audio 在连续切片时沿用旧位置。
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

  /// 从当前播放位置播到音频自然结束（整篇连续播放用）。
  ///
  /// 不 setClip：清除任何残留 clip 后从引擎当前 position 播放，await 直到 just_audio
  /// 发出 `ProcessingState.completed` 或 session 失效。每个自然结束只解析一次 await，
  /// 因此对 just_audio 在部分平台发出的重复/滞后 `completed` 事件天然免疫——
  /// 调用方据此做确定性的整篇循环计数，不依赖反应式事件流。
  Future<void> playToEnd(int sessionId) async {
    if (!isActiveSession(sessionId)) return;

    await _audioPlayer.play();
    // play() 是真正启动播放的点，并发场景下上游可能在此之前 bump session。
    if (!isActiveSession(sessionId)) {
      await _audioPlayer.pause();
      return;
    }

    await _audioPlayer.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed,
    );
  }

  // --- 区间播放（段落级） ---

  /// 播放指定时间区间一次（段落播放用）
  ///
  /// [start] 区间起始时间，[end] 区间结束时间。
  /// 设置 clip 后播放，等待完成。受 sessionId 保护。
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId,
  ) async {
    AppLogger.log(
      'AudioEngine',
      '▶ playRangeOnce: range=${start.inMilliseconds}-${end.inMilliseconds}ms, '
          'sessionId=$sessionId, currentSessionId=${state.sessionId}, '
          'isActive=${isActiveSession(sessionId)}, '
          'audioId=${state.currentAudioId}',
    );
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playRangeOnce SKIPPED: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    state = state.copyWith(clipStart: start, isClipActive: true);
    await _audioPlayer.setClip(start: start, end: end);

    // setClip 是 await 点，microtask 可能在此期间改变 session
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playRangeOnce SKIPPED after setClip: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // 在播放中切到同段另一句时，旧 position 可能仍落在新 clip 范围内，
    // 导致 play() 沿用旧 position 而非跳到 clip 起点。
    // 显式 seek 到 clip 相对起点（Duration.zero）保证从目标句开始播放。
    await _audioPlayer.seek(Duration.zero);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playRangeOnce SKIPPED after seek: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // play() 是真正启动音频的点，必须最后一次 check session：
    // 上游 pause / seek 在并发场景下可能在 setClip → seek(0) 期间 bump session，
    // 不在这里拦住会让旧 session 启动一段短暂的播放再被 stop。
    await _audioPlayer.play();
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playRangeOnce: session $sessionId 在 play() 后已过期，主动 pause',
      );
      await _audioPlayer.pause();
      return;
    }

    AppLogger.log(
      'AudioEngine',
      '│ play() returned: processingState=${_audioPlayer.processingState.name}, '
          'playing=${_audioPlayer.playing}, '
          'sessionActive=${isActiveSession(sessionId)}',
    );

    await _audioPlayer.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed,
    );
    AppLogger.log(
      'AudioEngine',
      '✓ playRangeOnce done: sessionStillActive=${isActiveSession(sessionId)}, '
          'processingState=${_audioPlayer.processingState.name}',
    );
  }

  // --- Session 管理 ---
  int newSession() {
    final oldId = state.sessionId;
    state = state.copyWith(sessionId: state.sessionId + 1);
    AppLogger.log(
      'AudioEngine',
      '🔄 newSession(): sessionId $oldId → ${state.sessionId}',
    );
    return state.sessionId;
  }

  bool isActiveSession(int id) => id == state.sessionId;
}
