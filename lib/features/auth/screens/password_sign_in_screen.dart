import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../auth_form_utils.dart';
import '../providers/auth_providers.dart';

/// 邮箱+密码登录页（App Store / Google Play 审核员专用隐藏入口）。
///
/// 仅做登录，不提供注册 / 找回密码；审核账号在 Supabase 后台手动预创建。
/// 由登录主页连续点击 logo 5 次进入，普通用户不可见。
typedef PasswordSignInAction =
    Future<void> Function(String email, String password);

class PasswordSignInScreen extends ConsumerStatefulWidget {
  const PasswordSignInScreen({super.key, this.onSignIn});

  /// 登录动作注入点，便于测试；为 null 时走统一 [AuthController]。
  final PasswordSignInAction? onSignIn;

  @override
  ConsumerState<PasswordSignInScreen> createState() =>
      _PasswordSignInScreenState();
}

class _PasswordSignInScreenState extends ConsumerState<PasswordSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isSigningIn = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String get _trimmedEmail => _emailController.text.trim();

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context)!;
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate() || _isSigningIn) return;

    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final action = widget.onSignIn;
      if (action != null) {
        await action(_trimmedEmail, _passwordController.text);
      } else {
        await ref
            .read(authControllerProvider)
            .signInWithPassword(
              email: _trimmedEmail,
              password: _passwordController.text,
            );
      }

      if (!mounted) return;
      _finishAuthAttempt(AuthAttemptResult.success);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = mapAuthExceptionMessage(l10n, error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = l10n.authUnknownError);
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _openPolicy(String path) async {
    await launchUrl(Uri.parse('https://www.echo-loop.top$path'));
  }

  void _dismissKeyboardOnTapOutside(PointerDownEvent event) {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// 密码登录是最终尝试，成功后把结果交回主登录页。
  void _finishAuthAttempt(AuthAttemptResult result) {
    if (context.canPop()) {
      context.pop(result);
      return;
    }
    context.go(AppRoutes.settings);
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.pushReplacement(AppRoutes.login);
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
      onBack: _handleBack,
      topGap: 16,
      headerGap: 24,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                decoration: buildAuthInputDecoration(
                  labelText: l10n.authEmailLabel,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !_isSigningIn,
                onTapOutside: _dismissKeyboardOnTapOutside,
                onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return l10n.authEmailRequired;
                  if (!isValidEmail(email)) return l10n.authEmailInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                decoration: buildAuthInputDecoration(
                  labelText: l10n.authPasswordLabel,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !_isSigningIn,
                onTapOutside: _dismissKeyboardOnTapOutside,
                onFieldSubmitted: (_) => _signIn(),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) return l10n.authPasswordRequired;
                  if (password.length < 6) return l10n.authPasswordTooShort;
                  return null;
                },
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _isSigningIn ? null : _signIn,
                child: _isSigningIn
                    ? _ButtonProgress(label: l10n.authSigningIn)
                    : Text(l10n.authSignInButton),
              ),
              const SizedBox(height: 12),
              buildAuthErrorText(context, _errorMessage),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
