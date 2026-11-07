import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 全应用共用的网络图片磁盘缓存。
///
/// 与默认 [DefaultCacheManager] 的差异：
/// - 用 [JsonCacheInfoRepository] 替代 sqflite 仓库（避免引入 sqflite 依赖、
///   消除桌面平台 ffi 全局 factory 警告，与项目 drift+sqlite3 解耦）
/// - 独立 cacheKey，与可能的第三方库默认 cache 池隔离
///
/// 缓存策略：30 天过期、最多 500 个文件。当前用于：
/// - 社区合集封面（Discover 页 / 详情页）
/// - 用户头像（账号页 / 设置页）
///
/// 如要新场景接入，统一传 `cacheManager: AppNetworkImageCache.instance`
/// 给 `CachedNetworkImage` 即可，无需新建 manager。
class AppNetworkImageCache extends CacheManager with ImageCacheManager {
  /// 缓存 key。整个 App 共享同一池，无需也不应再起新 key。
  static const cacheKey = 'app_network_images';

  /// 单例。整个进程生命周期持有，避免重复初始化磁盘 / json repo。
  static final AppNetworkImageCache instance = AppNetworkImageCache._();

  AppNetworkImageCache._()
    : super(
        Config(
          cacheKey,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 500,
          repo: JsonCacheInfoRepository(databaseName: cacheKey),
          fileService: HttpFileService(),
        ),
      );
}
