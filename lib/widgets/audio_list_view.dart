// 音频列表视图
//
// 展示音频列表，支持排序。同时用于资源库全局列表和合集详情页。
// - items 为 null 时从 audioLibraryProvider 读取（全局场景）
// - items 非 null 时使用传入的列表（合集场景）
// 排序逻辑统一使用 audioListSettingsProvider。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_item.dart';
import '../providers/audio_library_provider.dart';
import '../providers/audio_list_settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/add_audio_dialog.dart';
import 'audio_list_tile.dart';
import 'edit_collection_membership_sheet.dart';
import 'edit_tag_membership_sheet.dart';

/// 音频列表视图 — 资源库全局列表和合集详情页共用
///
/// [items] 为 null 时从 audioLibraryProvider 读取全局音频列表；
/// 非 null 时使用传入的列表（合集场景）。
/// [collectionId] 传递给 AudioListTile 以区分上下文。
/// [emptyState] 自定义空状态组件。
class AudioListView extends ConsumerWidget {
  /// 外部传入的音频列表（合集场景），为 null 时从 provider 读取
  final List<AudioItem>? items;

  /// 合集 ID — 传递给 AudioListTile
  final String? collectionId;

  /// 自定义空状态组件
  final Widget? emptyState;

  const AudioListView({
    super.key,
    this.items,
    this.collectionId,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // 数据来源：外部传入 or provider
    final List<AudioItem> audioItems =
        items ?? ref.watch(audioLibraryProvider.select((s) => s.audioItems));

    final settings = ref.watch(audioListSettingsProvider);

    // 排序
    final sortedItems = _sortItems(audioItems, settings.sortType);

    if (sortedItems.isEmpty) {
      return emptyState ?? _DefaultEmptyState(l10n: l10n);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sortedItems.length,
      itemBuilder: (context, index) {
        final item = sortedItems[index];
        return AudioListTile(
          audioItem: item,
          collectionId: collectionId,
          onManageCollections: () =>
              _showManageCollectionsSheet(context, item.id),
          onManageTags: () => _showManageTagsSheet(context, item.id),
          onDelete: () => _confirmDeleteAudio(context, ref, item),
        );
      },
    );
  }

  /// 按排序类型排序音频列表
  List<AudioItem> _sortItems(List<AudioItem> items, AudioSortType sortType) {
    final sorted = List<AudioItem>.from(items);
    switch (sortType) {
      case AudioSortType.nameAsc:
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case AudioSortType.nameDesc:
        sorted.sort((a, b) => b.name.compareTo(a.name));
      case AudioSortType.dateAsc:
        sorted.sort((a, b) => a.addedDate.compareTo(b.addedDate));
      case AudioSortType.dateDesc:
        sorted.sort((a, b) => b.addedDate.compareTo(a.addedDate));
    }
    return sorted;
  }

  /// 显示合集归属编辑 BottomSheet
  void _showManageCollectionsSheet(BuildContext context, String audioId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditCollectionMembershipSheet(audioId: audioId),
    );
  }

  /// 显示标签归属编辑 BottomSheet
  void _showManageTagsSheet(BuildContext context, String audioId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditTagMembershipSheet(audioId: audioId),
    );
  }

  /// 确认删除音频
  void _confirmDeleteAudio(
    BuildContext context,
    WidgetRef ref,
    AudioItem item,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 32,
        ),
        title: Text(l10n.deleteAudio),
        content: Text(l10n.deleteAudioConfirm(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(audioLibraryProvider.notifier).removeAudioItem(item.id);
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
}

/// 默认空状态视图（全局音频列表用）
class _DefaultEmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _DefaultEmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(l10n.noAudioItems, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s),
          Text(
            l10n.noAudioItemsHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AddAudioDialog(),
              );
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addAudio),
          ),
        ],
      ),
    );
  }
}

/// 音频排序按钮 — 公开组件，可在多处复用
class AudioSortButton extends ConsumerWidget {
  const AudioSortButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<AudioSortType>(
      icon: const Icon(Icons.sort),
      tooltip: l10n.sortAudio,
      onSelected: (type) {
        ref.read(audioListSettingsProvider.notifier).setSortType(type);
      },
      itemBuilder: (context) {
        final current = ref.read(audioListSettingsProvider).sortType;
        return [
          _sortMenuItem(l10n.sortByNameAsc, AudioSortType.nameAsc, current),
          _sortMenuItem(l10n.sortByNameDesc, AudioSortType.nameDesc, current),
          _sortMenuItem(l10n.sortByDateAsc, AudioSortType.dateAsc, current),
          _sortMenuItem(l10n.sortByDateDesc, AudioSortType.dateDesc, current),
        ];
      },
    );
  }

  PopupMenuItem<AudioSortType> _sortMenuItem(
    String label,
    AudioSortType type,
    AudioSortType current,
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
