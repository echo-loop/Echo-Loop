import 'package:drift/drift.dart';

import 'audio_items.dart';

/// 学习进度表
///
/// 单表设计，一行一个音频。完成状态由 currentStage + currentSubStage 推导。
/// 两列均为 TEXT，存储枚举的字符串键，解耦存储与枚举顺序。
class LearningProgresses extends Table {
  /// 音频 ID，主键 + 外键关联 audio_items（级联删除）
  TextColumn get audioItemId =>
      text().references(AudioItems, #id, onDelete: KeyAction.cascade)();

  /// 当前大阶段键（对应 LearningStage.key）
  TextColumn get currentStage =>
      text().withDefault(const Constant('firstLearn'))();

  /// 当前子步骤键（对应 SubStageType.key）
  TextColumn get currentSubStage =>
      text().withDefault(const Constant('blindListen'))();

  /// 难度等级（0=easy, 1=medium, 2=hard）
  IntColumn get difficulty => integer().withDefault(const Constant(1))();

  /// 首次学习完成时间（复习间隔计算基准，首次学习完成前为 null）
  DateTimeColumn get firstLearnCompletedAt => dateTime().nullable()();

  /// 上一阶段完成时间（复习调度核心字段，用于计算下次复习时间）
  DateTimeColumn get lastStageCompletedAt => dateTime().nullable()();

  /// 当前阶段开始时间（进入该阶段的时间，用于断点续学和耗时计算）
  DateTimeColumn get currentStageStartedAt => dateTime().nullable()();

  /// 累计学习时长（毫秒）
  IntColumn get totalStudyDurationMs =>
      integer().withDefault(const Constant(0))();

  /// 盲听已完成遍数（用户可随时查看）
  IntColumn get blindListenPassCount =>
      integer().withDefault(const Constant(0))();

  /// 精听断点续学句子索引（null 表示从头开始）
  IntColumn get intensiveListenSentenceIndex => integer().nullable()();

  /// 精听标记的难句数量
  IntColumn get intensiveListenDifficultCount => integer().nullable()();

  /// 精听总完成遍数（每次完成精听 +1，类似盲听的 blindListenPassCount）
  IntColumn get intensiveListenPassCount => integer().nullable()();

  /// 跟读总完成遍数（每次完成跟读 +1）
  IntColumn get shadowingPassCount => integer().nullable()();

  /// 跟读断点续学句子索引（null 表示从头开始）
  IntColumn get shadowingSentenceIndex => integer().nullable()();

  /// 难句补练断点续学句子索引（null 表示从头开始）
  IntColumn get difficultPracticeSentenceIndex => integer().nullable()();

  /// 复述断点续学段落索引（null 表示从头开始）
  IntColumn get retellParagraphIndex => integer().nullable()();

  /// 复述总完成遍数（每次完成复述 +1）
  IntColumn get retellPassCount => integer().nullable()();

  /// 盲听断点续学段落索引（null 表示从头开始）
  IntColumn get blindListenParagraphIndex => integer().nullable()();

  /// 自由练习-盲听断点段落索引
  IntColumn get freePlayBlindListenParagraphIndex => integer().nullable()();

  /// 自由练习-精听断点句子索引
  IntColumn get freePlayIntensiveListenSentenceIndex => integer().nullable()();

  /// 自由练习-跟读断点句子索引
  IntColumn get freePlayShadowingSentenceIndex => integer().nullable()();

  /// 自由练习-难句补练断点句子索引
  IntColumn get freePlayDifficultPracticeSentenceIndex =>
      integer().nullable()();

  /// 自由练习-复述断点段落索引
  IntColumn get freePlayRetellParagraphIndex => integer().nullable()();

  /// 新学习断点保存时间（>3天则不恢复）
  DateTimeColumn get newLearningBreakpointSavedAt => dateTime().nullable()();

  /// 自由练习断点保存时间（>3天则不恢复）
  DateTimeColumn get freePlayBreakpointSavedAt => dateTime().nullable()();

  /// 最后更新时间
  DateTimeColumn get updatedAt => dateTime()();

  /// 用户（或自动跳过策略）在该音频上跳过的子步骤集合
  ///
  /// 存储格式：逗号分隔的 `'stage.key:subStage.key'`（空字符串 = 空集合）。
  ///
  /// 不变量：与 `stage_completions` 中该音频的 (stage, subStage) 集合**互斥**——
  /// 写 completion 时清除此集合中对应 key；写 skip 时若已 completed 则早返回。
  TextColumn get skippedSubStages =>
      text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {audioItemId};
}
