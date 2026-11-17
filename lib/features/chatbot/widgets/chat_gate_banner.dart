/// 发送前闸门 banner（唯一数据源 = state.gate）。
library;

import 'package:flutter/material.dart';
import 'package:echo_loop/widgets/common/svg_action_icon.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../subscription/models/premium_feature.dart';
import '../../subscription/utils/ai_quota_copy.dart';
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
        : aiQuotaExceededTitleFor(l10n, PremiumFeature.aiChat);
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
          isAuth
              ? SvgActionIcon(
                  assetName: 'assets/icon/lock.svg',
                  size: 18,
                  color: scheme.onPrimaryContainer,
                )
              : Icon(
                  Icons.workspace_premium_outlined,
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
