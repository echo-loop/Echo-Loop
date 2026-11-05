// 收藏词汇页 TTS 预热接线测试
//
// 验证收藏词汇 tile 创建时增量预热发音文本，离开时取消。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/daos/saved_sense_group_dao.dart';
import 'package:echo_loop/database/daos/saved_word_dao.dart';
import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/short_audio_player_provider.dart';
import 'package:echo_loop/providers/pronunciation/pronunciation_providers.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/screens/favorites_screen.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:echo_loop/widgets/common/prewarm_visibility.dart';

import '../helpers/mock_providers.dart';

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}

class _MockAudioItemDao extends Mock implements AudioItemDao {
  final Map<String, AudioItem> items = {};
  final Map<String, String?> transcripts = {};

  _MockAudioItemDao() {
    when(() => getById(any())).thenAnswer((invocation) async {
      final arguments = invocation.positionalArguments;
      final id = arguments.length == 1 ? arguments.first : null;
      return id is String ? items[id] : null;
    });
    when(() => getTranscriptSrt(any())).thenAnswer((invocation) async {
      final arguments = invocation.positionalArguments;
      final id = arguments.length == 1 ? arguments.first : null;
      return id is String ? transcripts[id] : null;
    });
  }
}

class _TestBookmarkDao implements BookmarkDao {
  final StreamController<List<BookmarkWithAudio>> _c;
  _TestBookmarkDao(this._c);
  @override
  Stream<List<BookmarkWithAudio>> watchAllWithAudioName() => _c.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _TestSavedWordDao implements SavedWordDao {
  final StreamController<List<SavedWord>> _c;
  _TestSavedWordDao(this._c);
  @override
  Stream<List<SavedWord>> watchAll() => _c.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _TestSavedSenseGroupDao implements SavedSenseGroupDao {
  final StreamController<List<SavedSenseGroup>> _c;
  _TestSavedSenseGroupDao(this._c);
  @override
  Stream<List<SavedSenseGroup>> watchAll() => _c.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// 录制预热调用的 TTS 控制器：build 跳过真实协调器/数据库，仅记录 prewarm/cancel。
class _RecordingTtsController extends TtsController {
  final List<List<String>> prewarmCalls = [];
  final List<String> spokenTexts = [];
  int cancelCount = 0;
  int engineWarmupCount = 0;

  @override
  TtsControllerState build() => const TtsControllerState();

  /// 模拟异步初始配置落定，触发可见 tile 重新提交预热。
  void markConfigured() {
    state = const TtsControllerState(configurationVersion: 1);
  }

  @override
  Future<void> prewarmTextsIncremental(List<String> texts) async {
    prewarmCalls.add(List.of(texts));
  }

  @override
  Future<bool> warmUpCurrentEngine() async {
    engineWarmupCount++;
    return true;
  }

  @override
  Future<void> speak(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    spokenTexts.add(text);
  }

  @override
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    spokenTexts.add(text);
    return AudioPlaybackResult.completed;
  }

  @override
  Future<void> stop() async {}

  @override
  void cancelTextsPrewarm() => cancelCount++;
}

/// 记录统一朗读入口的分流：`cdnWords` 中的单词视为 CDN 已有音频，不经 TTS。
class _RecordingPronunciationPlayback extends TextPlaybackController {
  final Set<String> cdnWords = {};
  final List<String> playedCdnWords = [];

  @override
  TextPlaybackState build() => const TextPlaybackState();

  @override
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    if (cdnWords.contains(text)) {
      playedCdnWords.add(text);
      return AudioPlaybackResult.completed;
    }
    return ref
        .read(ttsControllerProvider.notifier)
        .speakWithResult(text, key: key);
  }

  @override
  Future<void> prewarmWord(String word) async {
    if (cdnWords.contains(word)) return;
    await ref.read(ttsControllerProvider.notifier).prewarmTextsIncremental([
      word,
    ]);
  }
}

/// 记录页面交给共享播放器的区间参数；播放器自身区间实现另有独立单测。
class _RecordingShortAudioPlayer extends LocalAudioClipPlayer {
  _RecordingShortAudioPlayer() : super(backend: _NoopShortAudioBackend());

  final List<String> openedPaths = [];
  final List<Duration> openedStarts = [];
  AudioPlaybackResult rangePlaybackResult = AudioPlaybackResult.completed;

  @override
  Future<AudioPlaybackResult> playRangeFile(
    String filePath, {
    required Duration start,
    required Duration end,
    String? playbackKey,
  }) async {
    openedPaths.add(filePath);
    openedStarts.add(start);
    return rangePlaybackResult;
  }
}

class _NoopShortAudioBackend implements AudioClipPlayerBackend {
  @override
  Stream<void> get completed => const Stream<void>.empty();

  @override
  Stream<String> get errors => const Stream<String>.empty();

  @override
  Stream<Duration> get positions => const Stream<Duration>.empty();

  @override
  Duration get position => Duration.zero;

  @override
  Future<void> open(String filePath, {Duration start = Duration.zero}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

MockDictionaryService _createDictionaryService() {
  final entries = {
    'tomorrow': const DictEntry(
      word: 'tomorrow',
      phonetic: 'təmɒrəʊ',
      translation: 'adv. 明天',
    ),
    'instructions': const DictEntry(
      word: 'instructions',
      phonetic: '',
      translation: 'n. 指令',
    ),
  };
  final service = MockDictionaryService();
  when(() => service.lookupAll(any())).thenAnswer((invocation) async {
    final words = invocation.positionalArguments.first as List<String>;
    return {
      for (final word in words)
        if (entries[word] case final entry?) word: entry,
    };
  });
  return service;
}

SavedWord _word(
  int id,
  String word, {
  String? audioItemId,
  int? sentenceIndex,
  String? sentenceText,
  int? sentenceStartMs,
  int? sentenceEndMs,
}) => SavedWord(
  id: id,
  word: word,
  audioItemId: audioItemId,
  sentenceIndex: sentenceIndex,
  sentenceText: sentenceText,
  sentenceStartMs: sentenceStartMs,
  sentenceEndMs: sentenceEndMs,
  practiceCount: 0,
  totalStudyMs: 0,
  viewedBack: false,
  lastPracticedAt: null,
  createdAt: DateTime(2026, 1, id),
  updatedAt: DateTime(2026, 1, id),
  deletedAt: null,
  syncStatus: 0,
);

SavedSenseGroup _phrase(
  int id,
  String display, {
  String? audioItemId,
  String? sentenceText,
  int? sentenceStartMs,
  int? sentenceEndMs,
}) => SavedSenseGroup(
  id: id,
  phraseText: display.toLowerCase(),
  displayText: display,
  audioItemId: audioItemId,
  sentenceIndex: null,
  sentenceText: sentenceText,
  sentenceStartMs: sentenceStartMs,
  sentenceEndMs: sentenceEndMs,
  groupStartMs: null,
  groupEndMs: null,
  practiceCount: 0,
  totalStudyMs: 0,
  viewedBack: false,
  lastPracticedAt: null,
  createdAt: DateTime(2026, 2, id),
  updatedAt: DateTime(2026, 2, id),
  deletedAt: null,
  syncStatus: 0,
);

AudioItem _audioItem(String id) => AudioItem(
  id: id,
  name: 'Source audio',
  audioPath: 'audios/$id.m4a',
  transcriptPath: null,
  addedDate: DateTime(2026),
  totalDuration: 30,
  sentenceCount: 1,
  wordCount: 3,
  isPinned: false,
  transcriptSource: 0,
  updatedAt: DateTime(2026),
  syncStatus: 0,
);

void main() {
  late StreamController<List<BookmarkWithAudio>> bookmarkC;
  late StreamController<List<SavedWord>> wordC;
  late StreamController<List<SavedSenseGroup>> phraseC;
  late _RecordingTtsController rec;
  late _RecordingPronunciationPlayback pronunciationPlayback;
  late MockDictionaryService dictionaryService;
  late Directory appDataDir;
  late _RecordingShortAudioPlayer shortAudioPlayer;
  late _MockAudioItemDao audioItemDao;
  late ValueNotifier<int> activeMainTab;

  setUp(() {
    bookmarkC = StreamController<List<BookmarkWithAudio>>.broadcast();
    wordC = StreamController<List<SavedWord>>.broadcast();
    phraseC = StreamController<List<SavedSenseGroup>>.broadcast();
    rec = _RecordingTtsController();
    pronunciationPlayback = _RecordingPronunciationPlayback();
    dictionaryService = _createDictionaryService();
    appDataDir = Directory.systemTemp.createTempSync('favorites_audio_test_');
    appDataDirectoryOverride = appDataDir;
    shortAudioPlayer = _RecordingShortAudioPlayer();
    audioItemDao = _MockAudioItemDao();
    activeMainTab = ValueNotifier<int>(2);
  });

  tearDown(() {
    bookmarkC.close();
    wordC.close();
    phraseC.close();
    appDataDirectoryOverride = null;
    if (appDataDir.existsSync()) appDataDir.deleteSync(recursive: true);
    activeMainTab.dispose();
  });

  Widget createWidget({Set<String> cdnWords = const {}}) {
    pronunciationPlayback.cdnWords
      ..clear()
      ..addAll(cdnWords);
    final router = GoRouter(
      initialLocation: '/favorites',
      routes: [
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: '/other',
          builder: (context, state) => const Scaffold(body: Text('Other')),
        ),
      ],
    );
    final app = MaterialApp.router(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      routerConfig: router,
    );
    return ProviderScope(
      overrides: dedupeOverrides([
        analyticsOverride(),
        ...studyTimeOverrides(),
        dictionaryServiceOverride(dictionaryService),
        bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao(bookmarkC)),
        savedWordDaoProvider.overrideWithValue(_TestSavedWordDao(wordC)),
        savedSenseGroupDaoProvider.overrideWithValue(
          _TestSavedSenseGroupDao(phraseC),
        ),
        audioItemDaoProvider.overrideWithValue(audioItemDao),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        shortAudioPlayerProvider.overrideWithValue(shortAudioPlayer),
        sentenceAiNotifierProvider.overrideWithValue(
          SentenceAiNotifier(
            cacheDao: _MockCacheDao(),
            apiClient: _MockApiClient(),
          ),
        ),
        ttsControllerProvider.overrideWith(() => rec),
        textPlaybackProvider.overrideWith(() => pronunciationPlayback),
      ]),
      child: ValueListenableBuilder<int>(
        valueListenable: activeMainTab,
        builder: (context, index, _) => MainTabVisibilityScope(
          currentIndex: index,
          rootRouteVisible: true,
          child: app,
        ),
      ),
    );
  }

  testWidgets('停在句子 tab 不预热词汇', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow'), _word(2, 'finished')]);
    phraseC.add([_phrase(1, 'can I book a table')]);
    await tester.pumpAndSettle();

    // 默认在句子 tab：IndexedStack 虽构建 _WordsView，但未激活不应预热。
    expect(rec.prewarmCalls, isEmpty);
  });

  testWidgets('切到词汇 tab 后为已创建的 tile 增量预热', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow'), _word(2, 'finished')]);
    phraseC.add([_phrase(1, 'can I book a table')]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();

    expect(rec.prewarmCalls, isNotEmpty);
    expect(
      rec.prewarmCalls.expand((texts) => texts),
      containsAll(['tomorrow', 'finished', 'can I book a table']),
    );
    expect(rec.engineWarmupCount, 1);
  });

  testWidgets('配置完成后仅重新提交当前可见 tile', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow'), _word(2, 'finished')]);
    phraseC.add([_phrase(1, 'can I book a table')]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    final callsBeforeConfiguration = rec.prewarmCalls.length;

    rec.markConfigured();
    await tester.pumpAndSettle();

    expect(rec.prewarmCalls.length, greaterThan(callsBeforeConfiguration));
    expect(
      rec.prewarmCalls.skip(callsBeforeConfiguration).expand((texts) => texts),
      containsAll(['tomorrow', 'finished', 'can I book a table']),
    );
  });

  testWidgets('CDN 已有音频的收藏单词跳过 TTS 预热，意群保留', (tester) async {
    await tester.pumpWidget(createWidget(cdnWords: {'tomorrow'}));
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow'), _word(2, 'finished')]);
    phraseC.add([_phrase(1, 'can I book a table')]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();

    final texts = rec.prewarmCalls.expand((texts) => texts);
    expect(texts, isNot(contains('tomorrow')));
    expect(texts, containsAll(['finished', 'can I book a table']));
  });

  testWidgets('收藏意群显示朗读按钮并朗读意群文本', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([]);
    phraseC.add([_phrase(1, 'said they were shy.')]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('said they were shy.'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite_phrase_speak')));

    expect(find.byKey(const Key('favorite_phrase_speak')), findsOneWidget);
    expect(rec.spokenTexts, ['said they were shy.']);
  });

  testWidgets('点击 CDN 已有音频的收藏单词走统一入口而不调用 TTS', (tester) async {
    await tester.pumpWidget(createWidget(cdnWords: {'tomorrow'}));
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow')]);
    phraseC.add([]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tomorrow'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite_speak')));

    expect(pronunciationPlayback.playedCdnWords, ['tomorrow']);
    expect(rec.spokenTexts, isEmpty);
  });

  testWidgets('无音标的收藏单词仍显示播放按钮', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'instructions')]);
    phraseC.add([]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('instructions'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('favorite_speak')), findsOneWidget);
  });

  testWidgets('词典未收录的收藏多词仍显示播放按钮并回退 TTS', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'birthday card')]);
    phraseC.add([]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('birthday card'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite_speak')));

    expect(find.byKey(const Key('favorite_speak')), findsOneWidget);
    expect(rec.spokenTexts, ['birthday card']);
  });

  testWidgets('词典未收录的收藏变形词仍显示播放按钮', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'carrying')]);
    phraseC.add([]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('carrying'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('favorite_speak')), findsOneWidget);
  });

  testWidgets('切离词汇 tab 取消在途预热', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow')]);
    phraseC.add([]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    final cancelsBefore = rec.cancelCount;

    await tester.tap(find.textContaining('Sentences'));
    await tester.pumpAndSettle();

    expect(rec.cancelCount, greaterThan(cancelsBefore));
  });

  testWidgets('切离主 tab 取消预热，返回主 tab 后重新预热', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow')]);
    phraseC.add([_phrase(1, 'can I book a table')]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    final callsBeforeLeave = rec.prewarmCalls.length;
    final cancelsBeforeLeave = rec.cancelCount;

    activeMainTab.value = 1;
    await tester.pumpAndSettle();
    expect(rec.cancelCount, greaterThan(cancelsBeforeLeave));

    activeMainTab.value = 2;
    await tester.pumpAndSettle();
    expect(rec.prewarmCalls.length, greaterThan(callsBeforeLeave));
  });

  testWidgets('数据流重发相同列表不重复提交已创建 tile', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow')]);
    phraseC.add([]);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();

    final before = rec.prewarmCalls.length;
    expect(before, greaterThanOrEqualTo(1));

    // drift 流可能重发内容相同的新实例列表，既有 tile 不应重复提交。
    wordC.add([_word(1, 'tomorrow')]);
    phraseC.add([]);
    await tester.pumpAndSettle();

    expect(rec.prewarmCalls.length, before, reason: '文本未变不应重启预热');
  });

  testWidgets('滚动后才预热后续由 ListView 创建的 tile', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([for (var i = 1; i <= 100; i++) _word(i, 'word_$i')]);
    phraseC.add([]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();

    final initialTexts = rec.prewarmCalls.expand((texts) => texts).toSet();
    expect(initialTexts, isNot(contains('word_1')));

    await tester.scrollUntilVisible(
      find.text('word_1'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(rec.prewarmCalls.length, greaterThan(initialTexts.length));
  });

  testWidgets('滚动开始取消未执行预热，停止后恢复可见 tile', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([for (var i = 1; i <= 100; i++) _word(i, 'word_$i')]);
    phraseC.add([]);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    final cancelsBefore = rec.cancelCount;
    final callsBeforeScroll = rec.prewarmCalls.length;

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(rec.cancelCount, greaterThan(cancelsBefore));
    expect(
      rec.prewarmCalls.length,
      greaterThan(callsBeforeScroll),
      reason: '停止滚动后应重新提交当前可见 tile 的预热',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('离开收藏页取消在途预热', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow')]);
    phraseC.add([]);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();

    // 导航离开 → _WordsView dispose → cancelTextsPrewarm。
    final ctx = tester.element(find.byType(FavoritesScreen));
    GoRouter.of(ctx).go('/other');
    await tester.pumpAndSettle();

    expect(rec.cancelCount, greaterThanOrEqualTo(1));
  });

  testWidgets('收藏单词来源句使用共享短音频播放器播放冗余时间区间', (tester) async {
    audioItemDao.items['audio-1'] = _audioItem('audio-1');
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([
      _word(
        1,
        'score',
        audioItemId: 'audio-1',
        sentenceText: 'Our team scores a try.',
        sentenceStartMs: 1200,
        sentenceEndMs: 3800,
      ),
    ]);
    phraseC.add([]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('score'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Our team scores a try.'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(shortAudioPlayer.openedPaths, [
      '${appDataDir.path}/audios/audio-1.m4a',
    ]);
    expect(shortAudioPlayer.openedStarts, [const Duration(milliseconds: 1200)]);
  });

  testWidgets('收藏意群来源句使用共享短音频播放器播放句子区间', (tester) async {
    audioItemDao.items['audio-2'] = _audioItem('audio-2');
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([]);
    phraseC.add([
      _phrase(
        1,
        'scores a try',
        audioItemId: 'audio-2',
        sentenceText: 'When our team scores a try.',
        sentenceStartMs: 4000,
        sentenceEndMs: 6200,
      ),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('scores a try'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('When our team scores a try.').last);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(shortAudioPlayer.openedPaths, [
      '${appDataDir.path}/audios/audio-2.m4a',
    ]);
    expect(shortAudioPlayer.openedStarts, [const Duration(milliseconds: 4000)]);
  });

  testWidgets('收藏意群原声不可用时回退来源句 TTS', (tester) async {
    shortAudioPlayer.rangePlaybackResult = AudioPlaybackResult.failed;
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([]);
    phraseC.add([
      _phrase(
        1,
        'scores a try',
        audioItemId: 'audio-2',
        sentenceText: 'When our team scores a try.',
        sentenceStartMs: 4000,
        sentenceEndMs: 6200,
      ),
    ]);
    audioItemDao.items['audio-2'] = _audioItem('audio-2');
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('scores a try'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('When our team scores a try.').last);
    await tester.pumpAndSettle();

    expect(rec.spokenTexts, ['When our team scores a try.']);
  });

  testWidgets('收藏意群原声被抢占时不回退来源句 TTS', (tester) async {
    shortAudioPlayer.rangePlaybackResult = AudioPlaybackResult.cancelled;
    audioItemDao.items['audio-2'] = _audioItem('audio-2');
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([]);
    phraseC.add([
      _phrase(
        1,
        'scores a try',
        audioItemId: 'audio-2',
        sentenceText: 'When our team scores a try.',
        sentenceStartMs: 4000,
        sentenceEndMs: 6200,
      ),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('scores a try'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('When our team scores a try.').last);
    await tester.pumpAndSettle();

    expect(rec.spokenTexts, isEmpty);
  });

  testWidgets('展开收藏意群后主 item 不重复显示来源句', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([]);
    phraseC.add([
      _phrase(1, 'scores a try', sentenceText: 'When our team scores a try.'),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    expect(find.text('When our team scores a try.'), findsOneWidget);

    await tester.tap(find.text('scores a try'));
    await tester.pumpAndSettle();
    expect(find.text('When our team scores a try.'), findsOneWidget);
  });
}
