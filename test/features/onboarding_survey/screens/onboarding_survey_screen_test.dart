import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:echo_loop/analytics/analytics_channel.dart';
import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/consent_manager.dart';
import 'package:echo_loop/analytics/models/event_names.dart';
import 'package:echo_loop/features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'package:echo_loop/features/onboarding_survey/data/user_onboarding_sync_service.dart';
import 'package:echo_loop/features/onboarding_survey/models/onboarding_question.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/features/onboarding_survey/providers/user_onboarding_sync_provider.dart';
import 'package:echo_loop/features/onboarding_survey/screens/onboarding_survey_screen.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/features/onboarding_survey/widgets/survey_choice_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/mock_providers.dart';

class _RecordingAnalyticsChannel implements AnalyticsChannel {
  final List<({String name, Map<String, Object>? params})> events = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    events.add((name: name, params: parameters));
  }

  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {}

  @override
  Future<void> setUserId(String? id) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}

  @override
  Future<void> setUserProperties(Map<String, String?> properties) async {}

  @override
  Future<void> unregisterSuperProperty(String name) async {}
}

class _RecordingOnboardingSync implements OnboardingSync {
  int localAnswersChanged = 0;

  @override
  Future<void> onAppResumed() async {}

  @override
  Future<void> onLocalAnswersChanged() async {
    localAnswersChanged++;
  }

  @override
  Future<void> onSessionChanged({required bool isSignedIn}) async {}
}

class _NoopOnboardingSync implements OnboardingSync {
  @override
  Future<void> onAppResumed() async {}

  @override
  Future<void> onLocalAnswersChanged() async {}

  @override
  Future<void> onSessionChanged({required bool isSignedIn}) async {}
}

/// 创建一个最小化的可路由测试 App，承载 onboarding 页 + study 占位页。
Widget _wrap({
  required SharedPreferences prefs,
  bool initialOnboardingCompleted = false,
  _RecordingAnalyticsChannel? analyticsChannel,
  OnboardingSync? onboardingSync,
  ThemeMode themeMode = ThemeMode.light,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.onboardingSurvey,
    routes: [
      GoRoute(
        path: AppRoutes.onboardingSurvey,
        builder: (_, __) => const OnboardingSurveyScreen(),
      ),
      GoRoute(
        path: AppRoutes.study,
        builder: (_, __) => const Scaffold(body: Text('STUDY_PLACEHOLDER')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialOnboardingCompletedProvider.overrideWithValue(
        initialOnboardingCompleted,
      ),
      onboardingSyncProvider.overrideWithValue(
        onboardingSync ?? _NoopOnboardingSync(),
      ),
      if (analyticsChannel == null)
        analyticsOverride()
      else
        analyticsServiceProvider.overrideWithValue(
          AnalyticsService(
            channel: analyticsChannel,
            consent: ConsentManager(prefs),
          ),
        ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('普通分支：选目标 → 时长 → 渠道 → 方法论页 → 点开始学习', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingSync = _RecordingOnboardingSync();
    await tester.pumpWidget(
      _wrap(prefs: prefs, onboardingSync: onboardingSync),
    );
    await tester.pumpAndSettle();

    expect(find.text('你练习英语听说的主要目标是什么？'), findsOneWidget);

    // 选"工作沟通" → 等待自动前进
    await tester.tap(find.text('工作沟通'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // 已切到时长页
    expect(find.text('你计划每天练习多久？'), findsOneWidget);
    expect(find.text('约 20 分钟'), findsOneWidget);

    // 选"不固定" → 自动跳到渠道页
    await tester.tap(find.text('不固定'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('你是从哪里知道我们的？'), findsOneWidget);
    // 中文用户应看到中文渠道选项
    expect(find.text('小红书'), findsOneWidget);
    expect(find.text('微信'), findsOneWidget);
    expect(find.text('抖音'), findsOneWidget);
    expect(find.text('快手'), findsOneWidget);
    // 英文渠道不展示
    expect(find.text('Reddit'), findsNothing);
    expect(find.text('Google Play'), findsNothing);

    await tester.tap(find.text('小红书'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // summary 页：headline + 4 要点 + 权限预告 + 开始学习 按钮，仍未提交
    expect(find.textContaining('提升英语听说'), findsOneWidget);
    expect(find.text('选择适合你水平的音频反复练习'), findsOneWidget);
    expect(find.text('通过复述练习口语，把听懂变成会说'), findsOneWidget);
    // 权限预告：纯展示 label，无交互
    expect(find.text('为了保证体验我们将请求以下权限'), findsOneWidget);
    expect(find.text('系统通知'), findsOneWidget);
    expect(find.text('录音'), findsOneWidget);
    expect(find.text('语音识别'), findsOneWidget);
    expect(find.text('开始学习'), findsOneWidget);
    expect(OnboardingSurveyStorage(prefs).isCompleted, isFalse);
    expect(find.text('STUDY_PLACEHOLDER'), findsNothing);

    // 点击"开始学习" → 提交并跳转
    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('STUDY_PLACEHOLDER'), findsOneWidget);
    expect(onboardingSync.localAnswersChanged, 1);

    final storage = OnboardingSurveyStorage(prefs);
    expect(storage.isCompleted, isTrue);
    final answers = storage.loadAnswers();
    expect(answers?.goal, equals(OnboardingGoal.work));
    expect(answers?.dailyMinutes, equals(OnboardingDailyMinutes.flexible));
    expect(
      answers?.referralSource,
      equals(OnboardingReferralSource.xiaohongshu),
    );
  });

  testWidgets('深色模式下题目、选项、品牌图标和 summary 使用深色主题颜色', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final darkTheme = AppTheme.dark();
    final colors = darkTheme.colorScheme;
    await tester.pumpWidget(_wrap(prefs: prefs, themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, isNull);
    expect(
      tester.widget<Text>(find.text('你练习英语听说的主要目标是什么？')).style?.color,
      colors.onSurface,
    );

    final dailyTile = find.ancestor(
      of: find.text('日常交流'),
      matching: find.byType(SurveyChoiceTile),
    );
    final unselectedMaterial = find.descendant(
      of: dailyTile,
      matching: find.byType(Material),
    );
    expect(tester.widget<Material>(unselectedMaterial).color, colors.surface);

    await tester.tap(find.text('日常交流'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<Material>(unselectedMaterial).color,
      colors.primaryContainer,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    await tester.tap(find.text('约 10 分钟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    final githubTile = find.ancestor(
      of: find.text('GitHub'),
      matching: find.byType(SurveyChoiceTile),
    );
    final githubIcon = find.descendant(
      of: githubTile,
      matching: find.byType(FaIcon),
    );
    expect(tester.widget<FaIcon>(githubIcon).color, colors.onSurface);

    await tester.tap(find.text('朋友推荐'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(
      tester.widget<Text>(find.textContaining('提升英语听说')).style?.color,
      colors.onSurface,
    );
    expect(
      tester.widget<Text>(find.text('为了保证体验我们将请求以下权限')).style?.color,
      colors.onSurfaceVariant,
    );
  });

  testWidgets('考试分支：目标 → 考试类型 → 时长 → 渠道 → summary → 开始学习', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('应对考试'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你当前在备考哪一类考试？'), findsOneWidget);
    expect(find.text('雅思 IELTS'), findsOneWidget);

    await tester.tap(find.text('雅思 IELTS'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你计划每天练习多久？'), findsOneWidget);

    await tester.tap(find.text('约 20 分钟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('你是从哪里知道我们的？'), findsOneWidget);
    await tester.tap(find.text('应用商店'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('开始学习'), findsOneWidget);
    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('STUDY_PLACEHOLDER'), findsOneWidget);
    final answers = OnboardingSurveyStorage(prefs).loadAnswers();
    expect(answers?.goal, equals(OnboardingGoal.exam));
    expect(answers?.examType, equals(OnboardingExamType.ielts));
    expect(answers?.dailyMinutes, equals(OnboardingDailyMinutes.m20));
    expect(answers?.referralSource, equals(OnboardingReferralSource.appStore));
  });

  testWidgets('其他分支：选其他 → 时长 → 渠道 → summary → 开始学习', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你计划每天练习多久？'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('继续'), findsNothing);

    await tester.tap(find.text('约 10 分钟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // 渠道页选"朋友推荐"
    await tester.tap(find.text('朋友推荐'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('STUDY_PLACEHOLDER'), findsOneWidget);
    final answers = OnboardingSurveyStorage(prefs).loadAnswers();
    expect(answers?.goal, equals(OnboardingGoal.other));
    expect(answers?.goalOtherText, isNull);
    expect(answers?.dailyMinutes, equals(OnboardingDailyMinutes.m10));
    expect(answers?.referralSource, equals(OnboardingReferralSource.friend));
  });

  testWidgets('影视播客分支：目标 → 时长 → 渠道 → summary → 开始学习', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('听懂影视播客'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你计划每天练习多久？'), findsOneWidget);

    await tester.tap(find.text('约 20 分钟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('B 站'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('STUDY_PLACEHOLDER'), findsOneWidget);
    final answers = OnboardingSurveyStorage(prefs).loadAnswers();
    expect(answers?.goal, equals(OnboardingGoal.content));
    expect(answers?.dailyMinutes, equals(OnboardingDailyMinutes.m20));
    expect(answers?.referralSource, equals(OnboardingReferralSource.bilibili));
  });

  testWidgets('summary 页可通过"上一步"返回渠道页修改答案', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('日常交流'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.text('约 10 分钟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await tester.tap(find.text('朋友推荐'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('开始学习'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);

    await tester.tap(find.text('上一步'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你是从哪里知道我们的？'), findsOneWidget);
    // 仍未写入完成态
    expect(OnboardingSurveyStorage(prefs).isCompleted, isFalse);
  });

  testWidgets('上一步：从时长页可以回到目标页', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    // 第一题不显示上一步
    expect(find.text('上一步'), findsNothing);

    await tester.tap(find.text('日常交流'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你计划每天练习多久？'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);

    await tester.tap(find.text('上一步'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你练习英语听说的主要目标是什么？'), findsOneWidget);
  });

  testWidgets('物理返回键被 PopScope 拦截', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    // ignore: deprecated_member_use
    await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pumpAndSettle();

    expect(find.text('你练习英语听说的主要目标是什么？'), findsOneWidget);
  });

  testWidgets('无跳过按钮渲染', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();
    expect(find.text('以后再说'), findsNothing);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Skip for now'), findsNothing);
  });

  testWidgets('埋点覆盖问卷展示、答案上报和完成漏斗', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final analytics = _RecordingAnalyticsChannel();
    await tester.pumpWidget(_wrap(prefs: prefs, analyticsChannel: analytics));
    await tester.pumpAndSettle();

    await tester.tap(find.text('应对考试'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.text('雅思 IELTS'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.text('约 20 分钟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await tester.tap(find.text('小红书'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    final names = analytics.events.map((event) => event.name).toList();
    expect(names, contains(Events.onboardingSurveyShown));
    expect(names, contains(Events.onboardingSurveyQuestionAnswered));
    expect(names, contains(Events.onboardingSurveyCompleted));

    // 验证每道题的答案上报
    final answers = analytics.events
        .where((event) => event.name == Events.onboardingSurveyQuestionAnswered)
        .toList();
    expect(answers.length, 4);

    expect(
      answers[0].params?[EventParams.questionId],
      OnboardingQuestionId.goal,
    );
    expect(answers[0].params?[EventParams.answerCode], OnboardingGoal.exam);

    expect(
      answers[1].params?[EventParams.questionId],
      OnboardingQuestionId.examType,
    );
    expect(
      answers[1].params?[EventParams.answerCode],
      OnboardingExamType.ielts,
    );

    expect(
      answers[2].params?[EventParams.questionId],
      OnboardingQuestionId.dailyMinutes,
    );
    expect(
      answers[2].params?[EventParams.answerCode],
      OnboardingDailyMinutes.m20,
    );

    expect(
      answers[3].params?[EventParams.questionId],
      OnboardingQuestionId.referralSource,
    );
    expect(
      answers[3].params?[EventParams.answerCode],
      OnboardingReferralSource.xiaohongshu,
    );

    // 完成事件应携带 referral_source
    final completed = analytics.events.firstWhere(
      (event) => event.name == Events.onboardingSurveyCompleted,
    );
    expect(
      completed.params?[EventParams.referralSource],
      OnboardingReferralSource.xiaohongshu,
    );
  });

  testWidgets('英文用户：渠道页展示国际渠道，不展示中文渠道', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: AppRoutes.onboardingSurvey,
      routes: [
        GoRoute(
          path: AppRoutes.onboardingSurvey,
          builder: (_, __) => const OnboardingSurveyScreen(),
        ),
        GoRoute(
          path: AppRoutes.study,
          builder: (_, __) => const Scaffold(body: Text('STUDY_PLACEHOLDER')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialOnboardingCompletedProvider.overrideWithValue(false),
          analyticsOverride(),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 走到渠道页
    await tester.tap(find.text('Daily conversation'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.text('About 10 min'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('How did you hear about us?'), findsOneWidget);
    expect(find.text('App Store'), findsOneWidget);
    expect(find.text('Google Play'), findsOneWidget);
    expect(find.text('Reddit'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('X / Twitter'), findsOneWidget);
    // 中文渠道不应展示
    expect(find.text('Xiaohongshu'), findsNothing);
    expect(find.text('WeChat'), findsNothing);
    expect(find.text('Douyin'), findsNothing);

    await tester.tap(find.text('Reddit'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await tester.tap(find.text('Start Practicing'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    final answers = OnboardingSurveyStorage(prefs).loadAnswers();
    expect(answers?.referralSource, equals(OnboardingReferralSource.reddit));
  });
}
