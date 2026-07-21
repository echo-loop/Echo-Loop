// 合集列表页面及可复用组件
//
// 原 CollectionScreen 保留用于 import，
// 内部组件（排序按钮、列表/网格视图、空状态、对话框）
// 导出供 LibraryScreen 复用。
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/sign_in_required_dialog.dart';
import '../features/official_collections/data/trigger_official_sync.dart';
import '../features/official_collections/providers/discover_podcasts_provider.dart';
import '../features/official_collections/providers/official_enrollment_provider.dart';
import '../features/official_collections/widgets/official_badge.dart';
import '../features/podcast/podcast_info_sheet.dart';
import '../features/podcast/podcast_repository.dart';
import '../features/podcast/podcast_search_provider.dart';
import '../features/podcast/widgets/podcast_subscribe_tile.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/app_network_image_cache.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/form_input_style.dart';
import '../widgets/audio_list_view.dart';
import '../widgets/common/secondary_action_button.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/text_input_dialog.dart';
import '../widgets/guide_flow.dart';

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
            context,
            l10n.sortByNameAsc,
            CollectionSortType.nameAsc,
            current,
          ),
          _sortMenuItem(
            context,
            l10n.sortByNameDesc,
            CollectionSortType.nameDesc,
            current,
          ),
          _sortMenuItem(
            context,
            l10n.sortByDateAsc,
            CollectionSortType.dateAsc,
            current,
          ),
          _sortMenuItem(
            context,
            l10n.sortByDateDesc,
            CollectionSortType.dateDesc,
            current,
          ),
        ];
      },
    );
  }

  PopupMenuItem<CollectionSortType> _sortMenuItem(
    BuildContext context,
    String label,
    CollectionSortType type,
    CollectionSortType current,
  ) {
    return appPopupMenuItem(
      context,
      value: type,
      label: label,
      selected: type == current,
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

/// 合集列表视图
class CollectionListView extends StatelessWidget {
  final List<Collection> collections;
  final GuideStep? firstItemStep;
  final GuideStep? firstMenuStep;

  const CollectionListView({
    super.key,
    required this.collections,
    this.firstItemStep,
    this.firstMenuStep,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // 横向 padding 为 0：卡片自己有 horizontal 12 的 margin，避免 8+12=20
      // 的双重内缩导致和顶部 DiscoverEntryBanner（horizontal 12）错位
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final isFirst = index == 0;
        return _CollectionListTile(
          collection: collections[index],
          itemStep: isFirst ? firstItemStep : null,
          menuStep: isFirst ? firstMenuStep : null,
        );
      },
    );
  }
}

/// 显示创建合集对话框（公开供 LibraryScreen 使用）
///
/// 使用统一底部 sheet：选择创建本地合集或订阅 Podcast 后，在 sheet 内完成输入。
void showCreateCollectionDialog(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CreateCollectionFlowSheet(),
  );
}

enum _CreateCollectionStep { chooseType, local, podcast }

class _CreateCollectionFlowSheet extends ConsumerStatefulWidget {
  const _CreateCollectionFlowSheet();

  @override
  ConsumerState<_CreateCollectionFlowSheet> createState() =>
      _CreateCollectionFlowSheetState();
}

class _CreateCollectionFlowSheetState
    extends ConsumerState<_CreateCollectionFlowSheet> {
  final _nameController = TextEditingController();
  _CreateCollectionStep _step = _CreateCollectionStep.chooseType;
  String? _errorText;

  /// 「订阅此链接」直连订阅进行中（阻止关闭 sheet）。
  bool _isSubmittingPodcast = false;

  /// 列表项订阅进行中的标识集合（CatalogPodcast.id / PodcastSearchResult.id）。
  final Set<String> _subscribingIds = <String>{};

  /// 任意订阅进行中：阻止 sheet 被关闭。
  bool get _busy => _isSubmittingPodcast || _subscribingIds.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CollectionSheetHeader(
                  title: _titleFor(l10n),
                  showBack: _step != _CreateCollectionStep.chooseType && !_busy,
                  onBack: _goBackToType,
                  onClose: _busy ? null : () => Navigator.pop(context),
                ),
                const SizedBox(height: AppSpacing.s),
                Flexible(
                  child: SingleChildScrollView(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _buildStep(l10n),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _titleFor(AppLocalizations l10n) {
    return switch (_step) {
      _CreateCollectionStep.chooseType => l10n.createCollection,
      _CreateCollectionStep.local => l10n.createCollection,
      _CreateCollectionStep.podcast => l10n.subscribePodcast,
    };
  }

  Widget _buildStep(AppLocalizations l10n) {
    return switch (_step) {
      _CreateCollectionStep.chooseType => _CollectionTypePanel(
        key: const ValueKey('choose-collection-type'),
        onLocal: () => _setStep(_CreateCollectionStep.local),
        onPodcast: () => _setStep(_CreateCollectionStep.podcast),
      ),
      _CreateCollectionStep.local => _LocalCollectionPanel(
        key: const ValueKey('local-collection-form'),
        controller: _nameController,
        errorText: _errorText,
        onBack: _goBackToType,
        onSubmit: _submitLocalCollection,
      ),
      _CreateCollectionStep.podcast => _PodcastSubscriptionPanel(
        key: const ValueKey('podcast-subscription-form'),
        subscribingIds: _subscribingIds,
        isSubmittingLink: _isSubmittingPodcast,
        linkErrorText: _errorText,
        onSubscribe: _subscribeItem,
        onSubscribeLink: _subscribeLink,
        onGoLearn: _goLearn,
      ),
    };
  }

  void _setStep(_CreateCollectionStep step) {
    setState(() {
      _step = step;
      _errorText = null;
    });
  }

  void _goBackToType() {
    if (_busy) return;
    _setStep(_CreateCollectionStep.chooseType);
  }

  void _submitLocalCollection() {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final error = _validateCollectionName(l10n, name);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    ref.read(collectionListProvider.notifier).createCollection(name);
    Navigator.pop(context);
  }

  String? _validateCollectionName(AppLocalizations l10n, String name) {
    if (name.isEmpty) return l10n.collectionNameEmpty;
    final exists = ref
        .read(collectionListProvider)
        .collections
        .any((c) => c.name.toLowerCase() == name.toLowerCase());
    if (exists) return l10n.collectionNameExists;
    return null;
  }

  /// 「订阅此链接」直连订阅：校验 URL → createAndFetch → 关闭 sheet 跳详情。
  ///
  /// 失败时把错误回填到面板顶部（[_errorText]），保持链接可见供用户修正。
  Future<void> _subscribeLink(String url) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.tryParse(url.trim());
    if (url.trim().isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => _errorText = l10n.audioUrlInvalid);
      return;
    }
    if (_busy) return;

    final canEnroll = await _ensureSignedIn(l10n);
    if (!mounted || !canEnroll) return;

    setState(() {
      _errorText = null;
      _isSubmittingPodcast = true;
    });
    try {
      final collection = await ref
          .read(podcastRepositoryProvider)
          .createAndFetch(url.trim());
      if (!mounted) return;
      Navigator.pop(context);
      context.go(AppRoutes.collectionDetail(collection.id));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingPodcast = false;
        _errorText = _formatPodcastError(l10n, e);
      });
    }
  }

  /// 列表项订阅（精选/搜索结果共用）：登录校验 → createAndFetch →
  /// 关闭 sheet 跳详情。用 [id] 驱动对应 tile 的 loading 态，防竞态。
  Future<void> _subscribeItem(String url, String id) async {
    final l10n = AppLocalizations.of(context)!;
    if (_busy) return;

    final canEnroll = await _ensureSignedIn(l10n);
    if (!mounted || !canEnroll) return;

    setState(() => _subscribingIds.add(id));
    try {
      final collection = await ref
          .read(podcastRepositoryProvider)
          .createAndFetch(url);
      if (!mounted) return;
      Navigator.pop(context);
      context.go(AppRoutes.collectionDetail(collection.id));
    } on PodcastAlreadySubscribedException catch (e) {
      if (!mounted) return;
      final existing = ref
          .read(collectionListProvider)
          .collections
          .where((c) => c.isPodcast && c.name == e.collectionName)
          .firstOrNull;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.podcastAlreadySubscribed(e.collectionName)),
        ),
      );
      if (existing != null) {
        Navigator.pop(context);
        context.go(AppRoutes.collectionDetail(existing.id));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_formatPodcastError(l10n, e))));
    } finally {
      if (mounted) setState(() => _subscribingIds.remove(id));
    }
  }

  /// 已订阅项「去学习」：关闭 sheet 跳到已有合集详情。
  void _goLearn(String collectionId) {
    Navigator.pop(context);
    context.go(AppRoutes.collectionDetail(collectionId));
  }

  /// 订阅动作前的登录校验（复用官方合集的登录门）。
  Future<bool> _ensureSignedIn(AppLocalizations l10n) {
    return ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.officialCollectionSignInRequiredTitle,
      message: l10n.podcastCatalogSignInRequiredMessage,
    );
  }

  String _formatPodcastError(AppLocalizations l10n, Object error) {
    if (error is PodcastAlreadySubscribedException) {
      return l10n.podcastAlreadySubscribed(error.collectionName);
    }
    if (error is PodcastFeedBlockedException) {
      return l10n.podcastFeedBlocked;
    }
    final raw = error.toString();
    final message = raw
        .replaceFirst('PodcastResolveException: ', '')
        .replaceFirst('PodcastParseException: ', '')
        .replaceFirst(RegExp(r'DioException \[[^\]]+\]:\s*'), '')
        .trim();
    return l10n.podcastSubscribeFailed(message.isEmpty ? raw : message);
  }
}

class _CollectionSheetHeader extends StatelessWidget {
  const _CollectionSheetHeader({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: showBack
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                  )
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}

class _CollectionTypePanel extends StatelessWidget {
  const _CollectionTypePanel({
    super.key,
    required this.onLocal,
    required this.onPodcast,
  });

  final VoidCallback onLocal;
  final VoidCallback onPodcast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CollectionOptionTile(
          key: const ValueKey('collection-option-local'),
          icon: Icons.create_new_folder_outlined,
          title: l10n.newCollectionOptionTitle,
          description: l10n.newCollectionOptionDescription,
          onTap: onLocal,
        ),
        const SizedBox(height: 12),
        _CollectionOptionTile(
          key: const ValueKey('collection-option-podcast'),
          icon: Icons.podcasts_rounded,
          title: l10n.subscribePodcast,
          description: l10n.subscribePodcastOptionDescription,
          onTap: onPodcast,
        ),
      ],
    );
  }
}

class _CollectionOptionTile extends StatelessWidget {
  const _CollectionOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalCollectionPanel extends StatefulWidget {
  const _LocalCollectionPanel({
    super.key,
    required this.controller,
    required this.errorText,
    required this.onBack,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  State<_LocalCollectionPanel> createState() => _LocalCollectionPanelState();
}

class _LocalCollectionPanelState extends State<_LocalCollectionPanel> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canSubmit = widget.controller.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          autofocus: true,
          style: compactFormTextStyle(context),
          textInputAction: TextInputAction.done,
          decoration: compactFormInputDecoration(
            context,
            labelText: l10n.collectionName,
            hintText: l10n.enterCollectionName,
            errorText: widget.errorText,
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(widget.controller.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => widget.onSubmit(),
        ),
        const SizedBox(height: AppSpacing.l),
        Row(
          children: [
            Expanded(
              child: SecondaryActionButton(
                onPressed: widget.onBack,
                label: l10n.back,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: canSubmit ? widget.onSubmit : null,
                child: Text(l10n.add),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 订阅 Podcast 面板：搜索框 + 列表（精选 / Apple 搜索结果 / 链接直连）。
///
/// - 搜索框为空 → 展示精选播客（复用 [discoverPodcastsProvider]）。
/// - 输入关键词 → 调 Apple iTunes Search（[podcastSearchResultsProvider]，防抖）。
/// - 输入 http/https 链接 → 自动识别，展示「订阅此链接」入口（RSS 高级用法）。
///
/// 订阅/去学习/登录校验/导航全部由父级回调完成，本面板只负责展示与分发。
class _PodcastSubscriptionPanel extends ConsumerStatefulWidget {
  const _PodcastSubscriptionPanel({
    super.key,
    required this.subscribingIds,
    required this.isSubmittingLink,
    required this.linkErrorText,
    required this.onSubscribe,
    required this.onSubscribeLink,
    required this.onGoLearn,
  });

  /// 正在订阅中的列表项标识（驱动对应 tile 的 loading）。
  final Set<String> subscribingIds;

  /// 「订阅此链接」直连订阅进行中。
  final bool isSubmittingLink;

  /// 链接直连订阅的错误文案（仅链接模式展示）。
  final String? linkErrorText;

  /// 订阅列表项：(订阅输入 URL, 状态标识 id)。
  final void Function(String url, String id) onSubscribe;

  /// 订阅粘贴的链接：(输入 URL)。
  final void Function(String url) onSubscribeLink;

  /// 已订阅项「去学习」：(本地合集 id)。
  final void Function(String collectionId) onGoLearn;

  @override
  ConsumerState<_PodcastSubscriptionPanel> createState() =>
      _PodcastSubscriptionPanelState();
}

class _PodcastSubscriptionPanelState
    extends ConsumerState<_PodcastSubscriptionPanel> {
  final _searchController = TextEditingController();

  /// 防抖后的查询词（已 trim）；驱动搜索/精选切换。
  String _query = '';
  Timer? _debounce;

  /// 精选 catalog 未初始化时惰性触发一次同步，避免重复触发。
  bool _syncTriggered = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // 立即 setState 更新清除按钮显隐；防抖 350ms 后再落到 _query。
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  /// 输入是 http/https 且 host 非空 → 返回可订阅的链接，否则 null。
  Uri? _asLink(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  /// 本地已订阅播客：feedUrl → collection，用于判定「去学习」。
  Map<String, Collection> _subscribedByFeed() {
    final state = ref.watch(collectionListProvider);
    return {
      for (final c in state.collections)
        if (c.isPodcast && c.podcastFeedUrl != null) c.podcastFeedUrl!: c,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rawText = _searchController.text;
    final link = _asLink(_query);
    final listHeight = MediaQuery.of(context).size.height * 0.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          enabled: !widget.isSubmittingLink,
          autofocus: false,
          style: compactFormTextStyle(context),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.search,
          decoration: compactFormInputDecoration(
            context,
            isDense: true,
            labelText: l10n.podcastSearchHint,
            hintText: l10n.podcastUrlHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: rawText.isEmpty || widget.isSubmittingLink
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _debounce?.cancel();
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          height: listHeight,
          child: link != null
              ? _buildLinkMode(l10n, link.toString())
              : _query.isEmpty
              ? _buildFeatured(l10n)
              : _buildSearch(l10n, _query),
        ),
      ],
    );
  }

  /// 链接模式：展示「订阅此链接」卡片。
  Widget _buildLinkMode(AppLocalizations l10n, String url) {
    return ListView(
      children: [
        if (widget.linkErrorText != null) ...[
          _CollectionInlineError(message: widget.linkErrorText!),
          const SizedBox(height: AppSpacing.s),
        ],
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.rss_feed_rounded),
            title: Text(l10n.podcastSubscribeThisLink),
            subtitle: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: widget.isSubmittingLink
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
            onTap: widget.isSubmittingLink
                ? null
                : () => widget.onSubscribeLink(url),
          ),
        ),
      ],
    );
  }

  /// 精选播客列表：null=未初始化(转圈并触发同步)，空=空态，否则列表。
  Widget _buildFeatured(AppLocalizations l10n) {
    final podcasts = ref.watch(discoverPodcastsProvider);
    if (podcasts == null) {
      if (!_syncTriggered) {
        _syncTriggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) triggerOfficialSync(ref);
        });
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (podcasts.isEmpty) {
      return _PodcastListMessage(message: l10n.discoverPodcastEmpty);
    }
    final subscribed = _subscribedByFeed();
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: podcasts.length,
      itemBuilder: (context, index) {
        final podcast = podcasts[index];
        final local = subscribed[podcast.rssUrl];
        return PodcastSubscribeTile(
          imageUrl: podcast.imageUrl,
          title: podcast.title,
          subtitle: podcast.description,
          subscribed: local != null,
          subscribing: widget.subscribingIds.contains(podcast.id),
          onSubscribe: () =>
              widget.onSubscribe(podcast.subscriptionInputUrl, podcast.id),
          onGoLearn: () {
            if (local != null) widget.onGoLearn(local.id);
          },
        );
      },
    );
  }

  /// Apple 搜索结果：loading/error/data(空态) 三态。
  Widget _buildSearch(AppLocalizations l10n, String term) {
    final async = ref.watch(podcastSearchResultsProvider(term));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _PodcastListMessage(message: l10n.podcastSearchFailed),
      data: (results) {
        if (results.isEmpty) {
          return _PodcastListMessage(message: l10n.podcastSearchEmpty);
        }
        final subscribed = _subscribedByFeed();
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: results.length,
          itemBuilder: (context, index) {
            final r = results[index];
            final local = subscribed[r.feedUrl];
            return PodcastSubscribeTile(
              imageUrl: r.artworkUrl,
              title: r.title,
              subtitle: r.author,
              subscribed: local != null,
              subscribing: widget.subscribingIds.contains(r.id),
              onSubscribe: () => widget.onSubscribe(r.feedUrl, r.id),
              onGoLearn: () {
                if (local != null) widget.onGoLearn(local.id);
              },
            );
          },
        );
      },
    );
  }
}

/// 列表区居中提示（空态 / 错误态）。
class _PodcastListMessage extends StatelessWidget {
  final String message;

  const _PodcastListMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.podcasts_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(message, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CollectionInlineError extends StatelessWidget {
  const _CollectionInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  final GuideStep? itemStep;
  final GuideStep? menuStep;

  const _CollectionListTile({
    required this.collection,
    this.itemStep,
    this.menuStep,
  });

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
    final card = Card(
      // margin 与 Discover 卡片保持一致
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
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
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildLeadingIcon(theme),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection.name,
                              style: theme.textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.audioCount(collectionState.getAudioCount(collection.id))} · ${l10n.updatedOn(formatTimeAgo(context, collection.updatedAt))}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (collection.isPodcast &&
                                podcastHasRefreshError(collection)) ...[
                              const SizedBox(height: 6),
                              _PodcastRefreshFailedChip(l10n: l10n),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _wrapWithGuideTarget(
                menuStep,
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
                    itemBuilder: (context) => collection.isPodcast
                        ? _buildPodcastMenuItems(
                            context,
                            collection,
                            l10n,
                            theme,
                          )
                        : collection.isOfficial
                        ? _buildOfficialMenuItems(
                            context,
                            collection,
                            l10n,
                            theme,
                          )
                        : _buildLocalMenuItems(
                            context,
                            collection,
                            l10n,
                            theme,
                          ),
                    onSelected: (value) {
                      if (value == 'togglePin') {
                        ref
                            .read(collectionListProvider.notifier)
                            .togglePin(collection.id);
                      } else if (value == 'rename') {
                        _showRenameCollectionDialog(context, ref, collection);
                      } else if (value == 'delete') {
                        _showDeleteConfirmDialog(context, ref, collection);
                      } else if (value == 'removeOfficial') {
                        _showRemoveOfficialConfirmDialog(
                          context,
                          ref,
                          collection,
                        );
                      } else if (value == 'podcastDetails') {
                        showPodcastFeedInfoSheet(
                          context,
                          collection,
                          refreshStatusText: podcastRefreshStatusText(
                            l10n,
                            collection,
                          ),
                        );
                      } else if (value == 'podcastUnsubscribe') {
                        _showPodcastUnsubscribeDialog(context, ref, collection);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _wrapWithGuideTarget(itemStep, card);
  }

  void _openCollection(BuildContext context) {
    context.push(AppRoutes.collectionDetail(collection.id));
  }

  /// 左侧 leading（尺寸 / 样式与 Discover 卡片完全一致）：
  /// - 官方合集且有 coverUrl：网络封面图（BoxFit.contain）
  /// - 其它情况：渐变背景 + 合集名首字母
  ///
  /// 官方合集会在右上角叠加 [OfficialCornerBadge] 角标（已下架则换成灰色 block 角标）。
  Widget _buildLeadingIcon(ThemeData theme) {
    const size = 56.0;
    final coverUrl = collection.coverUrl;

    // podcast 合集：有封面显示封面图，否则用 podcast 图标
    if (collection.isPodcast) {
      if (coverUrl != null && coverUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: coverUrl,
            cacheManager: AppNetworkImageCache.instance,
            width: size,
            height: size,
            fit: BoxFit.cover,
            // 缓存命中时立即显示，去掉默认 500ms 淡入造成的延迟感
            fadeInDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            placeholder: (_, __) => _podcastIconPlaceholder(theme, size),
            errorWidget: (_, __, ___) => _podcastIconPlaceholder(theme, size),
          ),
        );
      }
      return _podcastIconPlaceholder(theme, size);
    }

    final Widget icon =
        (collection.isOfficial && coverUrl != null && coverUrl.isNotEmpty)
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: coverUrl,
              cacheManager: AppNetworkImageCache.instance,
              width: size,
              height: size,
              fit: BoxFit.contain,
              // 缓存命中时立即显示，去掉默认 500ms 淡入造成的延迟感
              fadeInDuration: Duration.zero,
              placeholderFadeInDuration: Duration.zero,
              placeholder: (_, __) => _letterPlaceholder(theme, size),
              errorWidget: (_, __, ___) => _letterPlaceholder(theme, size),
            ),
          )
        : _letterPlaceholder(theme, size);

    if (!collection.isOfficial) return icon;

    // Stack 不裁剪溢出，让角标向外偏移 4px，营造贴在图标外缘的"app 角标"观感
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            top: -4,
            right: -4,
            child: OfficialCornerBadge(isDeprecated: collection.isDeprecated),
          ),
        ],
      ),
    );
  }

  Widget _podcastIconPlaceholder(ThemeData theme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.secondaryContainer,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.podcasts_rounded,
        size: 28,
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
  }

  /// 渐变背景 + 合集名首字母占位（与官方合集卡片 `_coverPlaceholder` 同款）。
  Widget _letterPlaceholder(ThemeData theme, double size) {
    final letter = collection.name.isEmpty
        ? '?'
        : collection.name.characters.first;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.tertiaryContainer,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PodcastRefreshFailedChip extends StatelessWidget {
  final AppLocalizations l10n;

  const _PodcastRefreshFailedChip({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                podcastRefreshFailedLabel(l10n),
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 可选包装成 GuideTarget：step 为 null 时直接返回 child。
Widget _wrapWithGuideTarget(GuideStep? step, Widget child) {
  if (step == null) return child;
  return GuideTarget(step: step, child: child);
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

/// 删除确认对话框（local 合集专用）
///
/// 提供「同时删除音频文件」复选框（默认不勾）：勾选则彻底删除合集内音频（含文件），
/// 否则仅删合集、保留音频。默认不勾以避免误删共享音频。
void _showDeleteConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  Collection collection,
) async {
  final audioCount = ref
      .read(collectionListProvider)
      .getAudioIds(collection.id)
      .length;
  final alsoDeleteAudio = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _DeleteCollectionDialog(name: collection.name, audioCount: audioCount),
  );

  if (alsoDeleteAudio == null) return;
  final notifier = ref.read(collectionListProvider.notifier);
  if (alsoDeleteAudio) {
    notifier.deleteCollectionWithAudios(collection.id);
  } else {
    notifier.deleteCollection(collection.id);
  }
}

/// 合集删除确认弹窗：默认仅删合集，勾选「同时删除音频文件」后主按钮切换为破坏色。
///
/// 返回值：`true` 表示同时删除音频，`false` 表示仅删合集，`null` 表示取消。
/// 风格与合集详情页批量删除弹窗（[_BatchDeleteDialog]）保持一致。
class _DeleteCollectionDialog extends StatefulWidget {
  const _DeleteCollectionDialog({required this.name, required this.audioCount});

  final String name;

  /// 合集内音频数量，展示在选项文案里。
  final int audioCount;

  @override
  State<_DeleteCollectionDialog> createState() =>
      _DeleteCollectionDialogState();
}

class _DeleteCollectionDialogState extends State<_DeleteCollectionDialog> {
  // 默认勾选：删合集通常意在清理音频，勾掉才退化为仅删合集。
  bool _alsoDeleteAudio = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error),
      title: Text(l10n.deleteCollection),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteCollectionConfirm(widget.name)),
          const SizedBox(height: 10),
          // 弱化提示：随选择切换，说明音频文件的去留。
          Text(
            _alsoDeleteAudio
                ? l10n.deleteCollectionDeleteAudioHint(widget.audioCount)
                : l10n.deleteCollectionKeepAudioHint(widget.audioCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // 同时删除音频文件选项：复用删除弹窗的紧凑可点整行。
          PermanentlyDeleteOption(
            value: _alsoDeleteAudio,
            label: l10n.deleteCollectionAlsoDeleteAudio,
            onChanged: (v) => setState(() => _alsoDeleteAudio = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _alsoDeleteAudio),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}

/// 从我的合集移除官方合集（彻底清空音频/字幕/学习记录）
void _showRemoveOfficialConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  Collection collection,
) async {
  final l10n = AppLocalizations.of(context)!;

  final confirmed = await showConfirmDialog(
    context: context,
    title: l10n.removeOfficialConfirmTitle(collection.name),
    message: l10n.removeOfficialConfirmMessage,
    icon: Icons.warning_amber_rounded,
    isDestructive: true,
    confirmLabel: l10n.removeOfficialConfirmConfirm,
    cancelLabel: l10n.cancel,
  );

  if (confirmed == true) {
    await ref.read(officialEnrollmentProvider.notifier).remove(collection.id);
  }
}

/// 本地合集（source='local'）的菜单项：pin/unpin 切换 / 重命名 / 删除。
List<PopupMenuEntry<String>> _buildLocalMenuItems(
  BuildContext context,
  Collection collection,
  AppLocalizations l10n,
  ThemeData theme,
) {
  return [
    appPopupMenuItem(
      context,
      value: 'togglePin',
      icon: _buildCollectionPinIcon(isPinned: collection.isPinned),
      label: collection.isPinned ? l10n.unpinCollection : l10n.pinCollection,
    ),
    appPopupMenuItem(
      context,
      value: 'rename',
      icon: const Icon(Icons.edit, size: 20),
      label: l10n.renameCollection,
    ),
    const PopupMenuDivider(height: 10),
    appPopupMenuItem(
      context,
      value: 'delete',
      icon: Icon(Icons.delete, size: 20, color: theme.colorScheme.error),
      label: l10n.delete,
      destructive: true,
    ),
  ];
}

/// 官方合集菜单项：pin（允许）/ 从我的合集移除（彻底清空）；
/// 不允许重命名、不允许删除合集内的音频。
List<PopupMenuEntry<String>> _buildOfficialMenuItems(
  BuildContext context,
  Collection collection,
  AppLocalizations l10n,
  ThemeData theme,
) {
  return [
    appPopupMenuItem(
      context,
      value: 'togglePin',
      icon: _buildCollectionPinIcon(isPinned: collection.isPinned),
      label: collection.isPinned ? l10n.unpinCollection : l10n.pinCollection,
    ),
    const PopupMenuDivider(height: 10),
    appPopupMenuItem(
      context,
      value: 'removeOfficial',
      icon: Icon(
        Icons.remove_circle_outline,
        size: 20,
        color: theme.colorScheme.error,
      ),
      label: l10n.removeFromMyCollections,
      destructive: true,
    ),
  ];
}

/// Podcast 合集菜单项：pin / 重命名 / 详情 / 退订（彻底清空）。
List<PopupMenuEntry<String>> _buildPodcastMenuItems(
  BuildContext context,
  Collection collection,
  AppLocalizations l10n,
  ThemeData theme,
) {
  return [
    appPopupMenuItem(
      context,
      value: 'togglePin',
      icon: _buildCollectionPinIcon(isPinned: collection.isPinned),
      label: collection.isPinned ? l10n.unpinCollection : l10n.pinCollection,
    ),
    appPopupMenuItem(
      context,
      value: 'rename',
      icon: const Icon(Icons.edit, size: 20),
      label: l10n.renameCollection,
    ),
    appPopupMenuItem(
      context,
      value: 'podcastDetails',
      icon: const Icon(Icons.info_outline, size: 20),
      label: l10n.podcastDetails,
    ),
    const PopupMenuDivider(height: 10),
    appPopupMenuItem(
      context,
      value: 'podcastUnsubscribe',
      icon: Icon(
        Icons.remove_circle_outline,
        size: 20,
        color: theme.colorScheme.error,
      ),
      label: l10n.podcastUnsubscribe,
      destructive: true,
    ),
  ];
}

/// 退订 podcast 合集（彻底清理单集记录、已下载文件与关联数据后删除合集）。
void _showPodcastUnsubscribeDialog(
  BuildContext context,
  WidgetRef ref,
  Collection collection,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showConfirmDialog(
    context: context,
    title: l10n.podcastUnsubscribeConfirmTitle(collection.name),
    message: l10n.podcastUnsubscribeConfirmMessage,
    icon: Icons.warning_amber_rounded,
    isDestructive: true,
    confirmLabel: l10n.podcastUnsubscribe,
    cancelLabel: l10n.cancel,
  );
  if (confirmed == true) {
    ref
        .read(collectionListProvider.notifier)
        .unsubscribePodcastCollection(collection.id);
  }
}
