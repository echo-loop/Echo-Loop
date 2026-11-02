/// 播客内容预览（只读）：拉取 RSS 并解析 episode 列表，不写入本地库。
///
/// 由订阅输入 URL 驱动（RSS 或 Apple Podcasts 链接），供精选 Podcast、Apple
/// 搜索结果和用户粘贴链接共用。只有用户明确订阅后才进入
/// [PodcastRepository.createAndFetch] 创建本地合集。
library;

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../services/refresh_coordinator.dart';
import '../../services/app_logger.dart';
import 'anti_bot_detector.dart';
import 'podcast_feed_parser.dart';
import 'podcast_models.dart';
import 'podcast_url_resolver.dart';

part 'podcast_preview_provider.g.dart';

/// Podcast 预览失败类型。
enum PodcastPreviewErrorKind {
  network,
  timeout,
  appleLookup,
  rssUnavailable,
  parseFailed,
  emptyFeed,

  /// 源站返回了反爬/人机验证挑战页，Dio 无法通过。
  blockedByAntiBot,
}

/// Podcast 预览失败。UI 只展示本类型映射后的友好文案。
class PodcastPreviewException implements Exception {
  final PodcastPreviewErrorKind kind;
  final Object? cause;

  const PodcastPreviewException(this.kind, [this.cause]);

  @override
  String toString() => 'PodcastPreviewException($kind, cause: $cause)';
}

/// Podcast 内容预览数据。
class PodcastPreviewData {
  final PodcastFeedMeta meta;
  final List<PodcastEpisode> episodes;

  const PodcastPreviewData({required this.meta, required this.episodes});
}

class _PodcastPreviewCacheEntry {
  final PodcastPreviewData data;
  final DateTime fetchedAt;

  const _PodcastPreviewCacheEntry({
    required this.data,
    required this.fetchedAt,
  });
}

@Riverpod(keepAlive: true)
Dio podcastPreviewDio(Ref ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
}

@Riverpod(keepAlive: true)
PodcastPreviewService podcastPreviewService(Ref ref) {
  return PodcastPreviewService(
    dio: ref.watch(podcastPreviewDioProvider),
    resolver: PodcastUrlResolver(dio: ref.watch(podcastPreviewDioProvider)),
    parser: PodcastFeedParser(),
  );
}

const _kPreviewRefreshWindow = Duration(minutes: 10);

/// 只读预览服务：解析订阅输入 URL → 拉取 RSS → 解析 episode，不写入本地库。
class PodcastPreviewService {
  final Dio _dio;
  final PodcastUrlResolver _resolver;
  final PodcastFeedParser _parser;
  final RefreshCoordinator<String, PodcastPreviewData> _refresh;
  final DateTime Function() _now;
  final Map<String, _PodcastPreviewCacheEntry> _cacheByFeedUrl = {};

  PodcastPreviewService({
    required Dio dio,
    required PodcastUrlResolver resolver,
    required PodcastFeedParser parser,
    RefreshCoordinator<String, PodcastPreviewData>? refreshCoordinator,
    DateTime Function()? now,
  }) : _dio = dio,
       _resolver = resolver,
       _parser = parser,
       _refresh =
           refreshCoordinator ??
           RefreshCoordinator<String, PodcastPreviewData>(
             now: now ?? DateTime.now,
           ),
       _now = now ?? DateTime.now;

  /// 由订阅输入 URL（RSS 或 Apple 链接）拉取预览。
  ///
  /// Apple 链接先经 [PodcastUrlResolver] 解析为 feedUrl；RSS 链接直接使用。
  /// 结果按解析后的 feedUrl 缓存并 10 分钟节流。
  Future<PodcastPreviewData> fetchByUrl(
    String inputUrl, {
    bool force = false,
  }) async {
    AppLogger.log(
      'PodcastPreview',
      'preview start inputUrl=$inputUrl force=$force',
    );
    try {
      final feedUrl = await _resolveFeedUrl(inputUrl);
      AppLogger.log('PodcastPreview', 'feed resolved url=$feedUrl');
      final cached = _cacheByFeedUrl[feedUrl];
      final result = await _refresh.run(
        key: feedUrl,
        force: force,
        lastRefreshedAt: cached?.fetchedAt,
        throttleWindow: _kPreviewRefreshWindow,
        refresh: () async {
          final data = await _fetchAndParse(feedUrl);
          _cacheByFeedUrl[feedUrl] = _PodcastPreviewCacheEntry(
            data: data,
            fetchedAt: _now(),
          );
          return data;
        },
      );
      final data = switch (result) {
        RefreshThrottled<PodcastPreviewData>() =>
          _cacheByFeedUrl[feedUrl]?.data ?? await _fetchAndParse(feedUrl),
        RefreshCompleted<PodcastPreviewData>(:final result) => result,
      };
      AppLogger.log(
        'PodcastPreview',
        'preview success feedUrl=$feedUrl episodes=${data.episodes.length}',
      );
      return data;
    } catch (error, stackTrace) {
      AppLogger.log(
        'PodcastPreview',
        'preview failed inputUrl=$inputUrl force=$force error=$error',
      );
      AppLogger.log('PodcastPreview', stackTrace.toString());
      rethrow;
    }
  }

  Future<PodcastPreviewData> _fetchAndParse(String feedUrl) async {
    final feedContent = await _fetchFeedContent(feedUrl);
    try {
      final result = _parser.parse(feedContent, feedUrl: feedUrl);
      if (result.episodes.isEmpty) {
        throw const PodcastPreviewException(PodcastPreviewErrorKind.emptyFeed);
      }
      return PodcastPreviewData(meta: result.meta, episodes: result.episodes);
    } on PodcastPreviewException {
      rethrow;
    } on PodcastParseException catch (e, stackTrace) {
      AppLogger.log(
        'PodcastPreview',
        'rss parse failed feedUrl=$feedUrl error=$e',
      );
      AppLogger.log('PodcastPreview', stackTrace.toString());
      throw PodcastPreviewException(PodcastPreviewErrorKind.parseFailed, e);
    } catch (e, stackTrace) {
      AppLogger.log(
        'PodcastPreview',
        'rss parse failed feedUrl=$feedUrl error=$e',
      );
      AppLogger.log('PodcastPreview', stackTrace.toString());
      throw PodcastPreviewException(PodcastPreviewErrorKind.parseFailed, e);
    }
  }

  /// 把用户输入 URL 归一为 RSS feedUrl：Apple 链接走 lookup，其余按 RSS 直用。
  Future<String> _resolveFeedUrl(String inputUrl) async {
    try {
      return await _resolver.resolve(inputUrl);
    } on PodcastResolveException catch (e) {
      throw PodcastPreviewException(PodcastPreviewErrorKind.appleLookup, e);
    } on DioException catch (e) {
      throw PodcastPreviewException(_kindForDio(e), e);
    } catch (e) {
      throw PodcastPreviewException(PodcastPreviewErrorKind.appleLookup, e);
    }
  }

  Future<String> _fetchFeedContent(String feedUrl) async {
    try {
      AppLogger.log('PodcastPreview', 'rss request → GET $feedUrl');
      final response = await _dio.get<String>(
        feedUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final content = response.data;
      AppLogger.log(
        'PodcastPreview',
        'rss response ← GET ${response.realUri} '
            '${response.statusCode ?? "(null)"} '
            'contentType=${response.headers.value("content-type") ?? "(null)"} '
            'bytes=${content?.length ?? 0}',
      );
      if (content == null || content.isEmpty) {
        throw const PodcastPreviewException(PodcastPreviewErrorKind.emptyFeed);
      }
      if (isAntiBotChallenge(
        contentType: response.headers.value('content-type'),
        body: content,
      )) {
        throw const PodcastPreviewException(
          PodcastPreviewErrorKind.blockedByAntiBot,
        );
      }
      return content;
    } on PodcastPreviewException {
      rethrow;
    } on DioException catch (e, stackTrace) {
      AppLogger.log(
        'PodcastPreview',
        'rss request failed feedUrl=$feedUrl type=${e.type} '
            'status=${e.response?.statusCode ?? "(null)"} error=$e',
      );
      AppLogger.log('PodcastPreview', stackTrace.toString());
      throw PodcastPreviewException(_kindForDio(e), e);
    } catch (e, stackTrace) {
      AppLogger.log(
        'PodcastPreview',
        'rss request failed feedUrl=$feedUrl error=$e',
      );
      AppLogger.log('PodcastPreview', stackTrace.toString());
      throw PodcastPreviewException(PodcastPreviewErrorKind.rssUnavailable, e);
    }
  }

  PodcastPreviewErrorKind _kindForDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => PodcastPreviewErrorKind.timeout,
      DioExceptionType.badResponse => PodcastPreviewErrorKind.rssUnavailable,
      _ => PodcastPreviewErrorKind.network,
    };
  }
}

/// 由订阅输入 URL 拉取单个 Podcast 的 RSS 预览。
///
/// [inputUrl] 为 RSS 或 Apple Podcasts 链接，同时用作 family key，
/// 天然按来源缓存并防竞态。
@riverpod
Future<PodcastPreviewData> podcastPreview(Ref ref, String inputUrl) async {
  if (inputUrl.trim().isEmpty) {
    throw const PodcastPreviewException(PodcastPreviewErrorKind.rssUnavailable);
  }
  return ref.watch(podcastPreviewServiceProvider).fetchByUrl(inputUrl);
}
