/// Apple 播客搜索 Provider
///
/// - [podcastSearchServiceProvider]：搜索客户端单例，测试可 override。
/// - [podcastSearchResultsProvider]：按关键词的搜索结果 family。
///   autoDispose + family 天然按 term 缓存、天然防竞态——UI 只 watch 最新
///   term，旧 term 的结果被丢弃，无需手写 token 校验。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'podcast_models.dart';
import 'podcast_search_service.dart';

part 'podcast_search_provider.g.dart';

/// 播客搜索客户端。
@riverpod
PodcastSearchService podcastSearchService(Ref ref) => PodcastSearchService();

/// 按关键词搜索播客；[term] 为空返回空列表。
@riverpod
Future<List<PodcastSearchResult>> podcastSearchResults(
  Ref ref,
  String term,
) async {
  final trimmed = term.trim();
  if (trimmed.isEmpty) return const <PodcastSearchResult>[];
  return ref.read(podcastSearchServiceProvider).search(trimmed);
}
