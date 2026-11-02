/// 跨句自动保存进度回归测试
///
/// 验证「每跨一句即持久化播放进度」的编排：
/// 1. gapless 连续播放跨句（位置流推进 currentFullIndex）触发保存；
/// 2. 同一句内的位置事件不重复触发保存（仅索引变化才存）；
/// 3. 边界推进（单句循环重播）经 _resumeAt 触发保存；
/// 4. 起播本身（play → _resumeAt）触发一次保存。
///
/// 通过计数子类隔离编排逻辑，不依赖真实 audioPlayer / 数据库。
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import '../../helpers/mock_providers.dart';

/// 测试用 AudioEngine：真实 session 计数 + 可控位置/状态流。
class _SessionAudioEngine extends TestAudioEngine {
  int _sessionId = 0;
  final _positionController = StreamController<Duration>.broadcast();
  final _playerStateController = StreamController<ja.PlayerState>.broadcast();

  Duration position = Duration.zero;
  Completer<void>? _clipCompleter;

  @override
  Duration get currentPosition => position;

  @override
  Future<void> seek(Duration pos) async {}

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;
    final completer = Completer<void>();
    _clipCompleter = completer;
    await completer.future;
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

  void emitPosition(Duration position) => _positionController.add(position);

  void emitPlayerState(ja.PlayerState playerState) {
    if (playerState.processingState == ja.ProcessingState.completed) {
      _clipCompleter?.complete();
      _clipCompleter = null;
    }
    _playerStateController.add(playerState);
  }

  void closeStreams() {
    _positionController.close();
    _playerStateController.close();
  }
}

/// 可注入 state 的 ListeningPractice 子类：记录 saveCurrentPlaybackState 调用次数，
/// 避免触达真实 audioPlayer / DB。
class _CountingListeningPractice extends ListeningPractice {
  int saveCount = 0;
  bool lastSilent = false;

  void seed({
    required List<Sentence> sentences,
    required PlaybackSettings settings,
    required int currentFullIndex,
  }) {
    state = state.copyWith(
      currentAudioItem: createTestAudioItem(),
      sentences: sentences,
      settings: settings,
      currentFullIndex: currentFullIndex,
    );
  }

  @override
  Future<void> saveCurrentPlaybackState({bool silent = false}) async {
    saveCount += 1;
    lastSilent = silent;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const continuousSettings = PlaybackSettings();

  final sentences = [
    Sentence(
      index: 0,
      text: 'First.',
      startTime: Duration.zero,
      endTime: const Duration(seconds: 3),
    ),
    Sentence(
      index: 1,
      text: 'Second.',
      startTime: const Duration(seconds: 3),
      endTime: const Duration(seconds: 6),
    ),
    Sentence(
      index: 2,
      text: 'Third.',
      startTime: const Duration(seconds: 6),
      endTime: const Duration(seconds: 9),
    ),
  ];

  late ProviderContainer container;
  late _SessionAudioEngine engine;
  late _CountingListeningPractice lp;

  setUp(() async {
    engine = _SessionAudioEngine();
    container = ProviderContainer(
      overrides: dedupeOverrides([
        audioEngineProvider.overrideWith(() => engine),
        studyTimeServiceProvider.overrideWithValue(FakeStudyTimeService()),
        listeningPracticeProvider.overrideWith(
          () => _CountingListeningPractice(),
        ),
      ]),
    );
    lp =
        container.read(listeningPracticeProvider.notifier)
            as _CountingListeningPractice;
    // 等待 build 内 _setupListeners 的 microtask 完成订阅
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() {
    container.dispose();
    engine.closeStreams();
  });

  /// 起播并把计数清零，隔离 play→_resumeAt 触发的首次保存。
  Future<void> startAndReset() async {
    unawaited(lp.play());
    await Future<void>.delayed(Duration.zero);
    engine.isPlaying = true;
    lp.saveCount = 0;
  }

  test('起播（play → _resumeAt）触发一次进度保存', () async {
    lp.seed(
      sentences: sentences,
      settings: continuousSettings,
      currentFullIndex: 0,
    );
    unawaited(lp.play());
    await Future<void>.delayed(Duration.zero);

    expect(lp.saveCount, 1);
    expect(lp.lastSilent, isTrue); // 自动保存走静默路径
  });

  test('gapless 连续播放跨句触发保存', () async {
    lp.seed(
      sentences: sentences,
      settings: continuousSettings,
      currentFullIndex: 0,
    );
    await startAndReset();

    // 位置进入第 1 句（3-6s）→ 跨句 → 保存一次
    engine.emitPosition(const Duration(seconds: 3));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(listeningPracticeProvider).currentFullIndex, 1);
    expect(lp.saveCount, 1);
  });

  test('同一句内的位置事件不重复触发保存', () async {
    lp.seed(
      sentences: sentences,
      settings: continuousSettings,
      currentFullIndex: 0,
    );
    await startAndReset();

    // 进入第 1 句 → 1 次保存
    engine.emitPosition(const Duration(seconds: 3));
    await Future<void>.delayed(Duration.zero);
    // 仍在第 1 句内多帧推进 → 不再保存
    engine.emitPosition(const Duration(milliseconds: 3500));
    engine.emitPosition(const Duration(milliseconds: 4000));
    await Future<void>.delayed(Duration.zero);

    expect(lp.saveCount, 1);
  });

  test('单句循环：clip 完成后重播并触发保存', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 0, // ∞ 无限重复当前句
        sentenceInterval: Duration.zero,
      ),
      currentFullIndex: 1, // 第 1 句 3-6s
    );
    await startAndReset();

    // clip 完成 → 单句循环重播当前句 → 保存
    engine.emitPlayerState(ja.PlayerState(false, ja.ProcessingState.completed));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(listeningPracticeProvider).currentFullIndex, 1);
    expect(lp.saveCount, greaterThanOrEqualTo(1));
  });
}
