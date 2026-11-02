/// 循环开关持久化与加载新音频行为回归测试
///
/// 验证：
/// 1. 加载一条新音频时，全文与收藏 tab 的循环设置保持不变。
/// 2. 重新加载同一音频（loadAudio 早返回路径）不动循环开关。
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/app_database.dart' hide AudioItem;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import '../../helpers/mock_providers.dart';

/// 测试用引擎：loadAudio/loadTranscript 不触碰真实文件，直接返回预置句子。
class _LoadAudioEngine extends TestAudioEngine {
  final List<Sentence> sentences;
  _LoadAudioEngine(this.sentences);

  @override
  Future<Duration?> loadAudio(
    AudioItem audioItem,
    double speed, {
    String? subtitle,
  }) async => null;

  @override
  Future<List<Sentence>> loadTranscript(AudioItem audioItem) async => sentences;
}

/// 可注入初始 state 的子类（复用真实业务逻辑）。
class _TestableListeningPractice extends ListeningPractice {
  void seed({
    required AudioItem audioItem,
    required PlaybackSettings settings,
    PlaybackSettings? bookmarkSettings,
  }) {
    state = state.copyWith(
      currentAudioItem: audioItem,
      settings: settings,
      bookmarkSettings: bookmarkSettings,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sentences = [
    Sentence(
      index: 0,
      text: '[INDISTINCT CHATTER]',
      startTime: Duration.zero,
      endTime: const Duration(seconds: 3),
    ),
    Sentence(
      index: 1,
      text: 'Second.',
      startTime: const Duration(seconds: 3),
      endTime: const Duration(seconds: 6),
    ),
  ];

  // 循环开关与非默认参数（用于验证切换音频后设置保留）
  const loopOnSettings = PlaybackSettings(
    loopWhole: true,
    loopSentence: true,
    sentenceLoopCount: 5,
    wholeLoopCount: 7,
  );

  late ProviderContainer container;
  late AppDatabase db;
  late _TestableListeningPractice lp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(
      NativeDatabase.memory(setup: configureAppDatabaseConnection),
    );
    container = ProviderContainer(
      overrides: dedupeOverrides([
        appDatabaseProvider.overrideWithValue(db),
        audioEngineProvider.overrideWith(() => _LoadAudioEngine(sentences)),
        listeningPracticeProvider.overrideWith(
          () => _TestableListeningPractice(),
        ),
      ]),
    );
    lp =
        container.read(listeningPracticeProvider.notifier)
            as _TestableListeningPractice;
    await Future<void>.delayed(Duration.zero); // 等 _setupListeners microtask
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('加载新音频时保留全文与收藏各自的循环设置', () async {
    lp.seed(
      audioItem: createTestAudioItem(id: 'audio-1'),
      settings: loopOnSettings,
      bookmarkSettings: const PlaybackSettings(
        loopWhole: true,
        loopSentence: false,
        wholeLoopCount: 4,
        sentenceLoopCount: 5,
        sentenceInterval: Duration(seconds: 3),
      ),
    );

    await lp.loadAudio(createTestAudioItem(id: 'audio-2'));

    final state = container.read(listeningPracticeProvider);
    expect(state.fullSettings.loopWhole, isTrue);
    expect(state.fullSettings.loopSentence, isTrue);
    expect(state.fullSettings.sentenceLoopCount, 5);
    expect(state.fullSettings.wholeLoopCount, 7);
    expect(state.bookmarkSettings.loopWhole, isTrue);
    expect(state.bookmarkSettings.loopSentence, isFalse);
    expect(state.bookmarkSettings.wholeLoopCount, 4);
    expect(state.bookmarkSettings.sentenceLoopCount, 5);
    expect(state.bookmarkSettings.sentenceInterval, const Duration(seconds: 3));
  });

  test('首次加载方括号字幕不自动收藏且文本原样显示', () async {
    await lp.loadAudio(createTestAudioItem(id: 'audio-brackets'));

    final state = container.read(listeningPracticeProvider);
    expect(state.bookmarkedIndices, isEmpty);
    expect(state.sentences.first.text, '[INDISTINCT CHATTER]');
    expect(state.sentences.first.isBookmarked, isFalse);
  });

  test('重新加载同一音频（早返回）不重置循环开关', () async {
    final item = createTestAudioItem(id: 'audio-1');
    lp.seed(audioItem: item, settings: loopOnSettings);

    // 同 id + 同 transcript：loadAudio 早返回，不进入重置路径
    await lp.loadAudio(createTestAudioItem(id: 'audio-1'));

    final settings = container.read(listeningPracticeProvider).settings;
    expect(settings.loopWhole, isTrue);
    expect(settings.loopSentence, isTrue);
  });
}
