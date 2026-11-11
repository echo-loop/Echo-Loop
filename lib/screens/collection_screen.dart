// 合集列表页面及可复用组件
//
// 原 CollectionScreen 保留用于 import，
// 内部组件（排序按钮、列表/网格视图、空状态、对话框）
// 导出供 LibraryScreen 复用。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/community_collections/models/community_asset_url.dart';
import '../features/community_collections/providers/community_enrollment_provider.dart';
import '../features/community_collections/widgets/community_badge.dart';
import '../features/podcast/podcast_info_sheet.dart';
import '../features/user_region/user_region_providers.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/app_network_image_cache.dart';
import '../theme/app_theme.dart';
import '../theme/list_item_text_styles.dart';
import '../utils/time_format.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/svg_action_icon.dart';
import '../widgets/common/form_input_style.dart';
import '../widgets/audio_list_view.dart';
import '../widgets/common/secondary_action_button.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/text_input_dialog.dart';
import '../widgets/guide_flow.dart';
import '../widgets/search_highlight_text.dart';

/// 合集排序按钮（公开供 LibraryScreen 使用）
class CollectionSortButton extends ConsumerWidget {
  const CollectionSortButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<CollectionSortType>(
      icon: const SvgActionIcon(assetName: 'assets/icon/sort.svg'),
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
            icon: const SvgActionIcon(assetName: 'assets/icon/plus.svg'),
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

  /// 搜索原始输入，用于合集名称高亮；为空时不高亮。
  final String searchQuery;

  /// 嵌入到其它可滚动组件中（如资源库搜索结果头部）时设为 true，列表按内容高度收缩。
  final bool shrinkWrap;

  /// 与 [shrinkWrap] 配合使用，嵌入时传入 [NeverScrollableScrollPhysics] 交由外层滚动。
  final ScrollPhysics? physics;

  const CollectionListView({
    super.key,
    required this.collections,
    this.firstItemStep,
    this.firstMenuStep,
    this.searchQuery = '',
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // 横向 padding 为 0：卡片自己有 horizontal 12 的 margin，避免 8+12=20
      // 的双重内缩导致和顶部 DiscoverEntryBanner（horizontal 12）错位
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final isFirst = index == 0;
        return _CollectionListTile(
          collection: collections[index],
          itemStep: isFirst ? firstItemStep : null,
          menuStep: isFirst ? firstMenuStep : null,
          searchQuery: searchQuery,
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

enum _CreateCollectionStep { chooseType, local }

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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
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
                title: l10n.createCollection,
                showBack: _step != _CreateCollectionStep.chooseType,
                onBack: _goBackToType,
                onClose: () => Navigator.pop(context),
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
    );
  }

  Widget _buildStep(AppLocalizations l10n) {
    return switch (_step) {
      _CreateCollectionStep.chooseType => _CollectionTypePanel(
        key: const ValueKey('choose-collection-type'),
        onLocal: () => _setStep(_CreateCollectionStep.local),
        onPodcast: _openPodcastSubscribe,
      ),
      _CreateCollectionStep.local => _LocalCollectionPanel(
        key: const ValueKey('local-collection-form'),
        controller: _nameController,
        errorText: _errorText,
        onBack: _goBackToType,
        onSubmit: _submitLocalCollection,
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
    _setStep(_CreateCollectionStep.chooseType);
  }

  /// 「订阅 Podcast」：关闭本 sheet 并进入统一的 Podcast 搜索与订阅页。
  void _openPodcastSubscribe() {
    Navigator.pop(context);
    context.push(AppRoutes.podcastSubscribe);
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
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                  )
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
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
  final String searchQuery;

  const _CollectionListTile({
    required this.collection,
    this.itemStep,
    this.menuStep,
    this.searchQuery = '',
  });

  static const Key _kListMenuHitAreaKey = Key('collection_list_menu_hit_area');
  static const double _kTrailingMenuWidth = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    final isChinaUser = ref.watch(isChinaUserProvider);
    final theme = Theme.of(context);
    final pinnedHighlightColor = theme.colorScheme.primary.withValues(
      alpha: 0.06,
    );
    final searchDescription = buildSearchDescriptionLine(
      description: collection.description,
      searchQuery: searchQuery,
      theme: theme,
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
                      _buildLeadingIcon(theme, isChinaUser),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SearchHighlightText(
                              text: collection.name,
                              searchQuery: searchQuery,
                              style: collectionTitleStyle(theme),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (searchDescription != null) ...[
                              const SizedBox(height: 4),
                              searchDescription,
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.audioCount(collectionState.getAudioCount(collection.id))} · ${l10n.updatedOn(formatTimeAgo(context, collection.updatedAt))}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                CollectionSourceCornerBadge(
                                  source: collection.source,
                                  isDeprecated: collection.isDeprecated,
                                ),
                                if (collection.isPodcast &&
                                    podcastHasRefreshError(collection))
                                  _PodcastRefreshFailedChip(l10n: l10n),
                              ],
                            ),
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
                        : collection.isCommunity
                        ? _buildCommunityMenuItems(
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
                      } else if (value == 'removeCommunity') {
                        _showRemoveCommunityConfirmDialog(
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
  /// - 社区合集且有 coverUrl：网络封面图（BoxFit.contain）
  /// - Podcast 合集且有 coverUrl：网络封面图（BoxFit.cover）
  /// - 其它情况：渐变背景 + 合集名首字母或 Podcast 图标
  Widget _buildLeadingIcon(ThemeData theme, bool isChinaUser) {
    const size = 56.0;
    final coverUrl = collection.isCommunity
        ? communityAssetUrlForRegion(
            globalUrl: collection.coverUrl,
            chinaUrl: collection.coverUrlChina,
            isChinaUser: isChinaUser,
          )
        : collection.coverUrl;

    // podcast 合集：有封面显示封面图，否则用 podcast 图标。
    final Widget icon;
    if (collection.isPodcast) {
      if (coverUrl != null && coverUrl.isNotEmpty) {
        icon = ClipRRect(
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
      } else {
        icon = _podcastIconPlaceholder(theme, size);
      }
    } else {
      icon = (collection.isCommunity && coverUrl != null && coverUrl.isNotEmpty)
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
    }

    return icon;
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

  /// 渐变背景 + 合集名首字母占位（与社区合集卡片 `_coverPlaceholder` 同款）。
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

/// 从我的合集移除社区合集（彻底清空音频/字幕/学习记录）
void _showRemoveCommunityConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  Collection collection,
) async {
  final l10n = AppLocalizations.of(context)!;

  final confirmed = await showConfirmDialog(
    context: context,
    title: l10n.removeCommunityConfirmTitle(collection.name),
    message: l10n.removeCommunityConfirmMessage,
    icon: Icons.warning_amber_rounded,
    isDestructive: true,
    confirmLabel: l10n.removeCommunityConfirmConfirm,
    cancelLabel: l10n.cancel,
  );

  if (confirmed == true) {
    await ref.read(communityEnrollmentProvider.notifier).remove(collection.id);
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

/// 社区合集菜单项：pin（允许）/ 从我的合集移除（彻底清空）；
/// 不允许重命名、不允许删除合集内的音频。
List<PopupMenuEntry<String>> _buildCommunityMenuItems(
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
      value: 'removeCommunity',
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
