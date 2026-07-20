/// 发送前闸门 banner（唯一数据源 = state.gate）。
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../state/chat_session_state.dart';

/// 发送前闸门 banner：
/// - authRequired → 登录引导；
/// - quotaExceeded → 升级（openPaywall）；
/// - none → SizedBox.shrink。
///
/// 一轮已开始后的失败（网络/断流/402）不在此显示——由那条气泡 inline 表达，
/// 避免 banner 与气泡同时出现两个重试/升级入口。
class ChatGateBanner extends StatelessWidget {
  const ChatGateBanner({
    super.key,
    required this.gate,
    required this.onUpgrade,
    required this.onSignIn,
  });

  final ChatGate gate;
  final VoidCallback onUpgrade;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    if (gate == ChatGate.none) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final bool isAuth = gate == ChatGate.authRequired;
    final String message = isAuth
        ? l10n.chatSignInMessage
        : l10n.chatQuotaTitle;
    final String action = isAuth ? l10n.chatSignInTitle : l10n.chatUpgrade;
    final VoidCallback onAction = isAuth ? onSignIn : onUpgrade;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      color: scheme.primaryContainer,
      child: Row(
        children: [
          Icon(
            isAuth ? Icons.lock_outline : Icons.workspace_premium_outlined,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}
