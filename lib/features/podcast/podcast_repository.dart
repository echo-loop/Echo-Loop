/// Podcast Repository
///
/// 负责：创建 podcast 合集、刷新 Feed（10 分钟节流 + inflight 合并）、
/// guid 去重入库。不触发字幕 API，由用户手动触发。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../models/audio_item.dart';
import '../../models/collection.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/collection_provider.dart';
import '../../services/app_logger.dart';
import '../../services/refresh_coordinator.dart';
import 'anti_bot_detector.dart';
import 'podcast_feed_parser.dart';
import 'podcast_models.dart';
import 'podcast_url_resolver.dart';

part 'podcast_repository.g.dart';

/// 10 分钟节流阈值
const _refreshThrottleMinutes = 10;

/// 重复订阅同一播客时抛出，携带已有合集名供 UI 提示。
class PodcastAlreadySubscribedException implements Exception {
  final String collectionName;
  const PodcastAlreadySubscribedException(this.collectionName);
  @override
  String toString() => 'PodcastAlreadySubscribedException: $collectionName';
}

/// 源站返回反爬/人机验证挑战页、Dio 无法通过时抛出。
class PodcastFeedBlockedException implements Exception {
  const PodcastFeedBlockedException();
  @override
  String toString() => 'PodcastFeedBlockedException';
}

@riverpod
PodcastRepository podcastRepository(Ref ref) {
  return PodcastRepository(ref);
}

class PodcastRepository {
  final Ref _ref;
  final Dio _dio;
  final PodcastUrlResolver _urlResolver;
  final PodcastFeedParser _feedParser;

  final RefreshCoordinator<String, void> _refresh;

  PodcastRepository(
    this._ref, {
    Dio? dio,
    PodcastUrlResolver? urlResolver,
    PodcastFeedParser? feedParser,
    RefreshCoordinator<String, void>? refreshCoordinator,
  }) : _dio = dio ?? Dio(),
       _urlResolver = urlResolver ?? PodcastUrlResolver(dio: dio),
       _feedParser = feedParser ?? PodcastFeedParser(),
       _refresh = refreshCoordinator ?? RefreshCoordinator<String, void>();

  // ── 创建 Podcast 合集 ─────────────────────────────────────────────────

  /// 通过用户输入的 URL 创建 podcast 合集并完成首次 Feed 拉取。
  ///
  /// 成功后合集和音频条目（占位，未下载）已入库。
  Future<Collection> createAndFetch(String inputUrl) async {
    final feedUrl = await _urlResolver.resolve(inputUrl);

    // 判重：同一 Feed 已订阅则拒绝创建，提示已有合集名
    final existing = _ref
        .read(collectionListProvider)
        .rawCollections
        .where((c) => c.isPodcast && c.podcastFeedUrl == feedUrl)
        .firstOrNull;
    if (existing != null) {
      throw PodcastAlreadySubscribedException(existing.name);
    }

    final feedContent = await _fetchFeedContent(feedUrl);
    final result = _feedParser.parse(feedContent, feedUrl: feedUrl);

    final now = DateTime.now();
    final collection = Collection(
      id: const Uuid().v4(),
      name: result.meta.title,
      createdDate: now,
      source: CollectionSource.podcast,
      coverUrl: result.meta.imageUrl,
      description: result.meta.description,
      podcastInputUrl: inputUrl,
      podcastFeedUrl: feedUrl,
      podcastMetaJson: jsonEncode(result.meta.toJson()),
      podcastLastRefreshedAt: now,
    );

    // 先把合集写入状态（_upsertCollection 内部处理）
    await _ref
        .read(collectionListProvider.notifier)
        .createPodcastCollection(collection);

    // 把 episodes 入库（去重）
    await _importEpisodes(result.episodes, collectionId: collection.id);
    return collection;
  }

  // ── 刷新 ─────────────────────────────────────────────────────────────

  /// 刷新 podcast 合集的 Feed，写入新 episode。
  ///
  /// [force] = true 跳过 10 分钟节流。
  /// 同一合集若已有进行中的刷新，直接返回同一个 Future（inflight 合并）。
  Future<void> refresh(String collectionId, {bool force = false}) {
    final collections = _ref.read(collectionListProvider).rawCollections;
    final collection = collections
        .where((c) => c.id == collectionId)
        .firstOrNull;
    if (collection == null || !collection.isPodcast) return Future.value();

    AppLogger.log(
      'PodcastRefresh',
      'repo refresh start collectionId=${collection.id} '
          'name=${collection.name} force=$force '
          'lastRefreshedAt=${collection.podcastLastRefreshedAt?.toIso8601String() ?? "(null)"}',
    );

    return _refresh
        .run(
          key: collectionId,
          force: force,
          lastRefreshedAt: collection.podcastLastRefreshedAt,
          throttleWindow: const Duration(minutes: _refreshThrottleMinutes),
          refresh: () => _doRefresh(collection),
        )
        .then((result) {
          switch (result) {
            case RefreshThrottled<void>():
              AppLogger.log(
                'PodcastRefresh',
                'repo refresh throttled collectionId=${collection.id} '
                    'name=${collection.name}',
              );
            case RefreshCompleted<void>():
              AppLogger.log(
                'PodcastRefresh',
                'repo refresh done collectionId=${collection.id} '
                    'name=${collection.name}',
              );
          }
        });
  }

  Future<void> _doRefresh(Collection collection) async {
    final feedUrl = collection.podcastFeedUrl;
    if (feedUrl == null) return;

    final refreshedAt = DateTime.now();
    try {
      AppLogger.log(
        'PodcastRefresh',
        'load feed start collectionId=${collection.id} '
            'name=${collection.name} feedUrl=$feedUrl',
      );
      final feed = await _loadFeedWithAppleFallback(collection, feedUrl);
      final result = feed.result;

      // 更新 feed 元信息 + 刷新状态。
      final updated = collection.copyWith(
        podcastLastRefreshedAt: refreshedAt,
        clearPodcastLastRefreshError: true,
        podcastMetaJson: jsonEncode(result.meta.toJson()),
        coverUrl: result.meta.imageUrl ?? collection.coverUrl,
        podcastFeedUrl: feed.url,
      );
      await _ref
          .read(collectionListProvider.notifier)
          .updatePodcastCollection(updated);

      final addedCount = await _importEpisodes(
        result.episodes,
        collectionId: collection.id,
      );
      AppLogger.log(
        'PodcastRefresh',
        'load feed success collectionId=${collection.id} '
            'name=${collection.name} resolvedFeedUrl=${feed.url} '
            'episodes=${result.episodes.length} added=$addedCount',
      );
    } catch (e) {
      final failed = collection.copyWith(
        podcastLastRefreshedAt: refreshedAt,
        podcastLastRefreshError: e.toString(),
      );
      await _ref
          .read(collectionListProvider.notifier)
          .updatePodcastCollection(failed, touchUpdatedAt: false);
      AppLogger.log(
        'PodcastRefresh',
        'load feed failed collectionId=${collection.id} '
            'name=${collection.name} feedUrl=$feedUrl error=$e',
      );
      rethrow;
    }
  }

  // ── 内部辅助 ─────────────────────────────────────────────────────────

  Future<_PodcastFeedLoadResult> _loadFeedWithAppleFallback(
    Collection collection,
    String feedUrl,
  ) async {
    try {
      return await _loadFeed(feedUrl);
    } catch (_) {
      final inputUrl = collection.podcastInputUrl;
      if (inputUrl == null || !_isApplePodcastUrl(inputUrl)) rethrow;

      final resolvedFeedUrl = await _urlResolver.resolve(inputUrl);
      if (resolvedFeedUrl == feedUrl) rethrow;

      return _loadFeed(resolvedFeedUrl);
    }
  }

  Future<_PodcastFeedLoadResult> _loadFeed(String feedUrl) async {
    final content = await _fetchFeedContent(feedUrl);
    return _PodcastFeedLoadResult(
      url: feedUrl,
      result: _feedParser.parse(content, feedUrl: feedUrl),
    );
  }

  Future<String> _fetchFeedContent(String feedUrl) async {
    AppLogger.log('PodcastRefresh', 'rss request → GET $feedUrl');
    final response = await _dio.get<String>(
      feedUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final content = response.data;
    AppLogger.log(
      'PodcastRefresh',
      'rss response ← GET ${response.realUri} '
          '${response.statusCode ?? "(null)"} '
          'bytes=${content?.length ?? 0}',
    );
    if (content == null || content.isEmpty) {
      throw const PodcastParseException('Feed 内容为空');
    }
    if (isAntiBotChallenge(
      contentType: response.headers.value('content-type'),
      body: content,
    )) {
      throw const PodcastFeedBlockedException();
    }
    return content;
  }

  bool _isApplePodcastUrl(String inputUrl) {
    final uri = Uri.tryParse(inputUrl.trim());
    final host = uri?.host.toLowerCase();
    return host != null &&
        (host.contains('podcasts.apple.com') ||
            host.contains('itunes.apple.com'));
  }

  /// 将 episodes 入库；只在同一合集内按 guid 去重。
  Future<int> _importEpisodes(
    List<PodcastEpisode> episodes, {
    required String collectionId,
  }) async {
    final audioLib = _ref.read(audioLibraryProvider.notifier);
    final collList = _ref.read(collectionListProvider.notifier);

    // 获取该合集已有的 guid 集合（避免重复）
    final existingItems = _ref.read(audioLibraryProvider).audioItems;
    final collectionAudioIds = _ref
        .read(collectionListProvider)
        .getAudioIds(collectionId)
        .toSet();
    final existingGuids = existingItems
        .where((item) => collectionAudioIds.contains(item.id))
        .map((item) => item.podcastEpisodeGuid)
        .whereType<String>()
        .toSet();

    final newItems = <AudioItem>[];
    for (final episode in episodes) {
      if (existingGuids.contains(episode.guid)) continue;

      final now = DateTime.now();
      final item = AudioItem(
        id: const Uuid().v4(),
        name: episode.title,
        addedDate: episode.pubDate ?? now,
        originalDate: episode.pubDate,
        totalDuration: episode.durationSeconds ?? 0,
        // audioPath = null：懒下载，用户点击后才下载
        podcastEpisodeGuid: episode.guid,
        podcastEnclosureUrl: episode.enclosureUrl,
        podcastEnclosureType: episode.enclosureType,
        podcastDescription: episode.description,
        podcastImageUrl: episode.imageUrl,
        podcastLink: episode.link,
      );

      newItems.add(item);
    }

    if (newItems.isEmpty) return 0;
    await audioLib.addAudioItems(newItems);
    await collList.addAudiosToCollection(
      collectionId,
      newItems.map((item) => item.id).toList(),
    );
    return newItems.length;
  }
}

class _PodcastFeedLoadResult {
  final String url;
  final PodcastFeedResult result;

  const _PodcastFeedLoadResult({required this.url, required this.result});
}
