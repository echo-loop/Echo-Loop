/// 词汇回收站弹窗
///
/// 合并展示已取消收藏的单词和意群，支持恢复、永久删除和清空操作。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/time_format.dart';

import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../dialogs/confirm_dialog.dart';
import 'recycle_bin_sheet_base.dart';

/// 打开词汇回收站弹窗
Future<void> showVocabularyRecycleBinSheet({required BuildContext context}) {
  return showRecycleBinSheet(
    context: context,
    builder: (_) => const _VocabularyRecycleBinSheet(),
  );
}

/// 已删除词汇条目（单词或意群的统一抽象）
class _DeletedVocabItem {
  /// 展示文本
  final String displayText;

  /// 唯一键（word 或 phraseText）
  final String key;

  /// true=意群, false=单词
  final bool isSenseGroup;

  /// 取消收藏时间
  final DateTime deletedAt;

  /// 来源句子文本（可选）
  final String? sentenceText;

  /// 数据库 ID（用于 ValueKey）
  final int id;

  const _DeletedVocabItem({
    required this.displayText,
    required this.key,
    required this.isSenseGroup,
    required this.deletedAt,
    required this.id,
    this.sentenceText,
  });
}

class _VocabularyRecycleBinSheet extends ConsumerStatefulWidget {
  const _VocabularyRecycleBinSheet();

  @override
  ConsumerState<_VocabularyRecycleBinSheet> createState() =>
      _VocabularyRecycleBinSheetState();
}

class _VocabularyRecycleBinSheetState
    extends ConsumerState<_VocabularyRecycleBinSheet> {
  final List<_DeletedVocabItem> _items = [];
  RecycleBinSortMode _sortMode = RecycleBinSortMode.timeDesc;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final wordDao = ref.read(savedWordDaoProvider);
    final sgDao = ref.read(savedSenseGroupDaoProvider);

    final (words, senseGroups) = await (
      wordDao.getDeletedWords(sortMode: _sortMode),
      sgDao.getDeletedSenseGroups(sortMode: _sortMode),
    ).wait;
    if (!mounted) return;

    final merged = <_DeletedVocabItem>[
      for (final w in words)
        _DeletedVocabItem(
          displayText: w.word,
          key: w.word,
          isSenseGroup: false,
          deletedAt: w.deletedAt!,
          id: w.id,
          sentenceText: w.sentenceText,
        ),
      for (final sg in senseGroups)
        _DeletedVocabItem(
          displayText: sg.displayText,
          key: sg.phraseText,
          isSenseGroup: true,
          deletedAt: sg.deletedAt!,
          id: sg.id,
          sentenceText: sg.sentenceText,
        ),
    ];

    // 内存归并排序
    _sortItems(merged);

    setState(() {
      _items
        ..clear()
        ..addAll(merged);
      _isLoading = false;
    });
  }

  void _sortItems(List<_DeletedVocabItem> items) {
    items.sort((a, b) {
      return switch (_sortMode) {
        RecycleBinSortMode.timeDesc => b.deletedAt.compareTo(a.deletedAt),
        RecycleBinSortMode.timeAsc => a.deletedAt.compareTo(b.deletedAt),
        RecycleBinSortMode.alphaAsc => a.displayText.toLowerCase().compareTo(
          b.displayText.toLowerCase(),
        ),
        RecycleBinSortMode.alphaDesc => b.displayText.toLowerCase().compareTo(
          a.displayText.toLowerCase(),
        ),
      };
    });
  }

  void _onSortChanged(RecycleBinSortMode sortMode) {
    if (_sortMode == sortMode) return;
    setState(() {
      _sortMode = sortMode;
      _sortItems(_items);
    });
  }

  Future<void> _onRestore(_DeletedVocabItem item) async {
    if (item.isSenseGroup) {
      await ref.read(savedSenseGroupDaoProvider).restoreSenseGroup(item.key);
    } else {
      await ref.read(savedWordDaoProvider).restoreWord(item.key);
    }
    if (!mounted) return;
    setState(() => _items.remove(item));
  }

  Future<void> _onDelete(_DeletedVocabItem item) async {
    if (item.isSenseGroup) {
      await ref
          .read(savedSenseGroupDaoProvider)
          .permanentlyDeleteSenseGroup(item.key);
    } else {
      await ref.read(savedWordDaoProvider).permanentlyDeleteWord(item.key);
    }
    if (!mounted) return;
    setState(() => _items.remove(item));
  }

  String _formatDeletedAt(DateTime dt) => formatTimeAgo(context, dt);

  Future<void> _onClearAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.recycleBinClearAll,
      message: l10n.recycleBinClearAllConfirm(_items.length),
      isDestructive: true,
      confirmLabel: l10n.recycleBinClearAll,
      cancelLabel: l10n.cancel,
    );

    if (confirmed != true || !mounted) return;

    final wordDao = ref.read(savedWordDaoProvider);
    final sgDao = ref.read(savedSenseGroupDaoProvider);
    await Future.wait([
      wordDao.permanentlyDeleteAllDeleted(),
      sgDao.permanentlyDeleteAllDeleted(),
    ]);
    if (!mounted) return;
    setState(() => _items.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RecycleBinSheetScaffold(
      itemCount: _items.length,
      isLoading: _isLoading,
      sortMode: _sortMode,
      onSortChanged: _onSortChanged,
      onClearAll: _items.isNotEmpty ? _onClearAll : null,
      child: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return RecycleBinDismissible(
            dismissKey: ValueKey(
              '${item.isSenseGroup ? "sg" : "w"}_${item.id}',
            ),
            onDelete: () => _onDelete(item),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.s,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.displayText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDeletedAt(item.deletedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      RecycleBinRestoreButton(
                        onRestore: () => _onRestore(item),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          );
        },
      ),
    );
  }
}
