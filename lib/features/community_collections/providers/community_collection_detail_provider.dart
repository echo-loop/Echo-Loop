import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/community_collection_cache.dart';
import '../models/community_collection_models.dart';
import '../models/community_collection_paging.dart';

part 'community_collection_detail_provider.g.dart';

/// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。
@riverpod
class CommunityCollectionFiles extends _$CommunityCollectionFiles {
  int _operationToken = 0;

  @override
  Future<CommunityCollectionPagedState<CommunityCollectionFile>> build(
    String collectionId,
  ) {
    ref.onDispose(() => _operationToken++);
    return _loadFirstPage();
  }

  /// 手动刷新第一页，并丢弃已经不属于新 cursor 链的后续页面。
  Future<void> refresh({bool force = false}) async {
    final token = ++_operationToken;
    final service = ref.read(communityCollectionCatalogServiceProvider);
    final outcome = await service.refreshFilesPage(
      collectionId,
      cursor: null,
      force: force,
    );
    if (token != _operationToken) return;

    switch (outcome) {
      case CommunityCollectionRefreshUpdated<
        CommunityCollectionCatalogPage<CommunityCollectionFile>
      >(
        :final items,
      ):
        state = AsyncData(CommunityCollectionPagedState.fromFirstPage(items));
      case CommunityCollectionRefreshThrottled<
        CommunityCollectionCatalogPage<CommunityCollectionFile>
      >():
        break;
      case CommunityCollectionRefreshFailed<
        CommunityCollectionCatalogPage<CommunityCollectionFile>
      >(
        :final error,
        :final stackTrace,
      ):
        if (state.valueOrNull == null) {
          state = AsyncError(error, stackTrace);
        }
    }
  }

  /// 加载当前 cursor 链上的下一页；同一时间只允许一个分页请求。
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    final cursor = current.nextCursor;
    if (cursor == null || cursor.isEmpty) return;
    final token = ++_operationToken;
    final service = ref.read(communityCollectionCatalogServiceProvider);
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );

    final cached = await service.loadCachedFilesPage(
      collectionId,
      cursor: cursor,
    );
    if (token != _operationToken) return;
    final hasCachedPage = cached != null;
    var latest = state.valueOrNull ?? current;
    if (cached != null) {
      latest = latest.replacePage(cached);
      state = AsyncData(latest.copyWith(isLoadingMore: true));
    }

    final outcome = await service.refreshFilesPage(
      collectionId,
      cursor: cursor,
      force: true,
    );
    if (token != _operationToken) return;
    latest = state.valueOrNull ?? latest;
    switch (outcome) {
      case CommunityCollectionRefreshUpdated<
        CommunityCollectionCatalogPage<CommunityCollectionFile>
      >(
        :final items,
      ):
        state = AsyncData(
          (hasCachedPage ? latest.replacePage(items) : latest.appendPage(items))
              .copyWith(isLoadingMore: false, clearLoadMoreError: true),
        );
      case CommunityCollectionRefreshThrottled<
        CommunityCollectionCatalogPage<CommunityCollectionFile>
      >():
        state = AsyncData(
          latest.copyWith(isLoadingMore: false, clearLoadMoreError: true),
        );
      case CommunityCollectionRefreshFailed<
        CommunityCollectionCatalogPage<CommunityCollectionFile>
      >(
        :final error,
      ):
        state = AsyncData(
          latest.copyWith(
            isLoadingMore: false,
            loadMoreError: hasCachedPage ? null : error,
            clearLoadMoreError: hasCachedPage,
          ),
        );
    }
  }

  Future<CommunityCollectionPagedState<CommunityCollectionFile>>
  _loadFirstPage() async {
    final token = ++_operationToken;
    final service = ref.read(communityCollectionCatalogServiceProvider);
    final cached = await service.loadCachedFilesPage(
      collectionId,
      cursor: null,
    );
    if (token != _operationToken) {
      return state.valueOrNull ??
          const CommunityCollectionPagedState(pages: []);
    }

    CommunityCollectionPagedState<CommunityCollectionFile>? cachedState;
    if (cached != null) {
      cachedState = CommunityCollectionPagedState.fromFirstPage(cached);
      state = AsyncData(cachedState);
    }

    final outcome = await service.refreshFilesPage(
      collectionId,
      cursor: null,
      force: true,
    );
    if (token != _operationToken) {
      return state.valueOrNull ??
          cachedState ??
          const CommunityCollectionPagedState(pages: []);
    }
    switch (outcome) {
      case CommunityCollectionRefreshUpdated<
        CommunityCollectionCatalogPage<CommunityCollectionFile>
      >(
        :final items,
      ):
        return CommunityCollectionPagedState.fromFirstPage(items);
      case CommunityCollectionRefreshThrottled<
        CommunityCollectionCatalogPage<CommunityCollectionFile>
      >():
        return cachedState ?? const CommunityCollectionPagedState(pages: []);
      case CommunityCollectionRefreshFailed<
        CommunityCollectionCatalogPage<CommunityCollectionFile>
      >(
        :final error,
        :final stackTrace,
      ):
        if (cachedState != null) return cachedState;
        Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
