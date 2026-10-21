// 复述播放器页面 Widget 测试
//
// 验证 SegmentedButton 位置和显示模式切换功能。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart'
    show ShadowingControlMode;
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/screens/retell_player_screen.dart';
import 'package:echo_loop/screens/sentence_detail_screen.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/new_user_guide_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/providers/media_engine/media_sense_group_range_playback.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';
import 'package:echo_loop/providers/notification_permission_provider.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/database/app_database.dart' show Bookmark;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/retell_recording_controller_provider.dart';
import 'package:echo_loop/providers/retell_review_evaluation_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/services/notification_permission_service.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/services/audio_playback_service.dart';
import 'package:echo_loop/services/audio_preview_controller.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/features/subscription/providers/subscription_availability.dart';
import 'package:echo_loop/features/subscription/models/ai_quota_rejection.dart';
import 'package:echo_loop/widgets/common/playback_controls.dart';
import 'package:echo_loop/widgets/common/recording_button.dart';
import 'package:echo_loop/widgets/common/masked_sentence_tile.dart';
import 'package:echo_loop/widgets/study/study_activity_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}

class _MockNotificationPermissionService extends Mock
    implements NotificationPermissionService {}

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

class _StaticRetellPlayer extends TestRetellPlayer {
  _StaticRetellPlayer(super.initialState, super.paragraphs, super.keywords);

  @override
  Future<void> startPlaying() async {}
}

class _TrackingRetellPlayer extends _StaticRetellPlayer {
  _TrackingRetellPlayer(super.initialState, super.paragraphs, super.keywords);

  int waitingCalls = 0;
  bool? lastAfterCurrentParagraph;
  bool? lastStopImmediately;

  int seekCalls = 0;
  int? lastSeekGlobalIndex;
  int bookmarkCalls = 0;
  int? lastBookmarkedSentenceIndex;

  @override
  void enterWaitingForUser({
    bool afterCurrentParagraph = false,
    bool stopImmediately = false,
  }) {
    waitingCalls += 1;
    lastAfterCurrentParagraph = afterCurrentParagraph;
    lastStopImmediately = stopImmediately;
  }

  @override
  Future<void> seekToSentence(int globalSentenceIndex) async {
    seekCalls += 1;
    lastSeekGlobalIndex = globalSentenceIndex;
    await super.seekToSentence(globalSentenceIndex);
  }

  @override
  Future<void> toggleBookmark(String audioItemId, Sentence sentence) async {
    bookmarkCalls += 1;
    lastBookmarkedSentenceIndex = sentence.index;
    await super.toggleBookmark(audioItemId, sentence);
  }

  void emit(RetellPlayerState nextState) {
    state = nextState;
  }
}

class _BlockingAudioPlaybackService extends AudioPlaybackService {
  final List<String> playedFiles = [];
  int stopCalls = 0;
  Completer<void>? playCompleter;

  @override
  Future<void> play(String filePath) {
    playedFiles.add(filePath);
    playCompleter = Completer<void>();
    return playCompleter!.future;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    final completer = playCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Future<void> dispose() async {
    final completer = playCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

class _RecordingResultRetellController extends TestRetellRecordingController {
  _RecordingResultRetellController(super.initialState);

  @override
  Future<void> stopAndEvaluate({required String referenceText}) async {
    final promptId = state.promptId ?? '';
    state = state.copyWith(phase: RetellRecordingPhase.processing);
    state = state.copyWith(
      phase: RetellRecordingPhase.idle,
      currentAttempt: SpeechPracticeAttempt(
        promptId: promptId,
        filePath: '/tmp/manual-stop-retell.m4a',
        finalTranscript: 'manual stop retell transcript',
        status: SpeechPracticeAttemptStatus.passed,
        score: 0.83,
      ),
      clearPromptId: true,
    );
  }
}

class _SeenGuideRegistry extends GuideRegistry {
  @override
  Future<bool> isSeen(String flowId) async => true;

  @override
  Future<void> markSeen(String flowId) async {}

  @override
  Future<void> reset(String flowId) async {}
}

/// 可在页面已完成初始化后推送评估状态的测试 controller。
class _ManualRetellReviewController extends RetellReviewEvaluationController {
  @override
  RetellReviewEvaluationState build() => const RetellReviewEvaluationState();

  @override
  void syncAttempt(String? attemptKey) {}

  void emit(RetellReviewEvaluationState next) {
    state = next;
  }
}

void main() {
  /// 创建测试段落
  List<List<Sentence>> createTestParagraphs() {
    return [createTestSentences(count: 3)];
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    RetellPlayerState? playerState,
    RetellRecordingState? recordingState,
    List<List<Sentence>>? paragraphs,
    Map<int, Set<int>>? keywords,
    TestRetellPlayer Function(
      RetellPlayerState initialState,
      List<List<Sentence>> paragraphs,
      Map<int, Set<int>> keywords,
    )?
    playerFactory,
    List<Override> extraOverrides = const [],
  }) {
    final testParagraphs = paragraphs ?? createTestParagraphs();
    final testKeywords = keywords ?? {};
    final initialState =
        playerState ??
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.listening,
          isPlaying: true,
          playingSentenceIndex: 0,
          settings: const RetellSettings(keywordMethod: KeywordMethod.random),
        );

    final router = GoRouter(
      initialLocation: '/collections/c1/a1/retell',
      routes: [
        GoRoute(
          path: '/collections/:collectionId/:audioId/retell',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return RetellPlayerScreen(
              collectionId: collectionId,
              audioItemId: audioId,
            );
          },
          routes: [
            GoRoute(
              path: 'sentence-detail',
              builder: (context, state) =>
                  const Scaffold(body: Text('Sentence Detail')),
            ),
          ],
        ),
        GoRoute(
          path: '/paywall',
          builder: (context, state) => const Scaffold(body: Text('Paywall')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        ...learningSettingsOverrides(),
        guideRegistryProvider.overrideWithValue(_SeenGuideRegistry()),
        listeningPracticeProvider.overrideWith(
          () => TestListeningPractice(
            ListeningPracticeState(
              sentences: testParagraphs.expand((p) => p).toList(),
            ),
          ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        foregroundAudioEngineProvider.overrideWith(
          () => TestForegroundAudioEngine(),
        ),
        mediaEngineProvider.overrideWith(MediaEngine.new),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(),
        ),
        learningSessionProvider.overrideWith(() => TestLearningSession()),
        retellPlayerProvider.overrideWith(
          () => (playerFactory ?? TestRetellPlayer.new)(
            initialState,
            testParagraphs,
            testKeywords,
          ),
        ),
        ...studyTimeOverrides(),
        retellRecordingControllerProvider.overrideWith(
          () => TestRetellRecordingController(
            recordingState ?? const RetellRecordingState(),
          ),
        ),
        bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao()),
        sentenceAiNotifierProvider.overrideWithValue(
          SentenceAiNotifier(
            cacheDao: _MockCacheDao(),
            apiClient: _MockApiClient(),
          ),
        ),
        ...extraOverrides,
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

  group('RetellPlayerScreen — SegmentedButton 位置', () {
    testWidgets('AI 复述评估额度用尽时先提示，确认升级后才进入订阅页', (tester) async {
      final reviewController = _ManualRetellReviewController();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        createTestWidget(
          extraOverrides: [
            retellReviewEvaluationProvider.overrideWith(() => reviewController),
            subscriptionAvailabilityProvider.overrideWithValue(true),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        ),
      );
      await tester.pumpAndSettle();

      reviewController.emit(
        const RetellReviewEvaluationState(
          attemptKey: 'retell:a1:0:/tmp/retell-review.m4a',
          phase: RetellReviewEvaluationPhase.failed,
          errorCode: 'quota_exceeded',
          quotaReason: AiQuotaRejectionReason.unsupportedForFreePlan,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("The free plan doesn't support AI retell review"),
        findsOneWidget,
      );
      expect(find.text('Paywall'), findsNothing);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(
        find.text("The free plan doesn't support AI retell review"),
        findsNothing,
      );

      // 用户再次主动评估时仍应可看到提示，而不是被已展示记录静默抑制。
      reviewController.emit(
        const RetellReviewEvaluationState(
          attemptKey: 'retell:a1:0:/tmp/retell-review.m4a',
          phase: RetellReviewEvaluationPhase.loading,
        ),
      );
      reviewController.emit(
        const RetellReviewEvaluationState(
          attemptKey: 'retell:a1:0:/tmp/retell-review.m4a',
          phase: RetellReviewEvaluationPhase.failed,
          errorCode: 'quota_exceeded',
          quotaReason: AiQuotaRejectionReason.unsupportedForFreePlan,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text("The free plan doesn't support AI retell review"),
        findsOneWidget,
      );

      await tester.tap(find.text('Upgrade Now'));
      await tester.pumpAndSettle();
      expect(find.text('Paywall'), findsOneWidget);
    });

    testWidgets('SegmentedButton 存在且位于句子列表之后', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final segmentedButton = find.byType(SegmentedButton<RetellDisplayMode>);
      expect(segmentedButton, findsOneWidget);
      expect(find.byType(PlaybackControls), findsOneWidget);

      final sentenceCard = find.byType(Card).first;
      final sentenceCardBox = tester.getRect(sentenceCard);
      final segmentedBox = tester.getRect(segmentedButton);

      expect(
        segmentedBox.top,
        greaterThanOrEqualTo(sentenceCardBox.bottom - 1),
        reason: 'SegmentedButton 应位于句子列表卡片下方',
      );
    });

    testWidgets('页面接入学习统计活动检测器', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(StudyActivityDetector), findsOneWidget);
    });

    testWidgets('切换显示模式功能正常', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 默认应选中 Visible Only
      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('Visible'), findsOneWidget);
      expect(find.text('Hidden'), findsOneWidget);

      // 点击 Show All
      await tester.tap(find.text('Visible'));
      await tester.pumpAndSettle();

      // 验证选中状态变化（通过 SegmentedButton 的 selected 属性）
      final segmented = tester.widget<SegmentedButton<RetellDisplayMode>>(
        find.byType(SegmentedButton<RetellDisplayMode>),
      );
      expect(segmented.selected, contains(RetellDisplayMode.showAll));
    });

    testWidgets('完成后不再检查学习版通知提示', (tester) async {
      final notificationService = _MockNotificationPermissionService();
      when(
        () => notificationService.canShowPrompt(),
      ).thenAnswer((_) async => true);

      final testParagraphs = createTestParagraphs();
      final initialState = RetellPlayerState(
        currentParagraphIndex: 0,
        totalParagraphs: testParagraphs.length,
        phase: RetellPhase.listening,
        isPlaying: true,
        playingSentenceIndex: 0,
        displayMode: RetellDisplayMode.showAll,
        settings: const RetellSettings(keywordMethod: KeywordMethod.random),
      );
      final trackingPlayer = _TrackingRetellPlayer(
        initialState,
        testParagraphs,
        const {},
      );

      await tester.pumpWidget(
        createTestWidget(
          playerState: initialState,
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => trackingPlayer,
          extraOverrides: [
            notificationPermissionServiceProvider.overrideWithValue(
              notificationService,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      trackingPlayer.emit(
        trackingPlayer.state.copyWith(stepFinished: true, isPlaying: false),
      );
      // 完成态包含循环动画，固定推进即可观察状态更新。
      await tester.pump(const Duration(milliseconds: 700));

      verifyNever(() => notificationService.canShowPrompt());
    });

    testWidgets('不同选中态下 SegmentedButton 总宽度保持不变', (tester) async {
      Future<double> pumpAndMeasure(RetellDisplayMode displayMode) async {
        await tester.pumpWidget(
          createTestWidget(
            playerState: RetellPlayerState(
              currentParagraphIndex: 0,
              totalParagraphs: 1,
              phase: RetellPhase.listening,
              isPlaying: true,
              playingSentenceIndex: 0,
              displayMode: displayMode,
              settings: const RetellSettings(
                keywordMethod: KeywordMethod.random,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        return tester
            .getRect(find.byType(SegmentedButton<RetellDisplayMode>))
            .width;
      }

      final keywordsOnlyWidth = await pumpAndMeasure(
        RetellDisplayMode.keywordsOnly,
      );
      final showAllWidth = await pumpAndMeasure(RetellDisplayMode.showAll);
      final hideAllWidth = await pumpAndMeasure(RetellDisplayMode.hideAll);

      expect(showAllWidth, equals(keywordsOnlyWidth));
      expect(hideAllWidth, equals(keywordsOnlyWidth));
    });

    testWidgets('录音和评估控制区位于可见性菜单下方', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: RetellPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 1,
            phase: RetellPhase.retelling,
            isPlaying: false,
            settings: const RetellSettings(keywordMethod: KeywordMethod.random),
          ),
          playerFactory: _StaticRetellPlayer.new,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final segmentedButton = find.byType(SegmentedButton<RetellDisplayMode>);
      final recordingButton = find.byType(RecordingButton);

      expect(segmentedButton, findsOneWidget);
      expect(recordingButton, findsOneWidget);
      expect(
        tester.getRect(recordingButton).top,
        greaterThan(tester.getRect(segmentedButton).bottom),
      );
    });

    testWidgets('播放前显示先听再复述提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: RetellPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 1,
            phase: RetellPhase.listening,
            isPlaying: false,
            settings: const RetellSettings(keywordMethod: KeywordMethod.random),
          ),
          playerFactory: _StaticRetellPlayer.new,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Listen first, then retell'), findsOneWidget);
      expect(find.text('Listening closely...'), findsNothing);
    });

    testWidgets('WaitingForUser 态即使 isPlaying 为 true 也显示播放图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: RetellPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 1,
            phase: RetellPhase.listening,
            isPlaying: true,
            isWaitingForUser: true,
            settings: const RetellSettings(keywordMethod: KeywordMethod.random),
          ),
          playerFactory: _StaticRetellPlayer.new,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('播放完成后空闲态不显示复述提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: RetellPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 1,
            phase: RetellPhase.retelling,
            isPlaying: false,
            settings: const RetellSettings(
              controlMode: ShadowingControlMode.manual,
              keywordMethod: KeywordMethod.random,
            ),
          ),
          playerFactory: _StaticRetellPlayer.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retell what you heard'), findsNothing);
      expect(find.text('Listening closely...'), findsNothing);
    });

    testWidgets('录音中显示录音状态而不显示复述提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: RetellPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 1,
            phase: RetellPhase.retelling,
            isPlaying: false,
            settings: const RetellSettings(
              controlMode: ShadowingControlMode.manual,
              keywordMethod: KeywordMethod.random,
            ),
          ),
          recordingState: const RetellRecordingState(
            phase: RetellRecordingPhase.recording,
          ),
          playerFactory: _StaticRetellPlayer.new,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Retell what you heard'), findsNothing);
      expect(find.text('Recording...'), findsOneWidget);
    });

    testWidgets('首次评估完成先弹窗，选择保持关闭后才启动倒计时', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final testParagraphs = createTestParagraphs();
      final player = _StaticRetellPlayer(
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.retelling,
          settings: const RetellSettings(keywordMethod: KeywordMethod.random),
        ),
        testParagraphs,
        const {},
      );
      final recordingController = TestRetellRecordingController(
        const RetellRecordingState(phase: RetellRecordingPhase.processing),
      );

      await tester.pumpWidget(
        createTestWidget(
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => player,
          recordingState: const RetellRecordingState(
            phase: RetellRecordingPhase.processing,
          ),
          extraOverrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialLearningSettingsProvider.overrideWithValue(
              LearningSettings.fromPrefsSync(prefs),
            ),
            retellRecordingControllerProvider.overrideWith(
              () => recordingController,
            ),
          ],
        ),
      );
      await tester.pump();

      recordingController.setState(
        const RetellRecordingState(
          phase: RetellRecordingPhase.idle,
          currentAttempt: SpeechPracticeAttempt(
            promptId: 'retell:a1:0',
            filePath: '/tmp/retell.m4a',
            status: SpeechPracticeAttemptStatus.passed,
            score: 0.8,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Auto-play your recording after retelling?'),
        findsOneWidget,
      );
      expect(player.postEvaluationPauseCalls, 0);

      await tester.tap(find.text('Not Now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        prefs.getBool(LearningSettingsKeys.retellAutoPlaybackPromptShown),
        isTrue,
      );
      expect(
        prefs.getBool(
          LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion,
        ),
        isNull,
      );
      expect(player.postEvaluationPauseCalls, 1);
      expect(player.lastPostEvaluationScore, 0.8);
    });

    testWidgets('全局已开启但未提示过时，首次完成不弹窗且直接自动回听', (tester) async {
      // Bug 1：用户在设置页开了全局开关（autoPlay=true）但 promptShown 仍为 false，
      // 首段完成不应再弹「是否开启」提示，且应直接自动回放。
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = _BlockingAudioPlaybackService();
      final testParagraphs = createTestParagraphs();
      final player = _StaticRetellPlayer(
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.retelling,
          settings: const RetellSettings(
            keywordMethod: KeywordMethod.random,
            autoPlayRecordingAfterCompletion: true,
          ),
        ),
        testParagraphs,
        const {},
      );
      final recordingController = TestRetellRecordingController(
        const RetellRecordingState(phase: RetellRecordingPhase.processing),
      );

      await tester.pumpWidget(
        createTestWidget(
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => player,
          recordingState: const RetellRecordingState(
            phase: RetellRecordingPhase.processing,
          ),
          extraOverrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialLearningSettingsProvider.overrideWithValue(
              LearningSettings.fromPrefsSync(prefs),
            ),
            retellRecordingPreviewProvider.overrideWithValue(
              AudioPreviewController(service: service),
            ),
            retellRecordingControllerProvider.overrideWith(
              () => recordingController,
            ),
          ],
        ),
      );
      await tester.pump();

      recordingController.setState(
        const RetellRecordingState(
          phase: RetellRecordingPhase.idle,
          currentAttempt: SpeechPracticeAttempt(
            promptId: 'retell:a1:0',
            filePath: '/tmp/retell.m4a',
            finalTranscript: 'retell transcript',
            status: SpeechPracticeAttemptStatus.passed,
            score: 0.8,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // 不应弹出首次提示
      expect(
        find.text('Auto-play your recording after retelling?'),
        findsNothing,
      );
      // 直接自动回放，回放结束前不启动倒计时
      expect(service.playedFiles, ['/tmp/retell.m4a']);
      expect(player.postEvaluationPauseCalls, 0);

      service.playCompleter?.complete();
      await tester.pumpAndSettle();

      expect(player.postEvaluationPauseCalls, 1);
    });

    testWidgets('关闭复述评级时显示录音 badge 且段间停顿不传评分', (tester) async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.retellAutoPlaybackPromptShown: true,
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: true,
        LearningSettingsKeys.retellRatingEnabled: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = _BlockingAudioPlaybackService();
      final testParagraphs = createTestParagraphs();
      final player = _StaticRetellPlayer(
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.retelling,
          settings: const RetellSettings(
            keywordMethod: KeywordMethod.random,
            autoPlayRecordingAfterCompletion: true,
          ),
        ),
        testParagraphs,
        const {},
      );
      final recordingController = TestRetellRecordingController(
        const RetellRecordingState(phase: RetellRecordingPhase.processing),
      );

      await tester.pumpWidget(
        createTestWidget(
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => player,
          recordingState: const RetellRecordingState(
            phase: RetellRecordingPhase.processing,
          ),
          extraOverrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialLearningSettingsProvider.overrideWithValue(
              LearningSettings.fromPrefsSync(prefs),
            ),
            retellRecordingPreviewProvider.overrideWithValue(
              AudioPreviewController(service: service),
            ),
            retellRecordingControllerProvider.overrideWith(
              () => recordingController,
            ),
          ],
        ),
      );
      await tester.pump();

      recordingController.setState(
        const RetellRecordingState(
          phase: RetellRecordingPhase.idle,
          currentAttempt: SpeechPracticeAttempt(
            promptId: 'retell:a1:0',
            filePath: '/tmp/retell.m4a',
            status: SpeechPracticeAttemptStatus.unavailable,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(service.playedFiles, ['/tmp/retell.m4a']);
      expect(find.text('Recording'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
      expect(player.postEvaluationPauseCalls, 0);

      service.playCompleter?.complete();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      expect(player.postEvaluationPauseCalls, 1);
      expect(player.lastPostEvaluationScore, isNull);
    });

    testWidgets('已开启自动回听时 badge 显示停止态，停止后才启动倒计时', (tester) async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.retellAutoPlaybackPromptShown: true,
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = _BlockingAudioPlaybackService();
      final testParagraphs = createTestParagraphs();
      final player = _StaticRetellPlayer(
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.retelling,
          settings: const RetellSettings(
            keywordMethod: KeywordMethod.random,
            autoPlayRecordingAfterCompletion: true,
          ),
        ),
        testParagraphs,
        const {},
      );
      final recordingController = TestRetellRecordingController(
        const RetellRecordingState(phase: RetellRecordingPhase.processing),
      );

      await tester.pumpWidget(
        createTestWidget(
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => player,
          recordingState: const RetellRecordingState(
            phase: RetellRecordingPhase.processing,
          ),
          extraOverrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialLearningSettingsProvider.overrideWithValue(
              LearningSettings.fromPrefsSync(prefs),
            ),
            retellRecordingPreviewProvider.overrideWithValue(
              AudioPreviewController(service: service),
            ),
            retellRecordingControllerProvider.overrideWith(
              () => recordingController,
            ),
          ],
        ),
      );
      await tester.pump();

      recordingController.setState(
        const RetellRecordingState(
          phase: RetellRecordingPhase.idle,
          currentAttempt: SpeechPracticeAttempt(
            promptId: 'retell:a1:0',
            filePath: '/tmp/retell.m4a',
            finalTranscript: 'retell transcript',
            status: SpeechPracticeAttemptStatus.passed,
            score: 0.72,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(service.playedFiles, ['/tmp/retell.m4a']);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
      expect(player.postEvaluationPauseCalls, 0);

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(service.stopCalls, 1);
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      expect(player.postEvaluationPauseCalls, 1);
      expect(player.lastPostEvaluationScore, 0.72);
    });

    testWidgets('手动控制模式下评估完成仍会自动回听录音', (tester) async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.retellAutoPlaybackPromptShown: true,
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = _BlockingAudioPlaybackService();
      final testParagraphs = createTestParagraphs();
      final player = _StaticRetellPlayer(
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.retelling,
          settings: const RetellSettings(
            keywordMethod: KeywordMethod.random,
            controlMode: ShadowingControlMode.manual,
            autoPlayRecordingAfterCompletion: true,
          ),
        ),
        testParagraphs,
        const {},
      );
      final recordingController = TestRetellRecordingController(
        const RetellRecordingState(phase: RetellRecordingPhase.processing),
      );

      await tester.pumpWidget(
        createTestWidget(
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => player,
          recordingState: const RetellRecordingState(
            phase: RetellRecordingPhase.processing,
          ),
          extraOverrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialLearningSettingsProvider.overrideWithValue(
              LearningSettings.fromPrefsSync(prefs),
            ),
            retellRecordingPreviewProvider.overrideWithValue(
              AudioPreviewController(service: service),
            ),
            retellRecordingControllerProvider.overrideWith(
              () => recordingController,
            ),
          ],
        ),
      );
      await tester.pump();

      recordingController.setState(
        const RetellRecordingState(
          phase: RetellRecordingPhase.idle,
          currentAttempt: SpeechPracticeAttempt(
            promptId: 'retell:a1:0',
            filePath: '/tmp/manual-retell.m4a',
            finalTranscript: 'manual retell transcript',
            status: SpeechPracticeAttemptStatus.passed,
            score: 0.81,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(service.playedFiles, ['/tmp/manual-retell.m4a']);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      service.playCompleter?.complete();
      await tester.pumpAndSettle();

      expect(player.postEvaluationPauseCalls, 0);
    });

    testWidgets('用户点击录音按钮停止后仍会自动回听录音', (tester) async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.retellAutoPlaybackPromptShown: true,
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = _BlockingAudioPlaybackService();
      final testParagraphs = createTestParagraphs();
      final player = _StaticRetellPlayer(
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.retelling,
          settings: const RetellSettings(
            keywordMethod: KeywordMethod.random,
            autoPlayRecordingAfterCompletion: true,
          ),
        ),
        testParagraphs,
        const {},
      );
      final recordingController = _RecordingResultRetellController(
        const RetellRecordingState(
          phase: RetellRecordingPhase.recording,
          promptId: 'retell:a1:0',
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => player,
          recordingState: const RetellRecordingState(
            phase: RetellRecordingPhase.recording,
            promptId: 'retell:a1:0',
          ),
          extraOverrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialLearningSettingsProvider.overrideWithValue(
              LearningSettings.fromPrefsSync(prefs),
            ),
            retellRecordingPreviewProvider.overrideWithValue(
              AudioPreviewController(service: service),
            ),
            retellRecordingControllerProvider.overrideWith(
              () => recordingController,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(RecordingButton));
      await tester.pump();
      await tester.pump();

      expect(service.playedFiles, ['/tmp/manual-stop-retell.m4a']);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(player.postEvaluationPauseCalls, 0);

      service.playCompleter?.complete();
      await tester.pumpAndSettle();

      expect(player.postEvaluationPauseCalls, 1);
      expect(player.lastPostEvaluationScore, 0.83);
    });

    testWidgets('同一段再次录音完成后仍会自动回听最新录音', (tester) async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.retellAutoPlaybackPromptShown: true,
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = _BlockingAudioPlaybackService();
      final testParagraphs = createTestParagraphs();
      final player = _StaticRetellPlayer(
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.retelling,
          settings: const RetellSettings(
            keywordMethod: KeywordMethod.random,
            controlMode: ShadowingControlMode.manual,
            autoPlayRecordingAfterCompletion: true,
          ),
        ),
        testParagraphs,
        const {},
      );
      final recordingController = _RecordingResultRetellController(
        const RetellRecordingState(
          phase: RetellRecordingPhase.recording,
          promptId: 'retell:a1:0',
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => player,
          recordingState: const RetellRecordingState(
            phase: RetellRecordingPhase.recording,
            promptId: 'retell:a1:0',
          ),
          extraOverrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialLearningSettingsProvider.overrideWithValue(
              LearningSettings.fromPrefsSync(prefs),
            ),
            retellRecordingPreviewProvider.overrideWithValue(
              AudioPreviewController(service: service),
            ),
            retellRecordingControllerProvider.overrideWith(
              () => recordingController,
            ),
          ],
        ),
      );
      await tester.pump();

      // 第一次录音完成并自动回听。
      await tester.tap(find.byType(RecordingButton));
      await tester.pump();
      await tester.pump();
      expect(service.playedFiles, ['/tmp/manual-stop-retell.m4a']);
      service.playCompleter?.complete();
      await tester.pumpAndSettle();

      // 用户不点击主播放按钮，直接开始并停止同一段的第二次录音。
      recordingController.setState(
        const RetellRecordingState(
          phase: RetellRecordingPhase.recording,
          promptId: 'retell:a1:0',
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(RecordingButton));
      await tester.pump();
      await tester.pump();

      expect(service.playedFiles, [
        '/tmp/manual-stop-retell.m4a',
        '/tmp/manual-stop-retell.m4a',
      ]);
    });

    testWidgets('等待态下手动开始录音，完成后仍会自动回听并启动倒计时', (tester) async {
      // Bug：打开设置面板会进入 isWaitingForUser=true，随后直接点录音按钮开始录音，
      // 若不退出等待态，评估完成处理会被 !isWaitingForUser 门控整体跳过 →
      // 不自动回放也不启动倒计时。
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.retellAutoPlaybackPromptShown: true,
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = _BlockingAudioPlaybackService();
      final testParagraphs = createTestParagraphs();
      final player = _StaticRetellPlayer(
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.retelling,
          // 关键：初始处于等待用户态（模拟刚关闭设置面板）
          isWaitingForUser: true,
          settings: const RetellSettings(
            keywordMethod: KeywordMethod.random,
            autoPlayRecordingAfterCompletion: true,
          ),
        ),
        testParagraphs,
        const {},
      );
      final recordingController = TestRetellRecordingController(
        const RetellRecordingState(phase: RetellRecordingPhase.idle),
      );

      await tester.pumpWidget(
        createTestWidget(
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => player,
          recordingState: const RetellRecordingState(
            phase: RetellRecordingPhase.idle,
          ),
          extraOverrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialLearningSettingsProvider.overrideWithValue(
              LearningSettings.fromPrefsSync(prefs),
            ),
            retellRecordingPreviewProvider.overrideWithValue(
              AudioPreviewController(service: service),
            ),
            retellRecordingControllerProvider.overrideWith(
              () => recordingController,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 等待态下手动点录音 → 应退出等待态并开始录音
      await tester.tap(find.byType(RecordingButton));
      await tester.pump();

      // 模拟录音自动完成
      recordingController.setState(
        const RetellRecordingState(
          phase: RetellRecordingPhase.idle,
          currentAttempt: SpeechPracticeAttempt(
            promptId: 'retell:a1:0',
            filePath: '/tmp/waiting-start-retell.m4a',
            finalTranscript: 'retell transcript',
            status: SpeechPracticeAttemptStatus.passed,
            score: 0.77,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // 自动回放发生，回放结束前不启动倒计时
      expect(service.playedFiles, ['/tmp/waiting-start-retell.m4a']);
      expect(player.postEvaluationPauseCalls, 0);

      service.playCompleter?.complete();
      await tester.pumpAndSettle();

      expect(player.postEvaluationPauseCalls, 1);
      expect(player.lastPostEvaluationScore, 0.77);
    });

    testWidgets('点击左侧讲解按钮进入详情前会进入 waiting for user', (tester) async {
      final testParagraphs = createTestParagraphs();
      final initialState = RetellPlayerState(
        currentParagraphIndex: 0,
        totalParagraphs: testParagraphs.length,
        phase: RetellPhase.listening,
        isPlaying: true,
        playingSentenceIndex: 0,
        displayMode: RetellDisplayMode.showAll,
        settings: const RetellSettings(keywordMethod: KeywordMethod.random),
      );
      final trackingPlayer = _TrackingRetellPlayer(
        initialState,
        testParagraphs,
        const {},
      );

      await tester.pumpWidget(
        createTestWidget(
          playerState: initialState,
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => trackingPlayer,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('$kMaskedSentenceExplanationHitAreaKeyPrefix-0'),
        ),
      );
      await tester.pump();

      expect(trackingPlayer.waitingCalls, 1);
      expect(trackingPlayer.lastStopImmediately, true);
      // 讲解入口不触发播放 seek
      expect(trackingPlayer.seekCalls, 0);
    });

    testWidgets('纯音频复述详情的播放与高亮来源都使用媒体引擎', (tester) async {
      final testParagraphs = createTestParagraphs();
      final initialState = RetellPlayerState(
        currentParagraphIndex: 0,
        totalParagraphs: testParagraphs.length,
        phase: RetellPhase.listening,
        isPlaying: true,
        playingSentenceIndex: 0,
        displayMode: RetellDisplayMode.showAll,
        settings: const RetellSettings(keywordMethod: KeywordMethod.random),
      );
      final trackingPlayer = _TrackingRetellPlayer(
        initialState,
        testParagraphs,
        const {},
      );

      await tester.pumpWidget(
        createTestWidget(
          playerState: initialState,
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => trackingPlayer,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('$kMaskedSentenceExplanationHitAreaKeyPrefix-0'),
        ),
      );
      await tester.pumpAndSettle();

      final detailContext = tester.element(find.text('Sentence Detail'));
      final extra = GoRouterState.of(detailContext).extra;
      expect(extra, isA<SentenceDetailArgs>());
      if (extra case final SentenceDetailArgs args) {
        final mediaEngine = ProviderScope.containerOf(
          detailContext,
        ).read(mediaEngineProvider.notifier);
        expect(args.rangePlayback, isA<MediaSenseGroupRangePlayback>());
        expect(args.wordHighlightSource.audioItemId, 'a1');
        expect(
          args.wordHighlightSource.currentPosition,
          mediaEngine.wordHighlightPosition,
        );
      }
    });

    testWidgets('点击句子正文调用 seekToSentence（不进入讲解页）', (tester) async {
      final testParagraphs = createTestParagraphs();
      final initialState = RetellPlayerState(
        currentParagraphIndex: 0,
        totalParagraphs: testParagraphs.length,
        phase: RetellPhase.listening,
        isPlaying: true,
        playingSentenceIndex: 0,
        displayMode: RetellDisplayMode.showAll,
        settings: const RetellSettings(keywordMethod: KeywordMethod.random),
      );
      final trackingPlayer = _TrackingRetellPlayer(
        initialState,
        testParagraphs,
        const {},
      );

      await tester.pumpWidget(
        createTestWidget(
          playerState: initialState,
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => trackingPlayer,
        ),
      );
      await tester.pumpAndSettle();

      // 点击第 2 句正文，从该句继续播放。
      await tester.tap(
        find.byKey(const ValueKey('$kMaskedSentenceBodyHitAreaKeyPrefix-1')),
      );
      await tester.pump();

      expect(trackingPlayer.seekCalls, 1);
      expect(trackingPlayer.lastSeekGlobalIndex, testParagraphs[0][1].index);
    });

    testWidgets('点击右侧收藏按钮直接切换收藏，不进入讲解页', (tester) async {
      final testParagraphs = createTestParagraphs();
      final initialState = RetellPlayerState(
        currentParagraphIndex: 0,
        totalParagraphs: testParagraphs.length,
        phase: RetellPhase.listening,
        isPlaying: true,
        playingSentenceIndex: 0,
        displayMode: RetellDisplayMode.showAll,
        settings: const RetellSettings(keywordMethod: KeywordMethod.random),
      );
      final trackingPlayer = _TrackingRetellPlayer(
        initialState,
        testParagraphs,
        const {},
      );

      await tester.pumpWidget(
        createTestWidget(
          playerState: initialState,
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => trackingPlayer,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('$kMaskedSentenceBookmarkHitAreaKeyPrefix-0'),
        ),
      );
      await tester.pump();

      expect(trackingPlayer.bookmarkCalls, 1);
      expect(trackingPlayer.lastBookmarkedSentenceIndex, 0);
      expect(trackingPlayer.waitingCalls, 0);
    });
  });
}
