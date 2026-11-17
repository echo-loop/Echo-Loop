import 'package:drift/drift.dart';

import 'audio_items.dart';

/// 收藏单词表
///
/// 存储用户在学习过程中收藏的单词，包括来源音频和句子信息。
/// 同一单词只保留最新一次收藏的来源信息（MVP 单来源设计）。
class SavedWords extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 单词原形（小写，lemmatized），全局唯一
  TextColumn get word => text().unique()();

  /// 稳定关联 FSRS 调度快照的业务主体 ID（不可变 UUID）。
  ///
  /// 与 [word] 解耦：调度身份不依赖可编辑/可合并的展示文本。
  TextColumn get memorySubjectId => text().nullable()();

  /// 来源音频 ID，FK → audio_items，音频删除时置空
  TextColumn get audioItemId => text().nullable().references(
    AudioItems,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// 来源句子文本（冗余存储，防止索引错位或音频删除后丢失上下文）
  TextColumn get sentenceText => text().nullable()();

  /// 来源句子起始时间（毫秒），冗余存储，删除字幕后仍可播放
  IntColumn get sentenceStartMs => integer().nullable()();

  /// 来源句子结束时间（毫秒），冗余存储，删除字幕后仍可播放
  IntColumn get sentenceEndMs => integer().nullable()();

  /// 练习次数（Flashcard 翻转到背面计为 1 次）
  IntColumn get practiceCount => integer().withDefault(const Constant(0))();

  /// 累计学习时长（毫秒），单张卡片最长 60 秒截断
  IntColumn get totalStudyMs => integer().withDefault(const Constant(0))();

  /// 是否曾翻转到背面查看释义
  BoolColumn get viewedBack => boolean().withDefault(const Constant(false))();

  /// 最近一次练习时间
  DateTimeColumn get lastPracticedAt => dateTime().nullable()();

  /// 收藏时间
  DateTimeColumn get createdAt => dateTime()();

  /// 最后修改时间
  DateTimeColumn get updatedAt => dateTime()();

  /// 软删除标记
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 同步状态（预留）
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}
