import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/sign_in_required_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/audio_item.dart';
import '../../../models/collection.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../router/app_router.dart';
import '../../../widgets/audio_list_view.dart';
import '../models/community_collection_models.dart';
import '../models/community_collection_paging.dart';
import '../providers/community_collection_detail_provider.dart';
import '../providers/community_enrollment_provider.dart';
import '../providers/discover_community_collections_provider.dart';
import '../widgets/community_collection_header.dart';

/// 社区合集详情页；文件预览和加入均使用 v2 数据。
class CommunityCollectionDetailScreen extends ConsumerStatefulWidget {
  final String remoteId;

  const CommunityCollectionDetailScreen({super.key, required this.remoteId});

  @override
  ConsumerState<CommunityCollectionDetailScreen> createState() =>
      _CommunityCollectionDetailScreenState();
}

class _CommunityCollectionDetailScreenState
    extends ConsumerState<CommunityCollectionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _localCollection(ref.read(collectionListProvider)) != null) {
        return;
      }
      if (ref
              .read(communityCollectionFilesProvider(widget.remoteId))
              .valueOrNull !=
          null) {
        unawaited(_forceRefreshRemoteFiles());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final listedCatalogEntry = ref
        .watch(discoverCommunityCollectionsProvider)
        .whenOrNull(
          data: (page) => page.items
              .where((item) => item.id == widget.remoteId)
              .firstOrNull,
        );
    final collectionState = ref.watch(collectionListProvider);
    final localCollection = _localCollection(collectionState);
    final localId = localCollection?.id;

    // 已加入合集时，列表真相在本地数据库；不要为了渲染本地列表再等待远端
    // catalog 请求，避免重新进入详情页被网络加载阻塞。
    if (localCollection != null) {
      final catalogEntry = _catalogEntryFromLocal(
        localCollection,
        collectionState.getAudioCount(localCollection.id),
      );
      return Scaffold(
        appBar: AppBar(title: Text(catalogEntry.name)),
        body: _Content(
          catalogEntry: catalogEntry,
          remotePage: null,
          fileCount: collectionState.getAudioCount(localCollection.id),
          localId: localId,
          onLoadMore: () {},
          onEnroll: () => _enroll(context, ref),
          onPreviewFileTap: (_) => _showEnrollDialog(context, ref),
          onLearn: () {
            context.go(AppRoutes.collectionDetail(localCollection.id));
          },
        ),
      );
    }

    final files = ref.watch(communityCollectionFilesProvider(widget.remoteId));
    final catalogEntry = files.valueOrNull?.collection ?? listedCatalogEntry;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          files.valueOrNull?.collection?.name ?? catalogEntry?.name ?? '',
        ),
      ),
      body: files.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => RefreshIndicator(
          onRefresh: _forceRefreshRemoteFiles,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * .6,
                child: Center(child: Text('$error')),
              ),
            ],
          ),
        ),
        data: (page) => RefreshIndicator(
          onRefresh: _forceRefreshRemoteFiles,
          child: _Content(
            catalogEntry: catalogEntry,
            remotePage: page,
            fileCount: catalogEntry?.fileCount ?? page.items.length,
            localId: localId,
            onLoadMore: () => unawaited(
              ref
                  .read(
                    communityCollectionFilesProvider(widget.remoteId).notifier,
                  )
                  .loadMore(),
            ),
            onEnroll: () => _enroll(context, ref),
            onPreviewFileTap: (_) => _showEnrollDialog(context, ref),
            onLearn: () {
              if (localId != null) {
                context.go(AppRoutes.collectionDetail(localId));
              }
            },
          ),
        ),
      ),
    );
  }

  /// 强制更新公开详情的第一页，成功后由 Provider 丢弃旧分页链。
  Future<void> _forceRefreshRemoteFiles() {
    return ref
        .read(communityCollectionFilesProvider(widget.remoteId).notifier)
        .refresh(force: true);
  }

  Collection? _localCollection(CollectionState state) {
    for (final collection in state.collections) {
      if (collection.isCommunity && collection.remoteId == widget.remoteId) {
        return collection;
      }
    }
    return null;
  }

  PublicCollectionCatalogEntry _catalogEntryFromLocal(
    Collection collection,
    int count,
  ) {
    return PublicCollectionCatalogEntry(
      id: collection.remoteId ?? widget.remoteId,
      name: collection.name,
      description: collection.description,
      coverUrl: collection.coverUrl,
      authorNickname: collection.authorNickname,
      fileCount: count,
      publishedAt: collection.publishedAt ?? collection.createdDate,
      updatedAt: collection.updatedAt,
    );
  }

  /// 未加入合集时，点击预览素材先提示用户添加合集。
  Future<void> _showEnrollDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldEnroll = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.enrollNeededTitle),
        content: Text(l10n.enrollNeededMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.addToMyCollections),
          ),
        ],
      ),
    );
    if (shouldEnroll == true && context.mounted) {
      await _enroll(context, ref);
    }
  }

  Future<void> _enroll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final allowed = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.communityCollectionSignInRequiredTitle,
      message: l10n.communityCollectionSignInRequiredMessage,
    );
    if (!allowed || !context.mounted) return;
    try {
      await ref
          .read(communityEnrollmentProvider.notifier)
          .enroll(widget.remoteId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.enrollSucceeded)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.enrollFailed)));
      }
    }
  }
}

class _Content extends StatelessWidget {
  final PublicCollectionCatalogEntry? catalogEntry;
  final CommunityCollectionPagedState<CommunityCollectionFile>? remotePage;
  final int fileCount;
  final String? localId;
  final VoidCallback onLoadMore;
  final VoidCallback onEnroll;
  final ValueChanged<CommunityCollectionFile> onPreviewFileTap;
  final VoidCallback onLearn;

  const _Content({
    required this.catalogEntry,
    required this.remotePage,
    required this.fileCount,
    required this.localId,
    required this.onLoadMore,
    required this.onEnroll,
    required this.onPreviewFileTap,
    required this.onLearn,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collection = catalogEntry;
    if (collection == null) {
      return Center(child: Text(l10n.communityCollectionDeprecated));
    }
    final header = CommunityCollectionHeader(
      description: collection.description,
      authorNickname: collection.authorNickname,
      updatedAt: collection.updatedAt,
      fileCount: fileCount,
    );
    final audioList = switch (localId) {
      final String id => _LocalAudioList(localId: id, header: header),
      _ => _PreviewList(
        header: header,
        files: remotePage?.items ?? const [],
        hasMore: remotePage?.hasMore ?? false,
        isLoadingMore: remotePage?.isLoadingMore ?? false,
        loadMoreError: remotePage?.loadMoreError,
        onLoadMore: onLoadMore,
        onTap: onPreviewFileTap,
      ),
    };
    return Column(
      children: [
        Expanded(child: audioList),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: localId == null ? onEnroll : onLearn,
                child: Text(
                  localId == null ? l10n.addToMyCollections : l10n.goLearn,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocalAudioList extends ConsumerWidget {
  final String localId;
  final Widget header;

  const _LocalAudioList({required this.localId, required this.header});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionListProvider);
    final items = collection
        .getAudioIds(localId)
        .map((id) => ref.read(audioLibraryProvider.notifier).getItemById(id))
        .whereType<AudioItem>()
        .toList(growable: false);
    return AudioListView(items: items, collectionId: localId, header: header);
  }
}

class _PreviewList extends StatelessWidget {
  final Widget header;
  final List<CommunityCollectionFile> files;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final VoidCallback onLoadMore;
  final ValueChanged<CommunityCollectionFile> onTap;

  const _PreviewList({
    required this.header,
    required this.files,
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.onLoadMore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = files.isEmpty && !hasMore;
    final footerCount = isLoadingMore || loadMoreError != null ? 1 : 0;
    final contentCount = isEmpty ? 1 : files.length + footerCount;
    final itemCount = 2 + contentCount;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification &&
            notification.metrics.extentAfter < 200) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, index) {
          if (isEmpty || index == 0 || index >= files.length + 1) {
            return const SizedBox.shrink();
          }
          return const Divider(height: 1);
        },
        itemBuilder: (context, index) {
          if (index == 0) return header;
          if (index == 1) return const _PreviewListHeader();
          if (isEmpty) {
            return const SizedBox(
              height: 160,
              child: Center(child: Text('暂无文件')),
            );
          }
          final fileIndex = index - 2;
          if (fileIndex >= files.length) {
            if (isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            return Center(
              child: TextButton(
                onPressed: onLoadMore,
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            );
          }
          final file = files[fileIndex];
          final durationSec = file.durationSec;
          return ListTile(
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16,
            ),
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            leading: Icon(
              file.mediaType == CommunityMediaType.video
                  ? Icons.videocam_outlined
                  : Icons.graphic_eq,
            ),
            title: Text(
              file.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            trailing: durationSec == null || durationSec <= 0
                ? null
                : Text(
                    _formatPreviewDuration(durationSec),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
            onTap: () => onTap(file),
          );
        },
      ),
    );
  }
}

/// 未加入态预览列表的列标题，与旧版合集详情页保持一致。
class _PreviewListHeader extends StatelessWidget {
  const _PreviewListHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      // 与文件行的标题起点（16 + 图标宽 24 + 间距 12）及右侧留白对齐。
      padding: const EdgeInsetsDirectional.fromSTEB(52, 8, 16, 8),
      child: Row(
        children: [
          Expanded(child: Text(l10n.audioListColumnName, style: style)),
          Text(l10n.audioListColumnDuration, style: style),
        ],
      ),
    );
  }
}

String _formatPreviewDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '${hours}h'
        : '${hours}h ${remainingMinutes}min';
  }
  if (minutes == 0) return '${seconds}s';
  return seconds == 0
      ? '${minutes}min'
      : '$minutes:${seconds.toString().padLeft(2, '0')}';
}
