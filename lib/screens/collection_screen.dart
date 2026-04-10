// 合集列表页面及可复用组件
//
// 原 CollectionScreen 保留用于 import，
// 内部组件（排序按钮、列表/网格视图、空状态、对话框）
// 导出供 LibraryScreen 复用。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/text_input_dialog.dart';

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

/// 合集网格视图
class CollectionGridView extends StatelessWidget {
  final List<Collection> collections;

  const CollectionGridView({super.key, required this.collections});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        return _CollectionGridTile(collection: collections[index]);
      },
    );
  }
}

/// 合集列表视图
class CollectionListView extends StatelessWidget {
  final List<Collection> collections;

  const CollectionListView({super.key, required this.collections});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        return _CollectionListTile(collection: collections[index]);
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

/// 文件夹网格卡片
class _CollectionGridTile extends ConsumerWidget {
  final Collection collection;

  const _CollectionGridTile({required this.collection});

  static const Key _kGridMenuHitAreaKey = Key('collection_grid_menu_hit_area');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    final theme = Theme.of(context);
    final pinnedHighlightColor = theme.colorScheme.primary.withValues(
      alpha: 0.06,
    );
    return Card(
      color: collection.isPinned ? pinnedHighlightColor : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCollection(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            children: [
              // 顶部操作栏：仅保留居中的更多菜单，pin 收进菜单内
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 36,
                    height: 32,
                    child: PopupMenuButton<String>(
                      key: _kGridMenuHitAreaKey,
                      padding: EdgeInsets.zero,
                      child: Center(
                        child: Icon(
                          Icons.more_horiz,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'togglePin',
                          child: _buildCollectionMenuItemRow(
                            _buildCollectionPinIcon(
                              isPinned: collection.isPinned,
                            ),
                            collection.isPinned
                                ? l10n.unpinCollection
                                : l10n.pinCollection,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'rename',
                          child: _buildCollectionMenuItemRow(
                            const Icon(Icons.edit, size: 18),
                            l10n.renameCollection,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: _buildCollectionMenuItemRow(
                            Icon(
                              Icons.delete,
                              size: 18,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            l10n.delete,
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'togglePin') {
                          ref
                              .read(collectionListProvider.notifier)
                              .togglePin(collection.id);
                        } else if (value == 'rename') {
                          _showRenameCollectionDialog(context, ref, collection);
                        } else if (value == 'delete') {
                          _showDeleteConfirmDialog(context, ref, collection);
                        }
                      },
                    ),
                  ),
                ],
              ),
              // 文件夹图标
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.transparent,
                child: Icon(
                  Icons.folder,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              // 合集名称
              Text(
                collection.name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              // 音频数量
              Text(
                l10n.audioCount(collectionState.getAudioCount(collection.id)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCollection(BuildContext context) {
    context.push(AppRoutes.collectionDetail(collection.id));
  }
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

  const _CollectionListTile({required this.collection});

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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                  padding: const EdgeInsets.fromLTRB(16, 10, 0, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.audioCount(collectionState.getAudioCount(collection.id))} · ${l10n.addedOn(_formatDate(collection.createdDate))}',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'togglePin',
                      child: _buildCollectionMenuItemRow(
                        _buildCollectionPinIcon(isPinned: collection.isPinned),
                        collection.isPinned
                            ? l10n.unpinCollection
                            : l10n.pinCollection,
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
                  ],
                  onSelected: (value) {
                    if (value == 'togglePin') {
                      ref
                          .read(collectionListProvider.notifier)
                          .togglePin(collection.id);
                    } else if (value == 'rename') {
                      _showRenameCollectionDialog(context, ref, collection);
                    } else if (value == 'delete') {
                      _showDeleteConfirmDialog(context, ref, collection);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _openCollection(BuildContext context) {
    context.push(AppRoutes.collectionDetail(collection.id));
  }
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

/// 删除确认对话框
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
