import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tts_cache.dart';

part 'tts_cache_dao.g.dart';

/// TTS 合成缓存 DAO
///
/// 按 [cacheKey] 读写合成结果元数据。读取时自动更新 [TtsCache.lastAccessedAt]，
/// 支持按过期时间清理与按 LRU 容量淘汰。文件本体的删除由上层
/// [TtsCacheStore] 负责，本 DAO 只管索引行。
@DriftAccessor(tables: [TtsCache])
class TtsCacheDao extends DatabaseAccessor<AppDatabase>
    with _$TtsCacheDaoMixin {
  TtsCacheDao(super.db);

  /// 根据 [cacheKey] 查找缓存条目。
  ///
  /// 命中时自动更新 [TtsCache.lastAccessedAt]。若传入 [slideTtl] 且该条目带有
  /// 过期时间（`expiresAt != null`，即非永久条目），则同时把 [TtsCache.expiresAt]
  /// 续期到 `now + slideTtl`——实现滑动过期：被访问（含后台预热命中）的热缓存
  /// 自动延长寿命，不再到固定的创建期限就被删。永久条目（`expiresAt == null`）
  /// 不受影响。返回整行；未命中返回 null。
  Future<TtsCacheData?> getByKey(String cacheKey, {Duration? slideTtl}) async {
    final row = await (select(
      ttsCache,
    )..where((t) => t.cacheKey.equals(cacheKey))).getSingleOrNull();
    if (row == null) return null;

    final now = DateTime.now();
    final renew = slideTtl != null && row.expiresAt != null;
    await (update(ttsCache)..where((t) => t.id.equals(row.id))).write(
      TtsCacheCompanion(
        lastAccessedAt: Value(now),
        expiresAt: renew ? Value(now.add(slideTtl)) : const Value.absent(),
      ),
    );
    return row;
  }

  /// 插入或更新缓存条目（以 [cacheKey] 为唯一键）。
  Future<void> upsert({
    required String cacheKey,
    required String textHash,
    required String sourceText,
    required String engine,
    required String voice,
    required String languageCode,
    required double speed,
    required String format,
    required String filePath,
    required int fileSize,
    DateTime? expiresAt,
    bool isPinned = false,
  }) {
    final now = DateTime.now();
    return into(ttsCache).insert(
      TtsCacheCompanion.insert(
        cacheKey: cacheKey,
        textHash: textHash,
        sourceText: sourceText,
        engine: engine,
        voice: voice,
        languageCode: languageCode,
        speed: speed,
        format: format,
        filePath: filePath,
        fileSize: fileSize,
        createdAt: now,
        lastAccessedAt: now,
        expiresAt: Value(expiresAt),
        isPinned: Value(isPinned),
      ),
      onConflict: DoUpdate(
        (old) => TtsCacheCompanion(
          filePath: Value(filePath),
          fileSize: Value(fileSize),
          lastAccessedAt: Value(now),
          expiresAt: Value(expiresAt),
        ),
        target: [ttsCache.cacheKey],
      ),
    );
  }

  /// 删除单条缓存索引。
  Future<int> deleteByKey(String cacheKey) {
    return (delete(ttsCache)..where((t) => t.cacheKey.equals(cacheKey))).go();
  }

  /// 取出所有已过期、未 pin 的条目（供上层删文件后再删行）。
  Future<List<TtsCacheData>> expiredEntries(DateTime now) {
    return (select(ttsCache)..where(
          (t) =>
              t.isPinned.equals(false) &
              t.expiresAt.isNotNull() &
              t.expiresAt.isSmallerThanValue(now),
        ))
        .get();
  }

  /// 未 pin 条目按最后访问时间升序（最久未访问在前），供 LRU 淘汰。
  Future<List<TtsCacheData>> unpinnedByLruAsc() {
    return (select(ttsCache)
          ..where((t) => t.isPinned.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.lastAccessedAt)]))
        .get();
  }

  /// 所有条目引用的文件路径集合。
  ///
  /// 供上层清理时识别孤儿文件：`tts_cache/` 目录下不在此集合的文件即为孤儿
  /// （磁盘有、DB 无引用，如 app 被杀于「已写盘、store 未提交」之间产生），可安全删除。
  Future<List<String>> allFilePaths() async {
    final rows = await (selectOnly(
      ttsCache,
    )..addColumns([ttsCache.filePath])).get();
    return rows.map((r) => r.read(ttsCache.filePath)!).toList();
  }

  /// 当前所有条目占用的总字节数。
  Future<int> totalSize() async {
    final expr = ttsCache.fileSize.sum();
    final row = await (selectOnly(ttsCache)..addColumns([expr])).getSingle();
    return row.read(expr) ?? 0;
  }

  /// 删除全部缓存（用户「清除缓存」）。
  Future<int> deleteAll() {
    return delete(ttsCache).go();
  }
}
