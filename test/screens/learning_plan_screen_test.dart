// 学习计划表页面测试
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/screens/learning_plan_screen.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/media_intensive_listen_startup.dart';
import 'package:echo_loop/models/media_learning_startup.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/audio_sentences_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/asr_model_installation_gate.dart';
import 'package:echo_loop/providers/asr_model_installation_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/app_database.dart' show Bookmark;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/time_provider.dart';
import 'package:echo_loop/services/speech_permission_service.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/mock_providers.dart';

class _EmptyBookmarkDao implements BookmarkDao {
  @override
  Future<Set<int>> getBookmarkedIndices(String audioItemId) async => <int>{};

  @override
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) =>
      Stream.value(const <Bookmark>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _ReadySpeechPermissionService implements SpeechPermissionService {
  const _ReadySpeechPermissionService();

  @override
  bool get isSupported => true;

  @override
  Future<SpeechPracticePermissionState> getStatus() async =>
      const SpeechPracticePermissionState(
        microphone: SpeechPracticePermissionStatus.granted,
        speech: SpeechPracticePermissionStatus.granted,
      );

  @override
  Future<SpeechPracticePermissionState> request({required bool onlyMic}) =>
      getStatus();

  @override
  Future<void> openAppSettings() async {}
}

/// 等待异步点击回调渲染目标控件；pumpAndSettle 不等待未调度新帧的 Future。
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var pumpCount = 0; pumpCount < 20; pumpCount++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump();
  }
  expect(finder, findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      // 新手引导 flows 预设已看过（避免 GuideFlow 启动 500ms timer
      // 在 widget dispose 后还 pending，导致测试报 Timer 错误）
      'guide_v1_learning_plan_no_transcript_seen': true,
      'guide_v1_learning_plan_with_transcript_seen': true,
      'guide_v1_learning_plan_pause_learning_seen': true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  final testAudioItem = AudioItem(
    id: 'test-1',
    name: 'Test Audio',
    audioPath: 'audios/test.mp3',
    transcriptPath: 'transcripts/test.srt',
    transcriptSource: TranscriptSource.ai,
    addedDate: DateTime(2026, 1, 1),
    sentenceCount: 10,
    wordCount: 50,
  );

  final testAudioItemNoTranscript = AudioItem(
    id: 'test-1',
    name: 'Test Audio',
    audioPath: 'audios/test.mp3',
    addedDate: DateTime(2026, 1, 1),
  );

  // 视频条目：audioPath 为 mp4，isVideo 派生为 true。
  final testVideoItem = AudioItem(
    id: 'test-1',
    name: 'Test Video',
    audioPath: 'videos/test.mp4',
    transcriptPath: 'transcripts/test.srt',
    transcriptSource: TranscriptSource.ai,
    addedDate: DateTime(2026, 1, 1),
    sentenceCount: 10,
    wordCount: 50,
  );

  Session signedInSession() {
    final user = User(
      id: 'user-1',
      appMetadata: const {'provider': 'email'},
      userMetadata: const {},
      aud: 'authenticated',
      email: 'learner@example.com',
      createdAt: '2026-06-12T00:00:00.000Z',
    );
    return Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: user,
      refreshToken: 'refresh',
    );
  }

  /// 创建测试用句子列表（模拟字幕加载后的 LP 状态）
  List<Sentence> createTestSentences({int count = 5}) {
    return List.generate(count, (i) {
      return Sentence(
        index: i,
        text: 'Test sentence number ${i + 1}.',
        startTime: Duration(seconds: i * 5),
        endTime: Duration(seconds: (i + 1) * 5),
      );
    });
  }

  /// 模拟 AI 转录完成后，LP 强制重载 DB 字幕内容并拿到新句子。
  ///
  /// 真实实现会从 audio_items.transcript_srt 读取字幕；测试中直接在
  /// forceTranscriptReload=true 时填入句子，验证计划页监听和重载链路。
  TestListeningPractice createTranscriptionReloadLp(
    AudioItem initialItem,
    List<Sentence> reloadedSentences,
  ) {
    return _TranscriptionReloadListeningPractice(
      ListeningPracticeState(currentAudioItem: initialItem),
      reloadedSentences,
    );
  }

  /// 构造「截至当前阶段所有过去阶段子步骤都完成」的 completedKeys。
  ///
  /// + 当前阶段中位于 currentSubStage 之前的子步骤也算完成。
  /// 用于把"按 stage.index 推导完成"的老测试预期映射到新签名。
  Set<String> seedCompletedKeys(
    LearningStage currentStage,
    SubStageType currentSub,
  ) {
    final set = <String>{};
    for (final s in LearningStage.values) {
      if (s.index < currentStage.index) {
        for (final sub in s.allSubStages) {
          set.add('${s.key}:${sub.key}');
        }
      } else if (s == currentStage) {
        for (final sub in s.allSubStages) {
          if (sub == currentSub) break;
          set.add('${s.key}:${sub.key}');
        }
      }
    }
    return set;
  }

  /// 若 progressState 未显式指定 completionsByAudio，按 progressMap 中
  /// 每条进度的 currentStage/currentSubStage 自动推导（旧测试预期保留）。
  LearningProgressState withAutoCompletions(LearningProgressState? state) {
    final base = state ?? const LearningProgressState();
    if (base.completionsByAudio.isNotEmpty || base.progressMap.isEmpty) {
      return base;
    }
    final completions = <String, Set<String>>{};
    for (final entry in base.progressMap.entries) {
      completions[entry.key] = seedCompletedKeys(
        entry.value.currentStage,
        entry.value.currentSubStage,
      );
    }
    return base.copyWith(completionsByAudio: completions);
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    LearningProgressState? progressState,
    AudioItem? audioItem,
    bool autoStart = false,
    bool retellRatingEnabled = true,
    DateTime? fixedNow,
    ListeningPracticeState? lpState,
    TestListeningPractice Function()? listeningPracticeOverride,
    List<Sentence>? videoSentences,
    Map<String, DateTime>? completedStageTimes,
    List<Override> extraOverrides = const [],
  }) {
    final item = audioItem ?? testAudioItem;
    final router = GoRouter(
      initialLocation: '/collections/col-1/test-1/plan',
      routes: [
        GoRoute(
          path: '/collections/:collectionId/:audioId/plan',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return LearningPlanScreen(
              collectionId: collectionId,
              audioItemId: audioId,
              autoStart: autoStart,
            );
          },
        ),
        GoRoute(
          path: '/collections/:collectionId/:audioId/player',
          builder: (context, state) {
            final routeItem = state.extra;
            return Scaffold(
              body: Text(
                routeItem is AudioItem
                    ? 'Media Test: ${routeItem.name}'
                    : 'Missing AudioItem',
              ),
            );
          },
        ),
        GoRoute(
          path: '/collections/:collectionId/:audioId/blind-listen',
          builder: (context, state) {
            final startup = state.extra;
            return _MediaStartupTestScreen(
              startup: startup is MediaLearningStartup ? startup : null,
              label: 'Listen without subtitles',
            );
          },
        ),
        GoRoute(
          path: '/collections/:collectionId/:audioId/retell',
          builder: (context, state) {
            final startup = state.extra;
            return _MediaStartupTestScreen(
              startup: startup is MediaLearningStartup ? startup : null,
              label: startup is MediaLearningStartup
                  ? 'Retell Startup ${startup.showVideoLoading}'
                  : 'Retell Startup Missing',
            );
          },
        ),
        GoRoute(
          path: '/collections/:collectionId/:audioId/intensive-listen',
          builder: (context, state) {
            final startup = state.extra;
            return _MediaStartupTestScreen(
              startup: startup is MediaIntensiveListenStartup ? startup : null,
            );
          },
        ),
        GoRoute(
          path: '/collections/:collectionId/:audioId/review-difficult-practice',
          builder: (context, state) {
            final startup = state.extra;
            return _MediaStartupTestScreen(
              startup: startup is MediaIntensiveListenStartup ? startup : null,
              label: 'Review Difficult Practice',
            );
          },
        ),
        GoRoute(
          path: '/collections/:collectionId/:audioId/media-player',
          builder: (context, state) => const Scaffold(body: Text('Video Test')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        analyticsOverride(),
        ...studyTimeOverrides(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // plan 静态全量；默认 autoSkipRetell=false（手动跳过路径）
        ...learningSettingsOverrides(retellRatingEnabled: retellRatingEnabled),
        audioLibraryProvider.overrideWith(
          () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
        ),
        listeningPracticeProvider.overrideWith(
          listeningPracticeOverride ??
              () => TestListeningPractice(
                lpState ??
                    (item.hasTranscript
                        ? ListeningPracticeState(
                            currentAudioItem: item,
                            sentences: createTestSentences(),
                          )
                        : ListeningPracticeState(currentAudioItem: item)),
              ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        learningProgressNotifierProvider.overrideWith(
          () =>
              TestLearningProgressNotifier(withAutoCompletions(progressState)),
        ),
        learningSessionProvider.overrideWith(() => TestLearningSession()),
        if (videoSentences != null)
          audioSentencesProvider(item.id).overrideWith((ref) => videoSentences),
        if (fixedNow != null) nowProvider.overrideWithValue(() => fixedNow),
        ...extraOverrides,
        reviewStageCompletionTimesProvider(item.id).overrideWith(
          (ref) =>
              Stream.value(completedStageTimes ?? const <String, DateTime>{}),
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

  group('LearningPlanScreen', () {
    testWidgets('显示 AppBar 中的音频名称', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Test Audio'), findsOneWidget);
    });

    testWidgets('无进度自动开始时按 v2 首步进入精听而不是盲听', (tester) async {
      await tester.pumpWidget(createTestWidget(autoStart: true));
      await tester.pumpAndSettle();

      expect(find.text('Listen sentence by sentence'), findsAtLeast(1));
    });

    testWidgets('AppBar 显示强化后的自由练习入口并可点击进入播放器', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('learning_plan_free_play_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('learning_plan_free_play_button')));
      await tester.pumpAndSettle();

      expect(find.text('Media Test: Test Audio'), findsOneWidget);
    });

    testWidgets('视频条目：页面正常渲染不崩溃，AppBar 显示视频名称', (tester) async {
      final lp = _RecordingListeningPractice();
      await tester.pumpWidget(
        createTestWidget(
          audioItem: testVideoItem,
          listeningPracticeOverride: () => lp,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Video'), findsOneWidget);
      // 视频条目不进入听力练习引擎：loadAudio 从未被调用（引擎不被该视频 id 触碰）。
      expect(lp.loadAudioCalls, isEmpty);
    });

    testWidgets('视频条目：逐句精听走独立媒体会话且不加载音频链路', (tester) async {
      final lp = _RecordingListeningPractice();
      final sentences = createTestSentences();
      final progressState = LearningProgressState(
        progressMap: {
          testVideoItem.id: LearningProgress(
            audioItemId: testVideoItem.id,
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.intensiveListen,
            updatedAt: DateTime(2026, 7, 28),
          ),
        },
      );
      await tester.pumpWidget(
        createTestWidget(
          audioItem: testVideoItem,
          progressState: progressState,
          listeningPracticeOverride: () => lp,
          videoSentences: sentences,
        ),
      );
      await tester.pumpAndSettle();

      final planContext = tester.element(find.byType(LearningPlanScreen));
      final container = ProviderScope.containerOf(planContext);

      await tester.tap(find.text('Start practicing').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Listen sentence by sentence.'), findsWidgets);

      await tester.tap(find.text('Start Practicing'));
      await tester.pumpAndSettle();

      final session = container.read(learningSessionProvider);
      expect(session.learningMode, LearningMode.intensiveListen);
      expect(session.playbackChain, LearningPlaybackChain.mediaEngine);
      expect(session.audioItemId, testVideoItem.id);
      expect(lp.loadAudioCalls, isEmpty);
      expect(find.text('Listen sentence by sentence'), findsOneWidget);
    });

    testWidgets('视频条目：计划内复习盲听走独立媒体会话且不加载音频链路', (tester) async {
      final now = DateTime(2026, 8, 11, 10);
      final lp = _RecordingListeningPractice();
      final sentences = createTestSentences();
      final progressState = LearningProgressState(
        progressMap: {
          testVideoItem.id: LearningProgress(
            audioItemId: testVideoItem.id,
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            lastStageCompletedAt: now.subtract(const Duration(days: 1)),
            updatedAt: now,
          ),
        },
      );
      await tester.pumpWidget(
        createTestWidget(
          audioItem: testVideoItem,
          progressState: progressState,
          fixedNow: now,
          listeningPracticeOverride: () => lp,
          videoSentences: sentences,
        ),
      );
      await tester.pumpAndSettle();
      final planContext = tester.element(find.byType(LearningPlanScreen));
      final container = ProviderScope.containerOf(planContext);

      await tester.tap(find.text('Continue practicing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Practicing'));
      await tester.pumpAndSettle();

      final session = container.read(learningSessionProvider);
      expect(session.learningMode, LearningMode.blindListen);
      expect(session.playbackChain, LearningPlaybackChain.mediaEngine);
      expect(session.audioItemId, testVideoItem.id);
      expect(lp.loadAudioCalls, isEmpty);
      expect(find.text('Listen without subtitles'), findsOneWidget);
    });

    testWidgets('音频条目：计划内盲听也延迟启动并使用共享媒体会话', (tester) async {
      final now = DateTime(2026, 8, 11, 10);
      final sentences = createTestSentences();
      final lp = _RecordingListeningPractice(
        ListeningPracticeState(
          currentAudioItem: testAudioItem,
          sentences: sentences,
        ),
      );
      final progressState = LearningProgressState(
        progressMap: {
          testAudioItem.id: LearningProgress(
            audioItemId: testAudioItem.id,
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            lastStageCompletedAt: now.subtract(const Duration(days: 1)),
            updatedAt: now,
          ),
        },
      );
      await tester.pumpWidget(
        createTestWidget(
          audioItem: testAudioItem,
          progressState: progressState,
          fixedNow: now,
          listeningPracticeOverride: () => lp,
        ),
      );
      await tester.pumpAndSettle();
      final planContext = tester.element(find.byType(LearningPlanScreen));
      final container = ProviderScope.containerOf(planContext);

      await tester.tap(find.text('Continue practicing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Practicing'));
      await tester.pumpAndSettle();

      final session = container.read(learningSessionProvider);
      expect(session.learningMode, LearningMode.blindListen);
      expect(session.playbackChain, LearningPlaybackChain.mediaEngine);
      expect(session.audioItemId, testAudioItem.id);
      expect(find.text('Listen without subtitles'), findsOneWidget);
    });

    testWidgets('视频条目：已完成复习盲听可用媒体链路自由练习并保留补做目标', (tester) async {
      final now = DateTime(2026, 8, 11, 10);
      final lp = _RecordingListeningPractice();
      final sentences = createTestSentences();
      final progressState = LearningProgressState(
        progressMap: {
          testVideoItem.id: LearningProgress(
            audioItemId: testVideoItem.id,
            currentStage: LearningStage.review2,
            currentSubStage: SubStageType.reviewDifficultPractice,
            updatedAt: now,
          ),
        },
        completionsByAudio: const {
          'test-1': {'review1:blindListen'},
        },
      );
      await tester.pumpWidget(
        createTestWidget(
          audioItem: testVideoItem,
          progressState: progressState,
          fixedNow: now,
          listeningPracticeOverride: () => lp,
          videoSentences: sentences,
        ),
      );
      await tester.pumpAndSettle();
      final planContext = tester.element(find.byType(LearningPlanScreen));
      final container = ProviderScope.containerOf(planContext);

      await tester.scrollUntilVisible(find.text('Review 2'), 200);
      await tester.tap(find.text('Review 2'));
      await tester.pumpAndSettle();
      final reviewTitleY = tester.getTopLeft(find.text('Review 2')).dy;
      final reviewBlindText = tester
          .elementList(find.text('Listen without subtitles'))
          .where(
            (element) =>
                tester.getTopLeft(find.byWidget(element.widget)).dy >
                reviewTitleY,
          )
          .reduce((nearest, candidate) {
            final nearestY = tester
                .getTopLeft(find.byWidget(nearest.widget))
                .dy;
            final candidateY = tester
                .getTopLeft(find.byWidget(candidate.widget))
                .dy;
            return candidateY < nearestY ? candidate : nearest;
          });
      final reviewBlindFinder = find.byWidget(reviewBlindText.widget);
      await tester.ensureVisible(reviewBlindFinder);
      await tester.tap(reviewBlindFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Practicing'));
      await tester.pumpAndSettle();

      final session = container.read(learningSessionProvider);
      expect(session.learningMode, LearningMode.blindListen);
      expect(session.playbackChain, LearningPlaybackChain.mediaEngine);
      expect(session.isFreePlay, isTrue);
      expect(session.catchUpStage, LearningStage.review1);
      expect(session.catchUpSubStage, SubStageType.blindListen);
      expect(lp.loadAudioCalls, isEmpty);
    });

    testWidgets('视频条目：随心听进入媒体页', (tester) async {
      final lp = _RecordingListeningPractice();
      await tester.pumpWidget(
        createTestWidget(
          audioItem: testVideoItem,
          listeningPracticeOverride: () => lp,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('learning_plan_free_play_button')));
      await tester.pumpAndSettle();

      expect(find.text('Video Test'), findsOneWidget);
      expect(find.text('Missing AudioItem'), findsNothing);
    });

    testWidgets('AppBar「更多」菜单：有字幕音频显示 4 项操作', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);

      await tester.tap(find.byKey(const Key('learning_plan_more_menu')));
      await tester.pumpAndSettle();

      expect(find.text('Manage Subtitles'), findsOneWidget);
      expect(find.text('Edit subtitles'), findsOneWidget);
      expect(find.text('Export Audio'), findsOneWidget);
      expect(find.text('Export PDF'), findsOneWidget);
    });

    testWidgets('AppBar「更多」菜单：无字幕音频隐藏编辑字幕/导出 PDF', (tester) async {
      await tester.pumpWidget(
        createTestWidget(audioItem: testAudioItemNoTranscript),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('learning_plan_more_menu')));
      await tester.pumpAndSettle();

      expect(find.text('Manage Subtitles'), findsOneWidget);
      expect(find.text('Export Audio'), findsOneWidget);
      expect(find.text('Edit subtitles'), findsNothing);
      expect(find.text('Export PDF'), findsNothing);
    });

    testWidgets('AppBar「更多」菜单：已有学习进度可确认重置', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('learning_plan_more_menu')));
      await tester.pumpAndSettle();

      final resetLabel = find.text('Reset Progress');
      expect(resetLabel, findsOneWidget);
      expect(
        tester.widget<Text>(resetLabel).style?.color,
        AppTheme.light().colorScheme.error,
      );

      await tester.tap(resetLabel);
      await tester.pumpAndSettle();
      expect(find.text('Reset Learning Progress?'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Learning progress has been reset'), findsOneWidget);
      expect(find.text('Start practicing'), findsOneWidget);
      // 重置成功 SnackBar 位于底部，会暂时遮挡固定的开始学习按钮。
      final planContext = tester.element(find.byType(LearningPlanScreen));
      ScaffoldMessenger.of(planContext).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Start practicing'));
      await tester.pumpAndSettle();
      expect(find.text('Start Practicing'), findsOneWidget);
    });

    testWidgets('显示进度卡片（0%，未开始）', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Not started'), findsOneWidget);
    });

    testWidgets('音频损坏时进度卡片显示内容警告徽章', (tester) async {
      final damagedItem = testAudioItem.copyWith(
        contentStatus: AudioContentStatus.damaged,
      );
      await tester.pumpWidget(createTestWidget(audioItem: damagedItem));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('learning_plan_content_warning_badge')),
        findsOneWidget,
      );
      expect(find.text('Audio issue'), findsOneWidget);
    });

    testWidgets('静音音频时进度卡片显示静音警告徽章', (tester) async {
      final silentItem = testAudioItem.copyWith(
        contentStatus: AudioContentStatus.silent,
      );
      await tester.pumpWidget(createTestWidget(audioItem: silentItem));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('learning_plan_content_warning_badge')),
        findsOneWidget,
      );
      expect(find.text('Possibly silent'), findsOneWidget);
    });

    testWidgets('内容正常时进度卡片不显示内容警告徽章', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('learning_plan_content_warning_badge')),
        findsNothing,
      );
    });

    testWidgets('显示首次学习区域的 4 个步骤', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('First Round'), findsOneWidget);
      expect(find.text('0/4'), findsOneWidget);
      expect(find.text('0/4 completed'), findsNothing);

      expect(find.text('Listen without subtitles'), findsWidgets);
      expect(find.text('Listen sentence by sentence'), findsOneWidget);
      expect(find.text('Listen & Repeat'), findsOneWidget);
      expect(find.text('Listen & Retell'), findsOneWidget);
    });

    testWidgets('复习区显示七个同级轮次', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 滚动到复习区域
      await tester.scrollUntilVisible(find.text('Review 1').first, 200);
      await tester.pumpAndSettle();

      expect(find.text('Review 1'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Review 7'), 200);
      expect(find.text('Review 7'), findsOneWidget);
    });

    testWidgets('当前复习轮次显示子阶段和时间标签', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.reviewDifficultPractice,
            lastStageCompletedAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );
      final fixedNow = DateTime(2026, 1, 1, 5, 0);

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: fixedNow),
      );
      await tester.pumpAndSettle();

      // 滚动到首轮复习区域
      await tester.scrollUntilVisible(find.text('Review 1').first, 200);
      await tester.pumpAndSettle();
      expect(find.text('Review 1'), findsWidgets);

      // 折叠当前轮次
      await tester.tap(find.text('Review 1').first);
      await tester.pumpAndSettle();

      // 重新展开
      await tester.tap(find.text('Review 1').first);
      await tester.pumpAndSettle();
    });

    testWidgets('当前复习轮次逾期时显示逾期文案且不显示固定间隔', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime(2026, 2, 26, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.reviewDifficultPractice,
            // review0 窗口结束 = completed + 12h，这里逾期 2h
            lastStageCompletedAt: now.subtract(const Duration(hours: 14)),
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Review 1').first, 200);
      await tester.pumpAndSettle();

      expect(find.textContaining('Due 2h ago'), findsAtLeast(1));
      expect(find.text('After 6 hours'), findsNothing);
    });

    testWidgets('显示底部"开始学习"按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Start practicing'), findsOneWidget);
    });

    testWidgets('无字幕时当前步骤和底部按钮可点击并提示先添加字幕', (tester) async {
      await tester.pumpWidget(
        createTestWidget(audioItem: testAudioItemNoTranscript),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Listen sentence by sentence'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('This audio has no subtitles yet'),
        ),
        findsOneWidget,
      );

      ScaffoldMessenger.of(
        tester.element(find.byType(LearningPlanScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start practicing'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('进行中时底部显示"继续学习"', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      expect(find.text('Continue practicing'), findsOneWidget);
    });

    testWidgets('复习未到时间时底部继续学习按钮禁用', (tester) async {
      final now = DateTime(2026, 2, 25, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            lastStageCompletedAt: now,
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue practicing'),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('进行中（未暂停）时底部同时显示"暂停学习"和"继续学习"两个按钮', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      expect(find.text('Continue practicing'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('暂停态时底部只显示"恢复学习"，不显示"继续学习"或"暂停学习"', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
            isPaused: true,
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 文案合并「Paused · Resume Learning」，仅一个按钮
      expect(find.textContaining('Resume Learning'), findsOneWidget);
      expect(find.textContaining('Paused'), findsOneWidget);
      expect(find.text('Continue practicing'), findsNothing);
      expect(find.text('Pause'), findsNothing);
    });

    testWidgets('点击底部"暂停学习"弹出确认弹窗', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      expect(find.text('Pause Learning?'), findsOneWidget);
    });

    testWidgets('暂停确认弹窗→取消：状态保持未暂停，按钮不变', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 点击"暂停学习"
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Pause Learning?'), findsOneWidget);

      // 点击"Cancel"
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 对话框关闭，按钮恢复原状
      expect(find.text('Pause Learning?'), findsNothing);
      expect(find.text('Continue practicing'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('暂停确认弹窗→确认：状态翻转 isPaused，按钮变单按钮', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 点击"暂停学习"
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Pause Learning?'), findsOneWidget);

      // 弹窗内确认按钮文案也是 "Pause"，取 .last
      await tester.tap(find.text('Pause').last);
      await tester.pumpAndSettle();

      // 对话框关闭，state 翻转 — 底部变单按钮
      expect(find.text('Pause Learning?'), findsNothing);
      expect(find.textContaining('Paused'), findsWidgets);
      expect(find.textContaining('Resume'), findsWidgets);
      expect(find.text('Continue practicing'), findsNothing);

      // 验证 Provider 状态 isPaused=true
      final appContext = tester.element(find.byType(LearningPlanScreen));
      final container = ProviderScope.containerOf(appContext);
      final p = container
          .read(learningProgressNotifierProvider)
          .progressMap['test-1'];
      expect(p!.isPaused, isTrue);
    });

    testWidgets('复习边界时刻到底后底部继续学习按钮可用', (tester) async {
      final now = DateTime(2026, 2, 25, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue practicing'),
      );
      expect(continueButton.onPressed, isNotNull);
    });

    testWidgets('复习盲听直接弹段落选择弹窗，显示阶段名和预估时长', (tester) async {
      final now = DateTime(2026, 2, 25, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue practicing'));
      await tester.pumpAndSettle();
      // 跳过复习简报弹窗，直接弹出盲听段落选择弹窗。
      expect(find.text('Listen without subtitles'), findsAtLeast(1));
      // 显示阶段名
      expect(find.text('Review 2'), findsAtLeast(1));
      // 显示开始练习按钮
      expect(find.text('Start Practicing'), findsOneWidget);
    });

    testWidgets('有进度时显示正确的完成步骤数', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
        // 真实完成历史：blindListen + intensiveListen
        completionsByAudio: const {
          'test-1': {'firstLearn:blindListen', 'firstLearn:intensiveListen'},
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      expect(find.text('2/4'), findsOneWidget);
      expect(find.text('2/4 completed'), findsNothing);
    });

    testWidgets('点击"开始学习"显示简报弹窗', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start practicing'));
      await tester.pumpAndSettle();

      // 当前子步骤是 blindListen，应弹出盲听简报弹窗。
      expect(find.text('Listen without subtitles'), findsAtLeast(1));
      expect(find.text('Start Practicing'), findsOneWidget);
    });

    testWidgets('AI 转录完成后 transcriptPath 仍为 null 时开始学习可立即弹出练习面板', (
      tester,
    ) async {
      final pendingItem = testAudioItemNoTranscript;
      final completedItem = pendingItem.copyWith(
        transcriptPath: null,
        transcriptSource: TranscriptSource.ai,
        transcriptLanguage: 'en',
        sentenceCount: 5,
        wordCount: 25,
      );
      final reloadedSentences = createTestSentences();
      final lp = createTranscriptionReloadLp(pendingItem, reloadedSentences);

      await tester.pumpWidget(
        createTestWidget(
          audioItem: pendingItem,
          listeningPracticeOverride: () => lp,
        ),
      );
      await tester.pumpAndSettle();

      final appContext = tester.element(find.byType(LearningPlanScreen));
      final container = ProviderScope.containerOf(appContext);
      await container
          .read(audioLibraryProvider.notifier)
          .updateAudioItem(completedItem);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start practicing'));
      await tester.pumpAndSettle();

      expect(find.text('Listen without subtitles'), findsAtLeast(1));
      expect(find.text('Start Practicing'), findsOneWidget);
      final lpState = container.read(listeningPracticeProvider);
      expect(lpState.sentences, hasLength(reloadedSentences.length));
    });

    testWidgets('简报弹窗点击开始练习后导航到精听播放器（v2 首步）', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start practicing'));
      await tester.pumpAndSettle();

      // 点击开始练习
      await tester.tap(find.text('Start Practicing'));
      await tester.pumpAndSettle();

      expect(find.text('Listen sentence by sentence'), findsOneWidget);
    });

    testWidgets('点击当前进行中步骤卡片效果同「开始学习」（弹出简报）', (tester) async {
      // 当前子步骤为精听 → 精听步骤卡为当前态、可点击。
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.intensiveListen,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 直接点击当前步骤卡片（不经底部按钮）。
      await tester.tap(find.text('Listen sentence by sentence'));
      await tester.pumpAndSettle();

      // 与点击底部「开始学习」一致：弹出精听简报。
      expect(find.text('Start Practicing'), findsOneWidget);
    });

    testWidgets('无字幕时点击当前步骤卡片无反应', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.intensiveListen,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(
          audioItem: testAudioItemNoTranscript,
          progressState: progressState,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Listen sentence by sentence'));
      await tester.pumpAndSettle();

      // 无字幕 → 回调为 null，点击不弹出任何练习面板。
      expect(find.text('Start Practicing'), findsNothing);
    });

    testWidgets('精听子步骤无字幕时显示提示对话框', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.intensiveListen,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );

      // LP 有 currentAudioItem 但无句子（模拟字幕缺失）
      await tester.pumpWidget(
        createTestWidget(
          progressState: progressState,
          lpState: ListeningPracticeState(
            currentAudioItem: testAudioItem,
            sentences: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // v2 精听是首步、未开始 → 底部按钮为「Start Learning」
      await tester.tap(find.text('Start practicing'));
      await tester.pumpAndSettle();

      // LP 无句子时应弹出"无字幕"提示对话框
      expect(find.text('No Subtitles Available'), findsOneWidget);
    });

    testWidgets('阶段标题行各列上下对齐且进度列不带完成后缀', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime(2026, 1, 10, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review7,
            currentSubStage: SubStageType.reviewDifficultPractice,
            firstLearnCompletedAt: now.subtract(const Duration(days: 8)),
            lastStageCompletedAt: now.subtract(const Duration(days: 4)),
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(
          locale: const Locale('zh'),
          progressState: progressState,
          fixedNow: now,
          completedStageTimes: {
            LearningStage.firstLearn.key: now.subtract(const Duration(days: 8)),
            LearningStage.review0.key: now.subtract(const Duration(days: 7)),
            LearningStage.review1.key: now.subtract(const Duration(days: 6)),
            LearningStage.review2.key: now.subtract(const Duration(days: 5)),
            LearningStage.review4.key: now.subtract(const Duration(days: 4)),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4/4 完成'), findsNothing);
      expect(find.text('3/3 完成'), findsNothing);
      expect(find.text('0/3 完成'), findsNothing);
      expect(find.text('4/4'), findsOneWidget);
      expect(find.text('0/3'), findsWidgets);

      double columnDx(String stageKey, String column) => tester
          .getTopLeft(
            find.byKey(Key('learning_plan_stage_${stageKey}_$column')),
          )
          .dx;

      void expectAligned(String column) {
        final firstLearnDx = columnDx('first_learn', column);
        for (final stageKey in ['review0', 'review7', 'review14']) {
          expect(
            columnDx(stageKey, column),
            moreOrLessEquals(firstLearnDx, epsilon: 0.1),
            reason: '$column should align for $stageKey',
          );
        }
      }

      expectAligned('title_column');
      expectAligned('status_icon_column');
      expectAligned('status_text_column');
      expectAligned('progress_column');
      expectAligned('expand_column');
    });

    testWidgets('audioItem 找不到时显示错误页面', (tester) async {
      final router = GoRouter(
        initialLocation: '/collections/col-1/nonexistent/plan',
        routes: [
          GoRoute(
            path: '/collections/:collectionId/:audioId/plan',
            builder: (context, state) {
              final collectionId = state.pathParameters['collectionId']!;
              final audioId = state.pathParameters['audioId']!;
              return LearningPlanScreen(
                collectionId: collectionId,
                audioItemId: audioId,
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ...learningSettingsOverrides(),
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(), // 空音频库
            ),
            listeningPracticeProvider.overrideWith(
              () => TestListeningPractice(),
            ),
            audioEngineProvider.overrideWith(() => TestAudioEngine()),
            learningProgressNotifierProvider.overrideWith(
              () => TestLearningProgressNotifier(),
            ),
            learningSessionProvider.overrideWith(() => TestLearningSession()),
          ],
          child: MaterialApp.router(
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
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Audio file not found. The file may have been deleted.'),
        findsOneWidget,
      );
    });

    testWidgets('添加字幕入口 AI 转录音频过长时显示弹窗内错误提示', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final longAudio = testAudioItemNoTranscript.copyWith(
        totalDuration: 31 * 60,
      );
      await prefs.setBool('guide_v1_subtitle_sheet_transcription_seen', true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsOverride(),
            sharedPreferencesProvider.overrideWithValue(prefs),
            ...learningSettingsOverrides(),
            audioLibraryProvider.overrideWith(
              () =>
                  TestAudioLibrary(AudioLibraryState(audioItems: [longAudio])),
            ),
            listeningPracticeProvider.overrideWith(
              () => TestListeningPractice(
                ListeningPracticeState(currentAudioItem: longAudio),
              ),
            ),
            audioEngineProvider.overrideWith(() => TestAudioEngine()),
            learningProgressNotifierProvider.overrideWith(
              () => TestLearningProgressNotifier(),
            ),
            learningSessionProvider.overrideWith(() => TestLearningSession()),
            supabaseSessionProvider.overrideWith(
              (ref) => Stream<Session?>.value(signedInSession()),
            ),
            // 已登录用户视为已解锁（Pro），转录机制测试不被额度闸拦截。
            subscriptionEntitlementOverride(),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('zh')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light(),
            routerConfig: GoRouter(
              initialLocation: '/collections/col-1/test-1/plan',
              routes: [
                GoRoute(
                  path: '/collections/:collectionId/:audioId/plan',
                  builder: (context, state) => LearningPlanScreen(
                    collectionId: state.pathParameters['collectionId']!,
                    audioItemId: state.pathParameters['audioId']!,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Subtitle'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Start Transcription'),
      );
      await tester.pump();

      expect(find.textContaining('Audio too long'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();

      expect(find.textContaining('Audio too long'), findsNothing);
    });

    testWidgets('已完成盲听步骤可点击直接进入自由练习', (tester) async {
      // v2：盲听是第 3 步，currentSubStage=retell 时盲听已完成
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.retell,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 盲听步骤已完成，点击弹出段落选择弹窗（自由练习模式）
      await tester.tap(find.text('Listen without subtitles').first);
      await tester.pumpAndSettle();

      // 应弹出盲听段落选择弹窗，并保留步骤标签。
      expect(find.text('Listen without subtitles'), findsAtLeast(1));
      expect(find.text('Start Practicing'), findsOneWidget);
    });

    testWidgets('未完成盲听步骤不可点击', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 盲听步骤是当前步骤（未完成），点击不应弹出简报弹窗
      final blindListeningCard = find.ancestor(
        of: find.text('Listen without subtitles').first,
        matching: find.byType(InkWell),
      );
      await tester.tap(blindListeningCard.first);
      await tester.pumpAndSettle();

      // 不应弹出简报弹窗（因为没有 onTap），步骤标签仍可见但不会多出弹窗标题
      expect(find.text('Listen without subtitles'), findsOneWidget);
    });

    testWidgets('过去阶段跳过的复述可点击进入自由练习（重开复述后补做）', (tester) async {
      // 模拟：曾关闭复述完成 firstLearn，跳过 retell，currentStage 进入 review0
      // 用户现在重开复述：retell 卡重新显示在 firstLearn 区，应支持自由练习点击
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.reviewDifficultPractice,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
        // 真实完成历史：blind/intensive/shadow 三个非复述步骤（retell 被跳过）
        completionsByAudio: const {
          'test-1': {
            'firstLearn:blindListen',
            'firstLearn:intensiveListen',
            'firstLearn:listenAndRepeat',
          },
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // firstLearn 已是过去阶段，section 默认折叠 → 先展开
      await tester.tap(find.text('First Round'));
      await tester.pumpAndSettle();

      // 段落复述卡片在 firstLearn 区可见（plan 含 + isPast）。
      // 注意：review0 也有「Listen & Retell」，所以 findsAtLeast(1)。
      expect(find.text('Listen & Retell'), findsAtLeast(1));

      // 找到 firstLearn 区的 _StepCard，验证它的 onTap 非空（可点击进入自由练习）。
      final stepCardFinder = find.ancestor(
        of: find.text('Listen & Retell').first,
        matching: find.byType(InkWell),
      );
      expect(stepCardFinder, findsAtLeast(1));
      final inkWell = tester
          .widgetList<InkWell>(stepCardFinder)
          .firstWhere((w) => w.onTap != null, orElse: () => const InkWell());
      expect(inkWell.onTap, isNotNull, reason: '过去阶段跳过的复述卡应支持点击进入自由练习');
    });

    for (final (item, isVideo) in [
      (testAudioItem, false),
      (testVideoItem, true),
    ]) {
      testWidgets('${isVideo ? '视频' : '音频'}复述补练通过统一媒体启动链路进入', (tester) async {
        final progressState = LearningProgressState(
          progressMap: {
            item.id: LearningProgress(
              audioItemId: item.id,
              currentStage: LearningStage.review0,
              currentSubStage: SubStageType.reviewDifficultPractice,
              updatedAt: DateTime(2026, 1, 1),
            ),
          },
          completionsByAudio: {
            item.id: {
              'firstLearn:blindListen',
              'firstLearn:intensiveListen',
              'firstLearn:listenAndRepeat',
            },
          },
        );
        await tester.pumpWidget(
          createTestWidget(
            audioItem: item,
            progressState: progressState,
            retellRatingEnabled: false,
            videoSentences: isVideo ? createTestSentences() : null,
            extraOverrides: [
              asrModelInstallationGateProvider.overrideWithValue(
                AsrModelInstallationGate(({required shouldCommit}) async {}),
              ),
              speechPermissionServiceProvider.overrideWithValue(
                const _ReadySpeechPermissionService(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final planContext = tester.element(find.byType(LearningPlanScreen));
        final container = ProviderScope.containerOf(planContext);

        await tester.tap(find.text('First Round'));
        await tester.pumpAndSettle();
        final retellCard = find.ancestor(
          of: find.text('Listen & Retell').first,
          matching: find.byType(InkWell),
        );
        final retellCardTap = tester
            .widgetList<InkWell>(retellCard)
            .map((widget) => widget.onTap)
            .whereType<VoidCallback>()
            .first;
        retellCardTap();
        final startPracticeButton = find.text('Start Practicing');
        await _pumpUntilFound(tester, startPracticeButton);
        await tester.pumpAndSettle();
        await tester.ensureVisible(startPracticeButton);
        await tester.pumpAndSettle();
        await tester.tap(startPracticeButton);
        await tester.pumpAndSettle();

        expect(find.text('Retell Startup $isVideo'), findsOneWidget);
        expect(
          container.read(learningSessionProvider).learningMode,
          LearningMode.retell,
        );
        expect(
          container.read(learningSessionProvider).playbackChain,
          LearningPlaybackChain.mediaEngine,
        );
        expect(container.read(learningSessionProvider).isFreePlay, isTrue);
      });
    }

    testWidgets('无字幕时显示警告横幅且开始按钮可点击', (tester) async {
      await tester.pumpWidget(
        createTestWidget(audioItem: testAudioItemNoTranscript),
      );
      await tester.pumpAndSettle();

      // 显示无字幕警告
      expect(find.text('This audio has no subtitles yet'), findsOneWidget);

      // 开始学习按钮保留点击反馈（查找底部按钮区域）
      final startButton = find.widgetWithText(FilledButton, 'Start practicing');
      expect(startButton, findsOneWidget);
      final button = tester.widget<FilledButton>(startButton);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('有字幕时显示句子数和单词数', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('10 sentences'), findsOneWidget);
      expect(find.text('50 words'), findsOneWidget);
    });

    testWidgets('有字幕时不显示警告横幅', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No transcript uploaded. A transcript is required to start the learning flow.',
        ),
        findsNothing,
      );
    });

    testWidgets('盲听已完成时仅显示遍数，不再显示难度', (tester) async {
      // v2：盲听是第 3 步，currentSubStage=retell 时盲听已完成
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.retell,
            difficulty: DifficultyLevel.hard,
            blindListenPassCount: 2,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 盲听步骤已完成，仅显示遍数；难度在精听完成时自动判定，盲听不再展示
      expect(find.textContaining('Listened 2 time(s)'), findsOneWidget);
      expect(find.textContaining('Difficulty:'), findsNothing);
    });

    testWidgets('未来复习轮次不显示固定间隔文案和动态解锁倒计时', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 首次学习刚完成，review1 需要 24h 后解锁
      final firstLearnCompletedAt = DateTime(2026, 1, 1);
      final now = DateTime(2026, 1, 1, 12, 0); // 12小时后
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.blindListen,
            firstLearnCompletedAt: firstLearnCompletedAt,
            lastStageCompletedAt: firstLearnCompletedAt,
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      // 滚动到 Review 2（review1 阶段，未来阶段）
      await tester.scrollUntilVisible(find.text('Review 2'), 200);
      await tester.pumpAndSettle();

      // 未来阶段既不显示固定间隔文案，也不显示动态倒计时
      expect(find.textContaining('Unlocks in'), findsNothing);
      expect(find.text('After 1 day'), findsNothing);
    });

    testWidgets('当前复习轮锁定时显示「立即解锁」，点击后解锁并隐藏按钮', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // review0 间隔 6h：1 小时前完成首学 → 还剩 5h，锁定中
      final firstLearnCompletedAt = DateTime(2026, 1, 1, 11, 0);
      final now = DateTime(2026, 1, 1, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.reviewDifficultPractice,
            firstLearnCompletedAt: firstLearnCompletedAt,
            lastStageCompletedAt: firstLearnCompletedAt,
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      // 锁定态：显示倒计时与「立即解锁」按钮
      expect(find.textContaining('Unlocks in'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Unlock now'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Unlock now'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icon/unlock.svg',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Unlock now'));
      await tester.pumpAndSettle();

      // 解锁后：manualUnlockAt 写入，按钮与倒计时消失
      final context = tester.element(find.byType(LearningPlanScreen));
      final container = ProviderScope.containerOf(context);
      final after = container
          .read(learningProgressNotifierProvider)
          .progressMap['test-1']!;
      expect(after.manualUnlockAt, isNotNull);
      expect(after.isReviewLockedAt(now), isFalse);
      expect(find.text('Unlock now'), findsNothing);
      expect(find.textContaining('Unlocks in'), findsNothing);
    });

    testWidgets('当前复习轮已到期时不显示「立即解锁」', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // review0 间隔 6h：7 小时前完成 → 已到期
      final now = DateTime(2026, 1, 1, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.reviewDifficultPractice,
            firstLearnCompletedAt: now.subtract(const Duration(hours: 7)),
            lastStageCompletedAt: now.subtract(const Duration(hours: 7)),
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlock now'), findsNothing);
    });

    testWidgets('已暂停时锁定轮次不显示「立即解锁」', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firstLearnCompletedAt = DateTime(2026, 1, 1, 11, 0);
      final now = DateTime(2026, 1, 1, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.reviewDifficultPractice,
            firstLearnCompletedAt: firstLearnCompletedAt,
            lastStageCompletedAt: firstLearnCompletedAt,
            updatedAt: now,
            isPaused: true,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlock now'), findsNothing);
    });

    testWidgets('已完成复习轮次显示相对完成时间', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 当前已进入 review1，说明 review0 已完成；标题行应显示 review0 的相对完成时间
      final firstLearnCompletedAt = DateTime(2026, 1, 1);
      final now = DateTime(2026, 1, 3, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            firstLearnCompletedAt: firstLearnCompletedAt,
            lastStageCompletedAt: now.subtract(const Duration(hours: 6)),
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(
          progressState: progressState,
          fixedNow: now,
          completedStageTimes: {
            LearningStage.review0.key: now.subtract(const Duration(days: 2)),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Review 1').first, 200);
      await tester.pumpAndSettle();

      expect(find.textContaining('Completed '), findsAtLeast(1));
      expect(find.text('Unlocked'), findsNothing);
      expect(find.text('After 1 day'), findsNothing);
    });

    testWidgets('已完成首次学习显示相对完成时间', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime(2026, 1, 3, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.reviewDifficultPractice,
            firstLearnCompletedAt: now.subtract(const Duration(days: 3)),
            lastStageCompletedAt: now.subtract(const Duration(days: 1)),
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(
          progressState: progressState,
          fixedNow: now,
          completedStageTimes: {
            LearningStage.firstLearn.key: now.subtract(const Duration(days: 3)),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Completed '), findsAtLeast(1));
    });

    testWidgets('已完成步骤圆形背景使用较深绿色（非 shade50）', (tester) async {
      // v2：currentSubStage=listenAndRepeat 时精听已完成（有完成步骤）
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 盲听步骤已完成，其圆形背景应使用浅绿色
      final containers = tester.widgetList<Container>(find.byType(Container));
      final greenContainers = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle) {
          return decoration.color == Colors.green.shade50;
        }
        return false;
      });
      expect(
        greenContainers,
        isNotEmpty,
        reason: '已完成步骤应使用 Colors.green.shade50 作为背景',
      );

      // 已完成步骤应显示边框
      final borderedContainers = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle) {
          return decoration.border != null;
        }
        return false;
      });
      expect(borderedContainers, isNotEmpty, reason: '已完成步骤应显示绿色边框');
    });

    testWidgets('已完成状态显示正确', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.completed,
            currentSubStage: SubStageType.blindListen,
            firstLearnCompletedAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 2, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('4/4'), findsOneWidget);
      expect(find.text('4/4 completed'), findsNothing);
      expect(find.text('✅'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icon/check-circle-3.svg',
        ),
        findsWidgets,
      );
    });

    // ====== Phase 2 Pilot：从 integration_test 下沉的 case ======

    testWidgets('无字幕音频显示警告横幅且开始学习按钮可点击', (tester) async {
      // v2 入口为精听、未开始 → 底部按钮为「Start Learning」
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.intensiveListen,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(
          progressState: progressState,
          audioItem: testAudioItemNoTranscript,
        ),
      );
      await tester.pumpAndSettle();

      // 验证警告横幅出现（warning 图标）
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // 验证底部按钮存在且保留点击反馈
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start practicing'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Phase 2 Pilot：精听已完成时显示完成标记和继续学习', (tester) async {
      // v2：精听是首步；完成精听后进行到跟读，此时已开始学习
      final completed = seedCompletedKeys(
        LearningStage.firstLearn,
        SubStageType.listenAndRepeat,
      );
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
        completionsByAudio: {'test-1': completed},
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 验证精听步骤显示完成标记（绿色勾图标）
      expect(find.byIcon(Icons.check), findsWidgets);

      // 验证底部按钮文案为"Continue practicing"
      expect(find.text('Continue practicing'), findsOneWidget);
      expect(find.text('Start practicing'), findsNothing);
    });

    testWidgets('精听阶段点击开始学习弹出精听简报', (tester) async {
      // v2：精听是入口子步骤、未开始 → 底部按钮为「Start Learning」
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.intensiveListen,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 点击"Start practicing"
      await tester.tap(find.text('Start practicing').last);
      await tester.pumpAndSettle();

      // 验证弹出的是精听简报（IntensiveListenBriefingSheet）
      expect(find.text('Listen sentence by sentence'), findsWidgets);
      expect(find.text('Start Practicing'), findsOneWidget);
    });

    // ====== Phase 3 Batch：从 integration_test 下沉的更多 case ======

    testWidgets('学习计划页显示精听遍数和跟读遍数', (tester) async {
      final completed = seedCompletedKeys(
        LearningStage.firstLearn,
        SubStageType.listenAndRepeat,
      );
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            blindListenPassCount: 2,
            intensiveListenPassCount: 2,
            shadowingPassCount: 1,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
        completionsByAudio: {'test-1': completed},
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 验证精听遍数显示（"Intensive listen 2x"）
      expect(find.textContaining('2x'), findsWidgets);
      // 验证跟读遍数显示（"Shadowing 1x"）
      expect(find.textContaining('1x'), findsWidgets);
    });

    testWidgets('无难句时跟读状态复用 saved sentences 数量文案', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(LearningPlanScreen));
      expect(
        AppLocalizations.of(context)!.listenAndRepeatBriefingDifficultCount(0),
        '0 saved sentences',
      );
    });

    testWidgets('逐句精听零收藏时不显示难句数，仍显示已练习遍数', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.intensiveListen,
            intensiveListenPassCount: 2,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );
      await tester.pumpWidget(
        createTestWidget(
          progressState: progressState,
          extraOverrides: [
            bookmarkDaoProvider.overrideWithValue(_EmptyBookmarkDao()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 challenging sentences'), findsNothing);
      expect(find.textContaining('Practiced 2x'), findsOneWidget);
    });

    // ====== 听前预热卡（「首次学习」上方） ======

    testWidgets('未开始且有字幕时显示听前预热卡', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Warm-up Listening'), findsOneWidget);
      expect(find.text('Recommended First'), findsOneWidget);
    });

    testWidgets('点击预热卡进入随心听播放器（与右上角入口同一目的地）', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 整卡可点（取消独立按钮），点标题即触发
      await tester.tap(find.text('Warm-up Listening'));
      await tester.pumpAndSettle();

      expect(find.text('Media Test: Test Audio'), findsOneWidget);
    });

    testWidgets('已开始学习后预热卡消失', (tester) async {
      // 已进行到跟读（精听入口子步骤已过）→ isStarted=true
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      expect(find.text('Warm-up Listening'), findsNothing);
    });

    testWidgets('无字幕时不显示预热卡', (tester) async {
      await tester.pumpWidget(
        createTestWidget(audioItem: testAudioItemNoTranscript),
      );
      await tester.pumpAndSettle();

      expect(find.text('Warm-up Listening'), findsNothing);
    });
  });
}

/// 模拟生产精听页消费路由启动任务，避免入口测试绕过媒体加载契约。
class _MediaStartupTestScreen extends StatefulWidget {
  const _MediaStartupTestScreen({this.startup, this.label});

  final MediaIntensiveListenStartup? startup;
  final String? label;

  @override
  State<_MediaStartupTestScreen> createState() =>
      _MediaStartupTestScreenState();
}

class _MediaStartupTestScreenState extends State<_MediaStartupTestScreen> {
  @override
  void initState() {
    super.initState();
    final startup = widget.startup;
    if (startup != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(startup.load());
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text(widget.label ?? 'Listen sentence by sentence'));
}

/// 记录 loadAudio 调用的测试用 LP，初始为空状态（无 currentAudioItem）。
///
/// 用于验证视频条目不进入听力练习引擎：_maybeLoadAudio 对视频早退，loadAudio 不被调用。
class _RecordingListeningPractice extends TestListeningPractice {
  _RecordingListeningPractice([super.initialState]);

  final List<AudioItem> loadAudioCalls = [];

  @override
  Future<void> loadAudio(
    AudioItem audioItem, {
    bool forceTranscriptReload = false,
  }) async {
    loadAudioCalls.add(audioItem);
    await super.loadAudio(
      audioItem,
      forceTranscriptReload: forceTranscriptReload,
    );
  }
}

class _TranscriptionReloadListeningPractice extends TestListeningPractice {
  final List<Sentence> reloadedSentences;

  _TranscriptionReloadListeningPractice(
    super.initialState,
    this.reloadedSentences,
  );

  @override
  Future<void> loadAudio(
    AudioItem audioItem, {
    bool forceTranscriptReload = false,
  }) async {
    state = state.copyWith(
      currentAudioItem: audioItem,
      sentences: forceTranscriptReload ? reloadedSentences : state.sentences,
      currentFullIndex: forceTranscriptReload && reloadedSentences.isNotEmpty
          ? 0
          : state.currentFullIndex,
    );
  }
}
