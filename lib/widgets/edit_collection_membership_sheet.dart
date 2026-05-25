// 合集归属编辑 BottomSheet
//
// Checkbox 多选方式编辑音频所属的合集，
// 勾选/取消即时生效，支持底部"创建新合集"入口。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'dialogs/text_input_dialog.dart';

/// 合集归属编辑 BottomSheet
///
/// 所有操作即时生效：勾选/取消、创建均立刻写入数据库。
class EditCollectionMembershipSheet extends ConsumerWidget {
  /// 要编辑归属的音频 ID
  final String audioId;

  const EditCollectionMembershipSheet({super.key, required this.audioId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final collectionState = ref.watch(collectionListProvider);
    // 只显示用户自建合集，官方精选合集不允许用户添加音频
    final collections = collectionState.collections
        .where((c) => c.source == CollectionSource.local)
        .toList();
    final audioCollectionIds =
        collectionState.audioToCollectionsMap[audioId] ?? [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.m, 0, AppSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖动手柄
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Text(
                l10n.manageCollections,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            // 合集列表
            if (collections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: Text(
                    l10n.noCollectionsYet,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: collections.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    final isSelected = audioCollectionIds.contains(
                      collection.id,
                    );
                    return CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                      ),
                      title: Text(collection.name),
                      value: isSelected,
                      onChanged: (value) {
                        final notifier = ref.read(
                          collectionListProvider.notifier,
                        );
                        if (value == true) {
                          notifier.addAudioToCollection(collection.id, audioId);
                        } else {
                          notifier.removeAudioFromCollection(
                            collection.id,
                            audioId,
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            const Divider(),
            // 创建新合集入口
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                l10n.createCollection,
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              onTap: () => _showCreateCollectionDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  /// 创建新合集对话框（复用通用文本输入对话框）
  void _showCreateCollectionDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final container = ProviderScope.containerOf(context);

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
    ).then((name) async {
      if (name == null) return;
      final notifier = container.read(collectionListProvider.notifier);
      await notifier.createCollection(name);

      // 获取新创建的合集 ID 并立刻关联
      final collections = container.read(collectionListProvider).rawCollections;
      final newCollection = collections.lastWhere((c) => c.name == name);
      await notifier.addAudioToCollection(newCollection.id, audioId);
    });
  }
}
