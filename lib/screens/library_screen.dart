// 资源库页面
//
// 展示合集列表；有搜索关键词时，IndexedStack 切换到全局搜索结果。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/community_collections/widgets/discover_entry_banner.dart';
import '../providers/new_user_guide_provider.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common/search_app_bar.dart';
import '../widgets/common/svg_action_icon.dart';
import '../widgets/guide_flow.dart';
import 'collection_screen.dart';
import 'library_search_results.dart';

/// 资源库页面 — 合集列表，支持全局搜索
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _keyCreateCollection = GlobalKey();

  /// 搜索模式开关。搜索模式下 AppBar 换成搜索框，关键词为空时仍显示完整列表。
  bool _isSearching = false;

  /// 搜索输入的原始内容；过滤时再去除首尾空格。
  String _searchQuery = '';

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// 有有效关键词时展示全局搜索结果，替代当前视图。
  bool get _showsSearchResults =>
      _isSearching && _searchQuery.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    final stepCreateCollection = GuideStep(
      key: _keyCreateCollection,
      description: l10n.guideLibraryCreateCollectionDescription,
    );

    return GuideFlowSequenceHost(
      flows: [
        GuideFlow(
          flowId: GuideFlowIds.libraryCreateCollection,
          // 搜索态下创建按钮不在 AppBar 上，引导目标不可见，不启动。
          shouldRun: !collectionState.isLoading && !_isSearching,
          steps: [stepCreateCollection],
        ),
      ],
      child: PopScope(
        // 搜索态下系统返回先退出搜索，而非离开资源库。
        canPop: !_isSearching,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isSearching) _exitSearch();
        },
        child: Scaffold(
          appBar: _isSearching
              ? SearchAppBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hintText: l10n.librarySearchHint,
                  query: _searchQuery,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onClear: _clearSearchQuery,
                  onCancel: _exitSearch,
                )
              : AppBar(
                  title: Text(l10n.myLibrary),
                  actions: _buildActions(l10n, stepCreateCollection),
                ),
          // 搜索结果与合集列表共用 IndexedStack：仅在需要时挂载结果页，避免无关过滤计算。
          body: IndexedStack(
            index: _showsSearchResults ? 1 : 0,
            children: [
              const _CollectionListBody(),
              if (_showsSearchResults)
                LibrarySearchResults(query: _searchQuery),
            ],
          ),
        ),
      ),
    );
  }

  /// 进入搜索模式。
  void _enterSearch() {
    setState(() => _isSearching = true);
  }

  /// 退出搜索模式：清空关键词，恢复当前视图。
  void _exitSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
  }

  /// 清空关键词但保持搜索模式，并把焦点交回输入框。
  void _clearSearchQuery() {
    _searchController.clear();
    _searchFocusNode.requestFocus();
    setState(() => _searchQuery = '');
  }

  /// 构建 AppBar actions
  List<Widget> _buildActions(AppLocalizations l10n, GuideStep createStep) {
    return [
      IconButton(
        key: const Key('library_search_button'),
        icon: const SvgActionIcon(assetName: 'assets/icon/search.svg'),
        tooltip: l10n.librarySearchTooltip,
        onPressed: _enterSearch,
      ),
      // 合集排序
      const CollectionSortButton(),
      // 「发现社区合集」入口已改为列表顶部的 DiscoverEntryBanner，更醒目；
      // AppBar 这里不再放 compass icon，避免重复。
      // 创建合集
      GuideTarget(
        step: createStep,
        child: IconButton(
          icon: const SvgActionIcon(assetName: 'assets/icon/plus.svg'),
          onPressed: () => showCreateCollectionDialog(context),
        ),
      ),
      const SizedBox(width: 8),
    ];
  }
}

/// 合集列表视图体（不含 Scaffold/AppBar）
class _CollectionListBody extends ConsumerWidget {
  const _CollectionListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionState = ref.watch(collectionListProvider);
    // Banner 在 loading / empty / data 三态下都显示，让新用户一进来就看到入口。
    return Column(
      children: [
        const DiscoverEntryBanner(),
        Expanded(child: _buildInner(collectionState)),
      ],
    );
  }

  Widget _buildInner(CollectionState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isEmpty) return const CollectionEmptyState();
    return CollectionListView(collections: state.collections);
  }
}
