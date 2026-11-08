import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/common/text_context_menu.dart';
import '../../profile/widgets/profile_edit_section.dart';
import '../providers/auth_providers.dart';

enum AuthDisplayProvider { apple, google, email, unknown }

/// 从当前 Supabase Session 判断本次登录实际使用的认证方式。
///
/// JWT 的 `amr` 记录当前会话的认证方法：邮箱验证码为 `otp`，第三方登录为
/// `oauth`。关联身份只用于进一步区分 Apple / Google，避免用户关联过 Google
/// 后改用邮箱 OTP 登录时仍被展示为 Google 登录。
AuthDisplayProvider authDisplayProviderForSession(Session session) {
  final authenticationMethods = _authenticationMethods(session.accessToken);
  if (authenticationMethods.contains('otp')) {
    return AuthDisplayProvider.email;
  }
  if (authenticationMethods.contains('oauth')) {
    return authDisplayProviderForUser(session.user);
  }
  return authDisplayProviderForUser(session.user);
}

Set<String> _authenticationMethods(String accessToken) {
  final segments = accessToken.split('.');
  if (segments.length != 3) return const {};

  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
    );
    if (payload is! Map<String, Object?>) return const {};

    final amr = payload['amr'];
    if (amr is! Iterable<Object?>) return const {};

    return {
      for (final entry in amr)
        if (entry is Map && entry['method'] is String)
          (entry['method'] as String).toLowerCase(),
    };
  } on FormatException {
    return const {};
  }
}

/// 从 Supabase User 的 provider 元数据判断登录方式。
///
/// UI 不根据邮箱域名推断 Apple/Google，避免把 Apple private relay 地址或
/// 其他托管邮箱误识别为第三方登录。Supabase 会在 app metadata 和 identities
/// 中记录真实 provider，这里只消费这份认证事实。
AuthDisplayProvider authDisplayProviderForUser(User user) {
  final providers = <String>{};
  final primaryProvider = user.appMetadata['provider'];
  if (primaryProvider is String) {
    providers.add(primaryProvider.toLowerCase());
  }

  final metadataProviders = user.appMetadata['providers'];
  if (metadataProviders is Iterable<Object?>) {
    for (final provider in metadataProviders) {
      if (provider is String) {
        providers.add(provider.toLowerCase());
      }
    }
  }

  for (final identity in user.identities ?? const <UserIdentity>[]) {
    providers.add(identity.provider.toLowerCase());
  }

  if (providers.contains('apple')) return AuthDisplayProvider.apple;
  if (providers.contains('google')) return AuthDisplayProvider.google;
  if (providers.contains('email')) return AuthDisplayProvider.email;
  return AuthDisplayProvider.unknown;
}

/// 将非 relay 账号标识压缩为适合设置页入口的短格式。
///
/// Apple private relay 使用明确的提供者文案展示，避免把域名改写成
/// `appleid.com` 造成误导；普通长邮箱仍保留短标识，详细邮箱在账号页展示。
String compactAccountListIdentifier(String value) {
  const maxLength = 24;
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) return trimmed;

  final atIndex = trimmed.indexOf('@');
  if (atIndex <= 0) {
    return '${trimmed.substring(0, 8)}...${trimmed.substring(trimmed.length - 8)}';
  }

  final localPart = trimmed.substring(0, atIndex);
  final domain = trimmed.substring(atIndex + 1);
  final localPrefix = localPart.length <= 8
      ? localPart
      : localPart.substring(0, 8);
  final visibleDomain = domain.length <= 14
      ? domain
      : domain.substring(domain.length - 14);
  return '$localPrefix...@$visibleDomain';
}

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.onSignOut});

  final Future<void> Function()? onSignOut;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isSigningOut = false;

  /// 账号页只服务已登录用户；一旦 session 消失，下一帧立即回到设置页，
  /// 避免退出登录过程中短暂渲染 `/account` 的已登出占位卡片。
  void _redirectToSettingsIfSignedOut() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.settings);
    });
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);
    try {
      final action = widget.onSignOut;
      if (action != null) {
        await action();
      } else {
        await ref.read(authControllerProvider).signOut();
      }
      if (!mounted) return;
      context.go(AppRoutes.settings);
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.watch(supabaseSessionProvider);
    final session = sessionState.value;

    if (session == null) {
      if (sessionState.hasValue) {
        _redirectToSettingsIfSignedOut();
      }
      return const Scaffold(body: SizedBox.shrink());
    }
    final user = session.user;
    final email = user.email?.trim();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            const ProfileEditSection(),
            const SizedBox(height: AppSpacing.l),
            _SectionHeader(title: l10n.signInSection),
            _SignInMethodCard(
              email: email,
              provider: authDisplayProviderForSession(session),
            ),
            // 退出登录与账号信息分开放置，避免误触。
            const SizedBox(height: AppSpacing.xl),
            _SignOutCard(isSigningOut: _isSigningOut, onSignOut: _signOut),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s, 0, 0, AppSpacing.s),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// 只读的登录方式信息：不可点击，因此不显示箭头与水波纹。
class _SignInMethodCard extends StatelessWidget {
  const _SignInMethodCard({required this.email, required this.provider});

  final String? email;
  final AuthDisplayProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final emailText = email?.isNotEmpty == true
        ? email.toString()
        : l10n.authEmailUnavailable;
    final title = switch (provider) {
      AuthDisplayProvider.apple => l10n.authAppleAccount,
      AuthDisplayProvider.google => l10n.authGoogleAccount,
      AuthDisplayProvider.email || AuthDisplayProvider.unknown => l10n.account,
    };
    // 没有真实邮箱时（占位文案）不提供复制菜单，避免把提示语写入剪贴板。
    final accountEmail = email;
    final hasCopyableEmail = accountEmail != null && accountEmail.isNotEmpty;
    return Card(
      child: GestureDetector(
        // 桌面右键与移动端长按都在指针处弹出「复制」菜单，与其他文本的交互一致。
        onSecondaryTapDown: hasCopyableEmail
            ? (details) => _showCopyMenu(
                context,
                details.globalPosition,
                accountEmail,
              )
            : null,
        onLongPressStart: hasCopyableEmail
            ? (details) => _showCopyMenu(
                context,
                details.globalPosition,
                accountEmail,
              )
            : null,
        child: ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(title),
          subtitle: Text(emailText),
        ),
      ),
    );
  }

  /// 在指针处弹出「复制」菜单；复制成功后用统一 toast 提示。
  void _showCopyMenu(BuildContext context, Offset position, String value) {
    final l10n = AppLocalizations.of(context)!;
    TextContextMenu.show(
      context,
      position,
      value,
      onCopied: () => showAppToast(
        overlayState: Overlay.of(context, rootOverlay: true),
        message: l10n.copied,
        icon: Icons.check,
      ),
    );
  }
}

/// 退出登录是唯一的危险操作，使用错误色并独立成卡片。
class _SignOutCard extends StatelessWidget {
  const _SignOutCard({required this.isSigningOut, required this.onSignOut});

  final bool isSigningOut;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final errorColor = Theme.of(context).colorScheme.error;
    return Card(
      child: ListTile(
        leading: isSigningOut
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.logout, color: errorColor),
        title: Text(l10n.authSignOut, style: TextStyle(color: errorColor)),
        enabled: !isSigningOut,
        onTap: isSigningOut ? null : onSignOut,
      ),
    );
  }
}
