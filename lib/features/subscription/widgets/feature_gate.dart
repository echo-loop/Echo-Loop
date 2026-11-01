/// 付费墙门控组件 + Paywall 导航助手。
///
/// 纯展示：watch [featureAccessProvider]，解锁渲染 [child]，锁定渲染 [locked] 占位。
/// 不承载业务逻辑（只问 featureAccessProvider）。锁定占位点击默认跳 Paywall——
/// 即「功能撞墙时弹出订阅页」入口。
///
/// Phase 0：因免费额度策略一律放行，[child] 总会渲染，不阻断任何现有流程。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../models/premium_feature.dart';
import '../providers/feature_access_provider.dart';
import '../providers/subscription_availability.dart';

/// 打开订阅计划介绍 / 购买页（功能撞墙、升级入口统一走这里）。
///
/// 查看 Paywall 与价格**无需登录**（利于转化、两个入口一致）；登录判定统一收敛到
/// 购买 / 恢复动作（见 [PaywallScreen]，走全 App 通用的 `ensureSignedInForAction`）。
///
/// 当前平台未启用订阅时不导航，仅提示——兜底覆盖所有撞墙入口（转录/意群/词典），
/// 避免未启用平台的用户被引到无法购买的 Paywall。
Future<void> openPaywall(BuildContext context, WidgetRef ref) async {
  if (!ref.read(subscriptionAvailabilityProvider)) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.premiumUnavailableOnPlatform)));
    return;
  }
  await context.push(AppRoutes.paywall);
}

/// 根据 [feature] 是否解锁，在 [child] 与锁定占位间切换的门控组件。
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.locked,
    this.onLockedTap,
  });

  /// 受保护的能力。
  final PremiumFeature feature;

  /// 解锁时渲染的内容。
  final Widget child;

  /// 锁定时渲染的占位（为 null 时锁定渲染空白 [SizedBox.shrink]）。
  final Widget? locked;

  /// 锁定占位被点击时的回调（为 null 时默认跳 Paywall）。
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(featureAccessProvider(feature));
    if (unlocked) return child;
    final placeholder = locked;
    if (placeholder == null) return const SizedBox.shrink();
    return InkWell(
      onTap: () => (onLockedTap ?? () => openPaywall(context, ref))(),
      child: placeholder,
    );
  }
}
