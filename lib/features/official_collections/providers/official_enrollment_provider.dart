import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../analytics/models/event_names.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../services/app_logger.dart';
import '../data/official_collection_repository.dart';
import '../data/official_catalog_service.dart';

part 'official_enrollment_provider.g.dart';

const _logTag = 'OfficialEnrollment';

/// enroll 的结果：localId + 是否是刚刚新创建的。
class EnrollResult {
  final String localCollectionId;

  /// true 表示本次 enroll 产生了新行（首次添加）；
  /// false 表示之前已添加过，只是复用现有行（用户重复点击或并发）。
  final bool createdNew;

  const EnrollResult({
    required this.localCollectionId,
    required this.createdNew,
  });
}

/// 加入/移除官方合集的业务入口。
///
/// 防重入：Repository.enroll 内部检查 `getByRemoteId`，命中已有则抛
/// [AlreadyEnrolledError]；DB 的 UNIQUE INDEX 作为并发兜底。
/// 成功后 invalidate `collectionListProvider` 让 Library 列表刷新。
@Riverpod(keepAlive: true)
class OfficialEnrollment extends _$OfficialEnrollment {
  @override
  void build() {
    // 无常驻状态；方法触发一次性动作。
  }

  /// 加入合集。成功返回本地 collectionId。
  ///
  /// **不发网络**：从本地 catalog 缓存读 detail。
  ///
  /// 抛出：
  /// - [CatalogNotInitializedError]：catalog 还没拉到本地，UI 引导下拉刷新
  /// - [OfficialCollectionNotFoundInCatalog]：catalog 已加载但无该 remoteId（运营下架）
  /// - 全局唯一同步入口是 syncAll；此方法不触发 syncAll
  Future<EnrollResult> enroll(String remoteId) async {
    AppLogger.log(_logTag, 'enroll start remoteId=$remoteId');
    final repo = ref.read(officialCollectionRepositoryProvider);
    final catalog = ref.read(officialCatalogServiceProvider);
    try {
      final localId = await repo.enroll(remoteId);
      await ref.read(audioLibraryProvider.notifier).loadLibrary();
      await ref.read(collectionListProvider.notifier).loadCollections();
      final snapshot = ref.read(collectionListProvider);
      AppLogger.log(
        _logTag,
        'enroll success localId=$localId, collections=${snapshot.collections.length} '
        '(official=${snapshot.collections.where((c) => c.isOfficial).length})',
      );

      // 埋点：获取合集详情作为参数
      final catalogDetail = catalog.cached?.collections
          .where((c) => c.id == remoteId)
          .firstOrNull;
      if (catalogDetail != null) {
        ref
            .read(analyticsServiceProvider)
            .track(Events.officialCollectionEnroll, {
              EventParams.remoteId: remoteId,
              EventParams.collectionName: catalogDetail.name,
              EventParams.audioCount: catalogDetail.audios.length,
            });
      }

      return EnrollResult(localCollectionId: localId, createdNew: true);
    } on AlreadyEnrolledError catch (e) {
      AppLogger.log(_logTag, 'enroll already-enrolled localId=${e.localId}');
      return EnrollResult(localCollectionId: e.localId, createdNew: false);
    } catch (e, st) {
      AppLogger.log(_logTag, 'enroll failed remoteId=$remoteId err=$e');
      AppLogger.log(_logTag, st.toString());
      rethrow;
    }
  }

  /// 从"我的合集"移除官方合集（彻底清空，见 Repository.remove）。
  ///
  /// 如果该合集有音频正在下载，调用方（UI 层）应先调 downloadNotifier.cancel()。
  /// 这里只负责 DB + 文件清理。
  Future<void> remove(String localCollectionId) async {
    AppLogger.log(_logTag, 'remove start localId=$localCollectionId');
    final repo = ref.read(officialCollectionRepositoryProvider);
    try {
      await repo.remove(localCollectionId);
      await ref.read(audioLibraryProvider.notifier).loadLibrary();
      await ref.read(collectionListProvider.notifier).loadCollections();
      AppLogger.log(_logTag, 'remove success localId=$localCollectionId');
    } catch (e, st) {
      AppLogger.log(_logTag, 'remove failed localId=$localCollectionId err=$e');
      AppLogger.log(_logTag, st.toString());
      rethrow;
    }
  }
}
