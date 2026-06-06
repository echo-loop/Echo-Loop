import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/audio_items.dart';

part 'audio_item_dao.g.dart';

/// 音频元数据 DAO
/// 提供音频项的 CRUD 操作
@DriftAccessor(tables: [AudioItems])
class AudioItemDao extends DatabaseAccessor<AppDatabase>
    with _$AudioItemDaoMixin {
  AudioItemDao(super.db);

  /// 获取所有未删除的音频项
  Future<List<AudioItem>> getAllActive() {
    return (select(audioItems)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.addedDate),
          ]))
        .get();
  }

  /// 监听所有未删除的音频项
  Stream<List<AudioItem>> watchAllActive() {
    return (select(audioItems)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.addedDate),
          ]))
        .watch();
  }

  /// 根据 ID 获取音频项
  Future<AudioItem?> getById(String id) {
    return (select(
      audioItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 根据官方合集中的 remoteAudioId 反查本地行。
  ///
  /// 同步时用于判断"远端新增音频在本地是否已存在"。
  Future<AudioItem?> getByRemoteAudioId(String remoteAudioId) {
    return (select(audioItems)
          ..where((t) => t.remoteAudioId.equals(remoteAudioId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// 插入或更新音频项
  Future<void> upsert(AudioItemsCompanion entry) {
    return into(audioItems).insertOnConflictUpdate(entry);
  }

  /// 批量插入音频项（用于迁移）
  Future<void> batchInsert(List<AudioItemsCompanion> entries) async {
    await batch((b) {
      b.insertAll(audioItems, entries, mode: InsertMode.insertOrReplace);
    });
  }

  /// 软删除音频项
  Future<void> softDelete(String id) {
    final now = DateTime.now();
    return (update(audioItems)..where((t) => t.id.equals(id))).write(
      AudioItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: Value(2), // pendingDelete
      ),
    );
  }

  /// 硬删除音频项（真正从数据库移除）
  Future<void> hardDelete(String id) {
    return (delete(audioItems)..where((t) => t.id.equals(id))).go();
  }

  /// 获取指定音频的词级时间戳 JSON
  ///
  /// 独立查询，避免列表加载时读取大 JSON 字段。
  Future<String?> getWordTimestamps(String audioItemId) async {
    final query = select(audioItems)..where((t) => t.id.equals(audioItemId));
    final row = await query.getSingleOrNull();
    return row?.wordTimestampsJson;
  }

  /// 更新词级时间戳（独立更新，不影响其他字段）
  Future<void> updateWordTimestamps(String audioItemId, String? json) {
    return (update(audioItems)..where((t) => t.id.equals(audioItemId))).write(
      AudioItemsCompanion(wordTimestampsJson: Value(json)),
    );
  }

  /// 获取指定音频的字幕内容（完整 SRT 文本）。
  ///
  /// 独立查询，避免列表加载时读取大字段。
  Future<String?> getTranscriptSrt(String audioItemId) async {
    final query = select(audioItems)..where((t) => t.id.equals(audioItemId));
    final row = await query.getSingleOrNull();
    return row?.transcriptSrt;
  }

  /// 更新字幕内容（独立更新，不影响其他字段）。
  Future<void> updateTranscriptSrt(String audioItemId, String? srt) {
    return (update(audioItems)..where((t) => t.id.equals(audioItemId))).write(
      AudioItemsCompanion(transcriptSrt: Value(srt)),
    );
  }

  /// 查询需要 backfill 字幕内容的行：有遗留文件路径但 transcript_srt 列为空。
  ///
  /// 启动时全量 backfill 用，从这些行的 [transcriptPath] 文件读入 SRT。
  /// 列填满后返回空，后续启动为 no-op。
  Future<List<AudioItem>> getRowsNeedingSrtBackfill() {
    return (select(audioItems)..where(
          (t) =>
              t.transcriptSrt.isNull() &
              t.transcriptPath.isNotNull() &
              t.transcriptPath.isNotValue(''),
        ))
        .get();
  }

  /// 原子保存字幕内容：SRT + 词级时间戳，单事务写入两个大字段。
  ///
  /// 供 AI 转录、编辑保存等「字幕内容整体落库」场景使用，避免分两次写入中途崩溃
  /// 出现 SRT 与词级时间戳不一致。[wordTimestampsJson] 为 null 表示同时清空词级
  /// 时间戳（如编辑后无词级数据）。句/词计数、来源、路径等模型列由
  /// `audioLibraryProvider.updateAudioItem` 单独写入（与本方法列不相交）。
  Future<void> saveTranscriptContent(
    String audioItemId, {
    required String srt,
    required String? wordTimestampsJson,
  }) {
    return transaction(() async {
      await (update(audioItems)..where((t) => t.id.equals(audioItemId))).write(
        AudioItemsCompanion(
          transcriptSrt: Value(srt),
          wordTimestampsJson: Value(wordTimestampsJson),
        ),
      );
    });
  }
}
