import 'package:drift/drift.dart';

/// 音频元数据表
class AudioItems extends Table {
  /// UUID 主键
  TextColumn get id => text()();

  /// 音频名称
  TextColumn get name => text()();

  /// 音频文件相对路径。
  ///
  /// NULL 表示音频尚未就绪（官方合集加入后、下载完成前）；非 NULL 表示文件已在本地。
  /// 是「音频是否可用」的单一真实来源。
  TextColumn get audioPath => text().nullable()();

  /// 字幕文件相对路径。
  ///
  /// NULL 表示无字幕或尚未下载；非 NULL 表示文件已在本地。
  TextColumn get transcriptPath => text().nullable()();

  /// 添加时间
  DateTimeColumn get addedDate => dateTime()();

  /// 时长（秒）
  IntColumn get totalDuration => integer().withDefault(const Constant(0))();

  /// 字幕句子数
  IntColumn get sentenceCount => integer().withDefault(const Constant(0))();

  /// 字幕单词数
  IntColumn get wordCount => integer().withDefault(const Constant(0))();

  /// 是否置顶
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// 字幕来源：0=local, 1=ai, null=无字幕
  IntColumn get transcriptSource => integer().nullable()();

  /// 音频文件 SHA256 指纹（缓存，避免重复计算）
  TextColumn get audioSha256 => text().nullable()();

  /// AI 转录使用的语言（'en' / 'multi'）
  TextColumn get transcriptLanguage => text().nullable()();

  /// 最后修改时间
  DateTimeColumn get updatedAt => dateTime()();

  /// 软删除标记
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 词级时间戳 JSON（AI 转录时由后端返回，与字幕一起管理）
  TextColumn get wordTimestampsJson => text().nullable()();

  /// 字幕内容（完整 SRT 文本）。
  ///
  /// DB 成为字幕的唯一真相源后，本列保存整段 SRT。NULL 表示无字幕，或旧行尚未
  /// backfill（由启动时全量 backfill 从 [transcriptPath] 指向的文件读入）。
  /// 大字段，与 [wordTimestampsJson] 一样不进列表查询，仅按需读写。
  TextColumn get transcriptSrt => text().nullable()();

  /// 同步状态：0=synced, 1=pendingUpload, 2=pendingDelete
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// 官方合集中该音频在后端的 UUID；仅官方合集音频有值。
  /// 用于同步比对（通过 remoteAudioId 反查本地行）。
  TextColumn get remoteAudioId => text().nullable()();

  /// 原始发布/播出日期。官方合集音频从后端 catalog 同步（如 VOA 某期的播出日期）；
  /// 用户自建音频保持 NULL。用于官方合集详情页「最早/最新发布」排序。
  DateTimeColumn get originalDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
