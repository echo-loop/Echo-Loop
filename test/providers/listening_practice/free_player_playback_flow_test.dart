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
  final _positionController = StreamController<Duration>.broadcast();
  final _playerStateController = StreamController<ja.PlayerState>.broadcast();

  Duration position = Duration.zero;
  Duration? lastSeek;
  Duration? lastClipStart;
  Duration? lastClipEnd;
  int playCount = 0;
  int pauseKeepSessionCount = 0;
  int stopCount = 0;
  int clearClipCount = 0;
  Completer<void>? _clipCompleter;

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
    expect(engine.stopCount, 1);
    expect(engine.isPlaying, isFalse);

    await lp.play();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(listeningPracticeProvider).currentFullIndex, 0);
    expect(engine.lastSeek, Duration.zero);
    expect(engine.playCount, 2);
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
    expect(engine.stopCount, 1);
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
    expect(container.read(listeningPracticeProvider).isPlaying, isTrue);

    await completeWhole(); // 第 1 遍完成 → 回卷起播第 2 遍
    expect(engine.playCount, 2);
    expect(engine.stopCount, 0);

    await completeWhole(); // 第 2 遍完成 → 第 3 遍
    expect(engine.playCount, 3);
    expect(engine.stopCount, 0);
    expect(container.read(listeningPracticeProvider).isPlaying, isTrue);

    await completeWhole(); // 第 3 遍完成 → 停止
    expect(engine.playCount, 3, reason: '不再起播第 4 遍');
    expect(engine.stopCount, 1);
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

    // 仍恰好播 3 遍后停止。
    expect(engine.playCount, 3);
    expect(engine.stopCount, 1);
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

    await completeWhole(); // 唯一一遍完成 → 停止
    final ended = container.read(listeningPracticeProvider);
    expect(engine.stopCount, 1);
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

    await completeWhole(); // 第 2 遍完成 → 停止
    expect(engine.stopCount, 1);
    expect(container.read(listeningPracticeProvider).isPlaying, isFalse);
  });
}
