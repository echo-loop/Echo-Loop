/// 通用测试包装器
///
/// 提供 `createTestApp` 辅助函数，将被测 Widget 包装在
/// ProviderScope + MaterialApp（含 localization delegates）中。
/// 提供 `createTestRouter` 辅助函数，用于需要路由的测试场景。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:echo_loop/database/app_database.dart'
    hide AudioItem, Collection;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/main.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart' show AudioItem;
import 'package:echo_loop/models/collection.dart' show Collection;
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/database/enums.dart' show LearningStage;
import 'package:echo_loop/providers/new_user_guide_provider.dart';
import 'package:echo_loop/providers/package_info_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/tag_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';
import 'package:echo_loop/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/providers/flashcard/flashcard_provider.dart';
import 'package:echo_loop/providers/transcription_task_provider.dart';
import 'package:echo_loop/theme/app_theme.dart';

import 'mock_providers.dart';

/// 创建测试用 App 包装器
///
/// 自动注入所有 Provider 的测试替身，可通过 [overrides] 覆盖。
/// [locale] 默认为英文，可切换为中文测试国际化。
/// [size] 用于设置窗口大小模拟不同设备。
Widget createTestApp(
  Widget child, {
  List<Override>? overrides,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  // 默认 overrides：所有 Provider 使用测试替身
  final defaultOverrides = <Override>[
    analyticsOverride(),
    usageOverride(),
    ...studyTimeOverrides(),
    ...learningSettingsOverrides(),
    appSettingsProvider.overrideWith(
      () => TestAppSettings(
        AppSettingsState(themeMode: themeMode, locale: locale),
      ),
    ),
    audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
    collectionListProvider.overrideWith(() => TestCollectionList()),
    tagListProvider.overrideWith(() => TestTagList()),
    listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
    audioEngineProvider.overrideWith(() => TestAudioEngine()),
    foregroundAudioEngineProvider.overrideWith(
      () => TestForegroundAudioEngine(),
    ),
    learningProgressNotifierProvider.overrideWith(
      () => TestLearningProgressNotifier(),
    ),
    learningSessionProvider.overrideWith(() => TestLearningSession()),
    blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
  ];

  // 合并自定义 overrides（覆盖同名 provider）
  final allOverrides = <Override>[...defaultOverrides, ...(overrides ?? [])];

  return ProviderScope(
    overrides: allOverrides,
    child: Builder(
      builder: (context) {
        // 注册 ShowcaseView 控制器（测试环境）
        // ignore: unused_local_variable
        final showcase = ShowcaseView.register();
        return MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: Scaffold(body: child),
        );
      },
    ),
  );
}

/// 创建包含 Scaffold 的测试 App（用于测试需要 Scaffold 上下文的 Screen）
///
/// 使用 mock GoRouter 处理导航，避免实际路由依赖。
Widget createTestScreen(
  Widget screen, {
  List<Override>? overrides,
  Locale locale = const Locale('en'),
}) {
  final defaultOverrides = <Override>[
    analyticsOverride(),
    usageOverride(),
    ...studyTimeOverrides(),
    appSettingsProvider.overrideWith(
      () => TestAppSettings(AppSettingsState(locale: locale)),
    ),
    audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
    collectionListProvider.overrideWith(() => TestCollectionList()),
    tagListProvider.overrideWith(() => TestTagList()),
    listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
    audioEngineProvider.overrideWith(() => TestAudioEngine()),
    foregroundAudioEngineProvider.overrideWith(
      () => TestForegroundAudioEngine(),
    ),
  ];

  // 合并自定义 overrides
  final allOverrides = <Override>[...defaultOverrides, ...(overrides ?? [])];

  final router = createTestRouter(screen);

  return ProviderScope(
    overrides: allOverrides,
    child: Builder(
      builder: (context) {
        // 注册 ShowcaseView 控制器（测试环境）
        // ignore: unused_local_variable
        final showcase = ShowcaseView.register();
        return MaterialApp.router(
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
        );
      },
    ),
  );
}

/// 在 flutter_test 中渲染完整 [EchoLoopApp]，注入与集成测试一致的 Provider 替身。
///
/// 用于把原本写在 `integration_test/` 里的「app shell」级用例（Tab 切换、主题切换、
/// 语言切换等）下沉到 `flutter_test`，绕开 LiveTest binding 的 8 分钟冷启动成本。
///
/// 调用者职责：
/// - 在 `testWidgets` 内部调用 `await pumpFullApp(tester)` 后，用 `tester.pump(...)`
///   推进 Riverpod async / Showcase 等异步初始化（建议先 pump 一次再 pump 1-200ms）。
/// - 测试末尾用 `await tester.pump(const Duration(seconds: 6));` 消耗冷启动保护
///   定时器，避免 pending timer 断言。
///
/// [overrides] 用于覆盖默认替身（例如预置 LearningProgress）。
Future<void> pumpFullApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  final packageInfo = PackageInfo(
    appName: 'Echo Loop',
    packageName: 'top.echo-loop',
    version: '1.0.0',
    buildNumber: '1',
  );

  // 把所有 guide flow 预置为「已看」，避免 Showcase 在测试中弹出 + 留下持续
  // 调度帧的 Timer 导致 pumpAndSettle 超时。
  final guideSeen = <String, Object>{
    for (final flowId in GuideFlowIds.all) 'guide_v1_${flowId}_seen': true,
  };
  SharedPreferences.setMockInitialValues(guideSeen);
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isFirstLaunchProvider.overrideWithValue(false),
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialOnboardingCompletedProvider.overrideWithValue(true),
        // 隐藏 AI section，避免 ASR 相关 Provider 未实现导致 UnimplementedError
        showOfflineAsrSectionProvider.overrideWithValue(false),
        offlineAsrOverride(),
        appSettingsProvider.overrideWith(() => TestAppSettings()),
        audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
        collectionListProvider.overrideWith(() => TestCollectionList()),
        tagListProvider.overrideWith(() => TestTagList()),
        listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        foregroundAudioEngineProvider.overrideWith(
          () => TestForegroundAudioEngine(),
        ),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(),
        ),
        learningSessionProvider.overrideWith(() => TestLearningSession()),
        blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
        intensiveListenPlayerProvider.overrideWith(
          () => TestIntensiveListenPlayer(),
        ),
        retellPlayerProvider.overrideWith(() => TestRetellPlayer()),
        reviewDifficultPracticeProvider.overrideWith(
          () => TestReviewDifficultPractice(),
        ),
        flashcardNotifierProvider.overrideWith(() => TestFlashcardNotifier()),
        transcriptionTaskManagerProvider.overrideWith(
          () => TestTranscriptionTaskManager(),
        ),
        packageInfoProvider.overrideWithValue(packageInfo),
        analyticsOverride(),
        usageOverride(),
        ...studyTimeOverrides(),
        ...learningSettingsOverrides(),
        appDatabaseProvider.overrideWithValue(
          AppDatabase(
            NativeDatabase.memory(
              setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
            ),
          ),
        ),
        ...overrides,
      ],
      child: const EchoLoopApp(),
    ),
  );
}

/// 在 flutter_test 中渲染完整 [EchoLoopApp] 并预置一份音频学习数据。
///
/// 对应 integration_test 中的 `createTestAppWithAudio`：注入 1 个 AudioItem +
/// 1 个 Collection（含音频关联）+ N 句 Sentence + LearningProgress（默认 firstLearn/
/// blindListen 阶段）+ AudioEngine totalDuration=25s。
///
/// 区别在于：通过构造器把数据塞进 Test* Notifier 的 `_initialState`，避免依赖
/// 「addPostFrameCallback + Notifier mutator」模式（test/helpers 的 mock 不暴露这些
/// mutator）。学习计划页等 UI 通常用 `findsAtLeast(1)` 之类的弱断言验证渲染即可。
Future<void> pumpFullAppWithAudio(
  WidgetTester tester, {
  AudioItem? audioItem,
  Collection? collection,
  List<Sentence>? sentences,
  LearningProgress? progress,
  List<Override> overrides = const [],
}) async {
  final seedAudioItem = audioItem ?? createTestAudioItem();
  final seedCollection = collection ?? createTestCollection();
  final seedSentences = sentences ?? createTestSentences();
  final seedProgress =
      progress ??
      createTestLearningProgress(currentStageStartedAt: DateTime.now());

  // 按 (currentStage, currentSubStage) 推导已完成的 sub_stage key 集合：
  // 当前 stage 内 currentSubStage 之前的子步骤 + 所有先前 stage 全部 sub_stages。
  final completed = <String>{};
  for (final stage in LearningStage.values) {
    if (stage.index < seedProgress.currentStage.index) {
      for (final sub in stage.allSubStages) {
        completed.add('${stage.key}:${sub.key}');
      }
    } else if (stage.index == seedProgress.currentStage.index) {
      final subs = stage.allSubStages;
      final idx = subs.indexOf(seedProgress.currentSubStage);
      if (idx > 0) {
        for (var i = 0; i < idx; i++) {
          completed.add('${stage.key}:${subs[i].key}');
        }
      }
    }
  }

  await pumpFullApp(
    tester,
    overrides: [
      audioLibraryProvider.overrideWith(
        () => TestAudioLibrary(AudioLibraryState(audioItems: [seedAudioItem])),
      ),
      collectionListProvider.overrideWith(
        () => TestCollectionList(
          CollectionState(
            rawCollections: [seedCollection],
            audioIdsMap: {
              seedCollection.id: [seedAudioItem.id],
            },
          ),
        ),
      ),
      learningProgressNotifierProvider.overrideWith(
        () => TestLearningProgressNotifier(
          LearningProgressState(
            progressMap: {seedProgress.audioItemId: seedProgress},
            completionsByAudio: {seedProgress.audioItemId: completed},
          ),
        ),
      ),
      listeningPracticeProvider.overrideWith(
        () => TestListeningPractice(
          ListeningPracticeState(sentences: seedSentences),
        ),
      ),
      audioEngineProvider.overrideWith(
        () => TestAudioEngine(
          initialState: const AudioEngineState(
            totalDuration: Duration(seconds: 25),
          ),
        ),
      ),
      foregroundAudioEngineProvider.overrideWith(
        () => TestForegroundAudioEngine(
          initialState: const AudioEngineState(
            totalDuration: Duration(seconds: 25),
          ),
        ),
      ),
      ...overrides,
    ],
  );
}

/// 创建测试用 GoRouter
///
/// 将传入的 [screen] 作为初始路由页面，
/// 并添加常用的 stub 路由用于导航测试。
GoRouter createTestRouter(Widget screen) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => screen),
      // stub 路由，用于验证导航跳转
      GoRoute(
        path: '/player',
        builder: (context, state) => const Scaffold(body: Text('Player')),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(body: Text('Settings')),
      ),
      GoRoute(
        path: '/sentence-detail',
        builder: (context, state) =>
            const Scaffold(body: Text('Sentence Detail')),
      ),
      GoRoute(
        path: '/collections/:collectionId',
        builder: (context, state) =>
            const Scaffold(body: Text('Collection Detail')),
        routes: [
          GoRoute(
            path: ':audioId/plan',
            builder: (context, state) =>
                const Scaffold(body: Text('Learning Plan')),
          ),
          GoRoute(
            path: ':audioId/player',
            builder: (context, state) => const Scaffold(body: Text('Player')),
          ),
          GoRoute(
            path: ':audioId/blind-listen',
            builder: (context, state) =>
                const Scaffold(body: Text('Blind Listen')),
          ),
        ],
      ),
    ],
  );
}
