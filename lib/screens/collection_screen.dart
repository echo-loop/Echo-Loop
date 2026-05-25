// 合集列表页面及可复用组件
//
// 原 CollectionScreen 保留用于 import，
// 内部组件（排序按钮、列表/网格视图、空状态、对话框）
// 导出供 LibraryScreen 复用。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/official_collections/providers/official_enrollment_provider.dart';
import '../features/official_collections/widgets/official_badge.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/app_network_image_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/text_input_dialog.dart';
import '../widgets/guide_flow.dart';

/// 合集排序按钮（公开供 LibraryScreen 使用）
class CollectionSortButton extends ConsumerWidget {
  const CollectionSortButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<CollectionSortType>(
      icon: const Icon(Icons.sort),
      onSelected: (type) {
        ref.read(collectionListProvider.notifier).setSortType(type);
      },
      itemBuilder: (context) {
        final current = ref.read(collectionListProvider).sortType;
        return [
          _sortMenuItem(
            l10n.sortByNameAsc,
            CollectionSortType.nameAsc,
            current,
          ),
          _sortMenuItem(
            l10n.sortByNameDesc,
            CollectionSortType.nameDesc,
            current,
          ),
          _sortMenuItem(
            l10n.sortByDateAsc,
            CollectionSortType.dateAsc,
            current,
          ),
          _sortMenuItem(
            l10n.sortByDateDesc,
            CollectionSortType.dateDesc,
            current,
          ),
        ];
      },
    );
  }

  PopupMenuItem<CollectionSortType> _sortMenuItem(
    String label,
    CollectionSortType type,
    CollectionSortType current,
  ) {
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          if (type == current)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// 合集空状态视图
class CollectionEmptyState extends StatelessWidget {
  const CollectionEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            l10n.noCollectionsYet,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            l10n.tapToCreateCollection,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton.icon(
            onPressed: () => showCreateCollectionDialog(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.createCollection),
          ),
        ],
      ),
    );
  }
}

/// 合集列表视图
class CollectionListView extends StatelessWidget {
  final List<Collection> collections;
  final GuideStep? firstItemStep;
  final GuideStep? firstMenuStep;

  const CollectionListView({
    super.key,
    required this.collections,
    this.firstItemStep,
    this.firstMenuStep,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // 横向 padding 为 0：卡片自己有 horizontal 12 的 margin，避免 8+12=20
      // 的双重内缩导致和顶部 DiscoverEntryBanner（horizontal 12）错位
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final isFirst = index == 0;
        return _CollectionListTile(
          collection: collections[index],
          itemStep: isFirst ? firstItemStep : null,
          menuStep: isFirst ? firstMenuStep : null,
        );
      },
    );
  }
}

/// 显示创建合集对话框（公开供 LibraryScreen 使用）
///
/// 需要 [WidgetRef] 来读取合集列表状态并创建合集。
void showCreateCollectionDialog(BuildContext context) {
  // 从 context 中找到最近的 ProviderScope
  final container = ProviderScope.containerOf(context);
  final l10n = AppLocalizations.of(context)!;

  showTextInputDialog(
    context: context,
    title: l10n.createCollection,
    labelText: l10n.collectionName,
    hintText: l10n.enterCollectionName,
    confirmLabel: l10n.add,
    cancelLabel: l10n.cancel,
    validator: (name) {
      if (name.isEmpty) return l10n.collectionNameEmpty;
      final collectionState = container.read(collectionListProvider);
      final exists = collectionState.collections.any(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
      if (exists) return l10n.collectionNameExists;
      return null;
    },
  ).then((name) {
    if (name != null) {
      container.read(collectionListProvider.notifier).createCollection(name);
    }
  });
}

Widget _buildCollectionMenuItemRow(Widget icon, String label) {
  return Row(
    children: [
      icon,
      const SizedBox(width: 8),
      Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
    ],
  );
}

Widget _buildCollectionPinIcon({required bool isPinned}) {
  return Transform.rotate(
    angle: 0.52,
    child: Icon(
      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
      size: 18,
      color: isPinned ? AppTheme.pinColor : null,
    ),
  );
}

/// 列表项
class _CollectionListTile extends ConsumerWidget {
  final Collection collection;
  final GuideStep? itemStep;
  final GuideStep? menuStep;

  const _CollectionListTile({
    required this.collection,
    this.itemStep,
    this.menuStep,
  });

  static const Key _kListMenuHitAreaKey = Key('collection_list_menu_hit_area');
  static const double _kTrailingMenuWidth = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    final theme = Theme.of(context);
    final pinnedHighlightColor = theme.colorScheme.primary.withValues(
      alpha: 0.06,
    );
    final card = Card(
      // margin 与 Discover 卡片保持一致
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: collection.isPinned ? pinnedHighlightColor : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCollection(context),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildLeadingIcon(theme),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection.name,
                              style: theme.textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.audioCount(collectionState.getAudioCount(collection.id))} · ${l10n.addedOn(_formatDate(collection.createdDate))}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _wrapWithGuideTarget(
                menuStep,
                SizedBox(
                  width: _kTrailingMenuWidth,
                  child: PopupMenuButton<String>(
                    key: _kListMenuHitAreaKey,
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    itemBuilder: (context) => collection.isOfficial
                        ? _buildOfficialMenuItems(collection, l10n, theme)
                        : _buildLocalMenuItems(collection, l10n, theme),
                    onSelected: (value) {
                      if (value == 'togglePin') {
                        ref
                            .read(collectionListProvider.notifier)
                            .togglePin(collection.id);
                      } else if (value == 'rename') {
                        _showRenameCollectionDialog(context, ref, collection);
                      } else if (value == 'delete') {
                        _showDeleteConfirmDialog(context, ref, collection);
                      } else if (value == 'removeOfficial') {
                        _showRemoveOfficialConfirmDialog(
                          context,
                          ref,
                          collection,
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _wrapWithGuideTarget(itemStep, card);
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _openCollection(BuildContext context) {
    context.push(AppRoutes.collectionDetail(collection.id));
  }

  /// 左侧 leading（尺寸 / 样式与 Discover 卡片完全一致）：
  /// - 官方合集且有 coverUrl：网络封面图（BoxFit.contain）
  /// - 其它情况：渐变背景 + 合集名首字母
  ///
  /// 官方合集会在右上角叠加 [OfficialCornerBadge] 角标（已下架则换成灰色 block 角标）。
  Widget _buildLeadingIcon(ThemeData theme) {
    const size = 56.0;
    final coverUrl = collection.coverUrl;
    final Widget icon =
        (collection.isOfficial && coverUrl != null && coverUrl.isNotEmpty)
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: coverUrl,
              cacheManager: AppNetworkImageCache.instance,
              width: size,
              height: size,
              fit: BoxFit.contain,
              placeholder: (_, __) => _letterPlaceholder(theme, size),
              errorWidget: (_, __, ___) => _letterPlaceholder(theme, size),
            ),
          )
        : _letterPlaceholder(theme, size);

    if (!collection.isOfficial) return icon;

    // Stack 不裁剪溢出，让角标向外偏移 4px，营造贴在图标外缘的"app 角标"观感
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            top: -4,
            right: -4,
            child: OfficialCornerBadge(isDeprecated: collection.isDeprecated),
          ),
        ],
      ),
    );
  }

  /// 渐变背景 + 合集名首字母占位（与官方合集卡片 `_coverPlaceholder` 同款）。
  Widget _letterPlaceholder(ThemeData theme, double size) {
    final letter = collection.name.isEmpty
        ? '?'
        : collection.name.characters.first;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.tertiaryContainer,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 可选包装成 GuideTarget：step 为 null 时直接返回 child。
Widget _wrapWithGuideTarget(GuideStep? step, Widget child) {
  if (step == null) return child;
  return GuideTarget(step: step, child: child);
}

// ===== 公共辅助方法 =====

/// 重命名合集对话框
void _showRenameCollectionDialog(
  BuildContext context,
  WidgetRef ref,
  Collection collection,
) async {
  final l10n = AppLocalizations.of(context)!;

  final name = await showTextInputDialog(
    context: context,
    title: l10n.renameCollection,
    labelText: l10n.collectionName,
    initialValue: collection.name,
    confirmLabel: l10n.ok,
    cancelLabel: l10n.cancel,
  );

  if (name != null) {
    ref
        .read(collectionListProvider.notifier)
        .renameCollection(collection.id, name);
  }
}

/// 删除确认对话框（local 合集专用）
void _showDeleteConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  Collection collection,
) async {
  final l10n = AppLocalizations.of(context)!;

  final confirmed = await showConfirmDialog(
    context: context,
    title: l10n.deleteCollection,
    message: l10n.deleteCollectionConfirm(collection.name),
    icon: Icons.warning_amber_rounded,
    isDestructive: true,
    confirmLabel: l10n.delete,
    cancelLabel: l10n.cancel,
  );

  if (confirmed == true) {
    ref.read(collectionListProvider.notifier).deleteCollection(collection.id);
  }
}

/// 从我的合集移除官方合集（彻底清空音频/字幕/学习记录）
void _showRemoveOfficialConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  Collection collection,
) async {
  final l10n = AppLocalizations.of(context)!;

  final confirmed = await showConfirmDialog(
    context: context,
    title: l10n.removeOfficialConfirmTitle(collection.name),
    message: l10n.removeOfficialConfirmMessage,
    icon: Icons.warning_amber_rounded,
    isDestructive: true,
    confirmLabel: l10n.removeOfficialConfirmConfirm,
    cancelLabel: l10n.cancel,
  );

  if (confirmed == true) {
    await ref.read(officialEnrollmentProvider.notifier).remove(collection.id);
  }
}

/// 本地合集（source='local'）的菜单项：pin/unpin 切换 / 重命名 / 删除。
List<PopupMenuEntry<String>> _buildLocalMenuItems(
  Collection collection,
  AppLocalizations l10n,
  ThemeData theme,
) {
  return [
    PopupMenuItem(
      value: 'togglePin',
      child: _buildCollectionMenuItemRow(
        _buildCollectionPinIcon(isPinned: collection.isPinned),
        collection.isPinned ? l10n.unpinCollection : l10n.pinCollection,
      ),
    ),
    PopupMenuItem(
      value: 'rename',
      child: _buildCollectionMenuItemRow(
        const Icon(Icons.edit),
        l10n.renameCollection,
      ),
    ),
    PopupMenuItem(
      value: 'delete',
      child: _buildCollectionMenuItemRow(
        Icon(Icons.delete, color: theme.colorScheme.error),
        l10n.delete,
      ),
    ),
  ];
}

/// 官方合集菜单项：pin（允许）/ 从我的合集移除（彻底清空）；
/// 不允许重命名、不允许删除合集内的音频。
List<PopupMenuEntry<String>> _buildOfficialMenuItems(
  Collection collection,
  AppLocalizations l10n,
  ThemeData theme,
) {
  return [
    PopupMenuItem(
      value: 'togglePin',
      child: _buildCollectionMenuItemRow(
        _buildCollectionPinIcon(isPinned: collection.isPinned),
        collection.isPinned ? l10n.unpinCollection : l10n.pinCollection,
      ),
    ),
    PopupMenuItem(
      value: 'removeOfficial',
      child: _buildCollectionMenuItemRow(
        Icon(Icons.remove_circle_outline, color: theme.colorScheme.error),
        l10n.removeFromMyCollections,
      ),
    ),
  ];
}
