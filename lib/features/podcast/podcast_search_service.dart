/// Apple 播客搜索服务
///
/// 调用 Apple 官方 iTunes Search API 按关键词查询播客：
/// `https://itunes.apple.com/search?media=podcast&entity=podcast&term=...`
///
/// 与 [PodcastUrlResolver] 一样，外部主机请求不走后端 Dio 工厂，直接裸构造
/// `Dio()`。响应解析复用「Dio 可能返回 Map 也可能返回原始 String」的双形态范式。
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import 'podcast_models.dart';

/// 播客搜索失败（面向 UI 归一的领域异常）
class PodcastSearchException implements Exception {
  final String message;
  const PodcastSearchException(this.message);
  @override
  String toString() => 'PodcastSearchException: $message';
}

/// Apple 播客搜索客户端
class PodcastSearchService {
  final Dio _dio;

  PodcastSearchService({Dio? dio}) : _dio = dio ?? Dio();

  /// 按关键词搜索播客，返回可订阅（含 feedUrl）的结果列表。
  ///
  /// [term] 为空时直接返回空列表（不发请求）。
  Future<List<PodcastSearchResult>> search(
    String term, {
    int limit = 25,
  }) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return const <PodcastSearchResult>[];
    try {
      final response = await _dio.get<Object?>(
        'https://itunes.apple.com/search',
        queryParameters: {
          'media': 'podcast',
          'entity': 'podcast',
          'term': trimmed,
          'limit': limit,
        },
      );
      return parseSearchResults(response.data);
    } on PodcastSearchException {
      rethrow;
    } catch (e) {
      throw PodcastSearchException('播客搜索失败：$e');
    }
  }

  /// 解析 iTunes Search 响应。
  ///
  /// Dio 在不同平台/响应头下可能返回 JSON map，也可能返回原始字符串。
  /// 遍历 `results`，跳过缺少 feedUrl 的项（无法订阅）。
  static List<PodcastSearchResult> parseSearchResults(Object? data) {
    final decoded = switch (data) {
      final Map<String, dynamic> map => map,
      final Map map => Map<String, dynamic>.from(map),
      final String text => jsonDecode(text) as Map<String, dynamic>,
      _ => throw const PodcastSearchException('iTunes search 响应格式无效'),
    };

    final results = decoded['results'];
    if (results is! List) return const <PodcastSearchResult>[];

    final list = <PodcastSearchResult>[];
    for (final item in results) {
      if (item is! Map) continue;
      final feedUrl = (item['feedUrl'] as String?)?.trim();
      if (feedUrl == null || feedUrl.isEmpty) continue;

      final trackId = item['trackId'];
      final id = trackId == null ? feedUrl : trackId.toString();
      final title = (item['collectionName'] as String?)?.trim();
      final artwork =
          (item['artworkUrl600'] as String?)?.trim().isNotEmpty ?? false
          ? (item['artworkUrl600'] as String).trim()
          : (item['artworkUrl100'] as String?)?.trim();

      list.add(
        PodcastSearchResult(
          id: id,
          title: (title == null || title.isEmpty) ? feedUrl : title,
          feedUrl: feedUrl,
          author: (item['artistName'] as String?)?.trim(),
          artworkUrl: (artwork == null || artwork.isEmpty) ? null : artwork,
          applePodcastUrl: (item['collectionViewUrl'] as String?)?.trim(),
        ),
      );
    }
    return list;
  }
}
