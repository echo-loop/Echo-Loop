import 'package:drift/drift.dart';

import 'audio_items.dart';

/// 收藏句表
///
/// 一条收藏就是「音频 + 那句话的文字与时间区间」，不记句子编号（编号随字幕
/// 编辑变化）；当前是第几句按区间中点在当前字幕里现算（见
/// `source_sentence_anchor.dart`）。字幕替换后文字与区间改写为当前对应的句子；
/// 字幕合并后同一句可对应多条收藏。
class Bookmarks extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 跨数据库迁移和字幕重解析仍保持稳定的记忆主体 ID。
  TextColumn get memorySubjectId => text().nullable()();

  /// 音频 ID，外键关联 audio_items.id
  TextColumn get audioItemId =>
      text().references(AudioItems, #id, onDelete: KeyAction.cascade)();

  /// 句子文本（字幕替换后改写为当前对应句子的文本）
  TextColumn get sentenceText => text()();

  /// 收藏区间起点（秒）
  RealColumn get startTime => real()();

  /// 收藏区间终点（秒）
  RealColumn get endTime => real()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime()();

  /// 最后修改时间
  DateTimeColumn get updatedAt => dateTime()();

  /// 软删除标记
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 同步状态
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}
