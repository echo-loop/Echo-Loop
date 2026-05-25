import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/collection_provider.dart';
import '../../../router/app_router.dart';
import '../../../services/app_logger.dart';
import '../data/official_catalog_service.dart';
import '../data/trigger_official_sync.dart';
import '../models/catalog.dart';
import '../providers/discover_collections_provider.dart';
import '../providers/official_enrollment_provider.dart';
import '../widgets/official_collection_card.dart';

const _logTag = 'DiscoverScreen';

/// 发现官方合集页。
///
/// 数据来源：本地 catalog 缓存（`cachedCatalogProvider`）。零网络。
///
/// 三态显式渲染：
/// - catalog 未初始化（首次安装等）→ loading
/// - catalog 已初始化但 collections 空 → empty
/// - catalog 有 collections → list + RefreshIndicator
///
/// 触发同步：
/// - initState 时若 `!hasInitialized` → 主动 fire-and-forget syncAll（兜底冷启动失败）
/// - 下拉刷新 → await syncAll(force: true)
/// - 不在此处单独触发任何 API 请求
class DiscoverCollectionsScreen extends ConsumerStatefulWidget {
  const DiscoverCollectionsScreen({super.key});

  @override
  ConsumerState<DiscoverCollectionsScreen> createState() =>
      _DiscoverCollectionsScreenState();
}

class _DiscoverCollectionsScreenState
    extends ConsumerState<DiscoverCollectionsScreen> {
  /// 当前正在 enroll 的 remoteId（让卡片 + 按钮转 spinner）
  final Set<String> _enrolling = <String>{};

  @override
  void initState() {
    super.initState();
    // 首次安装 / 文件损坏 / 上次冷启动失败时的兜底：本地无缓存就立即拉。
    // inflight 防重入保证不会和 main.dart 启动时那次重复发请求。
    final svc = ref.read(officialCatalogServiceProvider);
    if (!svc.hasInitialized) {
      AppLogger.log(
        _logTag,
        'initState: catalog not initialized, triggering syncAll',
      );
      unawaited(_syncCatalog());
    }
  }

  /// 触发全局唯一同步；helper 内部处理 outcome=updated 后的
  /// loadLibrary + loadCollections + invalidate catalog。
  Future<CatalogRefreshOutcome?> _syncCatalog({bool force = false}) =>
      triggerOfficialSync(ref, force: force);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collections = ref.watch(discoverCollectionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.discoverOfficialCollections)),
      body: _buildBody(collections, l10n),
    );
  }

  Widget _buildBody(
    List<CatalogCollection>? collections,
    AppLocalizations l10n,
  ) {
    // null = catalog 未初始化 → loading
    if (collections == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // empty = 已初始化但无合集 → empty 状态（仍允许下拉刷新）
    return RefreshIndicator(
      onRefresh: () async {
        final outcome = await _syncCatalog(force: true);
        if (!mounted) return;
        if (outcome is CatalogUnchanged) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.discoverEmpty == '' ? '' : '已是最新')),
          );
        } else if (outcome is CatalogFailed) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.discoverLoadFailed)));
        }
      },
      child: collections.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _EmptyState(message: l10n.discoverEmpty),
                ),
              ],
            )
          : _buildList(collections),
    );
  }

  Widget _buildList(List<CatalogCollection> items) {
    final collectionState = ref.watch(collectionListProvider);
    final enrolledRemoteIds = {
      for (final c in collectionState.collections)
        if (c.isOfficial && c.remoteId != null) c.remoteId!,
    };
    final remoteIdToLocalId = {
      for (final c in collectionState.collections)
        if (c.isOfficial && c.remoteId != null) c.remoteId!: c.id,
    };
    AppLogger.log(
      _logTag,
      'build list: catalog=${items.length}, enrolled=${enrolledRemoteIds.length}',
    );

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final enrolled = enrolledRemoteIds.contains(item.id);
        final enrolling = _enrolling.contains(item.id);
        return OfficialCollectionCard(
          item: item,
          enrolled: enrolled,
          enrolling: enrolling,
          onOpenDetail: () => context.push('/discover/${item.id}'),
          onEnroll: () => _handleEnroll(item),
          onGoLearn: () {
            final localId = remoteIdToLocalId[item.id];
            if (localId != null) {
              // 用 go 不用 push：/discover 在 root navigator，
              // /collections/xxx 在 shell branch。跨 navigator push
              // 会触发 go_router 17 + Flutter 3.24+ 的重复 page key assertion。
              context.go(AppRoutes.collectionDetail(localId));
            }
          },
        );
      },
    );
  }

  Future<void> _handleEnroll(CatalogCollection item) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    AppLogger.log(
      _logTag,
      'tap enroll remoteId=${item.id} name="${item.name}"',
    );
    setState(() => _enrolling.add(item.id));
    try {
      final result = await ref
          .read(officialEnrollmentProvider.notifier)
          .enroll(item.id);
      AppLogger.log(
        _logTag,
        'enroll returned localId=${result.localCollectionId} '
        'createdNew=${result.createdNew}',
      );
      if (!mounted) return;
      if (result.createdNew) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.enrollSucceeded)));
      }
    } catch (e) {
      AppLogger.log(_logTag, 'enroll threw: $e');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.enrollFailed)));
    } finally {
      if (mounted) {
        setState(() => _enrolling.remove(item.id));
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_outlined,
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
