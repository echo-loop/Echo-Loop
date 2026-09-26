import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../analytics/models/event_names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/collection_provider.dart';
import '../community_collection_routes.dart';

/// 合集列表顶部固定的「发现资源」入口条。
///
/// 不滚动、永远可见，点击进入资源库主导航壳内的发现页。文案固定为「发现资源 / 播客、托福、雅思、四六级、口译...」，
/// 副标题直接列出代表性合集类型，便于用户一眼看出"里面是什么"。
class DiscoverEntryBanner extends ConsumerWidget {
  /// 点击回调；默认打开发现资源列表。测试可注入 mock。
  final VoidCallback? onTap;

  const DiscoverEntryBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final title = l10n.discoverEntryTitleA;
    final subtitle = l10n.discoverEntrySubtitleA;
    final palette = _DiscoverEntryPalette.resolve(theme.brightness);
    const radius = BorderRadius.all(Radius.circular(12));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.backgroundStart, palette.backgroundEnd],
          ),
          border: Border.all(color: palette.border),
          boxShadow: palette.shadow,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: palette.inkSplash,
              highlightColor: palette.inkHighlight,
              onTap:
                  onTap ??
                  () {
                    // 仅 onTap 时点查一次 enrolled 数量，作为 analytics 维度上报，
                    // 不再驱动文案切换，所以不进入 watch 路径。
                    final enrolledCommunityCount = ref
                        .read(collectionListProvider)
                        .collections
                        .where((c) => c.isCommunity && !c.isDeprecated)
                        .length;
                    ref.read(analyticsServiceProvider).track(
                      Events.discoverEntryTapped,
                      {EventParams.enrolledCount: enrolledCommunityCount},
                    );
                    context.push(CommunityCollectionRoutes.discoverResources);
                  },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 25,
                        color: palette.icon,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: palette.title,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.subtitle,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, size: 22, color: palette.chevron),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverEntryPalette {
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color border;
  final Color icon;
  final Color title;
  final Color subtitle;
  final Color chevron;
  final Color inkSplash;
  final Color inkHighlight;
  final List<BoxShadow> shadow;

  const _DiscoverEntryPalette({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.border,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chevron,
    required this.inkSplash,
    required this.inkHighlight,
    required this.shadow,
  });

  static _DiscoverEntryPalette resolve(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _DiscoverEntryPalette(
        backgroundStart: const Color(0xFF102A36),
        backgroundEnd: const Color(0xFF172D46),
        border: const Color(0x6672C7D6),
        icon: const Color(0xFF8AD8E4),
        title: const Color(0xFFE7F4F8),
        subtitle: const Color(0xFFB8CBD4),
        chevron: const Color(0xCC79D6E6),
        inkSplash: const Color(0x3379D6E6),
        inkHighlight: const Color(0x1A79D6E6),
        shadow: const [],
      );
    }

    return _DiscoverEntryPalette(
      backgroundStart: const Color(0xFFEAF8FA),
      backgroundEnd: const Color(0xFFDDEFFA),
      border: const Color(0xFFA9D5DF),
      icon: const Color(0xFF32758D),
      title: const Color(0xFF17384A),
      subtitle: const Color(0xFF587080),
      chevron: const Color(0xCC3B7F94),
      inkSplash: const Color(0x26256B86),
      inkHighlight: const Color(0x14256B86),
      shadow: const [
        BoxShadow(
          color: Color(0x1A256B86),
          blurRadius: 16,
          offset: Offset(0, 7),
        ),
      ],
    );
  }
}
