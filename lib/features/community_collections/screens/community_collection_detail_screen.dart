import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/sign_in_required_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/collection.dart';
import '../../../providers/collection_provider.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../models/community_collection_models.dart';
import '../models/community_collection_paging.dart';
import '../providers/community_collection_detail_provider.dart';
import '../providers/community_enrollment_provider.dart';
import '../providers/discover_community_collections_provider.dart';
import '../widgets/community_collection_header.dart';
import '../widgets/community_difficulty_badge.dart';

/// 社区合集公开详情页；文件列表统一使用公开详情数据，订阅状态只决定底部操作。
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
      if (!mounted) return;
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
    final localId = _localCollection(collectionState)?.id;

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

  /// 按远端 ID 查找本地订阅，仅用于选择底部操作及学习跳转目标。
  Collection? _localCollection(CollectionState state) {
    for (final collection in state.collections) {
      if (collection.isCommunity && collection.remoteId == widget.remoteId) {
        return collection;
      }
    }
    return null;
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
  final VoidCallback onLearn;

  const _Content({
    required this.catalogEntry,
    required this.remotePage,
    required this.fileCount,
    required this.localId,
    required this.onLoadMore,
    required this.onEnroll,
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
    final audioList = _PreviewList(
      header: header,
      files: remotePage?.items ?? const [],
      hasMore: remotePage?.hasMore ?? false,
      isLoadingMore: remotePage?.isLoadingMore ?? false,
      loadMoreError: remotePage?.loadMoreError,
      onLoadMore: onLoadMore,
    );
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

class _PreviewList extends StatelessWidget {
  final Widget header;
  final List<CommunityCollectionFile> files;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final VoidCallback onLoadMore;

  const _PreviewList({
    required this.header,
    required this.files,
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = files.isEmpty && !hasMore;
    final footerCount = isLoadingMore || loadMoreError != null ? 1 : 0;
    final contentCount = isEmpty ? 1 : files.length + footerCount;
    final itemCount = 1 + contentCount;
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
          if (isEmpty || index >= files.length) {
            return const SizedBox.shrink();
          }
          return Divider(
            key: index == 0
                ? const ValueKey('community-collection-files-start-divider')
                : null,
            height: 1,
          );
        },
        itemBuilder: (context, index) {
          if (index == 0) return header;
          if (isEmpty) {
            return const SizedBox(
              height: 160,
              child: Center(child: Text('暂无文件')),
            );
          }
          final fileIndex = index - 1;
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
          return _CommunityCollectionPreviewTile(file: file);
        },
      ),
    );
  }
}

/// 独立构建单条预览素材，使文字与图标直接依赖当前主题并在主题切换时刷新。
class _CommunityCollectionPreviewTile extends StatelessWidget {
  const _CommunityCollectionPreviewTile({required this.file});

  final CommunityCollectionFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final durationSec = file.durationSec;
    final difficulty = file.difficulty;
    final mediaTypeLabel = switch (file.mediaType) {
      CommunityMediaType.audio => l10n.exportAudioFile,
      CommunityMediaType.video => l10n.exportVideoFile,
    };
    final mediaTypeIcon = switch (file.mediaType) {
      CommunityMediaType.audio => Icons.graphic_eq,
      CommunityMediaType.video => Icons.videocam_outlined,
    };
    final mediaTypeColor = switch (file.mediaType) {
      CommunityMediaType.audio => theme.colorScheme.primary,
      CommunityMediaType.video => AppTheme.videoMediaTypeColor(
        theme.brightness,
      ),
    };
    final durationLabel = durationSec == null || durationSec <= 0
        ? null
        : _formatPreviewDuration(durationSec);
    final description = file.description?.trim();
    final Widget? descriptionSubtitle =
        description == null || description.isEmpty
        ? null
        : Text(
            description,
            key: ValueKey('community-collection-file-description-${file.id}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color.lerp(
                theme.colorScheme.onSurfaceVariant,
                theme.colorScheme.surface,
                0.22,
              ),
              height: 1.3,
            ),
          );

    return ListTile(
      key: ValueKey(file.id),
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      title: Row(
        children: [
          Semantics(
            key: ValueKey('community-collection-file-type-${file.id}'),
            label: mediaTypeLabel,
            child: ExcludeSemantics(
              child: SizedBox.square(
                dimension: 24,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(mediaTypeIcon, size: 22, color: mediaTypeColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              file.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: descriptionSubtitle,
      trailing: difficulty == null && durationLabel == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (difficulty != null)
                  CommunityDifficultyBadge(difficulty: difficulty),
                if (difficulty != null && durationLabel != null)
                  const SizedBox(height: 4),
                if (durationLabel != null)
                  Text(
                    durationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
