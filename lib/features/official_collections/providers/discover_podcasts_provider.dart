import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/official_catalog_service.dart';
import '../models/catalog.dart';

part 'discover_podcasts_provider.g.dart';

/// Discover 页的精选 Podcast 列表。
///
/// 与官方合集共用同一份 catalog 缓存；返回 null 表示 catalog 尚未初始化，
/// 返回空 list 表示已初始化但后端暂无精选 Podcast。
@Riverpod(keepAlive: true)
List<CatalogPodcast>? discoverPodcasts(Ref ref) {
  final catalog = ref.watch(cachedCatalogProvider);
  if (catalog == null) {
    final svc = ref.read(officialCatalogServiceProvider);
    return svc.hasInitialized ? const <CatalogPodcast>[] : null;
  }
  return catalog.podcastCatalogs;
}

/// 从 catalog 缓存中按 id 查找单个精选 Podcast。
@Riverpod(keepAlive: true)
CatalogPodcast? podcastCatalogDetail(Ref ref, String podcastId) {
  final catalog = ref.watch(cachedCatalogProvider);
  if (catalog == null) return null;
  for (final podcast in catalog.podcastCatalogs) {
    if (podcast.id == podcastId) return podcast;
  }
  return null;
}
