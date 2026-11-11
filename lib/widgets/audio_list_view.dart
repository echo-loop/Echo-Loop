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
import '../providers/collection_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'audio_list_tile.dart';
import 'common/app_popup_menu.dart';
import 'common/svg_action_icon.dart';
import 'dialogs/confirm_dialog.dart';
import 'edit_collection_membership_sheet.dart';
import 'edit_tag_membership_sheet.dart';
import 'guide_flow.dart';
import 'import_audio_sheet.dart';

/// 判断 [target] 的音频文件是否被库中其他条目共享。
///
/// 同内容音频导入时会复用同一磁盘文件（多个条目指向同一 `audioPath`）。删除某个
/// 条目时，仅当没有其他条目引用同一文件，文件才会被真正删除。返回 `true` 表示仍有
/// 其他条目共享该文件，删除本条目不会删掉音频文件。`audioPath` 为空（未就绪）时返回
/// `false`。
bool isAudioFileSharedByOthers(List<AudioItem> items, AudioItem target) {
  final path = target.audioPath;
  if (path == null) return false;
  return items.any((other) => other.id != target.id && other.audioPath == path);
}

/// 按排序类型排序音频列表（置顶项固定在前，不参与排序）。
///
/// [AudioSortType.custom] 保持传入顺序不变（置顶项仍然提前）。
/// [AudioSortType.originalDateAsc/Desc] 中 `originalDate == null` 统一排到末尾。
List<AudioItem> sortAudioItems(List<AudioItem> items, AudioSortType sortType) {
  final pinned = items.where((i) => i.isPinned).toList();
  final unpinned = items.where((i) => !i.isPinned).toList();

  // custom：保持原顺序，仅做 pinned 前置
  if (sortType == AudioSortType.custom) {
    return [...pinned, ...unpinned];
  }

  // originalDate 比较：null 统一排到末尾
  int cmpByOriginalDate(AudioItem a, AudioItem b, {required bool asc}) {
    final da = a.originalDate;
    final db = b.originalDate;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return asc ? da.compareTo(db) : db.compareTo(da);
  }

  int Function(AudioItem, AudioItem) comparator;
  switch (sortType) {
    case AudioSortType.custom:
      comparator = (_, __) => 0; // 上面已 return，这里只为穷举
    case AudioSortType.nameAsc:
      comparator = (a, b) => a.name.compareTo(b.name);
    case AudioSortType.nameDesc:
      comparator = (a, b) => b.name.compareTo(a.name);
    case AudioSortType.dateAsc:
      comparator = (a, b) => a.addedDate.compareTo(b.addedDate);
    case AudioSortType.dateDesc:
      comparator = (a, b) => b.addedDate.compareTo(a.addedDate);
    case AudioSortType.originalDateAsc:
      comparator = (a, b) => cmpByOriginalDate(a, b, asc: true);
    case AudioSortType.originalDateDesc:
      comparator = (a, b) => cmpByOriginalDate(a, b, asc: false);
  }

  pinned.sort((a, b) => b.addedDate.compareTo(a.addedDate));
  unpinned.sort(comparator);
  return [...pinned, ...unpinned];
}

/// 音频列表视图 — 资源库全局列表和合集详情页共用
class AudioListView extends ConsumerStatefulWidget {
  /// 外部传入的音频列表（合集场景），为 null 时从 provider 读取
  final List<AudioItem>? items;

  /// 合集 ID — 传递给 AudioListTile
  final String? collectionId;

  /// 自定义空状态组件
  final Widget? emptyState;

  /// 列表首项；适用于需要随文件一起滚动的详情摘要。
  final Widget? header;

  /// 是否将第一条音频的菜单作为合集详情引导 target。
  final bool guideFirstAudioMenu;

  /// 外部传入的菜单引导步骤。传入后由外部 flow 统一调度，避免嵌套 flow 抢先启动。
  final GuideStep? menuGuideStep;

  /// 当前音频列表是否允许启动页面引导。
  final bool guideEnabled;

  /// 覆盖全局 [audioListSettingsProvider] 的排序类型。
  /// 非 null 时：使用此值排序，不再 watch provider（适用于社区合集详情页等
  /// 需要独立 sort state 的场景）。
  final AudioSortType? overrideSortType;

  /// 覆盖滚动物理属性，例如下拉刷新需要的始终可滚动行为。
  final ScrollPhysics? scrollPhysics;

  /// 是否处于多选模式（合集详情页批量删除）。默认关闭，库/播客场景零影响。
  final bool selectionMode;

  /// 多选模式下已选中的音频 id 集合。
  final Set<String> selectedIds;

  /// 长按某项时回调 —— 进入多选并选中该 id（由外层注入）。
  final ValueChanged<String>? onEnterSelection;

  /// 多选模式下点击某项时回调 —— 切换该 id 选中态（由外层注入）。
  final ValueChanged<String>? onToggleSelection;

  /// 合集内搜索的原始输入，透传给每个 [AudioListTile] 用于高亮。
  final String searchQuery;

  /// 外部持有的滚动控制器。合集详情页用它在进入/退出搜索时保存并恢复滚动位置。
  final ScrollController? scrollController;

  const AudioListView({
    super.key,
    this.items,
    this.collectionId,
    this.emptyState,
    this.header,
    this.guideFirstAudioMenu = false,
    this.menuGuideStep,
    this.guideEnabled = true,
    this.overrideSortType,
    this.scrollPhysics,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onEnterSelection,
    this.onToggleSelection,
    this.searchQuery = '',
    this.scrollController,
  });

  @override
  ConsumerState<AudioListView> createState() => _AudioListViewState();
}

class _AudioListViewState extends ConsumerState<AudioListView> {
  // Guide step keys 在 state 层持有，避免 rebuild 时重建导致 showcaseview
  // 拿到过期的 key。
  final _keyAudioMenu = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 数据来源：外部传入 or provider
    final List<AudioItem> audioItems =
        widget.items ??
        ref.watch(audioLibraryProvider.select((s) => s.audioItems));

    // 受控模式（overrideSortType 非 null）下不再 watch provider，避免全局排序
    // 变化把社区合集详情页的独立 sort state 误刷。
    final AudioSortType sortType =
        widget.overrideSortType ??
        ref.watch(audioListSettingsProvider).sortType;

    // 排序
    final sortedItems = _sortItems(audioItems, sortType);

    if (sortedItems.isEmpty) {
      final emptyState = widget.emptyState ?? _DefaultEmptyState(l10n: l10n);
      final header = widget.header;
      if (header == null) return emptyState;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          header,
          SizedBox(height: 280, child: emptyState),
        ],
      );
    }

    final showMenuGuide = widget.guideEnabled && widget.guideFirstAudioMenu;

    final stepAudioMenu =
        widget.menuGuideStep ??
        GuideStep(
          key: _keyAudioMenu,
          description: l10n.guideCollectionAudioMenuDescription,
        );

    final header = widget.header;
    final headerCount = header == null ? 0 : 1;
    final listView = ListView.builder(
      controller: widget.scrollController,
      padding: header == null ? const EdgeInsets.all(8) : EdgeInsets.zero,
      physics: widget.scrollPhysics,
      itemCount: sortedItems.length + headerCount,
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header;
        final itemIndex = index - headerCount;
        final item = sortedItems[itemIndex];
        final isFirst = itemIndex == 0;
        final tile = AudioListTile(
          audioItem: item,
          collectionId: widget.collectionId,
          searchQuery: widget.searchQuery,
          menuStep: (isFirst && showMenuGuide) ? stepAudioMenu : null,
          onManageCollections: () =>
              _showManageCollectionsSheet(context, item.id),
          onManageTags: () => _showManageTagsSheet(context, item.id),
          onDelete: () => _confirmDeleteAudio(context, ref, item),
          selectionMode: widget.selectionMode,
          selected: widget.selectedIds.contains(item.id),
          onLongPress: widget.onEnterSelection == null
              ? null
              : () => widget.onEnterSelection!(item.id),
          onSelectToggle: widget.onToggleSelection == null
              ? null
              : () => widget.onToggleSelection!(item.id),
        );
        return tile;
      },
    );

    if (!showMenuGuide || widget.menuGuideStep != null) return listView;

    return GuideFlowSequenceHost(
      flows: [
        GuideFlow(
          flowId: GuideFlowIds.collectionDetailAudioList,
          shouldRun: true,
          steps: [if (showMenuGuide) stepAudioMenu],
        ),
      ],
      child: listView,
    );
  }

  List<AudioItem> _sortItems(List<AudioItem> items, AudioSortType sortType) {
    return sortAudioItems(items, sortType);
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

  /// 确认删除音频。
  ///
  /// 分两种上下文：
  /// - 资源库（collectionId 为空）：删除即彻底删除音频（含文件），无额外选项。
  /// - 合集详情页：默认仅"从当前合集移除"，并提供"彻底删除该音频"复选框（默认不勾）。
  ///   若音频还属于其它合集，弹窗列出全部所属合集，提醒彻底删除会从所有合集消失。
  Future<void> _confirmDeleteAudio(
    BuildContext context,
    WidgetRef ref,
    AudioItem item,
  ) async {
    final collectionId = widget.collectionId;
    if (collectionId == null) {
      await _confirmDeleteFromLibrary(context, ref, item);
    } else {
      await _confirmDeleteFromCollection(context, ref, item, collectionId);
    }
  }

  /// 资源库上下文：彻底删除音频。
  Future<void> _confirmDeleteFromLibrary(
    BuildContext context,
    WidgetRef ref,
    AudioItem item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    // 同一音频文件可能被多个条目共享（历史遗留重复条目）。仅当本条目是唯一引用该
    // 文件的条目时，删除才会真正删掉音频文件，此时才提示"永久删除"。
    final fileSharedByOthers = isAudioFileSharedByOthers(
      ref.read(audioLibraryProvider).audioItems,
      item,
    );
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteAudio,
      message: fileSharedByOthers
          ? l10n.deleteAudioConfirmKeepFile(item.name)
          : l10n.deleteAudioConfirm(item.name),
      icon: Icons.warning_amber_rounded,
      isDestructive: true,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
    );
    if (confirmed == true) {
      ref.read(audioLibraryProvider.notifier).removeAudioItem(item.id);
    }
  }

  /// 合集上下文：默认从当前合集移除，可选彻底删除。
  Future<void> _confirmDeleteFromCollection(
    BuildContext context,
    WidgetRef ref,
    AudioItem item,
    String collectionId,
  ) async {
    // 收集该音频所属的「其它」合集名称（排除当前合集），用于提示彻底删除的影响范围
    // 并决定复选框默认值：仅当前合集引用时默认彻底删除，被其它合集引用时默认仅移除。
    final collectionState = ref.read(collectionListProvider);
    final memberCollectionIds =
        collectionState.audioToCollectionsMap[item.id] ?? const [];
    final otherCollectionNames = <String>[];
    for (final cId in memberCollectionIds) {
      if (cId == collectionId) continue;
      final c = collectionState.rawCollections
          .where((c) => c.id == cId)
          .firstOrNull;
      if (c != null) otherCollectionNames.add(c.name);
    }

    final choice = await showDialog<_DeleteAudioChoice>(
      context: context,
      builder: (_) => _DeleteFromCollectionDialog(
        audioName: item.name,
        otherCollectionNames: otherCollectionNames,
      ),
    );
    if (choice == null) return;
    switch (choice) {
      case _DeleteAudioChoice.removeFromCollection:
        await ref
            .read(collectionListProvider.notifier)
            .removeAudioFromCollection(collectionId, item.id);
      case _DeleteAudioChoice.deletePermanently:
        await ref.read(audioLibraryProvider.notifier).removeAudioItem(item.id);
    }
  }
}

/// 合集详情页删除音频的用户选择。
enum _DeleteAudioChoice { removeFromCollection, deletePermanently }

/// 合集上下文的删除弹窗：默认"从合集移除"，可勾选"彻底删除该音频"。
///
/// 复选框默认值取决于引用情况：被其它合集引用时默认仅移除（false），仅当前合集
/// 引用时默认彻底删除（true）。弹窗以弱化的小字提示音频还属于哪些合集 / 未被其它
/// 合集引用，帮助用户判断是否安全彻底删除。
class _DeleteFromCollectionDialog extends StatefulWidget {
  const _DeleteFromCollectionDialog({
    required this.audioName,
    required this.otherCollectionNames,
  });

  final String audioName;

  /// 该音频所属的「其它」合集名称（不含当前合集）。
  final List<String> otherCollectionNames;

  @override
  State<_DeleteFromCollectionDialog> createState() =>
      _DeleteFromCollectionDialogState();
}

class _DeleteFromCollectionDialogState
    extends State<_DeleteFromCollectionDialog> {
  late bool _permanently;

  @override
  void initState() {
    super.initState();
    // 仅当前合集引用 → 默认彻底删除；被其它合集引用 → 默认仅移除。
    _permanently = widget.otherCollectionNames.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sharedByOthers = widget.otherCollectionNames.isNotEmpty;
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return AlertDialog(
      title: Text(l10n.removeFromCollection),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.removeFromCollectionConfirm(widget.audioName)),
          const SizedBox(height: 10),
          // 弱化提示：还属于哪些合集 / 未被其它合集引用。
          Text(
            sharedByOthers
                ? l10n.audioBelongsToCollections(
                    widget.otherCollectionNames.join('、'),
                  )
                : l10n.audioNotInOtherCollections,
            style: hintStyle,
          ),
          const SizedBox(height: 12),
          // 彻底删除选项：紧凑的可点整行，默认值见 initState。
          PermanentlyDeleteOption(
            value: _permanently,
            onChanged: (v) => setState(() => _permanently = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _permanently
                ? _DeleteAudioChoice.deletePermanently
                : _DeleteAudioChoice.removeFromCollection,
          ),
          style: _permanently
              ? FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                )
              : null,
          child: Text(_permanently ? l10n.delete : l10n.removeFromCollection),
        ),
      ],
    );
  }
}

/// 「彻底删除该音频」紧凑选项行。
///
/// 整行可点切换，左侧小复选框，右侧标题，风格与 app 内其它删除弹窗一致。
/// 单条删除与合集批量删除共用，[label] 为空时用单条默认文案。
class PermanentlyDeleteOption extends StatelessWidget {
  const PermanentlyDeleteOption({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// 选项文案，为空时回退到单条删除文案 `permanentlyDeleteAudio`。
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = value;
    final accent = colorScheme.error;

    return Material(
      color: selected
          ? accent.withValues(alpha: 0.08)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeColor: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label ?? l10n.permanentlyDeleteAudio,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
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
              showImportAudioSheet(context);
            },
            icon: const SvgActionIcon(assetName: 'assets/icon/plus.svg'),
            label: Text(l10n.addAudio),
          ),
        ],
      ),
    );
  }
}

/// 音频排序按钮 — 公开组件，可在多处复用。
///
/// **默认模式**（无参）：菜单固定 4 项（名称 ×2 + 日期 ×2），读写全局
/// `audioListSettingsProvider`。
///
/// **受控模式**（`allowedTypes` + `current` + `onChanged` 三者非 null）：
/// 菜单内容完全由调用方决定，状态也由调用方管理，provider 不参与。
/// 社区合集详情页用此模式避免全局 sort 被污染。
/// 排序按钮图标（SVG，与合集搜索图标同一套线性风格）。
const _sortIconAsset = 'assets/icon/sort.svg';

class AudioSortButton extends ConsumerWidget {
  /// 受控模式：显示的选项子集（按数组顺序）。为 null 走默认模式。
  final List<AudioSortType>? allowedTypes;

  /// 受控模式当前选中值。
  final AudioSortType? current;

  /// 受控模式的选中回调。
  final ValueChanged<AudioSortType>? onChanged;

  const AudioSortButton({
    super.key,
    this.allowedTypes,
    this.current,
    this.onChanged,
  });

  bool get _isControlled =>
      allowedTypes != null && current != null && onChanged != null;

  Widget _sortIcon() => const SvgActionIcon(assetName: _sortIconAsset);

  /// 每种 SortType 对应的 i18n 标签
  String _labelFor(AudioSortType t, AppLocalizations l10n) {
    switch (t) {
      case AudioSortType.custom:
        return l10n.sortDefault;
      case AudioSortType.nameAsc:
        return l10n.sortByNameAsc;
      case AudioSortType.nameDesc:
        return l10n.sortByNameDesc;
      case AudioSortType.dateAsc:
        return l10n.sortByDateAsc;
      case AudioSortType.dateDesc:
        return l10n.sortByDateDesc;
      case AudioSortType.originalDateAsc:
        return l10n.sortByOriginalDateAsc;
      case AudioSortType.originalDateDesc:
        return l10n.sortByOriginalDateDesc;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    if (_isControlled) {
      final types = allowedTypes!;
      final cur = current!;
      return PopupMenuButton<AudioSortType>(
        icon: _sortIcon(),
        onSelected: (t) => onChanged!(t),
        itemBuilder: (context) => [
          for (final t in types)
            _sortMenuItem(context, _labelFor(t, l10n), t, cur),
        ],
      );
    }

    // 默认模式：读写全局 provider，固定 4 项
    return PopupMenuButton<AudioSortType>(
      icon: _sortIcon(),
      onSelected: (type) {
        ref.read(audioListSettingsProvider.notifier).setSortType(type);
      },
      itemBuilder: (context) {
        final cur = ref.read(audioListSettingsProvider).sortType;
        return [
          _sortMenuItem(
            context,
            l10n.sortByNameAsc,
            AudioSortType.nameAsc,
            cur,
          ),
          _sortMenuItem(
            context,
            l10n.sortByNameDesc,
            AudioSortType.nameDesc,
            cur,
          ),
          _sortMenuItem(
            context,
            l10n.sortByDateAsc,
            AudioSortType.dateAsc,
            cur,
          ),
          _sortMenuItem(
            context,
            l10n.sortByDateDesc,
            AudioSortType.dateDesc,
            cur,
          ),
        ];
      },
    );
  }

  PopupMenuItem<AudioSortType> _sortMenuItem(
    BuildContext context,
    String label,
    AudioSortType type,
    AudioSortType current,
  ) {
    return appPopupMenuItem(
      context,
      value: type,
      label: label,
      selected: type == current,
    );
  }
}
