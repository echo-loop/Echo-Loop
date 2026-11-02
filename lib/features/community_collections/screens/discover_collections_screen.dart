import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../auth/sign_in_required_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/collection_provider.dart';
import '../../../router/app_router.dart';
import '../models/community_collection_models.dart';
import '../models/community_collection_paging.dart';
import '../community_collection_routes.dart';
import '../data/trigger_community_catalog_refresh.dart';
import '../../user_region/user_region_providers.dart';
import '../providers/community_enrollment_provider.dart';
import '../providers/discover_community_collections_provider.dart';
import '../widgets/community_collection_card.dart';

/// 社区合集发现页；公开列表由 v2 cursor API 提供，页面只负责展示和动作分发。
class DiscoverCommunityCollectionsScreen extends ConsumerStatefulWidget {
  const DiscoverCommunityCollectionsScreen({super.key});

  @override
  ConsumerState<DiscoverCommunityCollectionsScreen> createState() =>
      _DiscoverCommunityCollectionsScreenState();
}

class _DiscoverCommunityCollectionsScreenState
    extends ConsumerState<DiscoverCommunityCollectionsScreen> {
  static const _loadMoreThreshold = 200.0;

  final Set<String> _enrolling = <String>{};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Provider 保持存活，列表页再次入栈时主动更新缓存目录。
      if (ref.read(discoverCommunityCollectionsProvider).value != null) {
        unawaited(
          ref
              .read(discoverCommunityCollectionsProvider.notifier)
              .refresh(force: true),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < _loadMoreThreshold) {
      unawaited(
        ref.read(discoverCommunityCollectionsProvider.notifier).loadMore(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverCommunityCollectionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.discoverCommunityCollections),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onRetry: () =>
              unawaited(triggerCommunityCatalogRefresh(ref, force: true)),
        ),
        data: (page) => _buildList(context, page),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    CommunityCollectionPagedState<PublicCollectionCatalogEntry> page,
  ) {
    final items = page.items;
    final collectionState = ref.watch(collectionListProvider);
    final isChinaUser = ref.watch(isChinaUserProvider);
    final enrolledRemoteIds = <String>{};
    for (final collection in collectionState.collections) {
      final remoteId = collection.remoteId;
      if (collection.isCommunity && remoteId != null) {
        enrolledRemoteIds.add(remoteId);
      }
    }
    final contentCount = 1 + (items.isEmpty ? 1 : items.length);
    return RefreshIndicator(
      onRefresh: _forceRefreshCatalog,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            contentCount +
            (page.isLoadingMore || page.loadMoreError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == contentCount) {
            return _CommunityLoadMoreFooter(
              isLoading: page.isLoadingMore,
              onRetry: () => unawaited(
                ref
                    .read(discoverCommunityCollectionsProvider.notifier)
                    .loadMore(),
              ),
            );
          }
          if (index == 0) {
            return const _PodcastDiscoverEntry();
          }
          if (items.isEmpty) {
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * .6,
              child: Center(
                child: Text(AppLocalizations.of(context)!.discoverEmpty),
              ),
            );
          }
          final item = items[index - 1];
          return CommunityCollectionCard(
            item: item,
            isChinaUser: isChinaUser,
            enrolled: enrolledRemoteIds.contains(item.id),
            enrolling: _enrolling.contains(item.id),
            onOpenDetail: () => context.push(
              CommunityCollectionRoutes.discoverCollection(item.id),
            ),
            onEnroll: () => _enroll(item),
          );
        },
      ),
    );
  }

  /// 强制刷新公开合集目录；发现页浏览不触发已订阅内容同步。
  Future<void> _forceRefreshCatalog() {
    return triggerCommunityCatalogRefresh(ref, force: true);
  }

  Future<void> _enroll(PublicCollectionCatalogEntry item) async {
    final l10n = AppLocalizations.of(context)!;
    final canEnroll = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.communityCollectionSignInRequiredTitle,
      message: l10n.communityCollectionSignInRequiredMessage,
    );
    if (!mounted || !canEnroll) return;
    setState(() => _enrolling.add(item.id));
    try {
      final result = await ref
          .read(communityEnrollmentProvider.notifier)
          .enroll(item.id);
      if (mounted && result.createdNew) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.enrollSucceeded)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.enrollFailed)));
      }
    } finally {
      if (mounted) setState(() => _enrolling.remove(item.id));
    }
  }
}

class _CommunityLoadMoreFooter extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onRetry;

  const _CommunityLoadMoreFooter({
    required this.isLoading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    return Center(
      child: TextButton(
        onPressed: onRetry,
        child: Text(AppLocalizations.of(context)!.retry),
      ),
    );
  }
}

/// `/discover` 中显示的 Apple Podcasts 入口。
class _PodcastDiscoverEntry extends StatelessWidget {
  const _PodcastDiscoverEntry();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.podcastSubscribe),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const _PodcastEntryImage(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.discoverPodcastEntryTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PodcastEntryImage extends StatelessWidget {
  const _PodcastEntryImage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.secondaryContainer,
      ),
      child: Icon(
        Icons.podcasts_rounded,
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 56,
        child: SvgPicture.asset(
          'assets/icon/apple-podcasts.svg',
          fit: BoxFit.cover,
          placeholderBuilder: (_) => placeholder,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(AppLocalizations.of(context)!.discoverLoadFailed),
      ),
    );
  }
}
