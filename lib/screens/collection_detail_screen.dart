// 合集详情页面
//
// 展示合集中的音频列表，复用 AudioListView 和 AudioSortButton。
// 支持上传音频到合集。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common/svg_action_icon.dart';
import '../models/audio_item.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/audio_list_settings_provider.dart';
import '../widgets/audio_list_view.dart';
import '../widgets/guide_flow.dart';
import '../widgets/import_audio_sheet.dart';
import '../features/podcast/podcast_repository.dart';
import '../features/podcast/podcast_models.dart';
import '../features/podcast/podcast_info_sheet.dart';
import '../features/podcast/widgets/podcast_feed_summary_header.dart';
import '../features/community_collections/data/community_sync_service.dart';
import '../features/community_collections/data/trigger_community_sync.dart';
import '../features/community_collections/widgets/community_collection_header.dart';
import '../services/app_logger.dart';
import '../utils/audio_search.dart';

const _searchIconAsset = 'assets/icon/search.svg';
const _addIconAsset = 'assets/icon/plus.svg';

/// 合集详情页面 - 展示合集中的音频，支持上传音频与合集内搜索
class CollectionDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  final _keyUpload = GlobalKey();
  final _keyAudioMenu = GlobalKey();
  _PodcastRefreshViewState? _podcastRefreshState;

  /// 多选模式开关（仅用户自建合集启用）。
  bool _selectionMode = false;

  /// 多选模式下已选中的音频 id 集合。
  final Set<String> _selectedIds = {};

  /// 社区合集的排序状态，页面内独立持有（不走全局 audioListSettingsProvider，
  /// 避免污染资源库 / 用户自建合集的排序偏好）。首次打开默认「社区编排顺序」。
  AudioSortType _communitySort = AudioSortType.custom;

  /// 社区合集排序菜单的可选项
  static const _communityAllowedSorts = [
    AudioSortType.custom,
    AudioSortType.nameAsc,
    AudioSortType.nameDesc,
    AudioSortType.originalDateAsc,
    AudioSortType.originalDateDesc,
  ];

  /// 搜索入口按钮的 Key，供测试定位（图标为 SVG，不能用 byIcon 查找）。
  static const _keySearchButton = Key('collection_search_button');

  /// 合集内搜索模式开关。只过滤当前合集已加载的节目，不访问后端。
  bool _isSearching = false;

  /// 搜索输入框的原始内容；过滤与高亮时再去除首尾空格。
  String _searchQuery = '';

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  /// 列表滚动控制器。隐藏合集介绍会改变列表高度，退出搜索时需要据此恢复位置。
  final _listScrollController = ScrollController();

  /// 进入搜索前的滚动偏移，退出搜索时恢复；未进入过搜索时为 null。
  double? _scrollOffsetBeforeSearch;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  /// 搜索模式下有有效关键词时为 true，此时无匹配应显示搜索空状态。
  bool get _hasSearchKeyword => _isSearching && _searchQuery.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    ref.watch(audioLibraryProvider); // watch to rebuild when library changes

    final collection = collectionState.rawCollections
        .where((c) => c.id == widget.collectionId)
        .firstOrNull;
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Collection not found')),
      );
    }

    // 获取合集中的音频项（从 junction 表缓存中读取）
    final audioIds = collectionState.getAudioIds(widget.collectionId);
    final audioItems = audioIds
        .map((id) => ref.read(audioLibraryProvider.notifier).getItemById(id))
        .whereType<AudioItem>()
        .toList();

    final hasAudioItems = audioItems.isNotEmpty;
    // 搜索只改变展示的列表，引导与合集是否为空仍以完整合集为准。
    final visibleItems = _isSearching
        ? filterAudioItemsByKeyword(audioItems, _searchQuery)
        : audioItems;

    // 仅用户自建合集允许多选删除；社区 / 播客合集音频由后端 / RSS 管理，禁止增删。
    final canMultiSelect = !collection.isCommunity && !collection.isPodcast;
    // 当前可见列表的 id 集合，用于全选判断与剔除已失效选中项；搜索时「全选」即全选搜索结果。
    final currentIds = visibleItems.map((a) => a.id).toSet();

    final stepUpload = GuideStep(
      key: _keyUpload,
      description: l10n.guideCollectionUploadDescription,
    );
    final stepAudioMenu = GuideStep(
      key: _keyAudioMenu,
      description: l10n.guideCollectionAudioMenuDescription,
    );

    return GuideFlowSequenceHost(
      flows: [
        GuideFlow(
          flowId: GuideFlowIds.collectionDetailUpload,
          shouldRun: !collection.isCommunity && !collection.isPodcast,
          steps: [stepUpload],
        ),
        GuideFlow(
          flowId: GuideFlowIds.collectionDetailAudioList,
          shouldRun: hasAudioItems,
          steps: [stepAudioMenu],
        ),
      ],
      child: PopScope(
        // 多选态、搜索态下系统返回优先退出当前模式，而非退出页面。
        canPop: !_selectionMode && !_isSearching,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_selectionMode) {
            _exitSelection();
          } else if (_isSearching) {
            _exitSearch();
          }
        },
        child: Scaffold(
          appBar: _selectionMode
              ? _buildSelectionAppBar(context, l10n, currentIds)
              : _isSearching
              ? _buildSearchAppBar(context, l10n)
              : AppBar(
                  title: Text(collection.name),
                  actions: [
                    IconButton(
                      key: _keySearchButton,
                      icon: const SvgActionIcon(assetName: _searchIconAsset),
                      tooltip: l10n.collectionSearchTooltip,
                      onPressed: _enterSearch,
                    ),
                    // 社区合集：独立 sort state + 5 项菜单（默认 / 名称×2 / 原始发布×2）
                    // 用户合集：保持现状 —— 4 项默认菜单 + 全局 provider
                    if (collection.isCommunity)
                      AudioSortButton(
                        allowedTypes: _communityAllowedSorts,
                        current: _communitySort,
                        onChanged: (t) => setState(() => _communitySort = t),
                      )
                    else
                      const AudioSortButton(),
                    // 社区合集 / podcast 合集禁止手动添加/删除音频，按钮隐藏
                    if (!collection.isCommunity && !collection.isPodcast)
                      GuideTarget(
                        step: stepUpload,
                        child: IconButton(
                          icon: const SvgActionIcon(assetName: _addIconAsset),
                          onPressed: () => showImportAudioSheet(
                            context,
                            collectionId: collection.id,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
          body: collection.isPodcast
              ? _PodcastCollectionBody(
                  collection: collection,
                  audioItems: visibleItems,
                  guideFirstAudioMenu: hasAudioItems,
                  menuGuideStep: stepAudioMenu,
                  refreshState: _podcastRefreshState,
                  onRefresh: () => _refreshPodcastFeed(force: true),
                  isSearching: _isSearching,
                  searchQuery: _searchQuery,
                  scrollController: _listScrollController,
                  searchEmptyState: _hasSearchKeyword
                      ? _buildSearchEmptyState(l10n)
                      : null,
                )
              : _buildCollectionAudioBody(
                  context: context,
                  collection: collection,
                  audioItems: visibleItems,
                  hasAudioItems: hasAudioItems,
                  canMultiSelect: canMultiSelect,
                  menuGuideStep: stepAudioMenu,
                  l10n: l10n,
                  // 搜索时隐藏合集介绍，把空间让给结果列表。
                  header: _isSearching || !collection.isCommunity
                      ? null
                      : CommunityCollectionHeader(
                          description: collection.description,
                          authorNickname: collection.authorNickname,
                          updatedAt: collection.updatedAt,
                          fileCount: collectionState.getAudioCount(
                            collection.id,
                          ),
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildCollectionAudioBody({
    required BuildContext context,
    required Collection collection,
    required List<AudioItem> audioItems,
    required bool hasAudioItems,
    required bool canMultiSelect,
    required GuideStep menuGuideStep,
    required AppLocalizations l10n,
    Widget? header,
  }) {
    final audioList = _buildAudioList(
      context,
      collection,
      audioItems,
      hasAudioItems,
      canMultiSelect,
      menuGuideStep,
      l10n,
      header: header,
      // 列表挂载了外部 scrollController，不再是 primary，Flutter 不会再默认
      // 使用 AlwaysScrollable 物理属性；这里显式保持原有行为（短列表也可下拉、回弹）。
      scrollPhysics: const AlwaysScrollableScrollPhysics(),
    );
    if (!collection.isCommunity) return audioList;
    return RefreshIndicator(
      onRefresh: _refreshCommunityCollection,
      child: audioList,
    );
  }

  /// 构建合集文件列表；社区合集和普通合集共用列表交互与空状态处理。
  Widget _buildAudioList(
    BuildContext context,
    Collection collection,
    List<AudioItem> audioItems,
    bool hasAudioItems,
    bool canMultiSelect,
    GuideStep menuGuideStep,
    AppLocalizations l10n, {
    Widget? header,
    ScrollPhysics? scrollPhysics,
  }) {
    return AudioListView(
      items: audioItems,
      collectionId: widget.collectionId,
      guideFirstAudioMenu: hasAudioItems,
      menuGuideStep: menuGuideStep,
      header: header,
      overrideSortType: collection.isCommunity ? _communitySort : null,
      scrollPhysics: scrollPhysics,
      scrollController: _listScrollController,
      searchQuery: _searchQuery,
      // 仅用户自建合集启用多选删除。
      selectionMode: canMultiSelect && _selectionMode,
      selectedIds: _selectedIds,
      onEnterSelection: canMultiSelect ? (id) => _enterSelection(id) : null,
      onToggleSelection: canMultiSelect ? (id) => _toggleSelect(id) : null,
      emptyState: _hasSearchKeyword
          ? _buildSearchEmptyState(l10n)
          : collection.isCommunity
          ? Center(
              child: Text(
                // 区分「已下架」vs「暂无音频」：前者是后端主动下线，后者
                // 是合集刚建还没上内容，两种文案语义不同不能复用。
                collection.isDeprecated
                    ? l10n.communityCollectionDeprecated
                    : l10n.communityCollectionEmpty,
                textAlign: TextAlign.center,
              ),
            )
          : _CollectionEmptyState(
              l10n: l10n,
              onAdd: () =>
                  showImportAudioSheet(context, collectionId: collection.id),
            ),
    );
  }

  /// 搜索有关键词但无匹配时的空状态。
  Widget _buildSearchEmptyState(AppLocalizations l10n) {
    return Center(
      child: Text(l10n.collectionSearchEmpty, textAlign: TextAlign.center),
    );
  }

  /// 搜索模式 AppBar：输入框替代标题，「取消」退出搜索模式。
  AppBar _buildSearchAppBar(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      automaticallyImplyLeading: false,
      // 输入框做成带底色的圆角搜索框，让用户一眼看出这里可以输入。
      title: Container(
        height: 40,
        padding: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              // 搜索图标作为 prefixIcon 与文字交给同一个 InputDecorator 排版，
              // 两者才能按同一基线垂直对齐。
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l10n.collectionSearchHint,
                  prefixIcon: SvgActionIcon(
                    assetName: _searchIconAsset,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 0,
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
                // 键盘上的搜索键只收起键盘，不退出搜索模式。
                onSubmitted: (_) => _searchFocusNode.unfocus(),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                tooltip: l10n.collectionSearchClearTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: _clearSearchQuery,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _exitSearch, child: Text(l10n.cancel)),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 进入搜索模式。搜索前先记录滚动位置，并回到列表顶部。
  void _enterSearch() {
    if (_listScrollController.hasClients) {
      _scrollOffsetBeforeSearch = _listScrollController.offset;
      _listScrollController.jumpTo(0);
    }
    setState(() => _isSearching = true);
  }

  /// 退出搜索模式：清空关键词，恢复合集介绍与进入搜索前的滚动位置。
  void _exitSearch() {
    final offset = _scrollOffsetBeforeSearch;
    _scrollOffsetBeforeSearch = null;
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
    if (offset != null) _restoreListOffset(offset);
  }

  /// 清空关键词但保持搜索模式，并把焦点交回输入框。
  void _clearSearchQuery() {
    _searchController.clear();
    _searchFocusNode.requestFocus();
    setState(() => _searchQuery = '');
  }

  /// 在本帧布局完成后恢复滚动偏移。头部重新出现会改变内容高度，因此需要 clamp 到有效范围。
  void _restoreListOffset(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScrollController.hasClients) return;
      final position = _listScrollController.position;
      _listScrollController.jumpTo(
        offset
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    });
  }

  /// 强制同步当前订阅的社区合集，并在同步部分或全部失败时提示用户。
  Future<void> _refreshCommunityCollection() async {
    try {
      final outcome = await triggerCommunitySync(
        ref,
        localCollectionId: widget.collectionId,
      );
      if (!mounted || !_communitySyncHasFailures(outcome)) return;
      _showCommunityCollectionRefreshFailed();
    } catch (error, stackTrace) {
      AppLogger.log('CommunitySync', 'detail refresh failed: $error');
      AppLogger.log('CommunitySync', stackTrace.toString());
      if (!mounted) return;
      _showCommunityCollectionRefreshFailed();
    }
  }

  void _showCommunityCollectionRefreshFailed() {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.communityCollectionRefreshFailed)),
    );
  }

  /// 判断单合集同步结果是否包含合集级或文件级失败。
  bool _communitySyncHasFailures(CommunitySyncOutcome outcome) {
    return switch (outcome) {
      CommunitySyncFailed() => true,
      CommunitySyncCompleted(:final failedCollections, :final failedFiles) =>
        failedCollections > 0 || failedFiles > 0,
      _ => false,
    };
  }

  /// 多选工具栏 AppBar：关闭按钮 + 已选数量 + 全选/取消全选 + 删除。
  AppBar _buildSelectionAppBar(
    BuildContext context,
    AppLocalizations l10n,
    Set<String> currentIds,
  ) {
    final selectedCount = _selectedIds.length;
    final allSelected =
        currentIds.isNotEmpty && _selectedIds.containsAll(currentIds);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelection,
      ),
      title: Text(l10n.selectedCount(selectedCount)),
      actions: [
        TextButton(
          onPressed: currentIds.isEmpty
              ? null
              : () => allSelected ? _deselectAll() : _selectAll(currentIds),
          child: Text(allSelected ? l10n.deselectAll : l10n.selectAll),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.delete,
          onPressed: selectedCount == 0
              ? null
              : () => _confirmBatchDelete(context, l10n, currentIds),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 进入多选并选中首个长按项。
  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(id);
    });
  }

  /// 退出多选并清空选中。
  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// 切换单项选中态。
  void _toggleSelect(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  /// 全选当前列表。
  void _selectAll(Set<String> currentIds) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(currentIds);
    });
  }

  /// 取消全选。
  void _deselectAll() {
    setState(_selectedIds.clear);
  }

  /// 批量删除：弹二选一确认，执行「仅从合集移除」或「彻底删除」。
  Future<void> _confirmBatchDelete(
    BuildContext context,
    AppLocalizations l10n,
    Set<String> currentIds,
  ) async {
    // 与当前列表求交，剔除删除前可能已失效的选中项。
    final ids = _selectedIds.intersection(currentIds);
    if (ids.isEmpty) {
      _exitSelection();
      return;
    }
    final choice = await showDialog<_BatchDeleteChoice>(
      context: context,
      builder: (_) => _BatchDeleteDialog(count: ids.length),
    );
    if (choice == null) return;
    switch (choice) {
      case _BatchDeleteChoice.removeFromCollection:
        await ref
            .read(collectionListProvider.notifier)
            .removeAudiosFromCollection(widget.collectionId, ids);
      case _BatchDeleteChoice.deletePermanently:
        await ref.read(audioLibraryProvider.notifier).removeAudioItems(ids);
    }
    if (mounted) _exitSelection();
  }

  /// 刷新 podcast feed。
  ///
  /// 进入页面时走普通刷新，交给 repository 的通用刷新策略节流；
  /// 下拉时传 force=true 强制拉取 RSS。
  Future<void> _refreshPodcastFeed({required bool force}) async {
    if (force && mounted) {
      setState(() {
        _podcastRefreshState = _PodcastRefreshViewState.refreshing(
          DateTime.now(),
        );
      });
    }
    try {
      await ref
          .read(podcastRepositoryProvider)
          .refresh(widget.collectionId, force: force);
      if (!mounted || !force) return;
      setState(() {
        _podcastRefreshState = null;
      });
    } catch (e) {
      if (!mounted || !force) return;
      setState(() {
        _podcastRefreshState = null;
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatPodcastRefreshError(l10n, e))),
      );
    }
  }

  String _formatPodcastRefreshError(AppLocalizations l10n, Object error) {
    if (error is PodcastFeedBlockedException) {
      return l10n.podcastRefreshFailed(l10n.podcastFeedBlocked);
    }
    final raw = error.toString();
    final message = raw
        .replaceFirst('PodcastParseException: ', '')
        .replaceFirst(RegExp(r'DioException \[[^\]]+\]:\s*'), '')
        .trim();
    return l10n.podcastRefreshFailed(message.isEmpty ? raw : message);
  }
}

class _PodcastRefreshViewState {
  final DateTime time;

  const _PodcastRefreshViewState._(this.time);

  factory _PodcastRefreshViewState.refreshing(DateTime time) =>
      _PodcastRefreshViewState._(time);
}

String? _podcastRefreshStatusText(
  AppLocalizations l10n,
  Collection collection,
  _PodcastRefreshViewState? state,
) {
  return podcastRefreshStatusText(l10n, collection, refreshingAt: state?.time);
}

/// Podcast 合集详情内容：顶部展示 Feed 元信息，下面复用音频列表。
class _PodcastCollectionBody extends StatelessWidget {
  final Collection collection;
  final List<AudioItem> audioItems;
  final bool guideFirstAudioMenu;
  final GuideStep menuGuideStep;
  final _PodcastRefreshViewState? refreshState;
  final Future<void> Function() onRefresh;

  /// 搜索模式下隐藏 Feed 摘要头部，把空间让给结果列表。
  final bool isSearching;
  final String searchQuery;
  final ScrollController scrollController;

  /// 搜索有关键词但无匹配时的空状态；为 null 时沿用原有空状态。
  final Widget? searchEmptyState;

  const _PodcastCollectionBody({
    required this.collection,
    required this.audioItems,
    required this.guideFirstAudioMenu,
    required this.menuGuideStep,
    required this.refreshState,
    required this.onRefresh,
    required this.isSearching,
    required this.searchQuery,
    required this.scrollController,
    required this.searchEmptyState,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AudioListView(
        items: audioItems,
        collectionId: collection.id,
        guideFirstAudioMenu: guideFirstAudioMenu,
        menuGuideStep: menuGuideStep,
        header: isSearching
            ? null
            : _PodcastFeedHeader(
                collection: collection,
                refreshState: refreshState,
              ),
        searchQuery: searchQuery,
        scrollPhysics: const AlwaysScrollableScrollPhysics(),
        scrollController: scrollController,
        emptyState:
            searchEmptyState ??
            ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Text(
                      l10n.communityCollectionEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _PodcastFeedHeader extends StatefulWidget {
  final Collection collection;
  final _PodcastRefreshViewState? refreshState;

  const _PodcastFeedHeader({
    required this.collection,
    required this.refreshState,
  });

  @override
  State<_PodcastFeedHeader> createState() => _PodcastFeedHeaderState();
}

class _PodcastFeedHeaderState extends State<_PodcastFeedHeader> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final meta = _decodeMeta(widget.collection.podcastMetaJson);
    final description = meta?.description ?? widget.collection.description;

    return PodcastFeedSummaryHeader(
      imageUrl: null,
      description: description,
      moreLabel: l10n.podcastShowMore,
      showCover: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.m,
      ),
      onTap: () => showPodcastFeedInfoSheet(
        context,
        widget.collection,
        refreshStatusText: _podcastRefreshStatusText(
          l10n,
          widget.collection,
          widget.refreshState,
        ),
      ),
    );
  }

  PodcastFeedMeta? _decodeMeta(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return PodcastFeedMeta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// 批量删除的用户选择。
enum _BatchDeleteChoice { removeFromCollection, deletePermanently }

/// 批量删除确认弹窗。
///
/// 与单条删除弹窗（`audio_list_view.dart` 的 `_DeleteFromCollectionDialog`）保持一致：
/// 默认「从合集移除」，勾选「彻底删除」复选框后主按钮切换为破坏色的彻底删除。
/// 批量场景下音频可能分属多个合集，故默认不勾选彻底删除。
class _BatchDeleteDialog extends StatefulWidget {
  const _BatchDeleteDialog({required this.count});

  /// 待删除音频数量。
  final int count;

  @override
  State<_BatchDeleteDialog> createState() => _BatchDeleteDialogState();
}

class _BatchDeleteDialogState extends State<_BatchDeleteDialog> {
  // 默认彻底删除：多选删除的主诉求通常是清理音频，勾掉才退化为仅移除。
  bool _permanently = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = widget.count;

    return AlertDialog(
      title: Text(l10n.removeFromCollectionBatch(count)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 始终展示当前选择的影响范围提示，风格与单条删除弹窗一致。
          Text(
            _permanently
                ? l10n.permanentlyDeleteBatchHint
                : l10n.removeFromCollectionBatchHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // 彻底删除选项：复用单条删除弹窗的紧凑可点整行。
          PermanentlyDeleteOption(
            value: _permanently,
            label: l10n.permanentlyDeleteBatch(count),
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
                ? _BatchDeleteChoice.deletePermanently
                : _BatchDeleteChoice.removeFromCollection,
          ),
          style: _permanently
              ? FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                )
              : null,
          child: Text(
            _permanently ? l10n.delete : l10n.removeFromCollectionBatch(count),
          ),
        ),
      ],
    );
  }
}

/// 合集空状态视图
class _CollectionEmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onAdd;

  const _CollectionEmptyState({required this.l10n, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.perm_media_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(l10n.emptyCollection, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.l),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const SvgActionIcon(assetName: _addIconAsset),
            label: Text(l10n.addAudioToCollection),
          ),
        ],
      ),
    );
  }
}
