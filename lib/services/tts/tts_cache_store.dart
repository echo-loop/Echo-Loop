/// TTS 合成结果缓存仓库
///
/// 统一管线的缓存层：音频文件落本地目录，索引/过期/容量由 [TtsCacheDao]（SQLite）
/// 管理。设计遵循业界标准——**过期靠数据库 [expiresAt]、淘汰靠 LRU，不依赖
/// 目录或文件名**。
///
/// 文件目录：`${getApplicationCacheDirectory()}/tts_cache/`（transient，不进
/// iCloud 备份）。仅管理本 app 自建的 `tts_cache/` 子目录，绝不触碰系统
/// `Library/Caches` 根（见 CLAUDE.md §7.5）。
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../../database/daos/tts_cache_dao.dart';
import '../../utils/text_normalize.dart';
import '../app_logger.dart';
import 'tts_engine.dart';

/// 缓存保留策略默认值。
class TtsCachePolicy {
  /// 普通发音（单词/例句）默认保留时长。
  static const defaultRetention = Duration(days: 10);

  /// 普通缓存容量上限（字节）。超过则 LRU 淘汰。
  static const maxBytes = 200 * 1024 * 1024; // 200 MB
}

/// TTS 缓存仓库。
class TtsCacheStore {
  TtsCacheStore({
    required TtsCacheDao Function() resolveDao,
    required Future<Directory> Function() resolveCacheDir,
  }) : _resolveDao = resolveDao,
       _resolveCacheDir = resolveCacheDir;

  /// 惰性解析 DAO：只在真正读写缓存时才触碰数据库，渲染发音按钮不连库。
  final TtsCacheDao Function() _resolveDao;
  final Future<Directory> Function() _resolveCacheDir;
  TtsCacheDao? _daoCache;
  Directory? _cachedDir;

  TtsCacheDao get _dao => _daoCache ??= _resolveDao();

  /// 解析（并按需创建）TTS 缓存目录。
  Future<Directory> _dir() async {
    if (_cachedDir != null) return _cachedDir!;
    final base = await _resolveCacheDir();
    final dir = Directory('${base.path}/tts_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _cachedDir = dir;
  }

  /// 由发音参数派生稳定缓存键。
  ///
  /// 同一文本在不同引擎/音色/语速下生成不同键，互不串音。
  /// 输出格式策略变更时升级命名空间，避免继续命中不兼容的旧缓存文件。
  String deriveKey({
    required String text,
    required TtsEngineKind engine,
    required String voiceId,
    required double speed,
    String? modelTag,
  }) {
    final raw = [
      // iOS 平台 TTS 从 CAF 改为 WAV，升级命名空间让旧文件不再命中。
      // 旧索引/文件无需迁移，后续清理会将不再引用的文件作为孤儿回收。
      'tts-cache-v3',
      hashText(text),
      engine.name,
      voiceId,
      speed.toStringAsFixed(2),
      // 仅当带模型标签（如 Kokoro fp32/int8）时追加分桶段；平台引擎为 null，
      // 不改变既有缓存键。
      if (modelTag != null) modelTag,
    ].join('|');
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// 查缓存。命中且文件存在则返回 [File]；未命中或文件已被外部删除则返回 null
  /// （并清理悬空索引行）。
  ///
  /// 命中时 DAO 刷新 lastAccessedAt，并按**滑动过期**把过期时间续期到
  /// `now + [TtsCachePolicy.defaultRetention]`——播放命中、后台预热命中都走此路，
  /// 故热缓存（被反复使用/预热）自动延寿，不再到固定创建期限即被删。
  Future<File?> lookup(String cacheKey) async {
    final row = await _dao.getByKey(
      cacheKey,
      slideTtl: TtsCachePolicy.defaultRetention,
    );
    if (row == null) return null;
    final file = File(row.filePath);
    if (!await file.exists()) {
      // 文件被外部清掉，索引行悬空——删除以便下次重新合成。
      await _dao.deleteByKey(cacheKey);
      return null;
    }
    return file;
  }

  /// 为 [cacheKey] 预留缓存目录（合成引擎将文件写入此目录）。
  Future<String> reserveDir() async => (await _dir()).path;

  /// 记录一条已落盘的合成结果到索引。
  ///
  /// [result] 的文件须已存在于缓存目录。[ttl] 为 null 表示永久（配合
  /// [isPinned]，本期不使用）。
  Future<void> store({
    required String cacheKey,
    required String text,
    required TtsEngineKind engine,
    required String voiceId,
    required String languageCode,
    required double speed,
    required TtsSynthesisResult result,
    Duration? ttl = TtsCachePolicy.defaultRetention,
    bool isPinned = false,
  }) async {
    final file = File(result.filePath);
    final size = await file.exists() ? await file.length() : 0;
    if (size <= 0) {
      AppLogger.log('TtsCacheStore', 'store 跳过：文件为空 ${result.filePath}');
      return;
    }
    final now = DateTime.now();
    await _dao.upsert(
      cacheKey: cacheKey,
      textHash: hashText(text),
      sourceText: text,
      engine: engine.name,
      voice: voiceId,
      languageCode: languageCode,
      speed: speed,
      format: result.format,
      filePath: result.filePath,
      fileSize: size,
      expiresAt: ttl == null ? null : now.add(ttl),
      isPinned: isPinned,
    );
  }

  /// 清理：先删过期（文件+索引），再按 LRU 把总容量压到 [maxBytes] 以下。
  ///
  /// 启动后延迟调用（不拖首屏）。永久（pin）条目不参与自动清理。
  Future<void> cleanup({int maxBytes = TtsCachePolicy.maxBytes}) async {
    try {
      final expired = await _dao.expiredEntries(DateTime.now());
      for (final row in expired) {
        await _deleteFileQuietly(row.filePath);
        await _dao.deleteByKey(row.cacheKey);
      }

      var total = await _dao.totalSize();
      var evicted = 0;
      if (total > maxBytes) {
        // 容量超限：按最久未访问淘汰。
        final lru = await _dao.unpinnedByLruAsc();
        for (final row in lru) {
          if (total <= maxBytes) break;
          await _deleteFileQuietly(row.filePath);
          await _dao.deleteByKey(row.cacheKey);
          total -= row.fileSize;
          evicted++;
        }
      }
      AppLogger.log(
        'TtsCacheStore',
        'cleanup 删过期 ${expired.length} 条、LRU 淘汰 $evicted 条',
      );
    } catch (e) {
      AppLogger.log('TtsCacheStore', 'cleanup 失败: $e');
    }
    // 清扫孤儿文件（磁盘有、DB 无引用），防止其永久占盘且不计入 LRU 容量统计。
    // 放在 try 外、无条件执行——不被上面的容量达标分支跳过。
    await _sweepOrphanFiles();
  }

  /// 清空全部 TTS 缓存（用户「清除缓存」）。
  ///
  /// 缓存目录是纯 transient 产物——需长期保留的音频会拷贝到应用目录、不留在此，
  /// 故清缓存即「全清」：删全部索引行 + 删 `tts_cache/` 目录下所有文件（含磁盘有、
  /// DB 无引用的孤儿）。返回释放的字节数，用于向用户展示释放量。
  Future<int> clearAll() async {
    await _dao.deleteAll();
    // 表已空 → 目录内文件都不被引用，复用孤儿清扫即可全删并返回释放字节。
    return _sweepOrphanFiles();
  }

  /// 清扫 `tts_cache/` 目录里未被任何索引行引用的文件（孤儿）。
  ///
  /// 按目录列举而非按 DB 行删除，故对「磁盘有、DB 无引用」的残留（app 被杀于
  /// 已写盘未入库之间、旧 DB 被替换、用户清缓存等）也能清掉。返回释放字节数。
  Future<int> _sweepOrphanFiles() async {
    var freed = 0;
    try {
      final dir = await _dir();
      if (!await dir.exists()) return 0;
      final keep = (await _dao.allFilePaths()).toSet();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (keep.contains(entity.path)) continue;
        try {
          final size = await entity.length();
          await entity.delete();
          freed += size;
        } catch (e) {
          AppLogger.log('TtsCacheStore', '清孤儿文件失败 ${entity.path}: $e');
        }
      }
    } catch (e) {
      AppLogger.log('TtsCacheStore', '_sweepOrphanFiles 失败: $e');
    }
    return freed;
  }

  Future<void> _deleteFileQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      AppLogger.log('TtsCacheStore', '删文件失败 $path: $e');
    }
  }
}
