import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../podcast/podcast_feed_parser.dart';
import '../../podcast/podcast_models.dart';
import '../../podcast/podcast_url_resolver.dart';
import '../models/catalog.dart';
import 'discover_podcasts_provider.dart';

part 'podcast_preview_provider.g.dart';

/// 发现页 Podcast 预览失败类型。
enum PodcastPreviewErrorKind {
  network,
  timeout,
  appleLookup,
  rssUnavailable,
  parseFailed,
  emptyFeed,
}

/// Podcast 预览失败。UI 只展示本类型映射后的友好文案。
class PodcastPreviewException implements Exception {
  final PodcastPreviewErrorKind kind;
  final Object? cause;

  const PodcastPreviewException(this.kind, [this.cause]);

  @override
  String toString() => 'PodcastPreviewException($kind, cause: $cause)';
}

/// 发现态 Podcast 内容预览。
class PodcastPreviewData {
  final PodcastFeedMeta meta;
  final List<PodcastEpisode> episodes;

  const PodcastPreviewData({required this.meta, required this.episodes});
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

/// 只读预览服务：拉取 RSS 并解析 episode，不写入本地库。
class PodcastPreviewService {
  final Dio _dio;
  final PodcastUrlResolver _resolver;
  final PodcastFeedParser _parser;

  PodcastPreviewService({
    required Dio dio,
    required PodcastUrlResolver resolver,
    required PodcastFeedParser parser,
  }) : _dio = dio,
       _resolver = resolver,
       _parser = parser;

  Future<PodcastPreviewData> fetch(CatalogPodcast podcast) async {
    final feedUrl = await _resolveFeedUrl(podcast);
    final feedContent = await _fetchFeedContent(feedUrl);
    try {
      final result = _parser.parse(feedContent, feedUrl: feedUrl);
      if (result.episodes.isEmpty) {
        throw const PodcastPreviewException(PodcastPreviewErrorKind.emptyFeed);
      }
      return PodcastPreviewData(meta: result.meta, episodes: result.episodes);
    } on PodcastPreviewException {
      rethrow;
    } on PodcastParseException catch (e) {
      throw PodcastPreviewException(PodcastPreviewErrorKind.parseFailed, e);
    } catch (e) {
      throw PodcastPreviewException(PodcastPreviewErrorKind.parseFailed, e);
    }
  }

  Future<String> _resolveFeedUrl(CatalogPodcast podcast) async {
    final rssUrl = podcast.rssUrl.trim();
    if (rssUrl.isNotEmpty) return rssUrl;
    try {
      return await _resolver.resolve(podcast.applePodcastUrl);
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
      final response = await _dio.get<String>(
        feedUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final content = response.data;
      if (content == null || content.isEmpty) {
        throw const PodcastPreviewException(PodcastPreviewErrorKind.emptyFeed);
      }
      return content;
    } on PodcastPreviewException {
      rethrow;
    } on DioException catch (e) {
      throw PodcastPreviewException(_kindForDio(e), e);
    } catch (e) {
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

/// 拉取单个精选 Podcast 的 RSS 预览。
@riverpod
Future<PodcastPreviewData> podcastPreview(Ref ref, String podcastId) async {
  final podcast = ref.watch(podcastCatalogDetailProvider(podcastId));
  if (podcast == null) {
    throw const PodcastPreviewException(PodcastPreviewErrorKind.rssUnavailable);
  }
  return ref.watch(podcastPreviewServiceProvider).fetch(podcast);
}
