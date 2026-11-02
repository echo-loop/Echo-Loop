/// NotificationPermissionDialog widget 测试。
///
/// 覆盖两种 mode 渲染 + 按钮回调路径。系统权限 / openAppSettings
/// 通过 mock 服务层屏蔽。
library;

import 'dart:async';

import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/notification_permission_provider.dart';
import 'package:echo_loop/services/notification_permission_service.dart';
import 'package:echo_loop/widgets/notification_permission_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/mock_providers.dart';

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockNotificationPermissionService extends Mock
    implements NotificationPermissionService {}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late MockAnalyticsService analytics;
  late MockNotificationPermissionService permissionService;

  setUp(() {
    analytics = MockAnalyticsService();
    permissionService = MockNotificationPermissionService();
    when(() => analytics.track(any(), any())).thenAnswer((_) async {});
    when(
      () => permissionService.onUserAcceptedPrompt(),
    ).thenAnswer((_) async => true);
    when(
      () => permissionService.onUserDismissedPrompt(),
    ).thenAnswer((_) async {});
  });

  Widget wrap(Widget child, SharedPreferences prefs) {
    return ProviderScope(
      overrides: dedupeOverrides([
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsServiceProvider.overrideWithValue(analytics),
        notificationPermissionServiceProvider.overrideWithValue(
          permissionService,
        ),
      ]),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  Future<void> pumpAndShow(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      wrap(
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Builder(
              builder: (innerCtx) => TextButton(
                onPressed: () =>
                    showNotificationPermissionDialog(innerCtx, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        prefs,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('渲染标题和正文', (tester) async {
    await pumpAndShow(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Turn on reminders'), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);
  });

  testWidgets('点 Turn on → onUserAcceptedPrompt 被调用', (tester) async {
    await pumpAndShow(tester);
    await tester.tap(find.text('Turn on reminders'));
    await tester.pumpAndSettle();
    verify(() => permissionService.onUserAcceptedPrompt()).called(1);
    verifyNever(() => permissionService.onUserDismissedPrompt());
  });

  testWidgets('点 Maybe later → onUserDismissedPrompt 被调用', (tester) async {
    await pumpAndShow(tester);
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    verify(() => permissionService.onUserDismissedPrompt()).called(1);
    verifyNever(() => permissionService.onUserAcceptedPrompt());
  });

  testWidgets('展示时埋点 notification_prompt_shown', (tester) async {
    await pumpAndShow(tester);
    verify(
      () => analytics.track('notification_prompt_shown', const {}),
    ).called(1);
  });

  testWidgets('按钮连击只触发一次 onUserAcceptedPrompt（debounce）', (tester) async {
    // 用 Completer 挂住第一次调用，验证按钮被锁住，连击不会重入
    final completer = Completer<bool>();
    when(
      () => permissionService.onUserAcceptedPrompt(),
    ).thenAnswer((_) => completer.future);
    await pumpAndShow(tester);

    // 第一次 tap 启动异步
    await tester.tap(find.text('Turn on reminders'));
    await tester.pump(); // 让 setState(_processing=true) 生效
    // 后续 tap 应被忽略（按钮 disabled）
    await tester.tap(find.text('Turn on reminders'));
    await tester.tap(find.text('Turn on reminders'));

    verify(() => permissionService.onUserAcceptedPrompt()).called(1);

    // 释放 future + 清理 dialog，避免 pending timer 警告
    completer.complete(false);
    await tester.pumpAndSettle();
  });
}
