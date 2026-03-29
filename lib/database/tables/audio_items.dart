import 'package:drift/drift.dart';

/// 音频元数据表
class AudioItems extends Table {
  /// UUID 主键
  TextColumn get id => text()();

  /// 音频名称
  TextColumn get name => text()();

  /// 音频文件相对路径
  TextColumn get audioPath => text()();

  /// 字幕文件相对路径（可选）
  TextColumn get transcriptPath => text().nullable()();

  /// 添加时间
  DateTimeColumn get addedDate => dateTime()();

  /// 时长（秒）
  IntColumn get totalDuration => integer().withDefault(const Constant(0))();

  /// 字幕句子数
  IntColumn get sentenceCount => integer().withDefault(const Constant(0))();

  /// 字幕单词数
  IntColumn get wordCount => integer().withDefault(const Constant(0))();

  /// 是否星标
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();

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

  /// 同步状态：0=synced, 1=pendingUpload, 2=pendingDelete
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
