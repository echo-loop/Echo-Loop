// 标签归属编辑 BottomSheet
//
// Checkbox 多选方式编辑音频所属的标签，
// 支持底部"创建新标签"入口（名称 + 颜色选择）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/tag_colors.dart';

/// 标签归属编辑 BottomSheet
class EditTagMembershipSheet extends ConsumerStatefulWidget {
  /// 要编辑归属的音频 ID
  final String audioId;

  const EditTagMembershipSheet({super.key, required this.audioId});

  @override
  ConsumerState<EditTagMembershipSheet> createState() =>
      _EditTagMembershipSheetState();
}

class _EditTagMembershipSheetState
    extends ConsumerState<EditTagMembershipSheet> {
  /// 当前选中的标签 ID 集合
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    final tagState = ref.read(tagListProvider);
    final currentTags = tagState.audioToTagsMap[widget.audioId] ?? [];
    _selectedIds = Set<String>.from(currentTags);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tags = ref.watch(tagListProvider.select((s) => s.tags));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Row(
                children: [
                  Text(
                    l10n.manageTags,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _onDone, child: Text(l10n.done)),
                ],
              ),
            ),
            const Divider(),
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
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    final isSelected = _selectedIds.contains(tag.id);
                    return CheckboxListTile(
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
                                _showDeleteTagDialog(context, tag),
                            tooltip: l10n.deleteTag,
                          ),
                        ],
                      ),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedIds.add(tag.id);
                          } else {
                            _selectedIds.remove(tag.id);
                          }
                        });
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
              onTap: () => _showCreateTagDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 点击完成 — 批量更新标签归属
  Future<void> _onDone() async {
    await ref
        .read(tagListProvider.notifier)
        .updateAudioTagMembership(widget.audioId, _selectedIds);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// 删除标签确认对话框
  void _showDeleteTagDialog(BuildContext context, Tag tag) {
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
              setState(() {
                _selectedIds.remove(tag.id);
              });
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
  void _showCreateTagDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    int selectedColor = kTagColors[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.createTag),
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
                onSubmitted: (_) => _createAndSelect(ctx, controller, selectedColor),
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
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => _createAndSelect(ctx, controller, selectedColor),
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  /// 创建标签并自动勾选
  Future<void> _createAndSelect(
    BuildContext dialogContext,
    TextEditingController controller,
    int colorValue,
  ) async {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    await ref.read(tagListProvider.notifier).createTag(name, colorValue);

    // 获取新创建的标签 ID
    final tags = ref.read(tagListProvider).tags;
    final newTag = tags.lastWhere((t) => t.name == name);

    setState(() {
      _selectedIds.add(newTag.id);
    });

    if (dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }
  }
}
