import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/audio_library_provider.dart';
import '../../../providers/collection_provider.dart';
import 'official_catalog_service.dart';
import 'official_sync_service.dart';

/// 触发全局唯一的官方合集同步入口（5 个调用点共用）。
///
/// 职责：
/// 1. 调 [OfficialSyncService.syncAll]（内部 inflight + 节流 + sha256 比对）
/// 2. 仅当 outcome=updated 时：
///    - invalidate [cachedCatalogProvider] 让 Discover/详情页 watcher 重 build
///    - 刷新 audioLibrary + collectionList 让 UI 读到最新行
/// 3. throttled / unchanged / failed → 全部跳过后续刷新，UI 不闪
///
/// 调用方：main.dart 冷启动 / resumed lifecycle / Discover 下拉 / 详情页下拉 /
/// Discover 详情页 initState 兜底。
Future<CatalogRefreshOutcome?> triggerOfficialSync(
  WidgetRef ref, {
  bool force = false,
}) async {
  try {
    final stats = await ref
        .read(officialSyncServiceProvider)
        .syncAll(force: force);
    if (stats.outcome is CatalogUpdated) {
      await ref.read(audioLibraryProvider.notifier).loadLibrary();
      await ref.read(collectionListProvider.notifier).loadCollections();
      ref.invalidate(cachedCatalogProvider);
    }
    return stats.outcome;
  } catch (_) {
    return null;
  }
}
