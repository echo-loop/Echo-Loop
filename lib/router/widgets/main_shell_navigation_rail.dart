import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/desktop_sidebar_provider.dart';
import '../../theme/app_theme.dart';

const _compactRailWidth = 72.0;
const _expandedRailWidth = 172.0;

/// 主导航侧栏；显示时始终允许用户收起或展开文字标签。
class MainShellNavigationRail extends ConsumerWidget {
  const MainShellNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      throw FlutterError('MainShellNavigationRail requires AppLocalizations.');
    }
    final isExpanded = ref.watch(desktopSidebarExpandedProvider);
    final railBackgroundColor =
        Theme.of(context).navigationRailTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;

    return NavigationRail(
      key: const ValueKey('main-shell-navigation-rail'),
      backgroundColor: railBackgroundColor,
      extended: isExpanded,
      minWidth: _compactRailWidth,
      minExtendedWidth: _expandedRailWidth,
      labelType: !isExpanded ? NavigationRailLabelType.none : null,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      trailingAtBottom: true,
      trailing: _MainShellSidebarToggle(isExpanded: isExpanded, l10n: l10n),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.library_music_outlined),
          selectedIcon: const Icon(
            Icons.library_music,
            color: AppTheme.navActiveColor,
          ),
          label: Text(l10n.library),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.school_outlined),
          selectedIcon: const Icon(
            Icons.school,
            color: AppTheme.navActiveColor,
          ),
          label: Text(l10n.study),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.bookmark_border),
          selectedIcon: const Icon(
            Icons.bookmark,
            color: AppTheme.navActiveColor,
          ),
          label: Text(l10n.favorites),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(
            Icons.person,
            color: AppTheme.navActiveColor,
          ),
          label: Text(l10n.profile),
        ),
      ],
    );
  }
}

/// 用 NavigationRail 自身的扩展动画同步侧栏宽度和底部按钮的水平位置。
class _MainShellSidebarToggle extends ConsumerWidget {
  const _MainShellSidebarToggle({required this.isExpanded, required this.l10n});

  final bool isExpanded;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extendedAnimation = NavigationRail.extendedAnimation(context);

    return AnimatedBuilder(
      animation: extendedAnimation,
      child: IconButton(
        key: const ValueKey('main-shell-sidebar-toggle'),
        tooltip: isExpanded ? l10n.collapseSidebar : l10n.expandSidebar,
        icon: Icon(
          isExpanded
              ? Icons.keyboard_double_arrow_left
              : Icons.keyboard_double_arrow_right,
        ),
        onPressed: () => unawaited(
          ref
              .read(desktopSidebarExpandedProvider.notifier)
              .setExpanded(!isExpanded),
        ),
      ),
      builder: (context, child) {
        final animationValue = extendedAnimation.value;
        final width =
            _compactRailWidth +
            (_expandedRailWidth - _compactRailWidth) * animationValue;

        return SizedBox(
          width: width,
          child: Padding(
            padding: EdgeInsets.only(right: 8 * animationValue, bottom: 16),
            child: Align(alignment: Alignment(animationValue, 0), child: child),
          ),
        );
      },
    );
  }
}
