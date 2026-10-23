import 'package:drift/drift.dart';

/// 媒体元数据表（音频 + 视频通用）。
///
/// 历史上仅存音频，故表名与多数列名带 `audio` 前缀；自视频内容类型接入后，
/// 视频条目复用同一张表（不新建表、不升 schema），`audioPath` 等字段实际存的是
/// 「主媒体文件」，与音视频类型无关。是否视频由 [audioPath] 扩展名派生
/// （见 `AudioItem.mediaType`），本表不落 mediaType 列。
///
/// 命名遗留：`audio*` 名称只是历史包袱，语义上等价于 `media*`。未来若接入账号与
/// 多端同步（字段名会固化进后端 schema 与 API 契约），应作一次独立的中性重命名重构
/// （`MediaItems` / `mediaPath` / `mediaSha256`），届时统一走 Drift 列 rename 迁移。
class AudioItems extends Table {
  /// UUID 主键
  TextColumn get id => text()();

  /// 音频名称
  TextColumn get name => text()();

  /// 主媒体文件相对路径（音频或视频，音频落 `audios/`、视频落 `videos/`）。
  ///
  /// NULL 表示媒体尚未就绪（社区合集加入后、下载完成前）；非 NULL 表示文件已在本地。
  /// 是「媒体是否可用」的单一真实来源，同时是媒体类型判定依据（按扩展名派生 video/audio）。
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

  /// 媒体文件 SHA256 指纹（缓存，避免重复计算）。纯文件哈希，音视频通用。
  TextColumn get audioSha256 => text().nullable()();

  /// 转码前原始媒体 SHA256 指纹。
  ///
  /// AI 转录优先用该值作为后端字幕缓存 key；为空时回退 [audioSha256]。
  /// 视频不转码（保留原始文件），此值等同原始文件指纹，音视频通用。
  TextColumn get originalAudioSha256 => text().nullable()();

  /// AI 转录使用的语言（'en' / 'multi'）
  TextColumn get transcriptLanguage => text().nullable()();

  /// 媒体内容有效性状态：0=ok, 1=damaged, 2=silent, null=未检测。
  /// 新下载时检测一次（短解码失败判 damaged，可解码但静音判 silent）。
  /// 视频条目跳过检测，恒为 null（见 `audio_library_provider.checkAudioContent`）。
  IntColumn get audioContentStatus => integer().nullable()();

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

  /// 社区合集中该音频在后端的 UUID；仅社区合集音频有值。
  /// 用于同步比对（通过 remoteAudioId 反查本地行）。
  TextColumn get remoteAudioId => text().nullable()();

  /// 原始发布/播出日期。社区合集音频从后端 catalog 同步（如 VOA 某期的播出日期）；
  /// 用户自建音频保持 NULL。用于社区合集详情页「最早/最新发布」排序。
  DateTimeColumn get originalDate => dateTime().nullable()();

  /// 社区合集文件从服务端消失的时间。
  ///
  /// 非 NULL 时表示该条目仍保留本地学习记录，但远端文件已不可用；
  /// 文件重新出现在 v2 列表后由同步清空。
  DateTimeColumn get communityUnavailableAt => dateTime().nullable()();

  /// 社区合集文件由服务端维护的 CEFR 难度（A1–C2）；普通媒体保持 NULL。
  TextColumn get communityDifficulty => text().nullable()();

  /// 用户导入来源类型：local / direct_url / cloud_drive。
  ///
  /// 社区合集不使用该字段，继续由 remoteAudioId 和 collections.source 标识。
  TextColumn get importSourceType => text().nullable()();

  /// 用户导入来源 URL。直链导入记录原始 URL；本地文件导入保持 NULL。
  TextColumn get importSourceUrl => text().nullable()();

  // ── Podcast Episode 字段（podcast 合集的音频条目时有效）──────────────────

  /// Podcast episode 的 RSS guid；用于同一合集内去重。
  /// 无 guid 的 episode 不导入。
  TextColumn get podcastEpisodeGuid => text().nullable()();

  /// Episode 音频文件的 enclosure URL（RSS `<enclosure url="...">`）
  TextColumn get podcastEnclosureUrl => text().nullable()();

  /// Enclosure MIME type，如 audio/mpeg
  TextColumn get podcastEnclosureType => text().nullable()();

  /// Episode 简介文本，来自 RSS item description。
  TextColumn get podcastDescription => text().nullable()();

  /// Episode 封面图 URL，来自 RSS item itunes:image。
  TextColumn get podcastImageUrl => text().nullable()();

  /// Episode 网页链接，来自 RSS item link。
  TextColumn get podcastLink => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
