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

  /// 难度等级（5 档：0=veryEasy, 1=easy, 2=medium, 3=hard, 4=veryHard）
  ///
  /// DB 列 default 为历史值 1；新建 LearningProgress 行的代码层（ensureProgress）
  /// 会显式写入 2 (medium)，所以该 default 实际不会生效，但出于谨慎不在此处变更，
  /// 避免触发 drift schema 重新校验。
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

  /// 复述断点续学句子索引（全局句子 index，null 表示从头开始）
  ///
  /// 段内位置：恢复时按句子 index 反查段，并在段时长 > 10s 时段内从该句开播。
  IntColumn get retellSentenceIndex => integer().nullable()();

  /// 复述总完成遍数（每次完成复述 +1）
  IntColumn get retellPassCount => integer().nullable()();

  /// 盲听断点续学句子索引（全局句子 index，null 表示从头开始）
  ///
  /// 段内位置：恢复时按句子 index 反查段，并在段时长 > 10s 时段内从该句开播。
  IntColumn get blindListenSentenceIndex => integer().nullable()();

  /// 自由练习-盲听断点句子索引（全局句子 index）
  IntColumn get freePlayBlindListenSentenceIndex => integer().nullable()();

  /// 自由练习-精听断点句子索引
  IntColumn get freePlayIntensiveListenSentenceIndex => integer().nullable()();

  /// 自由练习-跟读断点句子索引
  IntColumn get freePlayShadowingSentenceIndex => integer().nullable()();

  /// 自由练习-难句补练断点句子索引
  IntColumn get freePlayDifficultPracticeSentenceIndex =>
      integer().nullable()();

  /// 自由练习-复述断点句子索引（全局句子 index）
  IntColumn get freePlayRetellSentenceIndex => integer().nullable()();

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
  TextColumn get skippedSubStages => text().withDefault(const Constant(''))();

  /// 是否暂停学习（true 表示该音频不参与复习调度，可由用户随时恢复）
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();

  /// 每个 [LearningStage] 的 plan 版本快照（dense map，JSON 存储）。
  ///
  /// 格式：JSON object，key = `LearningStage.key`，value = 整数版本号。例：
  /// `{"firstLearn":1,"review0":2,"review1":2,...,"review28":2}`
  ///
  /// **不包含 `completed`**：completed 是毕业终态标记、无 plan，不参与版本系统。
  ///
  /// **写入规则**：snapshot-per-entity 模式。仅在创建 progress / 迁移时
  /// 由系统 stamp。日常用户操作（完成 / 跳过 substep、暂停等）**都不修改**
  /// 此字段。区别于 `stage_completions`（持续累加）。
  /// 如未来需要让存量 audio 升级到新版，需写显式迁移修改本字段。
  ///
  /// 写入时机：
  /// - 新建 progress：stamp `kLatestPlanVersions`
  /// - v33→v34 迁移：每条 audio baseline 全 v1 + 按 stage 是否有 completion 判定：
  ///   该 stage 在 `stage_completions` 表里**无任何记录** → 升级到 v2
  ///   （未碰过的轮次用新版；碰过的轮次锁旧版保留体验）
  ///
  /// 派生函数：`LearningPlan.standard(stagePlanVersions: ...)`。
  TextColumn get planVersionsJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {audioItemId};
}
