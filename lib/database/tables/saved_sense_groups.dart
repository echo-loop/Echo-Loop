import 'package:drift/drift.dart';

import 'audio_items.dart';

/// 收藏意群表
///
/// 存储用户收藏的意群（短语），包括来源音频、句子和意群精确时间范围。
/// 与 [SavedWords] 独立存储，避免相互干扰。
class SavedSenseGroups extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 意群文本（归一化：小写 + trim + 去句末标点，保留撇号），全局唯一
  TextColumn get phraseText => text().unique()();

  /// 意群原始文本（保留大小写，用于展示）
  TextColumn get displayText => text()();

  /// 来源音频 ID，FK → audio_items，音频删除时置空
  TextColumn get audioItemId => text().nullable().references(
    AudioItems,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// 来源句子索引
  IntColumn get sentenceIndex => integer().nullable()();

  /// 来源句子文本（冗余存储，闪卡复习时展示上下文）
  TextColumn get sentenceText => text().nullable()();

  /// 来源句子起始时间（毫秒）
  IntColumn get sentenceStartMs => integer().nullable()();

  /// 来源句子结束时间（毫秒）
  IntColumn get sentenceEndMs => integer().nullable()();

  /// 意群精确起始时间（毫秒），用于收藏页直接播放意群片段
  IntColumn get groupStartMs => integer().nullable()();

  /// 意群精确结束时间（毫秒）
  IntColumn get groupEndMs => integer().nullable()();

  /// 练习次数
  IntColumn get practiceCount => integer().withDefault(const Constant(0))();

  /// 收藏时间
  DateTimeColumn get createdAt => dateTime()();

  /// 最后修改时间
  DateTimeColumn get updatedAt => dateTime()();

  /// 软删除标记
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 同步状态（预留）
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}
