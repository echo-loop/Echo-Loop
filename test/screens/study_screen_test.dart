import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/daos/stage_completion_dao.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/study_task_provider.dart';
import 'package:echo_loop/screens/study_screen.dart';
import 'package:echo_loop/widgets/learning_progress_icon.dart';
import 'package:echo_loop/providers/time_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget createTestWidget({
    List<AudioItem> audioItems = const [],
    AudioLibraryState? audioLibraryState,
    required LearningProgressState progressState,
    DateTime? fixedNow,
    List<RecentCompletion>? recentCompletions,
    AudioItem? recommendedMaterial,
    AsyncValue<AudioItem?>? recommendationState,
  }) {
    final router = GoRouter(
      initialLocation: '/study',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              Scaffold(body: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/collections',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Library')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/study',
                  builder: (context, state) => const StudyScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/favorites',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Favorites')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Settings')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/audio/:audioId/plan',
          builder: (context, state) =>
              const Scaffold(body: Text('Learning Plan')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        ...learningSettingsOverrides(prefs: prefs),
        audioLibraryProvider.overrideWith(
          () => TestAudioLibrary(
            audioLibraryState ?? AudioLibraryState(audioItems: audioItems),
          ),
        ),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(progressState),
        ),
        if (fixedNow != null) nowProvider.overrideWithValue(() => fixedNow),
        if (recentCompletions != null)
          recentCompletionsProvider.overrideWith(
            (ref) => Future.value(recentCompletions),
          ),
        studyRecommendationProvider.overrideWithValue(
          recommendationState ?? AsyncData<AudioItem?>(recommendedMaterial),
        ),
      ],
      child: MaterialApp.router(
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    );
  }

  testWidgets('无任务时显示空状态', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        progressState: const LearningProgressState(isLoading: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No study tasks yet'), findsOneWidget);
    expect(find.text('Go to Library'), findsOneWidget);
  });

  testWidgets('没有首次学习任务时显示推荐材料并可打开学习计划', (tester) async {
    final now = DateTime(2026, 10, 11, 12);
    final recommended = AudioItem(
      id: 'recommended-audio',
      name: 'Recommended Audio',
      audioPath: 'audios/recommended.mp3',
      addedDate: now,
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: [recommended],
        progressState: const LearningProgressState(isLoading: false),
        fixedNow: now,
        recommendedMaterial: recommended,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recommended for you'), findsOneWidget);
    expect(find.text('Recommended Audio'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pumpAndSettle();

    expect(find.text('Learning Plan'), findsOneWidget);
  });

  testWidgets('为你推荐显示在待解锁任务之前', (tester) async {
    final now = DateTime(2026, 10, 11, 12);
    final upcoming = AudioItem(
      id: 'upcoming-audio',
      name: 'Upcoming Audio',
      audioPath: 'audios/upcoming.mp3',
      addedDate: now,
    );
    final recommended = AudioItem(
      id: 'recommended-audio',
      name: 'Recommended Audio',
      audioPath: 'audios/recommended.mp3',
      addedDate: now,
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: [upcoming, recommended],
        progressState: LearningProgressState(
          progressMap: {
            upcoming.id: LearningProgress(
              audioItemId: upcoming.id,
              currentStage: LearningStage.review2,
              lastStageCompletedAt: now,
              updatedAt: now,
            ),
          },
          isLoading: false,
        ),
        fixedNow: now,
        recentCompletions: const [],
        recommendedMaterial: recommended,
      ),
    );
    await tester.pumpAndSettle();

    final upcomingHeader = find.text('Upcoming Reviews (1)');
    await tester.ensureVisible(upcomingHeader);
    await tester.pumpAndSettle();

    expect(find.text('Recommended for you'), findsOneWidget);
    expect(upcomingHeader, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Recommended for you')).dy,
      lessThan(tester.getTopLeft(upcomingHeader).dy),
    );
  });

  testWidgets('音频列表加载中时显示骨架，不显示空状态', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        audioLibraryState: const AudioLibraryState(isLoading: true),
        progressState: const LearningProgressState(isLoading: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No study tasks yet'), findsNothing);
    expect(find.text('Go to Library'), findsNothing);
  });

  testWidgets('学习进度加载中时显示骨架，不显示空状态', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        progressState: const LearningProgressState(isLoading: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No study tasks yet'), findsNothing);
    expect(find.text('Go to Library'), findsNothing);
  });

  testWidgets('推荐数据加载中时不闪现空状态', (tester) async {
    final now = DateTime(2026, 10, 11, 12);
    final material = AudioItem(
      id: 'audio-1',
      name: 'Audio One',
      audioPath: 'audios/audio-1.mp3',
      addedDate: now,
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: [material],
        progressState: const LearningProgressState(isLoading: false),
        fixedNow: now,
        recommendationState: const AsyncLoading<AudioItem?>(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No study tasks yet'), findsNothing);
    expect(find.text('Go to Library'), findsNothing);
  });

  testWidgets('已有任务时即使库正在 reload 也保留任务，不显示骨架', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Existing Task Audio',
        audioPath: 'audios/existing.mp3',
        addedDate: now,
        totalDuration: 180,
      ),
    ];

    await tester.pumpWidget(
      createTestWidget(
        // 运行期 reload：audioItems 已有数据，但 isLoading 被置回 true。
        audioLibraryState: AudioLibraryState(
          audioItems: audioItems,
          isLoading: true,
        ),
        progressState: LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.review1,
              updatedAt: now,
            ),
          },
          isLoading: false,
        ),
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 骨架不含任何任务文案；任务卡正常渲染即证明未被骨架替换。
    expect(find.text('Existing Task Audio'), findsAtLeast(1));
  });

  testWidgets('未到时间复习任务的开始按钮禁用', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Upcoming Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now,
        ),
      },
      isLoading: false,
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // upcoming reviews 默认折叠，先展开
    final expansionTile = find.byType(ExpansionTile);
    expect(expansionTile, findsWidgets);
    await tester.tap(expansionTile.first);
    await tester.pumpAndSettle();

    // 找到 FilledButton（任务卡片中的按钮），应该是禁用的
    final disabledButtons = find.byWidgetPredicate(
      (w) => w is FilledButton && w.onPressed == null,
    );
    expect(disabledButtons, findsAtLeast(1));
  });

  testWidgets('待解锁任务（v2 首步难句补练、无完成记录）显示倒计时而非"学习中"', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Upcoming v2 Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
    ];
    // review2 v2 首步为难句补练（≠ allSubStages.first 盲听），本轮无完成记录。
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review2,
          currentSubStage: SubStageType.reviewDifficultPractice,
          lastStageCompletedAt: now, // 未到时间 → 待解锁，距解锁 24h（review2 间隔）
          updatedAt: now,
        ),
      },
      isLoading: false,
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // upcoming reviews 默认折叠，先展开
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();

    // 应显示解锁倒计时（24h → "in 1d"），不应误显"In Progress"
    expect(find.text('in 1d'), findsOneWidget);
    expect(find.text('In Progress'), findsNothing);
  });

  testWidgets('复习任务点击开始后导航到学习计划页', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
          updatedAt: now,
        ),
      },
      completionsByAudio: {
        'audio-1': {'firstLearn:intensiveListen'},
      },
      isLoading: false,
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 音频名称出现在任务卡片中
    expect(find.text('Review Audio'), findsAtLeast(1));

    // 本轮无完成记录，按钮文案应为 Start
    await tester.tap(find.text('Start').first);
    await tester.pumpAndSettle();

    expect(find.text('Learning Plan'), findsOneWidget);
  });

  testWidgets('逾期复习任务显示逾期文案', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Overdue Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          // review1 窗口结束 = completed + 18h(间隔) + 24h(窗口) = 42h，这里逾期 3h
          lastStageCompletedAt: now.subtract(const Duration(hours: 45)),
          updatedAt: now,
        ),
      },
      isLoading: false,
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 新格式："Review due · Due 3h ago"
    expect(find.textContaining('Due 3h ago'), findsOneWidget);
    // 任务卡片本轮无完成记录 → 按钮显示 Start
    final startButtons = find.widgetWithText(FilledButton, 'Start');
    expect(startButtons, findsAtLeast(1));
  });

  testWidgets('首次学习材料由推荐卡展示，不再展示阶段任务卡', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'First Study Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.intensiveListen,
          updatedAt: now,
        ),
      },
      completionsByAudio: {
        'audio-1': {
          '${LearningStage.firstLearn.key}:${SubStageType.intensiveListen.key}',
        },
      },
      isLoading: false,
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
        recommendedMaterial: audioItems.first,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recommended for you'), findsOneWidget);
    expect(find.text('First Study Audio'), findsOneWidget);
    expect(find.textContaining('Listen sentence by sentence'), findsOneWidget);
  });

  testWidgets('已完成音频显示在折叠区', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Completed Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.completed,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // "All done" 状态
    expect(find.text('All done for now!'), findsOneWidget);

    // 展开已完成区
    expect(find.textContaining('Completed Materials (1)'), findsOneWidget);
    await tester.tap(find.textContaining('Completed Materials (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Completed Audio'), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('已完成视频显示视频图标且不叠加对钩', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'video-1',
        name: 'Completed Video',
        audioPath: 'videos/test.mp4',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'video-1': LearningProgress(
          audioItemId: 'video-1',
          currentStage: LearningStage.completed,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Completed Materials (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Completed Video'), findsOneWidget);
    expect(_findSvgAsset('assets/icon/video-2.svg'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('有任务时不应出现 Hero Card（渐变大卡片）', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
      AudioItem(
        id: 'audio-2',
        name: 'First Study Audio',
        audioPath: 'audios/first.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 不应出现 Hero Card 的 "Continue practicing" 标签
    expect(find.text('Continue practicing'), findsNothing);
    // 复习任务直接显示；未完成首次学习材料由推荐区统一承载。
    expect(find.text('Review Audio'), findsAtLeast(1));
    expect(find.text('First Study Audio'), findsNothing);
  });

  testWidgets('任务分组标题使用固定 SVG 图标替换 emoji', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'review-audio',
        name: 'Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
      AudioItem(
        id: 'first-audio',
        name: 'First Study Audio',
        audioPath: 'audios/first.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'review-audio': LearningProgress(
          audioItemId: 'review-audio',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
          updatedAt: now,
        ),
      },
      isLoading: false,
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🔁'), findsNothing);
    expect(find.text('🌱'), findsNothing);
    expect(_findSvgAsset('assets/icon/refresh.svg'), findsOneWidget);
    expect(_findSvgAsset('assets/icon/reading.svg'), findsNothing);
  });

  testWidgets('学习社群入口保持紧凑高度并使用发现入口青蓝色系', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'First Study Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: const LearningProgressState(isLoading: false),
        fixedNow: now,
        recommendedMaterial: audioItems.first,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Join Community'), findsOneWidget);
    expect(find.text('Learn, ask, and share'), findsOneWidget);

    final communityDecoration = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) {
          final gradient = decoration.gradient;
          return gradient is LinearGradient &&
              gradient.colors.length == 2 &&
              gradient.colors.first == const Color(0xFFEAF8FA) &&
              gradient.colors.last == const Color(0xFFDDEFFA);
        });

    expect(communityDecoration.borderRadius, BorderRadius.circular(12));
    expect(
      (communityDecoration.border! as Border).top.color,
      const Color(0xFFA9D5DF),
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.group_rounded)).size, 20);
    expect(tester.widget<Icon>(find.byIcon(Icons.chevron_right)).size, 20);
  });

  testWidgets('任务卡片中显示 LearningProgressIcon', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Test Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.review1,
              updatedAt: now,
            ),
          },
          isLoading: false,
        ),
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LearningProgressIcon), findsAtLeast(1));
  });

  testWidgets('多个未学习音频时页面只显示一条推荐材料', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'review-audio',
        name: 'Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
        totalDuration: 180,
      ),
      AudioItem(
        id: 'short-audio',
        name: 'Short Audio',
        audioPath: 'audios/short.mp3',
        addedDate: now.subtract(const Duration(days: 1)),
        totalDuration: 90,
      ),
      AudioItem(
        id: 'long-audio',
        name: 'Long Audio',
        audioPath: 'audios/long.mp3',
        addedDate: now.subtract(const Duration(days: 2)),
        totalDuration: 240,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'review-audio': LearningProgress(
          audioItemId: 'review-audio',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
        ),
      },
      isLoading: false,
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
        recommendedMaterial: audioItems[1],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review Audio'), findsAtLeast(1));
    expect(find.text('Short Audio'), findsAtLeast(1));
    expect(find.text('Long Audio'), findsNothing);
  });

  testWidgets('无任务时点击"去导入音频"导航到 Library', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        audioItems: const [],
        progressState: const LearningProgressState(isLoading: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go to Library'));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('最近完成区段显示记录并默认折叠', (tester) async {
    final now = DateTime(2026, 3, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Test Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];

    final completions = [
      RecentCompletion(
        audioId: 'audio-1',
        audioName: 'Test Audio',
        stage: 'firstLearn',
        subStage: 'blindListen',
        completedAt: now.subtract(const Duration(hours: 2)),
        durationMs: 5000,
      ),
      RecentCompletion(
        audioId: 'audio-1',
        audioName: 'Test Audio',
        stage: 'firstLearn',
        subStage: 'intensiveListen',
        completedAt: now.subtract(const Duration(minutes: 30)),
        durationMs: 8000,
      ),
    ];

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: const LearningProgressState(isLoading: false),
        fixedNow: now,
        recentCompletions: completions,
      ),
    );
    await tester.pumpAndSettle();

    // 折叠区标题可见
    expect(find.textContaining('Recently Completed Tasks (2)'), findsOneWidget);
    // 摘要文案可见
    expect(find.text('Past 24 hours'), findsOneWidget);

    // 默认折叠 —— 子项不可见
    expect(find.text('Listen without subtitles'), findsNothing);

    // 展开后子项可见
    await tester.tap(find.textContaining('Recently Completed Tasks (2)'));
    await tester.pumpAndSettle();
    // 相对时间出现在最近完成区段中
    expect(find.text('2h ago'), findsOneWidget);
    expect(find.text('30m ago'), findsOneWidget);
    // 媒体图标与「合集」item 同款圆环风格，不再叠加对钩徽标，避免被误认为整个
    // 音频已学完；完成状态改由左侧绿色条传达。
    final mediaIcon = tester.widget<SizedBox>(
      find.byKey(const ValueKey('recent_completion_media_icon')).first,
    );
    expect(mediaIcon.width, 36);
    expect(mediaIcon.height, 36);
    final accentBars = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.color == LearningProgressIcon.completedColor)
        .toList();
    expect(accentBars.length, 2);
  });

  testWidgets('最近完成视频使用视频图标而不是完成对钩', (tester) async {
    final now = DateTime(2026, 3, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Active Audio',
        audioPath: 'audios/active.mp3',
        addedDate: now,
      ),
      AudioItem(
        id: 'video-1',
        name: 'Recently Completed Video',
        audioPath: 'videos/recent.mp4',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.listenAndRepeat,
          updatedAt: now,
        ),
        'video-1': LearningProgress(
          audioItemId: 'video-1',
          currentStage: LearningStage.completed,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      },
      isLoading: false,
    );
    final completions = [
      RecentCompletion(
        audioId: 'video-1',
        audioName: 'Recently Completed Video',
        stage: 'firstLearn',
        subStage: 'blindListen',
        completedAt: now.subtract(const Duration(minutes: 10)),
        durationMs: 5000,
      ),
    ];

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
        recentCompletions: completions,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Recently Completed Tasks (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Recently Completed Video'), findsOneWidget);
    expect(_findSvgAsset('assets/icon/video-2.svg'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('无最近完成记录时不显示折叠区', (tester) async {
    final now = DateTime(2026, 3, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Test Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: const LearningProgressState(isLoading: false),
        fixedNow: now,
        recentCompletions: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Recently Completed'), findsNothing);
  });
}

Finder _findSvgAsset(String assetName) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is SvgPicture &&
        widget.bytesLoader is SvgAssetLoader &&
        (widget.bytesLoader as SvgAssetLoader).assetName == assetName,
  );
}
