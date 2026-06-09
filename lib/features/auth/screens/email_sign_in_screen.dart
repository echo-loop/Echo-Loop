import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../auth_form_utils.dart';
import '../providers/auth_providers.dart';

typedef EmailAction = Future<void> Function(String email);
typedef VerifyOtpAction = Future<void> Function(String email, String token);
typedef ResendOtpAction = Future<void> Function(String email);

enum _EmailOtpStep { emailEntry, otpEntry }

class EmailSignInScreen extends ConsumerStatefulWidget {
  const EmailSignInScreen({
    super.key,
    this.onSendOtp,
    this.onVerifyOtp,
    this.onResendOtp,
    this.initialEmail = '',
    this.startInOtpStep = false,
  });

  final EmailAction? onSendOtp;
  final VerifyOtpAction? onVerifyOtp;
  final ResendOtpAction? onResendOtp;
  final String initialEmail;
  final bool startInOtpStep;

  @override
  ConsumerState<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends ConsumerState<EmailSignInScreen> {
  static const int _resendCooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _tokenController;
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _tokenFocusNode = FocusNode();

  Timer? _resendTimer;
  late _EmailOtpStep _step;
  String? _otpRequestedEmail;
  int _secondsRemaining = 0;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isResendingOtp = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _tokenController = TextEditingController();
    _step = widget.startInOtpStep && widget.initialEmail.isNotEmpty
        ? _EmailOtpStep.otpEntry
        : _EmailOtpStep.emailEntry;
    if (_step == _EmailOtpStep.otpEntry) {
      _otpRequestedEmail = widget.initialEmail.trim();
      _startCooldown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _tokenFocusNode.requestFocus();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _emailFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _tokenController.dispose();
    _emailFocusNode.dispose();
    _tokenFocusNode.dispose();
    super.dispose();
  }

  /// 认证页只维护一份本地倒计时，避免发送与验证状态在不同页面分裂。
  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsRemaining <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining -= 1);
    });
  }

  bool get _isBusy => _isSendingOtp || _isVerifyingOtp || _isResendingOtp;

  String get _trimmedEmail => _emailController.text.trim();

  /// 用户修改邮箱后，旧验证码和倒计时立即失效，回到当前页的发送态。
  void _resetOtpStateForEditedEmail() {
    _resendTimer?.cancel();
    setState(() {
      _step = _EmailOtpStep.emailEntry;
      _otpRequestedEmail = null;
      _secondsRemaining = 0;
      _tokenController.clear();
      _errorMessage = null;
      _isVerifyingOtp = false;
      _isResendingOtp = false;
    });
  }

  Future<void> _sendOtp() async {
    final l10n = AppLocalizations.of(context)!;
    final formState = _formKey.currentState;
    if (formState == null ||
        !formState.validate() ||
        _isSendingOtp ||
        _isVerifyingOtp ||
        _isResendingOtp) {
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    try {
      final action = widget.onSendOtp;
      if (action != null) {
        await action(_trimmedEmail);
      } else {
        await ref.read(authControllerProvider).requestEmailOtp(_trimmedEmail);
      }

      if (!mounted) return;
      setState(() {
        _step = _EmailOtpStep.otpEntry;
        _otpRequestedEmail = _trimmedEmail;
        _tokenController.clear();
      });
      _startCooldown();
      _tokenFocusNode.requestFocus();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = mapAuthExceptionMessage(l10n, error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = l10n.authUnknownError);
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final l10n = AppLocalizations.of(context)!;
    final formState = _formKey.currentState;
    if (formState == null ||
        !formState.validate() ||
        _isSendingOtp ||
        _isVerifyingOtp ||
        _isResendingOtp) {
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });

    try {
      final action = widget.onVerifyOtp;
      if (action != null) {
        await action(_trimmedEmail, _tokenController.text.trim());
      } else {
        await ref
            .read(authControllerProvider)
            .verifyEmailOtp(
              email: _trimmedEmail,
              token: _tokenController.text.trim(),
            );
      }

      if (!mounted) return;
      _finishAuthAttempt(AuthAttemptResult.success);
    } on AuthException catch (error) {
      if (!mounted) return;
      _showVerificationError(mapAuthExceptionMessage(l10n, error));
    } catch (_) {
      if (!mounted) return;
      _showVerificationError(l10n.authUnknownError);
    } finally {
      if (mounted) {
        setState(() => _isVerifyingOtp = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _isBusy) return;

    setState(() {
      _isResendingOtp = true;
      _errorMessage = null;
    });

    try {
      final action = widget.onResendOtp;
      if (action != null) {
        await action(_trimmedEmail);
      } else {
        await ref.read(authControllerProvider).requestEmailOtp(_trimmedEmail);
      }
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.authOtpResent)),
        );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = mapAuthExceptionMessage(
          AppLocalizations.of(context)!,
          error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = AppLocalizations.of(context)!.authUnknownError,
      );
    } finally {
      if (mounted) {
        setState(() => _isResendingOtp = false);
      }
    }
  }

  Future<void> _openPolicy(String path) async {
    await launchUrl(Uri.parse('https://www.echo-loop.top$path'));
  }

  /// 点击输入框外部时释放焦点，避免软键盘遮挡后续主操作按钮。
  void _dismissKeyboardOnTapOutside(PointerDownEvent event) {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _showVerificationError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// OTP 校验是邮箱登录的最终尝试，结束后把结果交回主登录页。
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
                textInputAction: _step == _EmailOtpStep.emailEntry
                    ? TextInputAction.go
                    : TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !_isBusy,
                onTapOutside: _dismissKeyboardOnTapOutside,
                onChanged: (value) {
                  if (_step == _EmailOtpStep.otpEntry &&
                      value.trim() != (_otpRequestedEmail ?? '')) {
                    _resetOtpStateForEditedEmail();
                  }
                },
                onFieldSubmitted: (_) {
                  if (_step == _EmailOtpStep.emailEntry) {
                    _sendOtp();
                  }
                },
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return l10n.authEmailRequired;
                  if (!isValidEmail(email)) return l10n.authEmailInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _step == _EmailOtpStep.emailEntry
                    ? _EmailIntroBlock(
                        key: const ValueKey('email-intro'),
                        description: l10n.authEmailOtpDescription,
                        autoCreateHint: l10n.authEmailOtpAutoCreateHint,
                        onSend: _isSendingOtp ? null : _sendOtp,
                        buttonChild: _isSendingOtp
                            ? _ButtonProgress(label: l10n.authSendingOtp)
                            : Text(l10n.authSendOtpButton),
                      )
                    : _OtpEntryBlock(
                        key: const ValueKey('otp-entry'),
                        emailSummary: _trimmedEmail,
                        otpField: TextFormField(
                          controller: _tokenController,
                          focusNode: _tokenFocusNode,
                          decoration: buildAuthInputDecoration(
                            labelText: l10n.authOtpLabel,
                          ),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          enabled: !_isBusy,
                          maxLength: 6,
                          onTapOutside: _dismissKeyboardOnTapOutside,
                          onChanged: (value) {
                            if (value.trim().length == 6 && !_isBusy) {
                              _verifyOtp();
                            }
                          },
                          onFieldSubmitted: (_) => _verifyOtp(),
                          validator: (value) {
                            if (_step != _EmailOtpStep.otpEntry) return null;
                            final token = value?.trim() ?? '';
                            if (token.isEmpty) return l10n.authOtpRequired;
                            if (token.length != 6) return l10n.authOtpInvalid;
                            return null;
                          },
                        ),
                        helpText: l10n.authOtpHelpText,
                        resendLabel: _secondsRemaining > 0
                            ? l10n.authResendOtpCountdown(_secondsRemaining)
                            : l10n.authResendOtpButton,
                        onResend: (_secondsRemaining > 0 || _isResendingOtp)
                            ? null
                            : _resendOtp,
                        onVerify: _isVerifyingOtp ? null : _verifyOtp,
                        verifyChild: _isVerifyingOtp
                            ? _ButtonProgress(label: l10n.authVerifyingOtp)
                            : Text(l10n.authVerifyOtpButton),
                      ),
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

class _EmailIntroBlock extends StatelessWidget {
  const _EmailIntroBlock({
    super.key,
    required this.description,
    required this.autoCreateHint,
    required this.onSend,
    required this.buttonChild,
  });

  final String description;
  final String autoCreateHint;
  final VoidCallback? onSend;
  final Widget buttonChild;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          autoCreateHint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(onPressed: onSend, child: buttonChild),
      ],
    );
  }
}

class _OtpEntryBlock extends StatelessWidget {
  const _OtpEntryBlock({
    super.key,
    required this.emailSummary,
    required this.otpField,
    required this.helpText,
    required this.resendLabel,
    required this.onResend,
    required this.onVerify,
    required this.verifyChild,
  });

  final String emailSummary;
  final Widget otpField;
  final String helpText;
  final String resendLabel;
  final VoidCallback? onResend;
  final VoidCallback? onVerify;
  final Widget verifyChild;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mark_email_read_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.authCheckEmailTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.authCheckEmailMessage(emailSummary),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        otpField,
        Text(
          helpText,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: onVerify, child: verifyChild),
        const SizedBox(height: 10),
        TextButton(onPressed: onResend, child: Text(resendLabel)),
      ],
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
        const SizedBox(width: AppSpacing.s),
        Text(label),
      ],
    );
  }
}
