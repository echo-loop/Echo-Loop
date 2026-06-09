import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 一次实际登录尝试的结束状态。
///
/// 邮箱验证码页通过该结果通知主登录页。成功和取消会结束认证流程；失败
/// 会停留在主登录页，方便用户改选其它登录方式。
enum AuthAttemptResult { success, failure, canceled }

/// 邮箱格式轻量校验。
///
/// 这里只做客户端即时反馈，最终结果仍以 Supabase Auth 返回为准。
bool isValidEmail(String value) {
  final trimmed = value.trim();
  final at = trimmed.indexOf('@');
  final dot = trimmed.lastIndexOf('.');
  return at > 0 && dot > at + 1 && dot < trimmed.length - 1;
}

/// 认证表单的最大宽度，避免桌面端输入框横向拉满。
const authFormMaxWidth = 420.0;

/// 认证页面共享品牌图标尺寸。
const authBrandLogoSize = 72.0;

/// 认证输入框统一装饰，确保带/不带尾部图标时高度一致。
InputDecoration buildAuthInputDecoration({
  required String labelText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  );
}

/// 创建稳定的表单错误区域，避免错误出现时页面大幅跳动。
Widget buildAuthErrorText(BuildContext context, String? message) {
  final colorScheme = Theme.of(context).colorScheme;
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 160),
    child: message == null
        ? const SizedBox(key: ValueKey('empty-error'), height: 20)
        : Semantics(
            key: const ValueKey('error-message'),
            liveRegion: true,
            child: Text(
              message,
              style: TextStyle(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
  );
}

/// 将底层认证异常映射为面向用户的稳定文案。
///
/// 优先拦截明显的配置类错误，避免把 SDK/后端英文错误直接暴露到 UI。
String mapAuthExceptionMessage(AppLocalizations l10n, AuthException error) {
  final normalized = error.message.toLowerCase();
  if (normalized.contains('not configured')) {
    return l10n.authUnavailable;
  }
  if (_isOtpVerificationError(normalized)) {
    return l10n.authOtpIncorrectOrExpired;
  }
  return error.message;
}

/// 识别 Supabase 邮箱 OTP 校验失败，避免把后端英文错误暴露给用户。
bool _isOtpVerificationError(String normalizedMessage) {
  return normalizedMessage.contains('invalid verification code') ||
      normalizedMessage.contains('invalid otp') ||
      normalizedMessage.contains('token has expired') ||
      normalizedMessage.contains('otp expired') ||
      normalizedMessage.contains('expired token');
}

/// 认证流程共享页面骨架。
///
/// 统一 logo、标题和滚动容器，避免不同认证子页面出现布局漂移。
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showPolicyNotice = false,
    this.onTermsTap,
    this.onPrivacyTap,
    this.onBack,
    this.topGap,
    this.headerGap,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showPolicyNotice;
  final VoidCallback? onTermsTap;
  final VoidCallback? onPrivacyTap;
  final VoidCallback? onBack;
  final double? topGap;
  final double? headerGap;

  @override
  Widget build(BuildContext context) {
    final shouldShowPolicyNotice =
        showPolicyNotice && onTermsTap != null && onPrivacyTap != null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
      ),
      bottomNavigationBar: shouldShowPolicyNotice
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  AppSpacing.l,
                ),
                child: AuthPolicyNotice(
                  onTermsTap: onTermsTap!,
                  onPrivacyTap: onPrivacyTap!,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight;
            final resolvedTopGap =
                topGap ??
                (viewportHeight >= 820
                    ? 28.0
                    : viewportHeight >= 700
                    ? 24.0
                    : 16.0);
            final resolvedHeaderGap =
                headerGap ??
                (viewportHeight >= 820
                    ? 40.0
                    : viewportHeight >= 700
                    ? 32.0
                    : 24.0);
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.m,
                AppSpacing.l,
                AppSpacing.l,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: authFormMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: resolvedTopGap),
                        AuthBrandHeader(title: title, subtitle: subtitle),
                        SizedBox(height: resolvedHeaderGap),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 认证页面顶部品牌区。
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Image.asset(
          'assets/icon/app-icon-1024.png',
          width: authBrandLogoSize,
          height: authBrandLogoSize,
          semanticLabel: 'Echo Loop',
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.graphic_eq_rounded,
            size: 48,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.s),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// 认证流程页底部协议提示。
class AuthPolicyNotice extends StatelessWidget {
  const AuthPolicyNotice({
    super.key,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall;

    return DefaultTextStyle(
      style: (textStyle ?? const TextStyle()).copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        children: [
          Text('${l10n.authTermsContinuationPrefix} '),
          InkWell(
            onTap: onTermsTap,
            child: Text(
              l10n.authTermsOfService,
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
          Text(l10n.authTermsJoiner),
          InkWell(
            onTap: onPrivacyTap,
            child: Text(
              l10n.authPrivacyPolicy,
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 注册前的显式协议确认。
///
/// 登录页只展示“继续即表示同意”的提示，创建账号时才要求用户主动勾选。
class PolicyConsentRow extends StatelessWidget {
  const PolicyConsentRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  void _toggle() {
    onChanged?.call(!value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Expanded(
          child: DefaultTextStyle(
            style: textStyle ?? const TextStyle(),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: onChanged == null ? null : _toggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${l10n.authTermsAgreementPrefix} '),
                  ),
                ),
                InkWell(
                  onTap: onTermsTap,
                  child: Text(
                    l10n.authTermsOfService,
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
                InkWell(
                  onTap: onChanged == null ? null : _toggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(l10n.authTermsJoiner),
                  ),
                ),
                InkWell(
                  onTap: onPrivacyTap,
                  child: Text(
                    l10n.authPrivacyPolicy,
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
