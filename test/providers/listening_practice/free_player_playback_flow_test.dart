/// Free Player 播放状态机场景测试。
///
/// 用一组测试字幕和可控 AudioEngine 模拟播放头推进，覆盖真实用户会遇到的
/// gapless 连播、单句循环、收藏跳播、seek、手动切句等组合。这里测试 provider
/// 编排，不依赖真实音频文件或 just_audio。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import '../../helpers/mock_providers.dart';

/// 可控 AudioEngine：真实 session 计数 + position/playerState 流 + 调用记录。
class _FlowAudioEngine extends TestAudioEngine {
  int _sessionId = 0;
  int positionListenCount = 0;
  int positionCancelCount = 0;
  int playerStateListenCount = 0;
  int playerStateCancelCount = 0;
  late final StreamController<Duration> _positionController;
  late final StreamController<ja.PlayerState> _playerStateController;

  Duration position = Duration.zero;
  Duration? lastSeek;
  Duration? lastClipStart;
  Duration? lastClipEnd;
  int playCount = 0;
  int pauseKeepSessionCount = 0;
  int stopCount = 0;
  int clearClipCount = 0;
  Completer<void>? _clipCompleter;

  _FlowAudioEngine() {
    _positionController = StreamController<Duration>.broadcast(
      onListen: () => positionListenCount += 1,
      onCancel: () => positionCancelCount += 1,
    );
    _playerStateController = StreamController<ja.PlayerState>.broadcast(
      onListen: () => playerStateListenCount += 1,
      onCancel: () => playerStateCancelCount += 1,
    );
  }

  @override
  Duration get currentPosition => position;

  @override
  Duration get absoluteCurrentPosition => state.clipStart + position;

  @override
  Future<void> seek(Duration pos) async {
    position = pos;
    lastSeek = pos;
  }

  @override
  Future<void> setClip(Duration start, Duration end) async {
    lastClipStart = start;
    lastClipEnd = end;
    state = state.copyWith(clipStart: start, isClipActive: true);
  }

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;
    await setClip(sentence.startTime, sentence.endTime);
    await seek(Duration.zero);
    await play();
    final completer = Completer<void>();
    _clipCompleter = completer;
    await completer.future;
  }

  /// 整篇连续播放：起播后挂起，由 [emitCompleted]（模拟自然播完）解析。
  @override
  Future<void> playToEnd(int sessionId) async {
    if (!isActiveSession(sessionId)) return;
    await play();
    final completer = Completer<void>();
    _clipCompleter = completer;
    await completer.future;
  }

  @override
  Future<void> clearClip() async {
    clearClipCount += 1;
    state = state.copyWith(clipStart: Duration.zero, isClipActive: false);
  }

  @override
  Future<void> play() async {
    playCount += 1;
    isPlaying = true;
  }

  @override
  Future<void> pauseKeepSession() async {
    pauseKeepSessionCount += 1;
    isPlaying = false;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    isPlaying = false;
    _sessionId += 1;
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _sessionId += 1;
  }

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  int get currentSessionId => _sessionId;

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Stream<Duration> get absolutePositionStream => _positionController.stream;

  @override
  Stream<ja.PlayerState> get playerStateStream => _playerStateController.stream;

  void emitPosition(Duration value) {
    position = value;
    _positionController.add(value);
  }

  void emitPlayerState({
    required bool playing,
    required ja.ProcessingState processingState,
  }) {
    isPlaying = playing;
    processingStateValue = processingState;
    _playerStateController.add(ja.PlayerState(playing, processingState));
  }

  /// 模拟一次自然播完。
  ///
  /// 解析当前挂起的 clip/整篇完成。`playing` 仍为 true——贴近 just_audio 在
  /// `completed` 时 `AudioPlayer.playing` 不变的真实行为，验证逻辑不依赖该标志。
  void emitCompleted() {
    _clipCompleter?.complete();
    _clipCompleter = null;
    _playerStateController.add(
      ja.PlayerState(true, ja.ProcessingState.completed),
    );
  }

  Future<void> closeStreams() async {
    await _positionController.close();
    await _playerStateController.close();
  }
}

/// 复用真实 ListeningPractice 逻辑，只开放测试 seed 入口并屏蔽真实持久化。
class _FlowListeningPractice extends ListeningPractice {
  void seed({
    required List<Sentence> sentences,
    required PlaybackSettings settings,
    int currentFullIndex = 0,
    Set<int> bookmarkedIndices = const {},
    PlaylistMode playlistMode = PlaylistMode.full,
  }) {
    final seededSentences = [
      for (final sentence in sentences)
        sentence.copyWith(
          isBookmarked: bookmarkedIndices.contains(sentence.index),
        ),
    ];
    state = state.copyWith(
      currentAudioItem: createTestAudioItem(),
      sentences: seededSentences,
      settings: settings,
      playlistMode: playlistMode,
      bookmarkedIndices: bookmarkedIndices,
      currentFullIndex: currentFullIndex,
      currentBookmarkIndex: playlistMode == PlaylistMode.bookmarks
          ? bookmarkedIndices.firstOrNull
          : null,
    );
  }

  @override
  Future<void> saveCurrentPlaybackState({bool silent = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sentences = [
    Sentence(
      index: 0,
      text: 'Short opener.',
      startTime: Duration.zero,
      endTime: const Duration(milliseconds: 1800),
    ),
    Sentence(
      index: 1,
      text: 'After a quiet gap.',
      startTime: const Duration(milliseconds: 2600),
      endTime: const Duration(milliseconds: 6200),
    ),
    Sentence(
      index: 2,
      text: 'Boundary-adjacent sentence.',
      startTime: const Duration(milliseconds: 6200),
      endTime: const Duration(milliseconds: 7900),
    ),
    Sentence(
      index: 3,
      text: 'Longer explanation sentence.',
      startTime: const Duration(milliseconds: 9100),
      endTime: const Duration(milliseconds: 14300),
    ),
    Sentence(
      index: 4,
      text: 'Tail sentence near audio end.',
      startTime: const Duration(milliseconds: 15100),
      endTime: const Duration(milliseconds: 17600),
    ),
  ];

  late ProviderContainer container;
  late _FlowAudioEngine engine;
  late _FlowListeningPractice lp;

  Future<void> flushBoundary() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> start() async {
    unawaited(lp.play());
    await Future<void>.delayed(Duration.zero);
    engine.isPlaying = true;
  }

  Future<void> completeClip() async {
    engine.emitCompleted();
    await flushBoundary();
    engine.isPlaying = true;
  }

  /// 模拟整篇 gapless 一遍自然播完（解析 [_FlowAudioEngine.playToEnd] 的挂起）。
  /// 不强制设回 isPlaying——续播是否发生由协程的 play() 决定。
  Future<void> completeWhole() async {
    engine.emitCompleted();
    await flushBoundary();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    engine = _FlowAudioEngine();
    container = ProviderContainer(
      overrides: [
        audioEngineProvider.overrideWith(() => engine),
        listeningPracticeProvider.overrideWith(() => _FlowListeningPractice()),
      ],
    );
    lp =
        container.read(listeningPracticeProvider.notifier)
            as _FlowListeningPractice;
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    container.dispose();
    await engine.closeStreams();
  });

  test('reattachLockScreen 自愈：夺回锁屏回调并清除任务残留的逻辑播放态/保活', () async {
    lp.seed(sentences: sentences, settings: const PlaybackSettings());
    await flushBoundary();

    // 模拟某学习/复习任务接管后离开：置空回调 + 残留逻辑播放态覆盖 + 保活在跑。
    engine.setTransportHandlers(onPlay: null, onPause: null);
    engine.setSkipHandlers(onPrevious: null, onNext: null);
    engine.setLogicalPlaying(true);
    final stopKeepAliveBefore = engine.stopKeepAliveCount;

    lp.reattachLockScreen();
    await flushBoundary();

    // Free Player 夺回播放/暂停 + 切句回调（有字幕 → 注册上一句/下一句）。
    expect(engine.lastOnPlay, isNotNull);
    expect(engine.lastOnNext, isNotNull);
    // 清除任务残留：逻辑播放态恢复 null（handler 回退读裸 player）、保活被停。
    expect(engine.logicalPlaying, isNull);
    expect(engine.stopKeepAliveCount, greaterThan(stopKeepAliveBefore));
  });

  test('普通连续播放按 position 更新高亮且不使用 clip', () async {
    lp.seed(sentences: sentences, settings: const PlaybackSettings());

    await start();
    engine.emitPosition(const Duration(milliseconds: 3000));
    await Future<void>.delayed(Duration.zero);
    engine.emitPosition(const Duration(milliseconds: 6500));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(listeningPracticeProvider).currentFullIndex, 2);
    expect(engine.lastClipStart, isNull);
  });

  test('外部暂停会回写逻辑播放态且保留当前播放会话', () async {
    lp.seed(sentences: sentences, settings: const PlaybackSettings());

    await start();
    engine.emitPlayerState(
      playing: false,
      processingState: ja.ProcessingState.ready,
    );
    await flushBoundary();

    final state = container.read(listeningPracticeProvider);
    expect(state.isPlaying, isFalse);
    expect(engine.currentSessionId, 1);
  });

  test('外部恢复播放会回写逻辑播放态', () async {
    lp.seed(sentences: sentences, settings: const PlaybackSettings());

    await start();
    engine.emitPlayerState(
      playing: false,
      processingState: ja.ProcessingState.ready,
    );
    await flushBoundary();
    engine.emitPlayerState(
      playing: true,
      processingState: ja.ProcessingState.ready,
    );
    await flushBoundary();

    expect(container.read(listeningPracticeProvider).isPlaying, isTrue);
  });

  test('resumeListeners 重复调用保持幂等：只恢复一套订阅', () async {
    // build 后首轮 setup 已在 microtask 中挂好 1 套监听。
    await flushBoundary();
    expect(engine.positionListenCount, 1);
    expect(engine.playerStateListenCount, 1);

    lp.suspendListeners();
    await flushBoundary();
    expect(engine.positionCancelCount, 1);
    expect(engine.playerStateCancelCount, 1);

    lp.resumeListeners();
    lp.resumeListeners();
    await flushBoundary();

    expect(engine.positionListenCount, 2, reason: '重复 resume 只应新增 1 套订阅');
    expect(
      engine.playerStateListenCount,
      2,
      reason: '重复 resume 只应新增 1 套 playerState 订阅',
    );
  });

  test('全文与收藏 tab 各自保存独立设置', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(playbackSpeed: 1.0),
      bookmarkedIndices: {0, 2},
    );

    await lp.updateSettings(
      const PlaybackSettings(playbackSpeed: 1.2, showTranscript: false),
    );
    await lp.setPlaylistMode(PlaylistMode.bookmarks);
    await lp.updateSettings(
      const PlaybackSettings(
        playbackSpeed: 0.8,
        singleSentenceMode: true,
        loopSentence: true,
      ),
    );
    await lp.setPlaylistMode(PlaylistMode.full);

    final state = container.read(listeningPracticeProvider);
    expect(state.fullSettings.playbackSpeed, 1.2);
    expect(state.fullSettings.showTranscript, isFalse);
    expect(state.fullSettings.singleSentenceMode, isFalse);
    expect(state.bookmarkSettings.playbackSpeed, 0.8);
    expect(state.bookmarkSettings.singleSentenceMode, isTrue);
    expect(state.bookmarkSettings.loopSentence, isTrue);
    expect(state.settings.playbackSpeed, 1.2);
  });

  test('切换到收藏 tab 时立即应用收藏 tab 的倍速设置', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(playbackSpeed: 1.0),
      bookmarkedIndices: {0, 2},
    );
    lp.state = lp.state.copyWith(
      bookmarkSettings: const PlaybackSettings(playbackSpeed: 0.8),
    );

    await lp.setPlaylistMode(PlaylistMode.bookmarks);

    expect(
      container.read(listeningPracticeProvider).settings.playbackSpeed,
      0.8,
    );
    expect(engine.playbackSpeed, 0.8);
  });

  test('切换到收藏 tab 时默认启用单句循环 1 次 + 1 秒', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(playbackSpeed: 1.0),
      bookmarkedIndices: {0, 2},
    );

    await lp.setPlaylistMode(PlaylistMode.bookmarks);

    final settings = container.read(listeningPracticeProvider).settings;
    expect(settings.loopSentence, isTrue);
    expect(settings.sentenceLoopCount, 1);
    expect(settings.sentenceInterval, const Duration(seconds: 1));
  });

  test('切换 tab 时停止上一个 tab 播放，且新 tab 不自动续播', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(playbackSpeed: 1.0),
      bookmarkedIndices: {2, 4},
    );

    await start();
    expect(engine.playCount, 1);
    expect(engine.isPlaying, isTrue);

    await lp.setPlaylistMode(PlaylistMode.bookmarks);

    final state = container.read(listeningPracticeProvider);
    expect(state.playlistMode, PlaylistMode.bookmarks);
    expect(state.currentBookmarkIndex, 2);
    expect(engine.stopCount, 1);
    expect(engine.playCount, 1);
    expect(engine.isPlaying, isFalse);
    expect(engine.lastSeek, const Duration(milliseconds: 6200));
  });

  test('播放中打开单句循环：当前句不中断，播完后从当前句句首开始循环', () async {
    lp.seed(sentences: sentences, settings: const PlaybackSettings());

    await start();
    expect(engine.playCount, 1);
    expect(engine.lastClipStart, isNull);

    await lp.updateSettings(
      const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
      ),
    );

    expect(engine.playCount, 1);
    expect(engine.lastClipStart, isNull);

    engine.emitPosition(const Duration(milliseconds: 3000));
    await flushBoundary();

    expect(container.read(listeningPracticeProvider).currentFullIndex, 0);
    expect(engine.playCount, 2);
    expect(engine.lastClipStart, Duration.zero);
    expect(engine.lastClipEnd, const Duration(milliseconds: 1800));
    expect(engine.lastSeek, Duration.zero);

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 0);
    expect(engine.lastClipStart, Duration.zero);
  });

  test('暂停时打开单句循环：只改设置，不自动播放', () async {
    lp.seed(sentences: sentences, settings: const PlaybackSettings());

    await lp.updateSettings(
      const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
      ),
    );

    final state = container.read(listeningPracticeProvider);
    expect(state.settings.loopSentence, isTrue);
    expect(engine.playCount, 0);
    expect(engine.lastSeek, isNull);
    expect(engine.lastClipStart, isNull);
  });

  test('有限单句循环：每个句子都独立循环 2 次后再进入下一句', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
      ),
    );

    await start();
    expect(engine.lastClipStart, Duration.zero);
    expect(engine.lastClipEnd, const Duration(milliseconds: 1800));

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 0);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, Duration.zero);

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 1);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, const Duration(milliseconds: 2600));
    expect(engine.lastClipEnd, const Duration(milliseconds: 6200));

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 1);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, const Duration(milliseconds: 2600));

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 2);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, const Duration(milliseconds: 6200));
    expect(engine.lastClipEnd, const Duration(milliseconds: 7900));
  });

  test('单句循环：sentenceRepeatsDone 镜像到 state 供状态栏展示当前句第几遍', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
      ),
    );

    await start();
    await flushBoundary();
    // 第 0 句第 1 遍播放中 → 已完成 0 → 状态栏显示 1/2。
    expect(container.read(listeningPracticeProvider).sentenceRepeatsDone, 0);

    await completeClip(); // 第 0 句第 1 遍完成 → 重播第 2 遍
    expect(
      container.read(listeningPracticeProvider).sentenceRepeatsDone,
      1,
      reason: '第 0 句第 2 遍播放中 → 状态栏显示 2/2',
    );

    await completeClip(); // 第 0 句第 2 遍完成 → 进入第 1 句，计数归零
    final s = container.read(listeningPracticeProvider);
    expect(s.currentFullIndex, 1);
    expect(s.sentenceRepeatsDone, 0, reason: '新句第 1 遍 → 状态栏显示 1/2');
  });

  test('单句循环：暂停后续播保留已完成遍数，不从第一遍重新开始', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 3,
        sentenceInterval: Duration.zero,
      ),
    );

    await start();
    await completeClip(); // 第 1 遍完成 → 已完成 1，第 2 遍播放中
    expect(container.read(listeningPracticeProvider).sentenceRepeatsDone, 1);

    // 第 2 遍播放到中途（position > 0），暂停。
    engine.position = const Duration(milliseconds: 500);
    await lp.pause();
    expect(
      container.read(listeningPracticeProvider).sentenceRepeatsDone,
      1,
      reason: '暂停不清零遍数',
    );

    // 续播：应保留已完成 1 遍，从「记住的进度」继续，而非回到第 1 遍。
    await start();
    expect(
      container.read(listeningPracticeProvider).sentenceRepeatsDone,
      1,
      reason: '续播保留已完成遍数（修复前会被重置为 0）',
    );

    await completeClip(); // 第 2 遍完成 → 已完成 2，第 3 遍播放中
    expect(container.read(listeningPracticeProvider).sentenceRepeatsDone, 2);

    await completeClip(); // 第 3 遍完成 → 满 3 遍进入第 1 句，计数归零
    final s = container.read(listeningPracticeProvider);
    expect(s.currentFullIndex, 1);
    expect(s.sentenceRepeatsDone, 0);
  });

  test('整篇循环播放中开启单句循环：整篇遍数不被重置（两套循环状态互不影响）', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopWhole: true,
        wholeLoopCount: 0, // 无限整篇循环
        wholeInterval: Duration.zero,
      ),
    );

    await start();
    await completeWhole(); // 整篇播完第 1 遍 → wholeLoopsDone=1，回卷重播
    expect(container.read(listeningPracticeProvider).wholeLoopsDone, 1);

    // 播放中开启单句循环 → 标记待交接（不立即打断当前播放态）。
    await lp.updateSettings(
      const PlaybackSettings(
        loopWhole: true,
        wholeLoopCount: 0,
        wholeInterval: Duration.zero,
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
      ),
    );

    // 跨句边界触发从 gapless 交接到句级循环。
    engine.emitPosition(const Duration(milliseconds: 3000));
    await flushBoundary();

    final s = container.read(listeningPracticeProvider);
    expect(s.wholeLoopsDone, 1, reason: '开启单句循环不应清零整篇已播遍数');
    expect(s.sentenceRepeatsDone, 0, reason: '新进入单句循环，当前句从第 1 遍开始');
  });

  test('单句循环：解析延迟暂停在当前句播完后才暂停，停在本句并保留遍数', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 3,
        sentenceInterval: Duration.zero,
      ),
    );

    await start();
    await completeClip(); // 第 1 遍完成 → 已完成 1，第 2 遍播放中
    expect(container.read(listeningPracticeProvider).sentenceRepeatsDone, 1);

    // 第 2 遍播放中点击解析：请求延迟暂停，但当前仍在播放、未中断。
    await lp.pauseAfterCurrentSentence();
    expect(
      container.read(listeningPracticeProvider).isPlaying,
      isTrue,
      reason: '当前句尚未播完，不立即暂停',
    );
    expect(container.read(listeningPracticeProvider).sentenceRepeatsDone, 1);

    // 第 2 遍自然播完 → 此时才暂停，停在第 0 句，保留已完成 2 遍。
    await completeClip();
    final paused = container.read(listeningPracticeProvider);
    expect(paused.isPlaying, isFalse, reason: '当前句播完后才暂停');
    expect(paused.currentFullIndex, 0, reason: '停在本句，不推进');
    expect(paused.sentenceRepeatsDone, 2);

    // 续播：从记住的 2 遍继续，再播一遍即满 3 遍进入下一句。
    await start();
    expect(container.read(listeningPracticeProvider).sentenceRepeatsDone, 2);
    await completeClip();
    final resumed = container.read(listeningPracticeProvider);
    expect(resumed.currentFullIndex, 1);
    expect(resumed.sentenceRepeatsDone, 0);
  });

  test('整篇 gapless：解析延迟暂停在跨句边界暂停并停留在刚播完的句子', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(loopSentence: false),
      currentFullIndex: 1,
    );

    await start();
    expect(container.read(listeningPracticeProvider).isPlaying, isTrue);

    // 第 1 句播放中点击解析：请求延迟暂停，当前不中断。
    await lp.pauseAfterCurrentSentence();
    expect(container.read(listeningPracticeProvider).isPlaying, isTrue);

    // 位置推进越过第 1 句进入第 2 句（6300ms ∈ 第 2 句[6200,7900]）→ 在边界暂停，
    // 并回退到刚播完的第 1 句，使解析面板停留在用户点击的句子上。
    engine.emitPosition(const Duration(milliseconds: 6300));
    await flushBoundary();

    final paused = container.read(listeningPracticeProvider);
    expect(paused.isPlaying, isFalse, reason: '跨句边界后暂停');
    expect(paused.currentFullIndex, 1, reason: '停留在刚播完的第 1 句，不滑到第 2 句');
    expect(
      engine.lastSeek,
      const Duration(milliseconds: 2600),
      reason: '回到第 1 句句首',
    );
  });

  test('未播放时 pauseAfterCurrentSentence 退化为立即暂停', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 3,
      ),
    );
    // 未起播，isPlaying 为 false。
    expect(container.read(listeningPracticeProvider).isPlaying, isFalse);
    await lp.pauseAfterCurrentSentence();
    expect(container.read(listeningPracticeProvider).isPlaying, isFalse);
  });

  test('无限单句循环：多次越界都回到当前句句首', () async {
    lp.seed(
      sentences: sentences,
      currentFullIndex: 2,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 0,
        sentenceInterval: Duration.zero,
      ),
    );

    await start();

    for (var i = 0; i < 3; i++) {
      await completeClip();
      expect(container.read(listeningPracticeProvider).currentFullIndex, 2);
      expect(engine.lastSeek, Duration.zero);
      expect(engine.lastClipStart, const Duration(milliseconds: 6200));
      expect(engine.lastClipEnd, const Duration(milliseconds: 7900));
    }
  });

  test('收藏模式：跳过非收藏句，收藏句也能各自循环 2 次', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
      ),
      bookmarkedIndices: {0, 2, 4},
      playlistMode: PlaylistMode.bookmarks,
    );

    await start();

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentBookmarkIndex, 0);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, Duration.zero);

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentBookmarkIndex, 2);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, const Duration(milliseconds: 6200));

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentBookmarkIndex, 2);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, const Duration(milliseconds: 6200));

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentBookmarkIndex, 4);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, const Duration(milliseconds: 15100));
  });

  test('播放中 seek 到新句后，单句循环计数从新句重新开始', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
      ),
    );

    await start();
    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 0);

    await lp.seekAbsolute(const Duration(milliseconds: 9500));
    engine.isPlaying = true;
    expect(container.read(listeningPracticeProvider).currentFullIndex, 3);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, const Duration(milliseconds: 9100));
    expect(engine.lastClipEnd, const Duration(milliseconds: 14300));

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 3);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, const Duration(milliseconds: 9100));
  });

  test('播放中在收藏 tab 点击进度条不会先清空 clip', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
      ),
      bookmarkedIndices: {0, 2, 4},
      playlistMode: PlaylistMode.bookmarks,
    );

    await start();
    expect(engine.lastClipStart, Duration.zero);

    await lp.seekAbsolute(const Duration(milliseconds: 9500));

    expect(container.read(listeningPracticeProvider).currentBookmarkIndex, 2);
    expect(engine.clearClipCount, 0);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, const Duration(milliseconds: 6200));
    expect(engine.lastClipEnd, const Duration(milliseconds: 7900));
  });

  test('手动切到下一句后，有限单句循环从新句第一次开始', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
      ),
    );

    await start();
    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 0);

    await lp.nextSentence();
    engine.isPlaying = true;
    expect(container.read(listeningPracticeProvider).currentFullIndex, 1);
    expect(engine.lastClipStart, const Duration(milliseconds: 2600));

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 1);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, const Duration(milliseconds: 2600));
  });

  test('播放中关闭单句循环：当前 clip 播完后切回 gapless，不重播当前句', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
      ),
    );

    await start();
    expect(engine.lastClipStart, Duration.zero);
    expect(engine.playCount, 1);

    await lp.updateSettings(const PlaybackSettings());

    expect(engine.playCount, 1);
    expect(container.read(listeningPracticeProvider).currentFullIndex, 0);

    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 1);
    expect(engine.playCount, 2);
    expect(engine.lastSeek, const Duration(milliseconds: 2600));

    engine.emitPosition(const Duration(milliseconds: 6500));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(listeningPracticeProvider).currentFullIndex, 2);
    expect(engine.lastClipStart, Duration.zero);
  });

  test('全文非循环播完后，再点播放从第 1 句重新开始', () async {
    lp.seed(sentences: sentences, settings: const PlaybackSettings());

    await start();
    engine.emitPosition(const Duration(milliseconds: 17600));
    await Future<void>.delayed(Duration.zero);
    engine.emitCompleted();
    await flushBoundary();

    expect(container.read(listeningPracticeProvider).currentFullIndex, 4);
    // 自然播完保留媒体会话（锁屏控件不消失），暂停而非 stop。
    expect(engine.pauseKeepSessionCount, 1);
    expect(engine.stopCount, 0);
    expect(engine.isPlaying, isFalse);

    await lp.play();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(listeningPracticeProvider).currentFullIndex, 0);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.playCount, 2);
  });

  test('有字幕恢复进入时存档位置停在结尾：首次点击从第 1 句重播，不从最后一句续播', () async {
    // 模拟 _restorePlaybackState 把高亮恢复到最后一句、引擎 seek 到结尾位置：
    // 本次 session 未真正播过，processingState 仍是 ready、_awaitingReplayFromStart
    // 为 false——此前会误判为「从当前句（最后一句）续播」。
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(),
      currentFullIndex: 4,
    );
    engine.setTotalDuration(const Duration(milliseconds: 17600));
    engine.position = const Duration(milliseconds: 17600);

    await lp.play();
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(listeningPracticeProvider).currentFullIndex,
      0,
      reason: '存档位置在结尾应识别为「已播完」，从第 1 句重播而非从最后一句',
    );
    expect(engine.lastSeek, Duration.zero, reason: '从第 1 句句首起播');
    expect(engine.playCount, 1);
  });

  test('收藏非循环播完后，再点播放从收藏列表第 1 句重新开始', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(),
      bookmarkedIndices: {1, 4},
      playlistMode: PlaylistMode.bookmarks,
    );
    lp.state = lp.state.copyWith(
      currentBookmarkIndex: 4,
      lastPlayedBookmarkIndex: 4,
    );

    await start();
    engine.emitCompleted();
    await flushBoundary();

    final endedState = container.read(listeningPracticeProvider);
    expect(endedState.currentBookmarkIndex, 4);
    expect(engine.pauseKeepSessionCount, 1);
    expect(engine.stopCount, 0);
    expect(engine.isPlaying, isFalse);

    await lp.play();
    await Future<void>.delayed(Duration.zero);

    final restartedState = container.read(listeningPracticeProvider);
    expect(restartedState.currentBookmarkIndex, 1);
    expect(engine.lastClipStart, const Duration(milliseconds: 2600));
    expect(engine.lastClipEnd, const Duration(milliseconds: 6200));
    expect(engine.playCount, 2);
  });

  test('单句循环与整篇循环同开：每句 2 遍，末尾回卷后重新计数', () async {
    final threeSentences = sentences.take(3).toList();
    lp.seed(
      sentences: threeSentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 2,
        sentenceInterval: Duration.zero,
        loopWhole: true,
        wholeLoopCount: 2,
        wholeInterval: Duration.zero,
      ),
    );

    await start();

    for (final index in [0, 1, 2]) {
      await completeClip();
      expect(container.read(listeningPracticeProvider).currentFullIndex, index);
      expect(engine.lastSeek, Duration.zero);
      expect(engine.lastClipStart, threeSentences[index].startTime);

      await completeClip();
      final expected = index == 2 ? 0 : index + 1;
      expect(
        container.read(listeningPracticeProvider).currentFullIndex,
        expected,
      );
      expect(engine.lastSeek, Duration.zero);
      expect(engine.lastClipStart, threeSentences[expected].startTime);
    }

    // 第二遍的第 0 句仍然要重新计数，不能继承上一遍末句的完成次数。
    await completeClip();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 0);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.lastClipStart, Duration.zero);
  });

  test('整篇循环 3 遍：恰好播放 3 遍后停止（不多不少）', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopWhole: true,
        wholeLoopCount: 3,
        wholeInterval: Duration.zero,
      ),
    );

    await start();
    await flushBoundary();
    expect(engine.playCount, 1, reason: '第 1 遍起播');
    var s = container.read(listeningPracticeProvider);
    expect(s.isPlaying, isTrue);
    expect(s.wholeLoopsDone, 0, reason: '第 1 遍播放中，已完成 0 遍 → 状态栏显示 1/3');

    await completeWhole(); // 第 1 遍完成 → 回卷起播第 2 遍
    expect(engine.playCount, 2);
    expect(engine.stopCount, 0);
    expect(
      container.read(listeningPracticeProvider).wholeLoopsDone,
      1,
      reason: '第 2 遍播放中 → 状态栏显示 2/3',
    );

    await completeWhole(); // 第 2 遍完成 → 第 3 遍
    expect(engine.playCount, 3);
    expect(engine.stopCount, 0);
    s = container.read(listeningPracticeProvider);
    expect(s.isPlaying, isTrue);
    expect(s.wholeLoopsDone, 2, reason: '第 3 遍播放中 → 状态栏显示 3/3');

    await completeWhole(); // 第 3 遍完成 → 暂停保留会话
    expect(engine.playCount, 3, reason: '不再起播第 4 遍');
    expect(engine.pauseKeepSessionCount, 1);
    expect(engine.stopCount, 0);
    expect(container.read(listeningPracticeProvider).isPlaying, isFalse);
  });

  test('整篇循环：同一遍内重复 completed 事件不会多计数提前停止', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopWhole: true,
        wholeLoopCount: 3,
        wholeInterval: Duration.zero,
      ),
    );

    await start();
    await flushBoundary();

    // 每遍结束连发两次 completed（模拟 just_audio 重复/滞后事件）。
    // 第二次发生在协程尚未重新挂起时，应被当作空事件忽略，不额外计数。
    for (var i = 0; i < 3; i++) {
      engine.emitCompleted();
      engine.emitCompleted(); // 重复事件
      await flushBoundary();
    }

    // 仍恰好播 3 遍后停止（保留会话）。
    expect(engine.playCount, 3);
    expect(engine.pauseKeepSessionCount, 1);
    expect(engine.stopCount, 0);
    expect(container.read(listeningPracticeProvider).isPlaying, isFalse);
  });

  test('整篇循环间隔：每遍之间按 wholeInterval 停顿后再回卷', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopWhole: true,
        wholeLoopCount: 2,
        wholeInterval: Duration(milliseconds: 50),
      ),
    );

    await start();
    await flushBoundary();
    expect(engine.playCount, 1);

    // 第 1 遍完成：先停顿 50ms，停顿期间还不应起播第 2 遍。
    engine.emitCompleted();
    await flushBoundary();
    expect(engine.playCount, 1, reason: '停顿期间不起播');

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(engine.playCount, 2, reason: '停顿结束后回卷起播第 2 遍');
  });

  test('整篇循环播完后图标恢复「播放」，单击从第 1 句重新开始', () async {
    lp.seed(
      sentences: sentences,
      currentFullIndex: 0,
      settings: const PlaybackSettings(
        loopWhole: true,
        wholeLoopCount: 1,
        wholeInterval: Duration.zero,
      ),
    );

    await start();
    // 播放中高亮推进到末句。
    engine.emitPosition(const Duration(milliseconds: 17600));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(listeningPracticeProvider).currentFullIndex, 4);

    await completeWhole(); // 唯一一遍完成 → 暂停保留会话
    final ended = container.read(listeningPracticeProvider);
    expect(engine.pauseKeepSessionCount, 1);
    expect(engine.stopCount, 0);
    expect(ended.isPlaying, isFalse, reason: '逻辑播放态为 false → 图标显示「播放」');
    expect(ended.currentFullIndex, 4, reason: '高亮停在末句属正常');

    // 图标是「播放」，单击即 play()（不会先触发 pause）→ 从第 1 句重新开始。
    engine.lastSeek = null;
    await lp.play();
    await flushBoundary();
    expect(container.read(listeningPracticeProvider).currentFullIndex, 0);
    expect(engine.lastSeek, Duration.zero);
    expect(container.read(listeningPracticeProvider).isPlaying, isTrue);
  });

  test('整篇循环暂停后续播：保留已完成遍数，播满剩余遍数后停止', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopWhole: true,
        wholeLoopCount: 2,
        wholeInterval: Duration.zero,
      ),
    );

    await start();
    await flushBoundary();

    await completeWhole(); // 第 1 遍完成，已进入第 2 遍
    expect(engine.stopCount, 0);

    // 第 2 遍播放途中暂停（位置 > 0 以走「精确位置续播」分支）。
    engine.emitPosition(const Duration(milliseconds: 3000));
    await Future<void>.delayed(Duration.zero);
    await lp.pause();
    expect(container.read(listeningPracticeProvider).isPlaying, isFalse);

    // 续播：保留 wholeLoopsDone=1，再播完这一遍即应停止（不应回到 0 重新数）。
    await lp.play();
    await flushBoundary();
    expect(container.read(listeningPracticeProvider).isPlaying, isTrue);
    expect(
      engine.position,
      const Duration(milliseconds: 3000),
      reason: '从暂停位置续播，不回卷句首（未重新 seek 到 0）',
    );

    await completeWhole(); // 第 2 遍完成 → 暂停保留会话
    expect(engine.pauseKeepSessionCount, 1);
    expect(engine.stopCount, 0);
    expect(container.read(listeningPracticeProvider).isPlaying, isFalse);
  });

  test('整篇循环播放中切下一句：保留已完成遍数，不重置为第一遍', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopWhole: true,
        wholeLoopCount: 3,
        wholeInterval: Duration.zero,
      ),
    );

    await start();
    await flushBoundary();

    await completeWhole(); // 第 1 遍播完 → wholeLoopsDone=1，回卷续播第 2 遍
    expect(container.read(listeningPracticeProvider).wholeLoopsDone, 1);

    await lp.nextSentence();
    await flushBoundary();

    expect(
      container.read(listeningPracticeProvider).wholeLoopsDone,
      1,
      reason: '切句是同一遍内换句，整篇遍数应保留',
    );
    expect(container.read(listeningPracticeProvider).isPlaying, isTrue);
  });

  test('整篇循环播放中切上一句：保留已完成遍数', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopWhole: true,
        wholeLoopCount: 3,
        wholeInterval: Duration.zero,
      ),
      currentFullIndex: 2,
    );

    await start();
    await flushBoundary();

    await completeWhole(); // wholeLoopsDone=1
    expect(container.read(listeningPracticeProvider).wholeLoopsDone, 1);

    // 回卷后高亮在第 0 句，先推进到第 2 句再切上一句。
    await lp.nextSentence();
    await lp.nextSentence();
    await lp.previousSentence();
    await flushBoundary();

    expect(container.read(listeningPracticeProvider).wholeLoopsDone, 1);
  });

  group('无字幕音频', () {
    test('起播：进入确定性循环、认领 session、逻辑播放态为真', () async {
      lp.seed(sentences: const [], settings: const PlaybackSettings());

      await start();
      await flushBoundary();

      expect(container.read(listeningPracticeProvider).isPlaying, isTrue);
      expect(engine.playCount, 1);
      // 关键：必须认领 session（≠ 初值 -1），否则被动状态同步对无字幕失效。
      expect(engine.currentSessionId, isNot(-1));
    });

    test('自然播完：逻辑播放态置假、保留会话停在暂停态（修复按钮卡暂停）', () async {
      lp.seed(sentences: const [], settings: const PlaybackSettings());

      await start();
      await flushBoundary();

      await completeWhole(); // 解析 playToEnd 的挂起 → 自然播完

      expect(
        container.read(listeningPracticeProvider).isPlaying,
        isFalse,
        reason: '播完后逻辑播放态应为假，按钮回到「播放」图标',
      );
      expect(engine.pauseKeepSessionCount, 1);
      expect(engine.stopCount, 0);
    });

    test('播完后再次播放：显式 seek(0) 从头重播（修复点了也播不起来）', () async {
      lp.seed(sentences: const [], settings: const PlaybackSettings());

      await start();
      await flushBoundary();
      await completeWhole();

      engine.lastSeek = null;
      await lp.play();
      await flushBoundary();

      expect(
        engine.lastSeek,
        Duration.zero,
        reason: '播完后重播必须 seek 回开头，just_audio 对 completed 直接 play 不回头',
      );
      expect(container.read(listeningPracticeProvider).isPlaying, isTrue);
    });

    test('恢复进入时存档位置停在结尾：首次点击 seek(0) 从头播（修复需点两次）', () async {
      lp.seed(sentences: const [], settings: const PlaybackSettings());
      // 模拟 _restorePlaybackState 把引擎 seek 到上次的结尾位置：position 等于
      // 总时长、processingState 仍是 ready（非 completed）、未置 awaitingReplay。
      engine.setTotalDuration(const Duration(seconds: 42));
      engine.position = const Duration(seconds: 42);

      unawaited(lp.play());
      await flushBoundary();

      expect(
        engine.lastSeek,
        Duration.zero,
        reason: '存档位置在结尾应识别为「已播完」，首次点击即从头重播而非从结尾续播',
      );
      expect(engine.playCount, 1, reason: '一次点击就起播');
      expect(container.read(listeningPracticeProvider).isPlaying, isTrue);
    });

    test('恢复进入时存档位置在中段：首次点击从落点续播，不 seek(0)', () async {
      lp.seed(sentences: const [], settings: const PlaybackSettings());
      engine.setTotalDuration(const Duration(seconds: 42));
      engine.position = const Duration(seconds: 20);

      unawaited(lp.play());
      await flushBoundary();

      expect(engine.lastSeek, isNull, reason: '中段位置是真正的续播，不应回卷到开头');
      expect(engine.playCount, 1);
    });

    test('整篇循环开启：播完一遍后回卷重播，不停止', () async {
      lp.seed(
        sentences: const [],
        settings: const PlaybackSettings(
          loopWhole: true,
          wholeLoopCount: 2,
          wholeInterval: Duration.zero,
        ),
      );

      await start();
      await flushBoundary();

      // 第 1 遍播完 → 回卷重播第 2 遍（不暂停）。
      await completeWhole();
      expect(container.read(listeningPracticeProvider).wholeLoopsDone, 1);
      expect(engine.pauseKeepSessionCount, 0, reason: '未播满，不应停止');
      expect(engine.lastSeek, Duration.zero, reason: '回卷到开头');
      expect(engine.playCount, 2, reason: '重新起播第 2 遍');
      expect(container.read(listeningPracticeProvider).isPlaying, isTrue);

      // 第 2 遍播完 → 已满 2 遍 → 停在暂停态。
      await completeWhole();
      expect(container.read(listeningPracticeProvider).wholeLoopsDone, 2);
      expect(engine.pauseKeepSessionCount, 1);
      expect(container.read(listeningPracticeProvider).isPlaying, isFalse);
    });

    test('seekRelative 前进：按相对位置 seek，不依赖字幕', () async {
      lp.seed(sentences: const [], settings: const PlaybackSettings());

      await start();
      engine.position = const Duration(milliseconds: 5000);
      await flushBoundary();

      await lp.seekRelative(const Duration(seconds: 10));

      expect(engine.lastSeek, const Duration(milliseconds: 15000));
    });

    test('seekRelative 后退到负值：钳制到 0', () async {
      lp.seed(sentences: const [], settings: const PlaybackSettings());

      await start();
      engine.position = const Duration(milliseconds: 3000);
      await flushBoundary();

      await lp.seekRelative(const Duration(seconds: -10));

      expect(engine.lastSeek, Duration.zero);
    });
  });
}
