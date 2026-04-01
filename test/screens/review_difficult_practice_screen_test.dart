// 难句补练页面 Widget 测试
//
// 验证盲听模式和跟读模式的 UI 渲染、按钮交互、状态切换。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/screens/review_difficult_practice_screen.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluency/database/daos/bookmark_dao.dart';
import 'package:fluency/database/daos/sentence_ai_cache_dao.dart';
import 'package:fluency/database/app_database.dart' show Bookmark;
import 'package:fluency/database/providers.dart';
import 'package:fluency/providers/sentence_ai_provider.dart';
import 'package:fluency/providers/speech_practice_session_provider.dart';
import 'package:fluency/providers/shadowing/shadowing_recording_controller.dart';
import 'package:fluency/services/sentence_ai_api_client.dart';
import 'package:fluency/theme/app_theme.dart';
import 'package:fluency/widgets/practice/sentence_annotation_card.dart';
import 'package:fluency/widgets/common/recording_button.dart';

import '../helpers/mock_providers.dart';

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}

/// 测试用 BookmarkDao
class _TestBookmarkDao implements BookmarkDao {
  @override
  Future<List<Bookmark>> getByAudioId(String audioItemId) async => [];

  @override
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) =>
      Stream<List<Bookmark>>.value([]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return Future<void>.value();
  }
}

/// 启动后定位到最后一句（等用户点"下一句"触发完成弹窗）
class _AutoCompleteReviewDifficultPractice extends TestReviewDifficultPractice {
  _AutoCompleteReviewDifficultPractice(super.initialState, super.testSentences);

  @override
  Future<void> startPlaying() async {
    state = state.copyWith(
      currentSentenceIndex: state.totalSentences - 1,
      isPlaying: false,
    );
  }
}

void main() {
  /// 创建测试用的难句补练状态
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
    LearningSessionState? sessionState,
    ShadowingRecordingPhase turnPhase = ShadowingRecordingPhase.idle,
    TestReviewDifficultPractice Function(
      ReviewDifficultPracticeState initialState,
      List<Sentence> sentences,
    )?
    playerFactory,
  }) {
    final sentences = createTestSentences(count: 5)
        .map((s) => s.copyWith(isBookmarked: true))
        .toList();
    final initialPlayerState = playerState ?? createPlayerState();

    final router = GoRouter(
      initialLocation: '/collections/c1/a1/review-difficult',
      routes: [
        GoRoute(
          path: '/collections/:collectionId/:audioId/review-difficult',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return ReviewDifficultPracticeScreen(
              collectionId: collectionId,
              audioItemId: audioId,
            );
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        listeningPracticeProvider.overrideWith(
          () => TestListeningPractice(
            ListeningPracticeState(sentences: sentences),
          ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(),
        ),
        learningSessionProvider.overrideWith(
          () =>
              TestLearningSession(sessionState ?? const LearningSessionState()),
        ),
        reviewDifficultPracticeProvider.overrideWith(
          () =>
              playerFactory?.call(initialPlayerState, sentences) ??
              TestReviewDifficultPractice(initialPlayerState, sentences),
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

  group('ReviewDifficultPracticeScreen — 盲听模式', () {
    testWidgets('显示 AppBar 标题', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Difficult Sentence Practice'), findsOneWidget);
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

      expect(find.text('Sentence 3/10'), findsOneWidget);
    });

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
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isAnnotationMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 共享 PracticeNormalModeView 不再显示盲听标签
      expect(find.byIcon(Icons.headphones), findsNothing);
      expect(find.text('Listening...'), findsNothing);
    });

    testWidgets('显示播放/暂停和上下句按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('暂停后显示播放图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 点击暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
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

    testWidgets('偷看时显示文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(isPlaying: true, isTextRevealed: true),
        ),
      );
      await tester.pumpAndSettle();

      // 逐词可点击布局：每个单词是单独的 Text
      expect(find.text('sentence'), findsOneWidget);
      expect(find.text('number'), findsOneWidget);
    });

    testWidgets('偷看字幕点击切换 — 初始隐藏显示听觉图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.hearing), findsOneWidget);
      expect(find.text('Test sentence number 1.'), findsNothing);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('偷看字幕点击切换 — 点击显示文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Peek'));
      await tester.pumpAndSettle();

      // 逐词可点击布局：每个单词是单独的 Text
      expect(find.text('sentence'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('偷看字幕点击切换 — 再次点击隐藏', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击显示
      await tester.tap(find.text('Peek'));
      await tester.pumpAndSettle();
      expect(find.text('sentence'), findsOneWidget);

      // 再次点击隐藏
      await tester.tap(find.text('Peek'));
      await tester.pumpAndSettle();
      expect(find.text('sentence'), findsNothing);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('句间停顿显示倒计时控件', (tester) async {
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

    testWidgets('难句标记行显示星标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.text('Marked difficult, tap to undo'), findsOneWidget);
    });
  });

  group('ReviewDifficultPracticeScreen — 跟读模式', () {
    testWidgets('跟读模式显示句子文本（RichText 可点击查词）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
            currentPlayCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SentenceAnnotationCard 使用 RichText 渲染可点击单词
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      // RichText 中包含句子文本
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Test'),
        ),
        findsOneWidget,
      );
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

    testWidgets('跟读模式显示难句标记行', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.text('Marked difficult, tap to undo'), findsOneWidget);
    });

    testWidgets('跟读模式显示翻译和分析区域', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 工具栏按钮显示翻译和解析
      expect(find.text('Translate'), findsOneWidget);
      expect(find.text('Analysis'), findsOneWidget);
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
          turnPhase: ShadowingRecordingPhase.awaitingSpeech,
        ),
      );
      await tester.pump();
      await tester.pump();

      // 跟读留白期显示录音面板（含录音按钮）
      expect(find.byType(RecordingButton), findsOneWidget);
    });

    testWidgets('跟读模式导航按钮可用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 5,
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prevIcon = find.byIcon(Icons.skip_previous_rounded);
      final nextIcon = find.byIcon(Icons.skip_next_rounded);

      final prevOpacity = tester.widget<Opacity>(
        find.ancestor(of: prevIcon, matching: find.byType(Opacity)).first,
      );
      final nextOpacity = tester.widget<Opacity>(
        find.ancestor(of: nextIcon, matching: find.byType(Opacity)).first,
      );
      expect(prevOpacity.opacity, 0.6);
      expect(nextOpacity.opacity, 0.6);
    });

    testWidgets('跟读模式播放按钮可用（非禁用）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 播放按钮显示暂停图标（非禁用态）
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });
  });

  group('ReviewDifficultPracticeScreen — 播放按钮交互', () {
    testWidgets('播放中点击 → 暂停', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 点击暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      // 应切换为播放图标
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('暂停中点击 → 恢复播放', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 先暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // 再恢复
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('点击听不懂 → 进入跟读模式', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isAnnotationMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Unclear"));
      await tester.pumpAndSettle();

      // 进入跟读模式后应显示 SentenceAnnotationCard
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      // 偷看和听不懂按钮应消失
      expect(find.text('Peek'), findsNothing);
      expect(find.text("Unclear"), findsNothing);
    });

    testWidgets('跟读模式暂停后恢复 → 从第 1 遍重新开始', (tester) async {
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

      // 暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      // 恢复 → resume 调 _startShadowReading()，currentPlayCount 回 1
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Play 1/3'), findsOneWidget);
    });
  });

  group('ReviewDifficultPracticeScreen — 中文本地化', () {
    testWidgets('中文显示正确', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('zh')));
      await tester.pumpAndSettle();

      expect(find.text('难句补练'), findsOneWidget);
      expect(find.text('偷看字幕'), findsOneWidget);
      expect(find.text('听不太懂'), findsOneWidget);
    });

    testWidgets('中文跟读模式遍数显示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          locale: const Locale('zh'),
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
            currentPlayCount: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('第 2/3 遍'), findsOneWidget);
    });
  });

  group('ReviewDifficultPracticeScreen — 完成弹窗', () {
    testWidgets('非自由练习模式完成弹窗显示步骤完成对话框', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          sessionState: const LearningSessionState(isFreePlay: false),
          playerState: createPlayerState(
            currentSentenceIndex: 4,
            totalSentences: 5,
            isPlaying: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 最后一句显示完成按钮（check_circle_rounded），点击触发完成弹窗
      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pumpAndSettle();

      // 完成弹窗应显示步骤完成对话框
      expect(find.text('Difficult Practice Complete'), findsOneWidget);
    });
  });
}
