/// 播客订阅列表项（公共组件）
///
/// 精选播客全屏页与「订阅 Podcast」弹窗共用。接收原始展示字段与回调，
/// 不感知具体数据模型（CatalogPodcast / PodcastSearchResult 皆可），
/// 保持纯展示 + 回调分发，业务逻辑留在调用方。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// 单个可订阅播客卡片。
///
/// trailing 三态：[subscribing] → 转圈；[subscribed] → 「去学习」；
/// 否则 → 「+」订阅按钮。[onOpen] 为 null 时内容区不可点（无预览页场景）。
class PodcastSubscribeTile extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final bool subscribed;
  final bool subscribing;

  /// 点击内容区（打开详情/预览）；为 null 时内容区不可点。
  final VoidCallback? onOpen;
  final VoidCallback onSubscribe;
  final VoidCallback onGoLearn;

  const PodcastSubscribeTile({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subscribed,
    required this.subscribing,
    required this.onSubscribe,
    required this.onGoLearn,
    this.subtitle,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Card(
      // 横向 margin 交由外层列表控制，保证与同容器内其他控件（如搜索框）左右对齐。
      margin: const EdgeInsets.symmetric(vertical: 3),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: Row(
                  children: [
                    PodcastCover(imageUrl: imageUrl, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((subtitle ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildTrailing(context, l10n, theme),
        ],
      ),
    );
  }

  Widget _buildTrailing(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (subscribing) {
      return const SizedBox(
        width: 72,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (subscribed) {
      return SizedBox(
        width: 72,
        child: InkWell(
          onTap: onGoLearn,
          child: Center(
            child: Text(
              l10n.goLearn,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 56,
      child: InkWell(
        onTap: onSubscribe,
        child: Tooltip(
          message: l10n.addToMyCollections,
          child: Center(
            child: Icon(
              Icons.add_circle_outline,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 播客封面（圆角图 + 占位 fallback），加载失败/空时显示 podcasts 图标。
class PodcastCover extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const PodcastCover({super.key, required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.podcasts_rounded,
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: imageUrl == null || imageUrl!.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}
