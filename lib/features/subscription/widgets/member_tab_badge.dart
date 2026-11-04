/// 「我的」导航图标上的会员角标。
///
/// 仅在权益已确认为会员（[EntitlementState.isActive]）时显示 VIP 角标：
/// unknown 中间态（冷启动、对账未完成）与 free 态都不显示，避免会员冷启动时先闪出
/// 免费态、或免费用户被误标。角标用于截图识别会员身份，不承载任何业务逻辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../providers/subscription_controller.dart';

class MemberTabBadge extends ConsumerWidget {
  const MemberTabBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMember = ref.watch(
      subscriptionControllerProvider.select((state) => state.isActive),
    );
    // 与设置页「升级」金色徽章同一套颜色，保证应用内金色标识一致；尺寸压小，避免盖住图标。
    final brightness = Theme.of(context).brightness;
    return Badge(
      isLabelVisible: isMember,
      label: const Text('VIP'),
      backgroundColor: AppTheme.premiumUpgradeBadgeBackground(brightness),
      textColor: AppTheme.memberBadgeText,
      largeSize: 11,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      textStyle: const TextStyle(
        fontSize: 7,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
      offset: const Offset(4, -2),
      child: child,
    );
  }
}
