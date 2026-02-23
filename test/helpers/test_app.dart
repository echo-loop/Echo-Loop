/// 通用测试包装器
///
/// 提供 `createTestApp` 辅助函数，将被测 Widget 包装在
/// ProviderScope + MaterialApp（含 localization delegates）中。
/// 提供 `createTestRouter` 辅助函数，用于需要路由的测试场景。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/tag_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/blind_listen_player_provider.dart';
import 'package:fluency/theme/app_theme.dart';

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
    learningProgressNotifierProvider.overrideWith(
      () => TestLearningProgressNotifier(),
    ),
    learningSessionProvider.overrideWith(() => TestLearningSession()),
    blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
  ];

  return ProviderScope(
    overrides: overrides ?? defaultOverrides,
    child: MaterialApp(
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
    appSettingsProvider.overrideWith(
      () => TestAppSettings(AppSettingsState(locale: locale)),
    ),
    audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
    collectionListProvider.overrideWith(() => TestCollectionList()),
    tagListProvider.overrideWith(() => TestTagList()),
    listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
    audioEngineProvider.overrideWith(() => TestAudioEngine()),
  ];

  final router = createTestRouter(screen);

  return ProviderScope(
    overrides: overrides ?? defaultOverrides,
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
