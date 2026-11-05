// 收藏页面 Widget 测试
//
// 验证句子/单词视图切换、按音频分组展示、空状态、收藏操作等 UI 行为。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/screens/favorites_screen.dart';
import 'package:echo_loop/screens/sentence_detail_screen.dart';
import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/daos/saved_sense_group_dao.dart';
import 'package:echo_loop/database/daos/saved_word_dao.dart';
import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_session/bookmark_review_provider.dart';
import 'package:echo_loop/providers/learning_session/favorite_review_due_count_provider.dart';
import 'package:echo_loop/providers/new_user_guide_provider.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:echo_loop/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

// ========== 测试用 Mock / Stub ==========

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}


class _MockAudioItemDao extends Mock implements AudioItemDao {
  _MockAudioItemDao({AudioItem? audioItem, String? transcriptSrt}) {
    // 默认返回 null（音频不存在），避免未 stub 报错
    when(() => getById(any())).thenAnswer((_) async => audioItem);
    when(() => getTranscriptSrt(any())).thenAnswer((_) async => transcriptSrt);
  }
}

/// 测试用 BookmarkDao — 通过 StreamController 控制数据
class _TestBookmarkDao implements BookmarkDao {
  final StreamController<List<BookmarkWithAudio>> _controller;

  _TestBookmarkDao(this._controller);

  @override
  Stream<List<BookmarkWithAudio>> watchAllWithAudioName() => _controller.stream;

  @override
  Future<List<Bookmark>> getByAudioId(String audioItemId) async => [];

  @override
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// 测试用 SavedWordDao — 通过 StreamController 控制数据
class _TestSavedWordDao implements SavedWordDao {
  final StreamController<List<SavedWord>> _controller;

  _TestSavedWordDao(this._controller);

  @override
  Stream<List<SavedWord>> watchAll() => _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// 测试用 SavedSenseGroupDao — 通过 StreamController 控制数据
class _TestSavedSenseGroupDao implements SavedSenseGroupDao {
  final StreamController<List<SavedSenseGroup>> _controller;

  _TestSavedSenseGroupDao(this._controller);

  @override
  Stream<List<SavedSenseGroup>> watchAll() async* {
    // 词汇页需要单词和意群两个流都完成首帧，默认先发出空意群列表。
    yield const [];
    yield* _controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _DeferredBookmarkReview extends BookmarkReview {
  final initialized = Completer<void>();

  @override
  BookmarkReviewState build() => const BookmarkReviewState();

  @override
  Future<void> initialize() => initialized.future;
}

class _ImmediateBookmarkReview extends BookmarkReview {
  @override
  BookmarkReviewState build() => const BookmarkReviewState();

  @override
  Future<void> initialize() async {}
}

/// 创建测试用 Bookmark 数据
Bookmark _createBookmark({
  required int id,
  required String audioItemId,
  required int sentenceIndex,
  String sentenceText = 'Test sentence.',
  double startTime = 0.0,
  double endTime = 5.0,
}) {
  return Bookmark(
    id: id,
    audioItemId: audioItemId,
    sentenceIndex: sentenceIndex,
    sentenceText: sentenceText,
    startTime: startTime,
    endTime: endTime,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    deletedAt: null,
    syncStatus: 0,
  );
}

/// 创建测试用 SavedWord 数据
SavedWord _createSavedWord({
  required int id,
  required String word,
  String? audioItemId,
  int? sentenceIndex,
  String? sentenceText,
  int? sentenceStartMs,
  int? sentenceEndMs,
}) {
  return SavedWord(
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
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    deletedAt: null,
    syncStatus: 0,
  );
}

/// 创建测试用 SavedSenseGroup 数据
SavedSenseGroup _createSavedPhrase({
  required int id,
  required String phraseText,
  String? audioItemId,
  String? sentenceText,
}) {
  return SavedSenseGroup(
    id: id,
    phraseText: phraseText,
    displayText: phraseText,
    audioItemId: audioItemId,
    sentenceIndex: null,
    sentenceText: sentenceText,
    sentenceStartMs: null,
    sentenceEndMs: null,
    groupStartMs: null,
    groupEndMs: null,
    practiceCount: 0,
    totalStudyMs: 0,
    viewedBack: false,
    lastPracticedAt: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    deletedAt: null,
    syncStatus: 0,
  );
}

void main() {
  late StreamController<List<BookmarkWithAudio>> bookmarkController;
  late StreamController<List<SavedWord>> wordController;
  late StreamController<List<SavedSenseGroup>> phraseController;
  SentenceDetailArgs? openedSentenceDetailArgs;

  setUp(() {
    bookmarkController = StreamController<List<BookmarkWithAudio>>.broadcast();
    wordController = StreamController<List<SavedWord>>.broadcast();
    phraseController = StreamController<List<SavedSenseGroup>>.broadcast();
    openedSentenceDetailArgs = null;
  });

  tearDown(() {
    bookmarkController.close();
    wordController.close();
    phraseController.close();
    debugDefaultTargetPlatformOverride = null;
  });

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
    AudioItem? sourceAudio,
    String? sourceTranscriptSrt,
    BookmarkReview? bookmarkReview,
    int? sentenceDueCount,
    Future<int> Function()? sentenceDueLoader,
    int? vocabularyDueCount,
    Future<int>? vocabularyDueFuture,
    SharedPreferences? guidePrefs,
    DictionaryService? dictionaryService,
  }) {
    final router = GoRouter(
      initialLocation: '/favorites',
      routes: [
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: '/bookmark-review',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('test-bookmark-review-close'),
                onPressed: context.pop,
                child: const Text('Bookmark Review'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/favorites/sentence-detail',
          builder: (context, state) {
            final args = state.extra;
            if (args is SentenceDetailArgs) {
              openedSentenceDetailArgs = args;
            }
            return const Scaffold(body: Text('Sentence detail destination'));
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: dedupeOverrides([
        analyticsOverride(),
        ...studyTimeOverrides(),
        dictionaryServiceOverride(dictionaryService),
        bookmarkDaoProvider.overrideWithValue(
          _TestBookmarkDao(bookmarkController),
        ),
        savedWordDaoProvider.overrideWithValue(
          _TestSavedWordDao(wordController),
        ),
        savedSenseGroupDaoProvider.overrideWithValue(
          _TestSavedSenseGroupDao(phraseController),
        ),
        audioItemDaoProvider.overrideWithValue(
          _MockAudioItemDao(
            audioItem: sourceAudio,
            transcriptSrt: sourceTranscriptSrt,
          ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        if (bookmarkReview != null)
          bookmarkReviewProvider.overrideWith(() => bookmarkReview),
        if (sentenceDueCount != null)
          favoriteSentenceDueCountProvider.overrideWith(
            (ref) async => sentenceDueCount,
          ),
        if (sentenceDueLoader != null)
          favoriteSentenceDueCountProvider.overrideWith(
            (ref) => sentenceDueLoader(),
          ),
        if (vocabularyDueCount != null)
          favoriteVocabularyDueCountProvider.overrideWith(
            (ref) async => vocabularyDueCount,
          ),
        if (vocabularyDueFuture != null)
          favoriteVocabularyDueCountProvider.overrideWith(
            (ref) => vocabularyDueFuture,
          ),
        if (guidePrefs != null) ...[
          sharedPreferencesProvider.overrideWithValue(guidePrefs),
          guideRegistryProvider.overrideWithValue(
            GuideRegistry(prefs: guidePrefs),
          ),
        ],
        sentenceAiNotifierProvider.overrideWithValue(
          SentenceAiNotifier(
            cacheDao: _MockCacheDao(),
            apiClient: _MockApiClient(),
          ),
        ),
      ]),
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: MaterialApp.router(
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('zh')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      ),
    );
  }

  group('FavoritesScreen — SegmentedButton 切换', () {
    testWidgets('新手引导目标绑定到两个收藏 Tab 而不是列表首项', (tester) async {
      await tester.pumpWidget(createTestWidget());
      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
          ),
          audioName: 'Audio 1',
        ),
      ]);
      wordController.add([_createSavedWord(id: 1, word: 'hello')]);
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.byKey(const Key('favorites-sentences-segment')),
          matching: find.byType(Showcase),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('favorites-vocabulary-segment')),
          matching: find.byType(Showcase),
        ),
        findsOneWidget,
      );
    });

    testWidgets('首次进入收藏页按句子再词汇顺序展示两个 Tab 引导', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(createTestWidget(guidePrefs: prefs));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));
      final firstActiveKey = ShowcaseView.get().getActiveShowcaseKey;
      expect(firstActiveKey, isNotNull);

      ShowcaseView.get().next();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        ShowcaseView.get().getActiveShowcaseKey,
        isNot(same(firstActiveKey)),
      );
    });

    testWidgets('重新显示句子 tab 时重新读取待复习数量', (tester) async {
      var dueCount = 2;
      var requests = 0;
      await tester.pumpWidget(
        createTestWidget(
          sentenceDueLoader: () async {
            requests += 1;
            return dueCount;
          },
          vocabularyDueCount: 1,
        ),
      );
      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            endTime: 3,
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();
      expect(find.text('2 due for review'), findsOneWidget);

      await tester.tap(find.text('Vocabulary'));
      await tester.pumpAndSettle();
      dueCount = 0;
      await tester.tap(find.textContaining('Sentences'));
      await tester.pumpAndSettle();

      expect(requests, greaterThanOrEqualTo(2));
      expect(find.text('All Done!'), findsOneWidget);
    });

    testWidgets('从后台恢复时刷新当前 tab 的待复习数量', (tester) async {
      var dueCount = 1;
      var requests = 0;
      await tester.pumpWidget(
        createTestWidget(
          sentenceDueLoader: () async {
            requests += 1;
            return dueCount;
          },
        ),
      );
      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            endTime: 3,
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      dueCount = 0;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(requests, 2);
      expect(find.text('All Done!'), findsOneWidget);
    });

    testWidgets('右上角更多菜单包含回收站和复习设置', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(
        tester.widget<AppBar>(find.byType(AppBar)).actionsPadding,
        const EdgeInsets.only(right: AppSpacing.s),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('favorites-more')),
          matching: find.byIcon(Icons.more_horiz),
        ),
        findsOneWidget,
      );
      final statistics = tester.getRect(
        find.byKey(const Key('favorites-statistics')),
      );
      final more = tester.getRect(find.byKey(const Key('favorites-more')));
      expect(more.left, closeTo(statistics.right, 0.01));

      await tester.tap(find.byKey(const Key('favorites-more')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Recycle Bin'), findsOneWidget);
      expect(find.text('Review settings'), findsOneWidget);
      expect(
        tester.getRect(find.text('Review settings')).top,
        lessThan(tester.getRect(find.text('Recycle Bin')).top),
      );
    });

    testWidgets('更多菜单显示复习设置入口', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.byKey(const Key('favorites-more')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Review settings'), findsOneWidget);
    });

    testWidgets('词汇 tab 的更多菜单同样显示复习设置入口', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.tap(find.text('Vocabulary'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('favorites-more')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Review settings'), findsOneWidget);
    });

    testWidgets('默认显示句子视图和 tab 标签', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // tab 标签文本可见
      expect(find.text('Sentences'), findsOneWidget);
      expect(find.text('Vocabulary'), findsOneWidget);
    });

    testWidgets('收藏数量以轻量 badge 显示且分段控件保持紧凑', (tester) async {
      await tester.pumpWidget(createTestWidget());
      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
          ),
          audioName: 'Audio One',
        ),
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 2,
            audioItemId: 'audio-1',
            sentenceIndex: 1,
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([
        _createSavedWord(id: 1, word: 'apple'),
        _createSavedWord(id: 2, word: 'banana'),
        _createSavedWord(id: 3, word: 'orange'),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('favorites-sentences-count')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('favorites-vocabulary-count')),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.menu_book_outlined)).size,
        18,
      );
      expect(find.text('Sentences (2)'), findsNothing);
      expect(find.text('Vocabulary (3)'), findsNothing);
      expect(
        tester
            .getSize(find.byKey(const Key('favorites-sentences-count')))
            .height,
        20,
      );
      final badgeText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('favorites-sentences-count')),
          matching: find.byType(Text),
        ),
      );
      expect(badgeText.textAlign, TextAlign.center);
      expect(
        tester
            .getSize(find.byKey(const Key('favorites-sentences-segment')))
            .height,
        closeTo(42, 0.01),
      );

      final shellWidth = tester
          .getSize(find.byKey(const Key('favorites-segmented-control-shell')))
          .width;
      expect(
        tester
            .getSize(find.byKey(const Key('favorites-sentences-segment')))
            .width,
        closeTo(shellWidth / 2, 0.01),
      );
      expect(
        tester
            .widget<Material>(
              find.byKey(const Key('favorites-sentences-segment')),
            )
            .color,
        Theme.of(
          tester.element(find.byKey(const Key('favorites-sentences-segment'))),
        ).colorScheme.secondaryContainer,
      );
      expect(
        tester
            .widget<Material>(
              find.byKey(const Key('favorites-vocabulary-segment')),
            )
            .color,
        Colors.transparent,
      );
    });

    testWidgets('点击 Vocabulary 切换到单词视图', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // 点击 Vocabulary 按钮
      await tester.tap(find.text('Vocabulary'));
      await tester.pump();

      // 单词视图加载中（stream 尚未发射数据）
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('切换到单词再切回句子', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.text('Vocabulary'));
      await tester.pump();

      await tester.tap(find.text('Sentences'));
      await tester.pump();

      // 句子视图应显示加载状态（等待 stream 数据）
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('FavoritesScreen — 句子视图', () {
    testWidgets('关闭句子复习后刷新待复习数量', (tester) async {
      var dueCount = 1;
      var requests = 0;
      await tester.pumpWidget(
        createTestWidget(
          bookmarkReview: _ImmediateBookmarkReview(),
          sentenceDueLoader: () async {
            requests += 1;
            return dueCount;
          },
        ),
      );
      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            endTime: 3,
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      expect(find.text('Bookmark Review'), findsOneWidget);

      dueCount = 0;
      await tester.tap(find.byKey(const Key('test-bookmark-review-close')));
      await tester.pumpAndSettle();

      expect(requests, 2);
      expect(find.text('All Done!'), findsOneWidget);
    });

    testWidgets('无数据时显示句子空状态', (tester) async {
      await tester.pumpWidget(createTestWidget());
      bookmarkController.add([]);
      wordController.add([]);
      await tester.pumpAndSettle();

      expect(find.text('No saved sentences yet'), findsOneWidget);
    });

    testWidgets('有数据时按音频分组展示', (tester) async {
      await tester.pumpWidget(createTestWidget());

      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            sentenceText: 'Hello world.',
          ),
          audioName: 'Audio One',
        ),
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 2,
            audioItemId: 'audio-1',
            sentenceIndex: 1,
            sentenceText: 'How are you?',
          ),
          audioName: 'Audio One',
        ),
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 3,
            audioItemId: 'audio-2',
            sentenceIndex: 0,
            sentenceText: 'Good morning.',
          ),
          audioName: 'Audio Two',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      // 两个音频分组标题
      expect(find.text('Audio One'), findsOneWidget);
      expect(find.text('Audio Two'), findsOneWidget);
    });

    testWidgets('显示"开始复习"按钮及句子数', (tester) async {
      await tester.pumpWidget(createTestWidget(sentenceDueCount: 1));

      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            sentenceText: 'Test sentence.',
            startTime: 0.0,
            endTime: 3.0,
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      // FilledButton.tonal 类型的开始复习按钮
      expect(find.byType(FilledButton), findsAtLeast(1));
      // 有待复习内容时统一使用闪卡图标。
      expect(find.byIcon(Icons.style_outlined), findsAtLeast(1));
      expect(find.text('1 due for review'), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton).last).height, 36);
    });

    testWidgets('中文放大字体下复习按钮完整显示且按内容增高', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          locale: const Locale('zh'),
          textScaler: const TextScaler.linear(2),
          sentenceDueCount: 1,
        ),
      );
      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            endTime: 3.0,
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      final label = find.text('待复习 1 个');
      final button = find.byType(FilledButton).last;
      expect(label, findsOneWidget);
      expect(tester.getSize(button).height, greaterThan(36));
      final buttonRect = tester.getRect(button);
      final labelRect = tester.getRect(label);
      expect(buttonRect.contains(labelRect.topLeft), isTrue);
      expect(
        buttonRect.contains(labelRect.bottomRight - const Offset(0.1, 0.1)),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('句子无待复习内容时显示空态并禁用按钮', (tester) async {
      await tester.pumpWidget(createTestWidget(sentenceDueCount: 0));
      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            endTime: 3.0,
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      expect(find.text('All Done!'), findsOneWidget);
      expect(find.text('🎉'), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton).last).height, 36);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
    });

    testWidgets('开始复习等待异步初始化完成后才导航', (tester) async {
      final bookmarkReview = _DeferredBookmarkReview();
      await tester.pumpWidget(
        createTestWidget(bookmarkReview: bookmarkReview, sentenceDueCount: 1),
      );
      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            endTime: 3.0,
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      expect(find.text('Bookmark Review'), findsNothing);

      bookmarkReview.initialized.complete();
      await tester.pumpAndSettle();
      expect(find.text('Bookmark Review'), findsOneWidget);
    });

    testWidgets('展开音频组后显示句子', (tester) async {
      await tester.pumpWidget(createTestWidget());

      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            sentenceText: 'Hello world.',
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      // 展开音频组
      await tester.tap(find.text('Audio One'));
      await tester.pumpAndSettle();

      // 句子文本可见
      expect(find.text('Hello world.'), findsOneWidget);
    });

    testWidgets('句子项显示时间戳', (tester) async {
      await tester.pumpWidget(createTestWidget());

      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            sentenceText: 'Test.',
            startTime: 65.0,
            endTime: 70.0,
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      // 展开
      await tester.tap(find.text('Audio One'));
      await tester.pumpAndSettle();

      // 句子文本可见（当前 UI 不显示时间戳）
      expect(find.text('Test.'), findsOneWidget);
    });

    testWidgets('句子项显示分组内编号且不显示播放按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());

      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            sentenceText: 'Test.',
          ),
          audioName: 'Audio One',
        ),
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 2,
            audioItemId: 'audio-1',
            sentenceIndex: 1,
            sentenceText: 'Second sentence.',
          ),
          audioName: 'Audio One',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      // 展开
      await tester.tap(find.text('Audio One'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('saved-sentence-number-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('saved-sentence-number-2')),
        findsOneWidget,
      );
      final numberRect = tester.getRect(
        find.byKey(const ValueKey('saved-sentence-number-1')),
      );
      final titleRect = tester.getRect(find.text('Test.'));
      expect(titleRect.left - numberRect.right, closeTo(8, 0.01));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('saved-sentence-number-1')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('saved-sentence-number-2')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    });

    testWidgets('多个音频分组不再显示单篇练习按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());

      bookmarkController.add([
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
          ),
          audioName: 'Audio One',
        ),
        BookmarkWithAudio(
          bookmark: _createBookmark(
            id: 2,
            audioItemId: 'audio-2',
            sentenceIndex: 0,
          ),
          audioName: 'Audio Two',
        ),
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fitness_center), findsNothing);
    });
  });

  group('FavoritesScreen — 单词视图', () {
    testWidgets('切换到词汇 tab 时不回退显示开始复习', (tester) async {
      final dueCount = Completer<int>();
      await tester.pumpWidget(
        createTestWidget(vocabularyDueFuture: dueCount.future),
      );
      wordController.add([_createSavedWord(id: 1, word: 'apple')]);
      await tester.pump();

      await tester.tap(find.textContaining('Vocabulary'));
      await tester.pump();

      expect(find.text('Start Quiz (1)'), findsNothing);
      expect(find.text('Loading'), findsOneWidget);

      dueCount.complete(2);
      await tester.pump();
      await tester.pump();
      expect(find.text('2 due for review'), findsOneWidget);
    });

    testWidgets('无数据时显示单词空状态', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // 切到单词视图
      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      wordController.add([]);
      await tester.pump();
      await tester.pump();

      expect(find.text('No saved vocabulary yet'), findsOneWidget);
    });

    testWidgets('有数据时显示单词列表', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      wordController.add([
        _createSavedWord(id: 1, word: 'apple'),
        _createSavedWord(id: 2, word: 'banana'),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('apple'), findsOneWidget);
      expect(find.text('banana'), findsOneWidget);
    });

    testWidgets('词汇复习入口显示待复习数量', (tester) async {
      await tester.pumpWidget(createTestWidget(vocabularyDueCount: 2));
      await tester.pump();

      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      wordController.add([_createSavedWord(id: 1, word: 'apple')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('2 due for review'), findsOneWidget);
    });

    testWidgets('词汇无待复习内容时显示庆祝图标', (tester) async {
      await tester.pumpWidget(createTestWidget(vocabularyDueCount: 0));
      await tester.pump();

      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      wordController.add([_createSavedWord(id: 1, word: 'apple')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('All Done!'), findsOneWidget);
      expect(find.text('🎉'), findsOneWidget);
      expect(find.byIcon(Icons.style_outlined), findsNothing);
    });

    testWidgets('单词项显示单词内容', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      wordController.add([_createSavedWord(id: 1, word: 'hello')]);
      await tester.pump();
      await tester.pump();

      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('iOS 单词展开后的播放行上下间距保持紧凑', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final dictionary = MockDictionaryService();
        when(() => dictionary.lookupAll(any())).thenAnswer(
          (_) async => {
            'foxes': const DictEntry(
              word: 'foxes',
              phonetic: 'fɒksɪz',
              translation: 'n. 狐',
            ),
          },
        );

        await tester.pumpWidget(createTestWidget(dictionaryService: dictionary));
        await tester.pump();
        await tester.tap(find.text('Vocabulary'));
        await tester.pump();
        bookmarkController.add([]);
        wordController.add([_createSavedWord(id: 1, word: 'foxes')]);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('foxes'));
        await tester.pump(const Duration(milliseconds: 250));

        final contentRect = tester.getRect(
          find.byKey(const Key('favorite-word-expanded-content')),
        );
        final pronunciationRect = tester.getRect(
          find.byKey(const Key('favorite-word-pronunciation-row')),
        );
        final tileRect = tester.getRect(
          find
              .ancestor(of: find.text('foxes'), matching: find.byType(ListTile))
              .first,
        );
        final speakRect = tester.getRect(
          find.byKey(const Key('favorite_speak')),
        );
        final translationRect = tester.getRect(find.text('n. 狐'));

        expect(pronunciationRect.top, closeTo(contentRect.top, 0.01));
        expect(tileRect.height, closeTo(40, 0.01));
        expect(pronunciationRect.height, greaterThanOrEqualTo(44));
        expect(speakRect.width, closeTo(36, 0.01));
        expect(speakRect.height, closeTo(36, 0.01));
        expect(
          translationRect.top - pronunciationRect.bottom,
          closeTo(AppSpacing.xs, 0.01),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Android 意群展开后的播放行与来源句保持紧凑间距', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final sourceAudio = AudioItem(
          id: 'audio-1',
          name: 'A source lesson',
          addedDate: DateTime(2026, 1, 1),
          totalDuration: 60,
          sentenceCount: 1,
          wordCount: 5,
          isPinned: false,
          updatedAt: DateTime(2026, 1, 1),
          syncStatus: 0,
        );
        await tester.pumpWidget(createTestWidget(sourceAudio: sourceAudio));
        await tester.pump();
        await tester.tap(find.text('Vocabulary'));
        await tester.pump();
        bookmarkController.add([]);
        wordController.add([]);
        phraseController.add([
          _createSavedPhrase(
            id: 1,
            phraseText: 'said they were shy.',
            audioItemId: 'audio-1',
            sentenceText: 'They said they were shy.',
          ),
        ]);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('said they were shy.'));
        await tester.pump(const Duration(milliseconds: 250));

        final contentRect = tester.getRect(
          find.byKey(const Key('favorite-phrase-expanded-content')),
        );
        final speakRect = tester.getRect(
          find.byKey(const Key('favorite_phrase_speak')),
        );
        final pronunciationRect = tester.getRect(
          find.byKey(const Key('favorite-phrase-pronunciation-row')),
        );
        final sourceRect = tester.getRect(
          find.byKey(const Key('favorite-phrase-source-sentence')),
        );
        final sourceAudioRect = tester.getRect(
          find.byKey(const Key('favorite-source-audio-reference')),
        );

        expect(pronunciationRect.top, closeTo(contentRect.top, 0.01));
        expect(
          tester
              .getRect(
                find
                    .ancestor(
                      of: find.text('said they were shy.'),
                      matching: find.byType(ListTile),
                    )
                    .first,
              )
              .height,
          closeTo(40, 0.01),
        );
        expect(speakRect.width, closeTo(36, 0.01));
        expect(speakRect.height, closeTo(36, 0.01));
        expect(speakRect.left, closeTo(contentRect.left + AppSpacing.m, 0.01));
        expect(
          sourceRect.top - pronunciationRect.bottom,
          closeTo(AppSpacing.xs, 0.01),
        );
        expect(
          contentRect.bottom - sourceAudioRect.bottom,
          closeTo(AppSpacing.s, 0.01),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('单词来源句不显示播放图标且来源音频右侧显示箭头', (tester) async {
      final sourceAudio = AudioItem(
        id: 'audio-1',
        name: 'A source lesson',
        addedDate: DateTime(2026, 1, 1),
        totalDuration: 60,
        sentenceCount: 1,
        wordCount: 5,
        isPinned: false,
        updatedAt: DateTime(2026, 1, 1),
        syncStatus: 0,
      );
      await tester.pumpWidget(createTestWidget(sourceAudio: sourceAudio));
      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      bookmarkController.add([]);
      wordController.add([
        _createSavedWord(
          id: 1,
          word: 'researcher',
          audioItemId: 'audio-1',
          sentenceIndex: 0,
          sentenceText: 'A researcher studies inherited traits.',
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('researcher'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
      expect(
        find.byKey(const Key('favorite-source-audio-reference')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('favorite-source-audio-reference')),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('单词来源句左侧与释义分隔线对齐', (tester) async {
      final sourceSentence = 'A researcher studies inherited traits.';
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      bookmarkController.add([]);
      wordController.add([
        _createSavedWord(
          id: 1,
          word: 'researcher',
          sentenceText: sourceSentence,
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('researcher'));
      await tester.pumpAndSettle();

      final sourceTextRect = tester.getRect(find.text(sourceSentence));
      final dividerRect = tester.getRect(find.byType(Divider));
      expect(sourceTextRect.left, closeTo(dividerRect.left, 0.01));
    });

    testWidgets('单词来源句箭头使用已存定位进入句子讲解页', (tester) async {
      final sourceAudio = AudioItem(
        id: 'audio-1',
        name: 'A source lesson',
        addedDate: DateTime(2026, 1, 1),
        totalDuration: 60,
        sentenceCount: 1,
        wordCount: 5,
        isPinned: false,
        updatedAt: DateTime(2026, 1, 1),
        syncStatus: 0,
      );
      await tester.pumpWidget(createTestWidget(sourceAudio: sourceAudio));
      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      bookmarkController.add([]);
      wordController.add([
        _createSavedWord(
          id: 1,
          word: 'researcher',
          audioItemId: 'audio-1',
          sentenceIndex: 2,
          sentenceText: 'A researcher studies inherited traits.',
          sentenceStartMs: 1200,
          sentenceEndMs: 3600,
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('researcher'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('favorite-word-source-sentence')),
          matching: find.byIcon(Icons.arrow_forward_ios),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sentence detail destination'), findsOneWidget);
      expect(openedSentenceDetailArgs?.audioItemId, 'audio-1');
      expect(openedSentenceDetailArgs?.audioName, 'A source lesson');
      expect(openedSentenceDetailArgs?.sentenceIndex, 2);
      expect(openedSentenceDetailArgs?.startTimeMs, 1200);
      expect(openedSentenceDetailArgs?.endTimeMs, 3600);
    });

    testWidgets('单词来源句右侧整块区域均可进入讲解页', (tester) async {
      final sourceAudio = AudioItem(
        id: 'audio-1',
        name: 'A source lesson',
        addedDate: DateTime(2026, 1, 1),
        totalDuration: 60,
        sentenceCount: 1,
        wordCount: 5,
        isPinned: false,
        updatedAt: DateTime(2026, 1, 1),
        syncStatus: 0,
      );
      await tester.pumpWidget(createTestWidget(sourceAudio: sourceAudio));
      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      bookmarkController.add([]);
      wordController.add([
        _createSavedWord(
          id: 1,
          word: 'researcher',
          audioItemId: 'audio-1',
          sentenceIndex: 2,
          sentenceText: 'A researcher studies inherited traits.',
          sentenceStartMs: 1200,
          sentenceEndMs: 3600,
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('researcher'));
      await tester.pumpAndSettle();

      final actionRect = tester.getRect(
        find.byKey(const Key('favorite-source-sentence-open-action')),
      );
      final tileRect = tester.getRect(
        find.byKey(const Key('favorite-word-source-sentence')),
      );
      expect(actionRect.width, 42);
      expect(actionRect.right, tileRect.right);

      await tester.tapAt(Offset(tileRect.right - 8, tileRect.center.dy));
      await tester.pumpAndSettle();

      expect(find.text('Sentence detail destination'), findsOneWidget);
      expect(openedSentenceDetailArgs?.sentenceIndex, 2);
    });

    testWidgets('单词来源句缺少时间时从字幕恢复后进入讲解页', (tester) async {
      final sourceAudio = AudioItem(
        id: 'audio-1',
        name: 'A source lesson',
        addedDate: DateTime(2026, 1, 1),
        totalDuration: 60,
        sentenceCount: 1,
        wordCount: 5,
        isPinned: false,
        updatedAt: DateTime(2026, 1, 1),
        syncStatus: 0,
      );
      await tester.pumpWidget(
        createTestWidget(
          sourceAudio: sourceAudio,
          sourceTranscriptSrt:
              '1\n00:00:01,200 --> 00:00:03,600\nA researcher studies inherited traits.\n',
        ),
      );
      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      bookmarkController.add([]);
      wordController.add([
        _createSavedWord(
          id: 1,
          word: 'researcher',
          audioItemId: 'audio-1',
          sentenceIndex: 9,
          sentenceText: 'A researcher studies inherited traits.',
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('researcher'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('favorite-word-source-sentence')),
          matching: find.byIcon(Icons.arrow_forward_ios),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sentence detail destination'), findsOneWidget);
      expect(openedSentenceDetailArgs?.sentenceIndex, 0);
      expect(openedSentenceDetailArgs?.startTimeMs, 1200);
      expect(openedSentenceDetailArgs?.endTimeMs, 3600);
    });

    testWidgets('来源材料已删除时显示不可点击提示', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      bookmarkController.add([]);
      wordController.add([
        _createSavedWord(
          id: 1,
          word: 'orphaned',
          sentenceText: 'This source sentence remains after deletion.',
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('orphaned'));
      await tester.pumpAndSettle();

      expect(find.text('Source material not found'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('favorite-word-source-sentence')),
          matching: find.byIcon(Icons.arrow_forward_ios),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });

  group('FavoritesScreen - source audio layout', () {
    testWidgets('long labels stay within a narrow row', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 120,
            child: Row(
              children: [
                Icon(Icons.headphones, size: 12),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'From: exceptionally long audio lesson',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('FavoritesScreen — 单词例句显示', () {
    testWidgets('展开单词后长例句完整显示（无 maxLines 截断）', (tester) async {
      final longSentence =
          'This is a very long example sentence that should be displayed in full '
          'without any truncation because the user needs to read the complete '
          'context of where this word was encountered during their study session.';

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.text('Vocabulary'));
      await tester.pump();
      bookmarkController.add([]);
      wordController.add([
        _createSavedWord(
          id: 1,
          word: 'encountered',
          audioItemId: 'audio-1',
          sentenceIndex: 0,
          sentenceText: longSentence,
        ),
      ]);
      await tester.pumpAndSettle();

      // 展开单词详情
      await tester.tap(find.text('encountered'));
      await tester.pumpAndSettle();

      // 例句应完整显示
      expect(find.text(longSentence), findsOneWidget);

      // 验证例句 Text widget 没有 maxLines 限制
      final textWidget = tester.widget<Text>(find.text(longSentence));
      expect(textWidget.maxLines, isNull, reason: '展开后的例句不应有 maxLines 限制');
    });
  });

  group('FavoritesScreen — 中文本地化', () {
    testWidgets('中文标题和 tab 标签', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('zh')));
      await tester.pump();

      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('句子'), findsOneWidget);
      expect(find.text('词汇'), findsOneWidget);
      expect(find.byIcon(Icons.subject), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);

      await tester.tap(find.text('词汇'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('中文句子空状态', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('zh')));
      bookmarkController.add([]);
      wordController.add([]);
      await tester.pumpAndSettle();

      expect(find.text('暂无收藏句子'), findsOneWidget);
    });
  });
}
