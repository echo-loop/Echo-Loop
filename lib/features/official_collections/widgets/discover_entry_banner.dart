import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../analytics/models/event_names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/collection_provider.dart';

/// 合集列表顶部固定的「发现精选合集」入口条。
///
/// 不滚动、永远可见，点击进入 `/discover`。文案固定为「发现精选合集 / 托福·雅思·专四专八·VOA…」，
/// 副标题直接列出代表性合集类型，便于用户一眼看出"里面是什么"。
class DiscoverEntryBanner extends ConsumerWidget {
  /// 点击回调；默认 `context.push('/discover')`。测试可注入 mock。
  final VoidCallback? onTap;

  const DiscoverEntryBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final title = l10n.discoverEntryTitleA;
    final subtitle = l10n.discoverEntrySubtitleA;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: theme.colorScheme.primaryContainer,
          child: InkWell(
            onTap:
                onTap ??
                () {
                  // 仅 onTap 时点查一次 enrolled 数量，作为 analytics 维度上报，
                  // 不再驱动文案切换，所以不进入 watch 路径。
                  final enrolledOfficialCount = ref
                      .read(collectionListProvider)
                      .collections
                      .where((c) => c.isOfficial && !c.isDeprecated)
                      .length;
                  ref.read(analyticsServiceProvider).track(
                    Events.discoverEntryTapped,
                    {EventParams.enrolledCount: enrolledOfficialCount},
                  );
                  context.push('/discover');
                },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.explore,
                    size: 24,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
