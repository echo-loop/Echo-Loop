/// 隐藏密码登录入口（审核员专用）的 Widget 测试。
///
/// 覆盖：登录主页连点 logo 5 次进入密码登录页、密码页表单校验、
/// 成功登录后跨过认证页返回登录前页面、登录失败的本地化错误提示。
library;

import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/models/event_names.dart';
import 'package:echo_loop/features/auth/screens/login_screen.dart';
import 'package:echo_loop/features/auth/screens/password_sign_in_screen.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

Widget _app(GoRouter router, {AnalyticsService? analytics}) {
  return ProviderScope(
    overrides: dedupeOverrides([
      analyticsServiceProvider.overrideWithValue(
        analytics ?? createTestAnalyticsServiceSync(),
      ),
    ]),
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
      routerConfig: router,
    ),
  );
}

GoRouter _router({
  PasswordSignInAction? onSignIn,
  String initialLocation = AppRoutes.login,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(
          isAppleSignInSupportedOverride: true,
          isGoogleSignInSupportedOverride: false,
        ),
      ),
      GoRoute(
        path: AppRoutes.passwordSignIn,
        builder: (context, state) => PasswordSignInScreen(onSignIn: onSignIn),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const Scaffold(body: Text('Settings')),
      ),
      GoRoute(
        path: AppRoutes.study,
        builder: (context, state) => const Scaffold(body: Text('Source Page')),
      ),
    ],
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapLogo(WidgetTester tester, int times) async {
  final logo = find.bySemanticsLabel('Echo Loop');
  for (var i = 0; i < times; i++) {
    await tester.tap(logo);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('连点 logo 不足 5 次不进入密码登录页', (tester) async {
    await tester.pumpWidget(_app(_router(onSignIn: (_, _) async {})));
    await tester.pumpAndSettle();

    await _tapLogo(tester, 4);

    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.byType(PasswordSignInScreen), findsNothing);
  });

  testWidgets('连点 logo 5 次进入密码登录页并记录登录方式', (tester) async {
    final analytics = _MockAnalyticsService();
    when(() => analytics.track(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      _app(_router(onSignIn: (_, _) async {}), analytics: analytics),
    );
    await tester.pumpAndSettle();

    await _tapLogo(tester, 5);

    expect(find.byType(PasswordSignInScreen), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    verify(
      () => analytics.track(Events.loginMethodSelected, {
        EventParams.method: 'password',
      }),
    ).called(1);
  });

  testWidgets('密码登录页校验邮箱和密码格式', (tester) async {
    await tester.pumpWidget(_app(_router(onSignIn: (_, _) async {})));
    await tester.pumpAndSettle();
    await _tapLogo(tester, 5);

    await _tapVisible(tester, find.text('Sign In'));
    expect(find.text('Enter your email'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'reviewer@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      '123',
    );
    await _tapVisible(tester, find.text('Sign In'));
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('密码登录成功后跨过认证页返回登录前页面', (tester) async {
    String? submittedEmail;
    String? submittedPassword;
    final router = _router(
      initialLocation: AppRoutes.study,
      onSignIn: (email, password) async {
        submittedEmail = email;
        submittedPassword = password;
      },
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    router.push(AppRoutes.login);
    await tester.pumpAndSettle();
    await _tapLogo(tester, 5);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'reviewer@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret123',
    );
    await _tapVisible(tester, find.text('Sign In'));

    expect(submittedEmail, 'reviewer@example.com');
    expect(submittedPassword, 'secret123');
    expect(find.text('Source Page'), findsOneWidget);
  });

  testWidgets('密码登录失败时停留在密码页并提示本地化错误', (tester) async {
    final router = _router(
      onSignIn: (_, _) async {
        throw const AuthException('Invalid login credentials');
      },
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await _tapLogo(tester, 5);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'reviewer@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrongpass',
    );
    await _tapVisible(tester, find.text('Sign In'));

    expect(find.byType(PasswordSignInScreen), findsOneWidget);
    expect(find.text('Invalid login credentials'), findsOneWidget);
    expect(find.text('Source Page'), findsNothing);
  });
}
