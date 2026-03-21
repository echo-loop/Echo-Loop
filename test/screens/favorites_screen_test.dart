// 收藏页面 Widget 测试
//
// 验证句子/单词视图切换、按音频分组展示、空状态、收藏操作等 UI 行为。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/screens/favorites_screen.dart';
import 'package:fluency/database/daos/audio_item_dao.dart';
import 'package:fluency/database/daos/bookmark_dao.dart';
import 'package:fluency/database/daos/saved_word_dao.dart';
import 'package:fluency/database/daos/sentence_ai_cache_dao.dart';
import 'package:fluency/database/app_database.dart';
import 'package:fluency/database/providers.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/sentence_ai_provider.dart';
import 'package:fluency/services/sentence_ai_api_client.dart';
import 'package:fluency/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

// ========== 测试用 Mock / Stub ==========

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}

class _MockAudioItemDao extends Mock implements AudioItemDao {
  _MockAudioItemDao() {
    // 默认返回 null（音频不存在），避免未 stub 报错
    when(() => getById(any())).thenAnswer((_) async => null);
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
}) {
  return SavedWord(
    id: id,
    word: word,
    audioItemId: audioItemId,
    sentenceIndex: sentenceIndex,
    sentenceText: sentenceText,
    sentenceStartMs: null,
    sentenceEndMs: null,
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

  setUp(() {
    bookmarkController = StreamController<List<BookmarkWithAudio>>.broadcast();
    wordController = StreamController<List<SavedWord>>.broadcast();
  });

  tearDown(() {
    bookmarkController.close();
    wordController.close();
  });

  Widget createTestWidget({Locale locale = const Locale('en')}) {
    final router = GoRouter(
      initialLocation: '/favorites',
      routes: [
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: '/bookmark-review',
          builder: (context, state) =>
              const Scaffold(body: Text('Bookmark Review')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        bookmarkDaoProvider.overrideWithValue(
          _TestBookmarkDao(bookmarkController),
        ),
        savedWordDaoProvider.overrideWithValue(
          _TestSavedWordDao(wordController),
        ),
        audioItemDaoProvider.overrideWithValue(_MockAudioItemDao()),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        sentenceAiNotifierProvider.overrideWithValue(
          SentenceAiNotifier(
            cacheDao: _MockCacheDao(),
            apiClient: _MockApiClient(),
          ),
        ),
      ],
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
    );
  }

  group('FavoritesScreen — SegmentedButton 切换', () {
    testWidgets('默认显示句子视图和 tab 标签', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // tab 标签文本可见
      expect(find.text('Sentences'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
    });

    testWidgets('点击 Words 切换到单词视图', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // 点击 Words 按钮
      await tester.tap(find.text('Words'));
      await tester.pump();

      // 单词视图加载中（stream 尚未发射数据）
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('切换到单词再切回句子', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.text('Words'));
      await tester.pump();

      await tester.tap(find.text('Sentences'));
      await tester.pump();

      // 句子视图应显示加载状态（等待 stream 数据）
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('FavoritesScreen — 句子视图', () {
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
      await tester.pumpWidget(createTestWidget());

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
      // 耳机图标（在按钮中）
      expect(find.byIcon(Icons.headphones), findsAtLeast(1));
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

      // 时间格式 MM:SS
      expect(find.text('01:05 - 01:10'), findsOneWidget);
    });

    testWidgets('句子项显示播放按钮', (tester) async {
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
      ]);
      wordController.add([]);
      await tester.pumpAndSettle();

      // 展开
      await tester.tap(find.text('Audio One'));
      await tester.pumpAndSettle();

      // 播放按钮
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });

    testWidgets('多个音频分组各自有练习按钮', (tester) async {
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

      // 每个音频组标题旁有耳机练习按钮 + 顶部复习按钮
      expect(find.byIcon(Icons.headphones), findsAtLeast(3));
    });
  });

  group('FavoritesScreen — 单词视图', () {
    testWidgets('无数据时显示单词空状态', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // 切到单词视图
      await tester.tap(find.text('Words'));
      await tester.pump();
      wordController.add([]);
      await tester.pump();
      await tester.pump();

      expect(find.text('No saved words yet'), findsOneWidget);
    });

    testWidgets('有数据时显示单词列表', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.text('Words'));
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

    testWidgets('单词项显示单词内容', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.text('Words'));
      await tester.pump();
      wordController.add([_createSavedWord(id: 1, word: 'hello')]);
      await tester.pump();
      await tester.pump();

      expect(find.text('hello'), findsOneWidget);
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

      await tester.tap(find.text('Words'));
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
      expect(textWidget.maxLines, isNull,
          reason: '展开后的例句不应有 maxLines 限制');
    });
  });

  group('FavoritesScreen — 中文本地化', () {
    testWidgets('中文标题和 tab 标签', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('zh')));
      await tester.pump();

      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('句子'), findsOneWidget);
      expect(find.text('单词'), findsOneWidget);
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
