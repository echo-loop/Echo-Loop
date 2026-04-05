/// 句子回收站弹窗
///
/// 展示已取消收藏的句子书签，支持恢复、永久删除和清空操作。
library;

import 'package:flutter/material.dart';
import '../../utils/time_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/daos/bookmark_dao.dart';
import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../dialogs/confirm_dialog.dart';
import 'recycle_bin_sheet_base.dart';

/// 打开句子回收站弹窗
Future<void> showSentenceRecycleBinSheet({required BuildContext context}) {
  return showRecycleBinSheet(
    context: context,
    builder: (_) => const _SentenceRecycleBinSheet(),
  );
}

class _SentenceRecycleBinSheet extends ConsumerStatefulWidget {
  const _SentenceRecycleBinSheet();

  @override
  ConsumerState<_SentenceRecycleBinSheet> createState() =>
      _SentenceRecycleBinSheetState();
}

class _SentenceRecycleBinSheetState
    extends ConsumerState<_SentenceRecycleBinSheet> {
  final List<BookmarkWithAudio> _items = [];
  RecycleBinSortMode _sortMode = RecycleBinSortMode.timeDesc;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final dao = ref.read(bookmarkDaoProvider);
    final items = await dao.getDeletedBookmarks(sortMode: _sortMode);
    if (!mounted) return;

    setState(() {
      _items
        ..clear()
        ..addAll(items);
      _isLoading = false;
    });
  }

  void _onSortChanged(RecycleBinSortMode sortMode) {
    if (_sortMode == sortMode) return;
    setState(() => _sortMode = sortMode);
    _loadData();
  }

  Future<void> _onRestore(BookmarkWithAudio item) async {
    final dao = ref.read(bookmarkDaoProvider);
    await dao.restoreBookmark(
      item.bookmark.audioItemId,
      item.bookmark.sentenceIndex,
    );
    if (!mounted) return;
    setState(() => _items.remove(item));
  }

  Future<void> _onDelete(BookmarkWithAudio item) async {
    final dao = ref.read(bookmarkDaoProvider);
    await dao.permanentlyDeleteBookmark(
      item.bookmark.audioItemId,
      item.bookmark.sentenceIndex,
    );
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

    final dao = ref.read(bookmarkDaoProvider);
    await dao.permanentlyDeleteAllDeleted();
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
            dismissKey: ValueKey('bm_${item.bookmark.id}'),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.bookmark.sentenceText,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.audioName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                if (item.bookmark.deletedAt != null)
                                  Text(
                                    _formatDeletedAt(item.bookmark.deletedAt!),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ],
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
