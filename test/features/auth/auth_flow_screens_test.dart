import 'package:echo_loop/features/auth/screens/email_sign_in_screen.dart';
import 'package:echo_loop/features/auth/screens/login_screen.dart';
import 'package:echo_loop/features/auth/screens/account_screen.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget _app(GoRouter router) {
  return ProviderScope(
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

GoRouter _authRouter({
  Future<void> Function(String email)? onSendOtp,
  Future<void> Function(String email, String token)? onVerifyOtp,
  Future<void> Function(String email)? onResendOtp,
  Future<void> Function()? onAppleSignIn,
  Future<void> Function()? onGoogleSignIn,
  bool isAppleSignInSupported = true,
  bool isGoogleSignInSupported = false,
  String initialLocation = AppRoutes.login,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginScreen(
          onAppleSignIn: onAppleSignIn,
          onGoogleSignIn: onGoogleSignIn,
          isAppleSignInSupportedOverride: isAppleSignInSupported,
          isGoogleSignInSupportedOverride: isGoogleSignInSupported,
        ),
      ),
      GoRoute(
        path: AppRoutes.emailSignIn,
        builder: (context, state) {
          final extra = state.extra;
          final email = extra is String ? extra : '';
          return EmailSignInScreen(
            initialEmail: email,
            onSendOtp: onSendOtp,
            onVerifyOtp: onVerifyOtp,
            onResendOtp: onResendOtp,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.checkEmail,
        builder: (context, state) {
          final extra = state.extra;
          final email = extra is String ? extra : '';
          return EmailSignInScreen(
            initialEmail: email,
            startInOtpStep: true,
            onSendOtp: onSendOtp,
            onVerifyOtp: onVerifyOtp,
            onResendOtp: onResendOtp,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.account,
        builder: (context, state) => const Scaffold(body: Text('Account')),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const Scaffold(body: Text('Settings')),
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

Finder _otpField() {
  return find.widgetWithText(TextFormField, '6-digit code');
}

void main() {
  testWidgets('登录入口默认只显示登录方式，不显示邮箱表单', (tester) async {
    await tester.pumpWidget(_app(_authRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Echo Loop'), findsOneWidget);
    expect(
      find.text('No password needed. We will email you a one-time code.'),
      findsNothing,
    );
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with Email Code'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('Android 平台只显示 Google 和邮箱登录入口', (tester) async {
    await tester.pumpWidget(
      _app(
        _authRouter(
          isAppleSignInSupported: false,
          isGoogleSignInSupported: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Email Code'), findsOneWidget);
  });

  testWidgets('Apple 平台只显示 Apple 和邮箱登录入口', (tester) async {
    await tester.pumpWidget(
      _app(
        _authRouter(
          isAppleSignInSupported: true,
          isGoogleSignInSupported: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with Email Code'), findsOneWidget);
  });

  testWidgets('点击 Apple 登录会调用统一登录动作并进入设置页', (tester) async {
    var signInCalled = false;
    final router = _authRouter(
      onAppleSignIn: () async {
        signInCalled = true;
      },
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();

    expect(signInCalled, isTrue);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('点击 Google 登录会调用统一登录动作并进入设置页', (tester) async {
    var signInCalled = false;
    final router = _authRouter(
      isAppleSignInSupported: false,
      isGoogleSignInSupported: true,
      onGoogleSignIn: () async {
        signInCalled = true;
      },
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(signInCalled, isTrue);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Google 登录不可用异常会提示改用邮箱验证码', (tester) async {
    final router = _authRouter(
      isAppleSignInSupported: false,
      isGoogleSignInSupported: true,
      onGoogleSignIn: () async {
        throw const AuthException('Google identity token is missing.');
      },
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Google sign-in is unavailable on this device. Use an email code instead.',
      ),
      findsOneWidget,
    );
    expect(find.text('Google identity token is missing.'), findsNothing);
  });

  testWidgets('Google 服务版本过低时显示明确设备文案', (tester) async {
    final router = _authRouter(
      isAppleSignInSupported: false,
      isGoogleSignInSupported: true,
      onGoogleSignIn: () async {
        throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.providerConfigurationError,
          description:
              'getCredentialAsync no provider dependencies found - please '
              'ensure the desired provider dependencies are added',
        );
      },
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Google services are outdated. Please update and try again.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Google sign-in is unavailable on this device. Use an email code instead.',
      ),
      findsNothing,
    );
  });

  testWidgets('用户取消 Google 登录不显示错误提示', (tester) async {
    final router = _authRouter(
      isAppleSignInSupported: false,
      isGoogleSignInSupported: true,
      onGoogleSignIn: () async {
        throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        );
      },
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('Apple 登录异常会映射为用户文案', (tester) async {
    final router = _authRouter(
      onAppleSignIn: () async {
        throw AuthException('Supabase auth is not configured.');
      },
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();

    expect(find.text('Authentication is not configured yet.'), findsOneWidget);
    expect(find.text('Supabase auth is not configured.'), findsNothing);
  });

  testWidgets('点击邮箱后进入单邮箱 OTP 页面', (tester) async {
    await tester.pumpWidget(_app(_authRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Email Code'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter your email and we will send a one-time code.'),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Send Code'), findsOneWidget);
  });

  testWidgets('邮箱 OTP 页面进入后自动聚焦邮箱输入框并打开输入法', (tester) async {
    await tester.pumpWidget(_app(_authRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Email Code'));
    await tester.pumpAndSettle();

    final emailField = find.byType(TextFormField);
    final emailEditableText = tester.widget<EditableText>(
      find.descendant(of: emailField, matching: find.byType(EditableText)),
    );

    expect(emailEditableText.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('邮箱 OTP 页面保留品牌 logo 和协议文案', (tester) async {
    await tester.pumpWidget(_app(_authRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Email Code'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Echo Loop'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('邮箱 OTP 页面会校验输入并提交有效邮箱', (tester) async {
    String? submittedEmail;
    final router = _authRouter(
      onSendOtp: (email) async {
        submittedEmail = email;
      },
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Email Code'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Send Code'));
    expect(find.text('Enter your email'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'bad-email');
    await _tapVisible(tester, find.text('Send Code'));
    expect(find.text('Enter a valid email'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await _tapVisible(tester, find.text('Send Code'));

    expect(submittedEmail, 'user@example.com');
    expect(find.text('Check your email'), findsOneWidget);
    expect(
      find.text('We sent a 6-digit code to user@example.com.'),
      findsOneWidget,
    );
    expect(find.text('60s until resend'), findsOneWidget);
  });

  testWidgets('邮箱 OTP 页面点击输入框外部会释放邮箱输入焦点', (tester) async {
    await tester.pumpWidget(_app(_authRouter()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Email Code'));
    await tester.pumpAndSettle();

    final emailField = find.byType(TextFormField);
    await tester.showKeyboard(emailField);
    await tester.pump();

    final emailEditableText = tester.widget<EditableText>(
      find.descendant(of: emailField, matching: find.byType(EditableText)),
    );
    expect(emailEditableText.focusNode.hasFocus, isTrue);

    await tester.tap(
      find.text('Enter your email and we will send a one-time code.'),
    );
    await tester.pumpAndSettle();

    expect(emailEditableText.focusNode.hasFocus, isFalse);
  });

  testWidgets('邮箱 OTP 页面会把未配置认证的底层异常映射为用户文案', (tester) async {
    final router = _authRouter(
      onSendOtp: (_) async {
        throw AuthException('Supabase auth is not configured.');
      },
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Email Code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await _tapVisible(tester, find.text('Send Code'));

    expect(find.text('Authentication is not configured yet.'), findsOneWidget);
    expect(find.text('Supabase auth is not configured.'), findsNothing);
  });

  testWidgets('兼容验证码路由时显示同页 OTP 阶段和默认倒计时', (tester) async {
    final router = _authRouter(initialLocation: AppRoutes.settings);

    await tester.pumpWidget(_app(router));
    router.push(AppRoutes.checkEmail, extra: 'hello@example.com');
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(
      find.text('We sent a 6-digit code to hello@example.com.'),
      findsOneWidget,
    );
    expect(find.text('6-digit code'), findsOneWidget);
    expect(find.text('60s until resend'), findsOneWidget);
    expect(find.text('Use another email'), findsNothing);
  });

  testWidgets('验证码页校验验证码长度并提交成功后进入我的 tab', (tester) async {
    String? submittedEmail;
    String? submittedToken;
    final router = _authRouter(
      initialLocation: AppRoutes.settings,
      onVerifyOtp: (email, token) async {
        submittedEmail = email;
        submittedToken = token;
      },
    );

    await tester.pumpWidget(_app(router));
    router.push(AppRoutes.checkEmail, extra: 'user@example.com');
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Continue'));
    expect(find.text('Enter the 6-digit code'), findsOneWidget);

    await tester.enterText(_otpField(), '123');
    await _tapVisible(tester, find.text('Continue'));
    expect(find.text('Enter a valid 6-digit code'), findsOneWidget);

    await tester.enterText(_otpField(), '123456');
    await tester.pumpAndSettle();

    expect(submittedEmail, 'user@example.com');
    expect(submittedToken, '123456');
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('OTP 阶段返回直接离开认证页，避免页内退回邮箱态', (tester) async {
    final router = _authRouter(onSendOtp: (_) async {});

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Email Code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'saved@example.com');
    await _tapVisible(tester, find.text('Send Code'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Echo Loop'), findsOneWidget);
    expect(find.text('Continue with Email Code'), findsOneWidget);
  });

  testWidgets('验证码页倒计时结束后可以重新发送', (tester) async {
    String? resentEmail;
    final router = _authRouter(
      initialLocation: AppRoutes.settings,
      onResendOtp: (email) async {
        resentEmail = email;
      },
    );

    await tester.pumpWidget(_app(router));
    router.push(AppRoutes.checkEmail, extra: 'resend@example.com');
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Resend code'));

    expect(resentEmail, 'resend@example.com');
    expect(find.text('A new code has been sent.'), findsOneWidget);
  });

  testWidgets('OTP 阶段修改邮箱会清空验证码状态并回到发送态', (tester) async {
    final router = _authRouter(onSendOtp: (_) async {});

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Email Code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'first@example.com');
    await _tapVisible(tester, find.text('Send Code'));

    expect(find.text('Check your email'), findsOneWidget);
    expect(
      find.text('We sent a 6-digit code to first@example.com.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'first@example.com'),
      'second@example.com',
    );
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsNothing);
    expect(find.text('Send Code'), findsOneWidget);
    expect(find.text('60s until resend'), findsNothing);
    expect(
      find.text('We sent a 6-digit code to first@example.com.'),
      findsNothing,
    );
  });

  testWidgets('OTP 阶段不显示更换邮箱入口', (tester) async {
    final router = _authRouter(initialLocation: AppRoutes.settings);

    await tester.pumpWidget(_app(router));
    router.push(AppRoutes.checkEmail, extra: 'hello@example.com');
    await tester.pumpAndSettle();

    expect(find.text('Use another email'), findsNothing);
  });

  testWidgets('主登录页返回会回到我的 tab', (tester) async {
    final router = _authRouter(initialLocation: AppRoutes.settings);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    router.push(AppRoutes.login);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('未登录时访问 account 会立即回到设置页，不显示中间登录卡片', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.account,
      routes: [
        GoRoute(
          path: AppRoutes.account,
          builder: (context, state) => const AccountScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const Scaffold(body: Text('Settings')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseSessionProvider.overrideWith((ref) => Stream.value(null)),
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
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sign in to Echo Loop'), findsNothing);
  });

  testWidgets('账号页 Apple 登录显示 Apple 账户和完整邮箱', (tester) async {
    final user = User(
      id: 'user-1',
      appMetadata: const {
        'provider': 'apple',
        'providers': ['apple'],
      },
      userMetadata: const {},
      aud: 'authenticated',
      email: 'mbfpw8sdy7@privaterelay.appleid.com',
      createdAt: '2026-06-04T00:00:00.000Z',
    );
    final session = Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: user,
      refreshToken: 'refresh',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseSessionProvider.overrideWith((ref) => Stream.value(session)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apple account'), findsOneWidget);
    expect(find.text('mbfpw8sdy7@privaterelay.appleid.com'), findsOneWidget);
    expect(find.text('mbfpw8sd...@erelay.appleid.com'), findsNothing);
  });

  testWidgets('账号页 Google 登录显示 Google 账户和完整邮箱', (tester) async {
    final user = User(
      id: 'user-1',
      appMetadata: const {
        'provider': 'google',
        'providers': ['google'],
      },
      userMetadata: const {},
      aud: 'authenticated',
      email: 'long.google.account@example.com',
      createdAt: '2026-06-04T00:00:00.000Z',
    );
    final session = Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: user,
      refreshToken: 'refresh',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseSessionProvider.overrideWith((ref) => Stream.value(session)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Google account'), findsOneWidget);
    expect(find.text('long.google.account@example.com'), findsOneWidget);
  });

  test('账号显示登录方式优先使用 Supabase identities provider', () {
    final user = User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: 'user@example.com',
      createdAt: '2026-06-04T00:00:00.000Z',
      identities: const [
        UserIdentity(
          id: 'identity-1',
          userId: 'user-1',
          identityData: {},
          identityId: 'identity-1',
          provider: 'google',
          createdAt: '2026-06-04T00:00:00.000Z',
          lastSignInAt: '2026-06-04T00:00:00.000Z',
        ),
      ],
    );

    expect(authDisplayProviderForUser(user), AuthDisplayProvider.google);
  });

  testWidgets('可见登录方式图标左侧对齐且尺寸一致', (tester) async {
    await tester.pumpWidget(_app(_authRouter()));
    await tester.pumpAndSettle();

    final appleIcon = find.byIcon(Icons.apple);
    final emailIcon = find.byIcon(Icons.mail_outline_rounded);

    expect(appleIcon, findsOneWidget);
    expect(emailIcon, findsOneWidget);

    final appleRect = tester.getRect(appleIcon);
    final emailRect = tester.getRect(emailIcon);

    expect(appleRect.left, emailRect.left);
    expect(appleRect.width, 22);
    expect(emailRect.width, 22);
    expect(appleRect.height, 22);
    expect(emailRect.height, 22);
  });
}
