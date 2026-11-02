import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../services/app_logger.dart';
import '../data/featured_podcast_service.dart';
import '../models/featured_podcast.dart';

part 'featured_podcasts_provider.g.dart';

/// 精选 Podcast 页面所需的数据和加载状态。
class FeaturedPodcastDiscoveryState {
  final FeaturedPodcastSnapshot? snapshot;
  final bool isRefreshingFirstPage;
  final Object? firstPageError;
  final bool isLoadingMore;
  final Object? loadMoreError;

  const FeaturedPodcastDiscoveryState({
    required this.snapshot,
    this.isRefreshingFirstPage = false,
    this.firstPageError,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  FeaturedPodcastDiscoveryState copyWith({
    FeaturedPodcastSnapshot? snapshot,
    bool? isRefreshingFirstPage,
    Object? firstPageError,
    bool clearFirstPageError = false,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) => FeaturedPodcastDiscoveryState(
    snapshot: snapshot ?? this.snapshot,
    isRefreshingFirstPage: isRefreshingFirstPage ?? this.isRefreshingFirstPage,
    firstPageError: clearFirstPageError
        ? null
        : firstPageError ?? this.firstPageError,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : loadMoreError ?? this.loadMoreError,
  );
}

/// 管理精选 Podcast 的缓存恢复、页面刷新和游标分页。
@Riverpod(keepAlive: true)
class FeaturedPodcasts extends _$FeaturedPodcasts {
  Future<void> _operationQueue = Future<void>.value();
  Future<void>? _firstPageRefreshRequest;
  Future<void>? _loadMoreRequest;
  int _lifetime = 0;

  @override
  Future<FeaturedPodcastDiscoveryState> build() async {
    ref.onDispose(() => _lifetime++);
    final snapshot = await ref
        .read(featuredPodcastServiceProvider)
        .loadCachedFirstPage();
    return FeaturedPodcastDiscoveryState(snapshot: snapshot);
  }

  /// 用户每次进入精选页时刷新第一页；并发进入只共用同一次请求。
  Future<void> refreshFirstPage() {
    final inFlightRequest = _firstPageRefreshRequest;
    if (inFlightRequest != null) return inFlightRequest;

    late final Future<void> request;
    request = _serialize(_refreshFirstPage).whenComplete(() {
      if (identical(_firstPageRefreshRequest, request)) {
        _firstPageRefreshRequest = null;
      }
    });
    _firstPageRefreshRequest = request;
    return request;
  }

  /// 加载当前页游标对应的下一页；与第一页刷新串行，避免混合旧游标链。
  Future<void> loadMore() {
    final inFlightRequest = _loadMoreRequest;
    if (inFlightRequest != null) return inFlightRequest;

    late final Future<void> request;
    request = _serialize(_loadMore).whenComplete(() {
      if (identical(_loadMoreRequest, request)) _loadMoreRequest = null;
    });
    _loadMoreRequest = request;
    return request;
  }

  Future<void> _refreshFirstPage() async {
    final current = state.value ?? await future;
    final lifetime = _lifetime;
    state = AsyncData(
      current.copyWith(isRefreshingFirstPage: true, clearFirstPageError: true),
    );

    try {
      final service = ref.read(featuredPodcastServiceProvider);
      final outcome = await service.refreshFirstPage(force: true);
      if (lifetime != _lifetime) return;

      final latest = state.value ?? current;
      switch (outcome) {
        case FeaturedPodcastUpdated():
        case FeaturedPodcastUnchanged():
        case FeaturedPodcastThrottled():
          state = AsyncData(
            latest.copyWith(
              snapshot: service.cachedSnapshot ?? latest.snapshot,
              isRefreshingFirstPage: false,
              clearFirstPageError: true,
            ),
          );
        case FeaturedPodcastFailed(:final error):
          state = AsyncData(
            latest.copyWith(
              isRefreshingFirstPage: false,
              firstPageError: error,
            ),
          );
      }
    } catch (error, stackTrace) {
      AppLogger.log('FeaturedPodcast', 'first page refresh failed: $error');
      AppLogger.log('FeaturedPodcast', stackTrace.toString());
      if (lifetime != _lifetime) return;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(isRefreshingFirstPage: false, firstPageError: error),
      );
    }
  }

  Future<void> _loadMore() async {
    final current = state.value ?? await future;
    if (current.isRefreshingFirstPage || current.isLoadingMore) return;

    final cursor = current.snapshot?.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    final lifetime = _lifetime;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    var hasCachedPage = false;

    try {
      final service = ref.read(featuredPodcastServiceProvider);
      final cachedPage = await service.loadCachedPage(cursor: cursor);
      if (lifetime != _lifetime) return;
      if (cachedPage != null) {
        hasCachedPage = true;
        state = AsyncData(
          (state.value ?? current).copyWith(
            snapshot: service.cachedSnapshot,
            isLoadingMore: true,
          ),
        );
      }

      final outcome = await service.refreshPage(cursor: cursor, force: true);
      if (lifetime != _lifetime) return;

      final latest = state.value ?? current;
      switch (outcome) {
        case FeaturedPodcastUpdated():
        case FeaturedPodcastUnchanged():
        case FeaturedPodcastThrottled():
          state = AsyncData(
            latest.copyWith(
              snapshot: service.cachedSnapshot ?? latest.snapshot,
              isLoadingMore: false,
              clearLoadMoreError: true,
            ),
          );
        case FeaturedPodcastFailed(:final error):
          state = AsyncData(
            latest.copyWith(
              isLoadingMore: false,
              loadMoreError: hasCachedPage ? null : error,
              clearLoadMoreError: hasCachedPage,
            ),
          );
      }
    } catch (error, stackTrace) {
      AppLogger.log('FeaturedPodcast', 'next page refresh failed: $error');
      AppLogger.log('FeaturedPodcast', stackTrace.toString());
      if (lifetime != _lifetime) return;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          isLoadingMore: false,
          loadMoreError: hasCachedPage ? null : error,
          clearLoadMoreError: hasCachedPage,
        ),
      );
    }
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final previous = _operationQueue;
    final completer = Completer<void>();
    _operationQueue = completer.future;
    return () async {
      try {
        await previous;
        await operation();
      } finally {
        completer.complete();
      }
    }();
  }
}
