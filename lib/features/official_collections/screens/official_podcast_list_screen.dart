import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/collection.dart';
import '../../../providers/collection_provider.dart';
import '../../../router/app_router.dart';
import '../../auth/sign_in_required_dialog.dart';
import '../../podcast/podcast_repository.dart';
import '../../podcast/widgets/podcast_subscribe_tile.dart';
import '../data/official_catalog_service.dart';
import '../data/trigger_official_sync.dart';
import '../models/catalog.dart';
import '../providers/discover_podcasts_provider.dart';

/// 发现页精选 Podcast 二级列表。
class OfficialPodcastListScreen extends ConsumerStatefulWidget {
  const OfficialPodcastListScreen({super.key});

  @override
  ConsumerState<OfficialPodcastListScreen> createState() =>
      _OfficialPodcastListScreenState();
}

class _OfficialPodcastListScreenState
    extends ConsumerState<OfficialPodcastListScreen> {
  final Set<String> _subscribing = <String>{};

  /// 触发全局唯一 catalog 同步；与 `DiscoverCollectionsScreen` 复用同一入口。
  Future<CatalogRefreshOutcome?> _syncCatalog({bool force = false}) =>
      triggerOfficialSync(ref, force: force);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final podcasts = ref.watch(discoverPodcastsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.discoverPodcastTitle)),
      // catalog 未初始化（null）→ 居中 spinner，此时无可下拉的滚动视图；
      // 已初始化（空/有数据）→ 统一包进 RefreshIndicator 支持下拉刷新。
      body: podcasts == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                final messenger = ScaffoldMessenger.of(context);
                final outcome = await _syncCatalog(force: true);
                if (!mounted) return;
                if (outcome is CatalogUnchanged) {
                  messenger.showSnackBar(const SnackBar(content: Text('已是最新')));
                } else if (outcome is CatalogFailed) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.discoverLoadFailed)),
                  );
                }
              },
              child: podcasts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _EmptyPodcastList(
                            message: l10n.discoverPodcastEmpty,
                          ),
                        ),
                      ],
                    )
                  : _buildList(podcasts),
            ),
    );
  }

  Widget _buildList(List<CatalogPodcast> podcasts) {
    final collectionState = ref.watch(collectionListProvider);
    final feedToCollection = _podcastCollectionsByFeed(collectionState);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: podcasts.length,
      itemBuilder: (context, index) {
        final podcast = podcasts[index];
        final localCollection = feedToCollection[podcast.rssUrl];
        return PodcastSubscribeTile(
          imageUrl: podcast.imageUrl,
          title: podcast.title,
          subtitle: podcast.description,
          subscribed: localCollection != null,
          subscribing: _subscribing.contains(podcast.id),
          onOpen: () =>
              context.push(AppRoutes.discoverPodcastPreview(podcast.id)),
          onSubscribe: () => _subscribe(podcast),
          onGoLearn: () {
            if (localCollection != null) {
              context.go(AppRoutes.collectionDetail(localCollection.id));
            }
          },
        );
      },
    );
  }

  Map<String, Collection> _podcastCollectionsByFeed(CollectionState state) {
    return {
      for (final c in state.collections)
        if (c.isPodcast && c.podcastFeedUrl != null) c.podcastFeedUrl!: c,
    };
  }

  Future<void> _subscribe(CatalogPodcast podcast) async {
    final l10n = AppLocalizations.of(context)!;
    final canEnroll = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.officialCollectionSignInRequiredTitle,
      message: l10n.podcastCatalogSignInRequiredMessage,
    );
    if (!mounted || !canEnroll) return;

    setState(() => _subscribing.add(podcast.id));
    try {
      final collection = await ref
          .read(podcastRepositoryProvider)
          .createAndFetch(podcast.subscriptionInputUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enrollSucceeded)));
      context.go(AppRoutes.collectionDetail(collection.id));
    } on PodcastAlreadySubscribedException catch (e) {
      if (!mounted) return;
      final existing = ref
          .read(collectionListProvider)
          .collections
          .where((c) => c.isPodcast && c.name == e.collectionName)
          .firstOrNull;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.podcastAlreadySubscribed(e.collectionName)),
        ),
      );
      if (existing != null) {
        context.go(AppRoutes.collectionDetail(existing.id));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.podcastCatalogSubscribeFailed)),
      );
    } finally {
      if (mounted) setState(() => _subscribing.remove(podcast.id));
    }
  }
}

class _EmptyPodcastList extends StatelessWidget {
  final String message;

  const _EmptyPodcastList({required this.message});

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
