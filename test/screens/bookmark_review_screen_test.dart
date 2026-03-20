// 收藏句子复习页面 Widget 测试
//
// 验证盲听/跟读模式 UI、进度显示、音频来源标签、偷看字幕、完成弹窗等。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/screens/bookmark_review_screen.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_session/bookmark_review_provider.dart';
import 'package:fluency/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluency/database/daos/bookmark_dao.dart';
import 'package:fluency/database/daos/sentence_ai_cache_dao.dart';
import 'package:fluency/database/app_database.dart' show Bookmark;
import 'package:fluency/database/providers.dart';
import 'package:fluency/models/bookmark_sentence.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/providers/sentence_ai_provider.dart';
import 'package:fluency/providers/speech_practice_session_provider.dart';
import 'package:fluency/providers/listen_and_repeat_turn_controller_provider.dart';
import 'package:fluency/services/sentence_ai_api_client.dart';
import 'package:fluency/theme/app_theme.dart';
import 'package:fluency/widgets/intensive_listen/sentence_annotation_card.dart';
import 'package:fluency/widgets/listen_and_repeat/speech_practice_turn_panel.dart';
import 'package:fluency/widgets/listen_and_repeat/speech_record_button.dart';

import '../helpers/mock_providers.dart';

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}

// ========== 测试用 BookmarkDao ==========

class _TestBookmarkDao implements BookmarkDao {
  @override
  Future<List<Bookmark>> getByAudioId(String audioItemId) async => [];

  @override
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

// ========== 测试用 BookmarkReview Provider ==========

/// 带预设句子的测试用 BookmarkReview
class _TestBookmarkReview extends BookmarkReview {
  final ReviewDifficultPracticeState _initialState;
  final List<BookmarkSentence> _testSentences;

  _TestBookmarkReview(this._initialState, this._testSentences);

  @override
  ReviewDifficultPracticeState build() {
    return _initialState;
  }

  @override
  BookmarkSentence? get currentBookmarkSentence =>
      _testSentences.isNotEmpty &&
          state.currentSentenceIndex < _testSentences.length
      ? _testSentences[state.currentSentenceIndex]
      : null;

  @override
  Sentence? get currentSentence => currentBookmarkSentence?.sentence;

  @override
  int get currentIndex => state.currentSentenceIndex;

  @override
  Future<void> startPlaying() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  void pause() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  @override
  Future<void> resume() async {
    if (state.isAnnotationMode) {
      state = state.copyWith(isPlaying: true, currentPlayCount: 1);
      return;
    }
    state = state.copyWith(isPlaying: true);
  }

  @override
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;
    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: true,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isTextRevealed: false,
    );
  }

  @override
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  @override
  Future<void> goToNext() async {
    if (state.currentSentenceIndex < state.totalSentences - 1) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isTextRevealed: false,
        isPauseBetweenPlays: false,
      );
    }
  }

  @override
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex > 0) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex - 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isTextRevealed: false,
        isPauseBetweenPlays: false,
      );
    }
  }

  @override
  BookmarkSentence? removeBookmark() {
    if (_testSentences.isEmpty) return null;
    return _testSentences[state.currentSentenceIndex];
  }

  @override
  Future<void> replayDuringCountdown() async {
    state = state.copyWith(isPauseBetweenPlays: false, isPlaying: true);
  }

  @override
  void pauseCountdown() {
    state = state.copyWith(isCountdownPaused: true);
  }

  @override
  void resumeCountdown() {
    state = state.copyWith(isCountdownPaused: false);
  }

  @override
  void disposePlayer() {
    state = const ReviewDifficultPracticeState();
  }

  @override
  Future<void> resetToStart() async {
    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _testSentences.length,
    );
  }
}

void main() {
  /// 创建测试用的收藏句子列表
  List<BookmarkSentence> createBookmarkSentences({int count = 5}) {
    return List.generate(count, (i) {
      return BookmarkSentence(
        sentence: Sentence(
          index: i,
          text: 'Bookmark sentence number ${i + 1}.',
          startTime: Duration(seconds: i * 5),
          endTime: Duration(seconds: (i + 1) * 5),
          isBookmarked: true,
        ),
        audioItemId: i < 3 ? 'audio-1' : 'audio-2',
        audioName: i < 3 ? 'Audio One' : 'Audio Two',
        originalSentenceIndex: i,
      );
    });
  }

  /// 创建测试用状态
  ReviewDifficultPracticeState createPlayerState({
    int currentSentenceIndex = 0,
    int totalSentences = 5,
    int currentPlayCount = 1,
    bool isPlaying = true,
    bool isAnnotationMode = false,
    bool isTextRevealed = false,
    bool isPauseBetweenPlays = false,
    bool isPauseBetweenSentences = false,
    Duration pauseRemaining = Duration.zero,
    Duration pauseDuration = Duration.zero,
    bool isCountdownPaused = false,
    bool isCountdownFastForward = false,
  }) {
    return ReviewDifficultPracticeState(
      currentSentenceIndex: currentSentenceIndex,
      totalSentences: totalSentences,
      currentPlayCount: currentPlayCount,
      isPlaying: isPlaying,
      isAnnotationMode: isAnnotationMode,
      isTextRevealed: isTextRevealed,
      isPauseBetweenPlays: isPauseBetweenPlays,
      isPauseBetweenSentences: isPauseBetweenSentences,
      pauseRemaining: pauseRemaining,
      pauseDuration: pauseDuration,
      isCountdownPaused: isCountdownPaused,
      isCountdownFastForward: isCountdownFastForward,
    );
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    ReviewDifficultPracticeState? playerState,
    List<BookmarkSentence>? sentences,
    ListenAndRepeatTurnPhase turnPhase = ListenAndRepeatTurnPhase.idle,
  }) {
    final testSentences = sentences ?? createBookmarkSentences();
    final initialPlayerState = playerState ?? createPlayerState();

    final router = GoRouter(
      initialLocation: '/bookmark-review',
      routes: [
        GoRoute(
          path: '/bookmark-review',
          builder: (context, state) => const BookmarkReviewScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        bookmarkReviewProvider.overrideWith(
          () => _TestBookmarkReview(initialPlayerState, testSentences),
        ),
        bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao()),
        speechPracticeSessionProvider.overrideWith(
          () => TestSpeechPracticeSession(),
        ),
        shadowingRecordingControllerProvider.overrideWith(
          () => TestShadowingRecordingController(initialPhase: turnPhase),
        ),
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

  group('BookmarkReviewScreen — 基本渲染', () {
    testWidgets('显示 AppBar 标题', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Bookmark Review'), findsOneWidget);
    });

    testWidgets('显示关闭按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('显示设置按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('显示进度文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3/10 sentences'), findsOneWidget);
    });

    testWidgets('显示音频来源名称', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 第一句来自 Audio One
      expect(find.textContaining('Audio One'), findsOneWidget);
    });

    testWidgets('显示进度条', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('BookmarkReviewScreen — 盲听模式', () {
    testWidgets('显示偷看和听不懂按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peek'), findsOneWidget);
      expect(find.text("Unclear"), findsOneWidget);
    });

    testWidgets('播放中不显示盲听标签（共享 widget 简化）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 共享 PracticeNormalModeView 不再显示盲听标签
      expect(find.byIcon(Icons.headphones), findsNothing);
      expect(find.text('Listening...'), findsNothing);
    });

    testWidgets('偷看切换显示句子文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(isPlaying: true, isTextRevealed: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bookmark sentence number 1.'), findsOneWidget);
    });

    testWidgets('偷看切换隐藏句子文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 非 revealed 时显示隐藏占位
      expect(find.byIcon(Icons.hearing), findsOneWidget);
      expect(find.text('Bookmark sentence number 1.'), findsNothing);
    });

    testWidgets('点击偷看切换文本可见性', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击偷看
      await tester.tap(find.text('Peek'));
      await tester.pumpAndSettle();

      // 切换后文本应可见
      expect(find.text('Bookmark sentence number 1.'), findsOneWidget);
    });

    testWidgets('显示收藏标记行', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark), findsAtLeast(1));
    });

    testWidgets('句间停顿显示倒计时', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPauseBetweenPlays: true,
            isPlaying: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('BookmarkReviewScreen — 跟读模式', () {
    testWidgets('跟读模式显示 SentenceAnnotationCard', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
    });

    testWidgets('跟读模式不显示偷看和听不懂按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peek'), findsNothing);
      expect(find.text("Unclear"), findsNothing);
    });

    testWidgets('跟读模式显示遍数标签', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
            currentPlayCount: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play 2/3'), findsOneWidget);
    });

    testWidgets('跟读留白期显示录音面板', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
            isPauseBetweenPlays: true,
            pauseRemaining: const Duration(seconds: 5),
            pauseDuration: const Duration(seconds: 8),
          ),
          turnPhase: ListenAndRepeatTurnPhase.awaitingSpeech,
        ),
      );
      await tester.pump();
      await tester.pump();

      // 跟读留白期显示录音面板（含录音按钮）
      expect(find.byType(SpeechPracticeTurnPanel), findsOneWidget);
      expect(find.byType(SpeechRecordButton), findsOneWidget);
    });
  });

  group('BookmarkReviewScreen — 播放控制', () {
    testWidgets('显示播放控制按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      // 播放中显示暂停图标
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('播放中点击暂停', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('暂停后点击恢复', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      // 恢复
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('第一句时上一句按钮禁用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(currentSentenceIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      final prevIcon = find.byIcon(Icons.skip_previous_rounded);
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: prevIcon, matching: find.byType(AnimatedOpacity))
            .first,
      );
      expect(opacity.opacity, 0.15);
    });

    testWidgets('最后一句时显示完成图标且始终可用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 4,
            totalSentences: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 最后一句显示 check_circle_rounded 而非 skip_next_rounded
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);

      // 按钮始终可用（opacity > 0.15）
      final checkIcon = find.byIcon(Icons.check_circle_rounded);
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: checkIcon, matching: find.byType(AnimatedOpacity))
            .first,
      );
      expect(opacity.opacity, greaterThan(0.15));
    });

    testWidgets('点击听不懂进入跟读模式', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Unclear"));
      await tester.pumpAndSettle();

      // 进入跟读模式后显示 SentenceAnnotationCard
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      expect(find.text('Peek'), findsNothing);
    });
  });

  group('BookmarkReviewScreen — 中文本地化', () {
    testWidgets('中文标题和操作文案', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('zh')));
      await tester.pumpAndSettle();

      expect(find.text('收藏复习'), findsOneWidget);
      expect(find.text('偷看字幕'), findsOneWidget);
      expect(find.text('听不太懂'), findsOneWidget);
    });
  });
}
