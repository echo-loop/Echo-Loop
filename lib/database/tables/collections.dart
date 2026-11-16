import 'package:drift/drift.dart';

/// 合集表
class Collections extends Table {
  /// UUID 主键
  TextColumn get id => text()();

  /// 合集名称
  TextColumn get name => text()();

  /// 创建时间
  DateTimeColumn get createdDate => dateTime()();

  /// 置顶
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// 最后修改时间
  DateTimeColumn get updatedAt => dateTime()();

  /// 软删除标记
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 同步状态
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// 合集来源：`local`（用户自建）| `community`（从后端加入的社区合集）
  ///
  /// 老数据默认 `local`。不可变 —— 决定了 UI 是否显示社区 badge、
  /// 长按菜单是否允许重命名/删除音频、移除流程是否彻底清空等。
  TextColumn get source => text().withDefault(const Constant('local'))();

  /// 社区合集在后端的 UUID；仅 source='community' 时有值。
  /// 与 [source]=community 联合唯一。
  TextColumn get remoteId => text().nullable()();

  /// 社区合集封面图 URL；用户自建合集目前为 null。
  TextColumn get coverUrl => text().nullable()();

  /// 已同步到中国 CDN 的社区合集封面图 URL。
  TextColumn get coverUrlChina => text().nullable()();

  /// 本地合集的自定义封面，相对应用数据目录的路径（如 `collection_covers/x.jpg`）。
  ///
  /// 只对 source='local' 有效；存相对路径是因为 iOS 容器绝对路径会随安装变化。
  /// 文件仅存本机，不同步后端，随本地备份一起导出。
  TextColumn get localCoverPath => text().nullable()();

  /// 社区合集描述；用户自建合集目前为 null。
  TextColumn get description => text().nullable()();

  /// 社区合集发布者昵称；老数据及匿名发布者保持 null。
  TextColumn get authorNickname => text().nullable()();

  /// 社区合集发布日期；老数据保持 null。
  DateTimeColumn get publishedAt => dateTime().nullable()();

  /// 社区合集被后端标记下架的时间；非 null 时 UI 置灰、sync 不再请求。
  /// source='local' 永远为 null。
  DateTimeColumn get deprecatedAt => dateTime().nullable()();

  // ── Podcast 字段（source='podcast' 时有效）────────────────────────────

  /// 用户输入的原始 URL（Apple Podcasts 链接或直接 RSS 链接）
  TextColumn get podcastInputUrl => text().nullable()();

  /// 解析后的 RSS Feed URL（Apple 链接经 iTunes lookup 后得到；直接 RSS 直通）
  TextColumn get podcastFeedUrl => text().nullable()();

  /// Feed 元信息 JSON（title / author / imageUrl / description 等）
  TextColumn get podcastMetaJson => text().nullable()();

  /// 最后一次刷新时间；成功/失败都会更新，用于节流和 UI 展示
  DateTimeColumn get podcastLastRefreshedAt => dateTime().nullable()();

  /// 最后一次刷新错误；成功刷新后清空
  TextColumn get podcastLastRefreshError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
