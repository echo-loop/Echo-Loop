import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../analytics/models/event_names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../services/app_logger.dart';
import '../../../theme/app_theme.dart';
import '../auth_form_utils.dart';
import '../google_services_availability.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.onAppleSignIn,
    this.onGoogleSignIn,
    this.isAppleSignInSupportedOverride,
    this.isGoogleSignInSupportedOverride,
  });

  final Future<void> Function()? onAppleSignIn;
  final Future<void> Function()? onGoogleSignIn;
  final bool? isAppleSignInSupportedOverride;
  final bool? isGoogleSignInSupportedOverride;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// 连续点击 logo 进入隐藏密码登录入口所需次数（App Store / Google Play 审核用）。
  static const int _passwordEntryTapTarget = 5;

  bool _isBusy = false;
  bool? _isAppleSignInAvailable;
  bool? _isGoogleSignInAvailable;
  int _logoTapCount = 0;

  bool get _isApplePlatformSupported {
    final override = widget.isAppleSignInSupportedOverride;
    if (override != null) return override;
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
  }

  bool get _isAppleSignInSupported => _isAppleSignInAvailable ?? false;

  bool get _isGoogleSignInSupported {
    final override = widget.isGoogleSignInSupportedOverride;
    if (override != null) return override;
    return _isGoogleSignInAvailable ?? false;
  }

  @override
  void initState() {
    super.initState();
    _resolveAppleSignInAvailability();
    _resolveGoogleSignInAvailability();
  }

  @override
  void didUpdateWidget(LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAppleSignInSupportedOverride !=
        widget.isAppleSignInSupportedOverride) {
      _resolveAppleSignInAvailability();
    }
    if (oldWidget.isGoogleSignInSupportedOverride !=
        widget.isGoogleSignInSupportedOverride) {
      _resolveGoogleSignInAvailability();
    }
  }

  /// 先按平台做快速过滤，再调用插件确认 native Sign in with Apple 实际可用。
  ///
  /// 这样不会在缺少系统能力或插件返回不可用时暴露一个只能失败的入口。
  Future<void> _resolveAppleSignInAvailability() async {
    final override = widget.isAppleSignInSupportedOverride;
    if (override != null) {
      setState(() => _isAppleSignInAvailable = override);
      return;
    }

    if (!_isApplePlatformSupported) {
      setState(() => _isAppleSignInAvailable = false);
      return;
    }

    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!mounted) return;
      setState(() => _isAppleSignInAvailable = isAvailable);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAppleSignInAvailable = false);
    }
  }

  /// 只有 Android 且 Google Play services 可用时才显示 Google 登录入口。
  ///
  /// 中国区 Android / 华为等无 GMS 设备会在这里被过滤，只保留邮箱 OTP
  /// 兜底，避免用户看到一个必然失败的入口。
  Future<void> _resolveGoogleSignInAvailability() async {
    final override = widget.isGoogleSignInSupportedOverride;
    if (override != null) {
      AppLogger.log('AuthGMS', 'login override availability=$override');
      setState(() => _isGoogleSignInAvailable = override);
      return;
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      AppLogger.log(
        'AuthGMS',
        'login availability skipped platform=$defaultTargetPlatform web=$kIsWeb',
      );
      setState(() => _isGoogleSignInAvailable = false);
      return;
    }

    final isAvailable = await const MethodChannelGoogleServicesAvailability()
        .isAvailable();
    if (!mounted) return;
    AppLogger.log('AuthGMS', 'login showGoogle=$isAvailable');
    setState(() => _isGoogleSignInAvailable = isAvailable);
  }

  String _authErrorMessage(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context)!;
    if (error is AuthException &&
        error.message == 'Supabase auth is not configured.') {
      return l10n.authUnavailable;
    }
    if (_isGooglePlayServicesOutdated(error)) {
      return l10n.authGoogleServicesOutdated;
    }
    if (_isGoogleSignInUnavailable(error)) {
      return l10n.authGoogleUnavailable;
    }
    return l10n.authUnknownError;
  }

  bool _isCanceledAppleSignIn(Object error) {
    return error is SignInWithAppleAuthorizationException &&
        error.code == AuthorizationErrorCode.canceled;
  }

  bool _isCanceledGoogleSignIn(Object error) {
    return error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled;
  }

  /// 识别 Google Play services 版本过低导致的 native Google 登录失败。
  ///
  /// 华为/出境易等环境可能能检测到 GMS 存在，但点击登录时才由
  /// Credential Manager 暴露 provider 依赖不可用错误；这里将该类错误
  /// 映射为明确的设备服务版本文案，而不是泛化成配置问题。
  bool _isGooglePlayServicesOutdated(Object error) {
    if (error is! GoogleSignInException) return false;

    final description = error.description?.toLowerCase() ?? '';
    return error.code == GoogleSignInExceptionCode.providerConfigurationError &&
        (description.contains('service_version_update_required') ||
            description.contains('out of date') ||
            description.contains('no provider dependencies found'));
  }

  bool _isGoogleSignInUnavailable(Object error) {
    if (error is AuthException) {
      return error.message == 'Google OAuth client is not configured.' ||
          error.message == 'Google identity token is missing.' ||
          error.message == 'Google access token is missing.';
    }
    if (error is GoogleSignInException) {
      return error.code ==
              GoogleSignInExceptionCode.providerConfigurationError ||
          error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.uiUnavailable;
    }
    return false;
  }

  Future<void> _signInWithApple() async {
    if (_isBusy) return;

    _trackLoginMethod('apple');
    setState(() => _isBusy = true);
    try {
      final action = widget.onAppleSignIn;
      if (action != null) {
        await action();
      } else {
        await ref.read(authControllerProvider).signInWithApple();
      }

      if (!mounted) return;
      _finishAuthAttempt(AuthAttemptResult.success);
    } catch (error) {
      if (!mounted) return;
      if (_isCanceledAppleSignIn(error)) {
        _finishAuthAttempt(AuthAttemptResult.canceled);
        return;
      }
      _showAuthError(error);
      _finishAuthAttempt(AuthAttemptResult.failure);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isBusy) return;

    _trackLoginMethod('google');
    setState(() => _isBusy = true);
    try {
      final action = widget.onGoogleSignIn;
      if (action != null) {
        await action();
      } else {
        await ref.read(authControllerProvider).signInWithGoogle();
      }

      if (!mounted) return;
      _finishAuthAttempt(AuthAttemptResult.success);
    } catch (error) {
      if (!mounted) return;
      if (_isCanceledGoogleSignIn(error)) {
        AppLogger.log('AuthGoogle', 'login canceled by user');
        _finishAuthAttempt(AuthAttemptResult.failure);
        return;
      }
      AppLogger.log('AuthGoogle', 'login failed error=$error');
      _showAuthError(error);
      _finishAuthAttempt(AuthAttemptResult.failure);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _openPolicy(String path) async {
    await launchUrl(Uri.parse('https://www.echo-loop.top$path'));
  }

  void _showAuthError(Object error) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(_authErrorMessage(context, error))),
      );
  }

  /// 登录成功或用户取消时结束认证流程；失败时留在主登录页，方便改选其它方式。
  ///
  /// 独立深链进入登录页时没有可回退页面，继续使用“我的”页作为兜底。
  void _finishAuthAttempt(AuthAttemptResult result) {
    if (result == AuthAttemptResult.failure) {
      return;
    }
    if (context.canPop()) {
      context.pop(result);
      return;
    }
    context.go(AppRoutes.settings);
  }

  /// 连续点击品牌 logo 满 [_passwordEntryTapTarget] 次后进入隐藏的密码登录页。
  ///
  /// 该入口仅供 App Store / Google Play 审核员使用，普通用户不可见。
  Future<void> _handleLogoTap() async {
    _logoTapCount += 1;
    if (_logoTapCount < _passwordEntryTapTarget) return;
    _logoTapCount = 0;
    _trackLoginMethod('password');
    final result = await context.push<AuthAttemptResult>(
      AppRoutes.passwordSignIn,
    );
    if (!mounted || result == null) return;
    _finishAuthAttempt(result);
  }

  Future<void> _openEmailSignIn() async {
    _trackLoginMethod('email');
    final result = await context.push<AuthAttemptResult>(AppRoutes.emailSignIn);
    if (!mounted || result == null) return;
    _finishAuthAttempt(result);
  }

  /// 仅记录用户选择的认证入口，不采集认证结果或表单操作。
  void _trackLoginMethod(String method) {
    ref.read(analyticsServiceProvider).track(Events.loginMethodSelected, {
      EventParams.method: method,
    });
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: l10n.authSignInTitle,
      showPolicyNotice: true,
      onTermsTap: () => _openPolicy('/terms'),
      onPrivacyTap: () => _openPolicy('/privacy'),
      onBack: () => _goBack(context),
      onLogoTap: _handleLogoTap,
      topGap: 44,
      headerGap: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isAppleSignInSupported) ...[
            _AuthMethodButton(
              icon: _isBusy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurface,
                      ),
                    )
                  : Icon(Icons.apple, size: 22, color: colorScheme.onSurface),
              label: l10n.authContinueWithApple,
              onPressed: _isBusy ? null : _signInWithApple,
            ),
            const SizedBox(height: AppSpacing.m),
          ],
          if (_isGoogleSignInSupported) ...[
            _AuthMethodButton(
              icon: _isBusy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurface,
                      ),
                    )
                  : FaIcon(
                      FontAwesomeIcons.google,
                      size: 22,
                      color: colorScheme.onSurface,
                    ),
              label: l10n.authContinueWithGoogle,
              onPressed: _isBusy ? null : _signInWithGoogle,
            ),
            const SizedBox(height: AppSpacing.m),
          ],
          _AuthMethodButton(
            icon: Icon(
              Icons.mail_outline_rounded,
              size: 22,
              color: colorScheme.onSurface,
            ),
            label: l10n.authContinueWithEmail,
            onPressed: _isBusy ? null : _openEmailSignIn,
          ),
        ],
      ),
    );
  }
}

class _AuthMethodButton extends StatelessWidget {
  const _AuthMethodButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.center,
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outlineVariant),
        backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
        minimumSize: const Size.fromHeight(58),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: SizedBox()),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: 24, child: Center(child: icon)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
