// 标签归属编辑 BottomSheet
//
// Checkbox 多选方式编辑音频所属的标签，
// 勾选/取消即时生效，支持底部"创建新标签"入口（名称 + 颜色选择）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/tag_colors.dart';

/// 标签归属编辑 BottomSheet
///
/// 所有操作即时生效：勾选/取消、创建、删除均立刻写入数据库。
class EditTagMembershipSheet extends ConsumerWidget {
  /// 要编辑归属的音频 ID
  final String audioId;

  const EditTagMembershipSheet({super.key, required this.audioId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tagState = ref.watch(tagListProvider);
    final tags = tagState.tags;
    final audioTagIds = tagState.audioToTagsMap[audioId] ?? [];

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
                l10n.manageTags,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            // 标签列表
            if (tags.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: Text(
                    l10n.noTagsYet,
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
                  itemCount: tags.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    final isSelected = audioTagIds.contains(tag.id);
                    return CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                      ),
                      secondary: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: tag.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(tag.name)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () =>
                                _showDeleteTagDialog(context, ref, tag),
                          ),
                        ],
                      ),
                      value: isSelected,
                      onChanged: (value) {
                        final notifier = ref.read(tagListProvider.notifier);
                        if (value == true) {
                          notifier.addAudioToTag(tag.id, audioId);
                        } else {
                          notifier.removeAudioFromTag(tag.id, audioId);
                        }
                      },
                    );
                  },
                ),
              ),
            const Divider(),
            // 创建新标签入口
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                l10n.createTag,
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              onTap: () => _showCreateTagDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  /// 删除标签确认对话框
  void _showDeleteTagDialog(BuildContext context, WidgetRef ref, Tag tag) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
        ),
        title: Text(l10n.deleteTag),
        content: Text(l10n.deleteTagConfirm(tag.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(tagListProvider.notifier).deleteTag(tag.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  /// 创建新标签对话框
  void _showCreateTagDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    int selectedColor = kTagColors[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isEmpty = controller.text.trim().isEmpty;
          return AlertDialog(
            title: Text(l10n.createTag, textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.tagName,
                    hintText: l10n.enterTagName,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  onSubmitted: (_) {
                    if (!isEmpty) {
                      _createAndAssign(ctx, ref, controller, selectedColor);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.selectColor,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kTagColors.map((colorValue) {
                    final isChosen = colorValue == selectedColor;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedColor = colorValue;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          shape: BoxShape.circle,
                          border: isChosen
                              ? Border.all(
                                  color: Theme.of(ctx).colorScheme.onSurface,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: isChosen
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: isEmpty
                          ? null
                          : () => _createAndAssign(
                              ctx,
                              ref,
                              controller,
                              selectedColor,
                            ),
                      child: Text(l10n.add),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// 创建标签并自动关联到当前音频
  Future<void> _createAndAssign(
    BuildContext dialogContext,
    WidgetRef ref,
    TextEditingController controller,
    int colorValue,
  ) async {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    final notifier = ref.read(tagListProvider.notifier);
    await notifier.createTag(name, colorValue);

    // 获取新创建的标签 ID 并立刻关联
    final tags = ref.read(tagListProvider).tags;
    final newTag = tags.lastWhere((t) => t.name == name);
    await notifier.addAudioToTag(newTag.id, audioId);

    if (dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }
  }
}
