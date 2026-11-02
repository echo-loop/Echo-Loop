import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
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
            _SignedInAccountCard(
              email: email,
              provider: authDisplayProviderForSession(session),
              isSigningOut: _isSigningOut,
              onSignOut: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInAccountCard extends StatelessWidget {
  const _SignedInAccountCard({
    required this.email,
    required this.provider,
    required this.isSigningOut,
    required this.onSignOut,
  });

  final String? email;
  final AuthDisplayProvider provider;
  final bool isSigningOut;
  final Future<void> Function() onSignOut;

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
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(title),
            subtitle: Text(emailText),
          ),
          const Divider(height: 1),
          ListTile(
            leading: isSigningOut
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            title: Text(l10n.authSignOut),
            enabled: !isSigningOut,
            onTap: isSigningOut ? null : onSignOut,
          ),
        ],
      ),
    );
  }
}
