/// 合集来源。
///
/// 决定 UI（社区 badge、菜单裁剪）与业务流程（enroll / remove / sync）。
/// 字段值对齐 Drift `collections.source` 列的字符串：`local` / `community`。
enum CollectionSource {
  /// 用户在本地自建的合集
  local,

  /// 从后端加入的社区合集（需要 sync、按需下载媒体、移除时彻底清空）
  community,

  /// 用户订阅的 Podcast RSS 合集（本机私有，不同步后端）
  podcast;

  /// 反序列化辅助；未知字符串回退到 [local] 避免炸。
  static CollectionSource fromString(String? raw) {
    return switch (raw) {
      'community' => CollectionSource.community,
      'official' => CollectionSource.community,
      'podcast' => CollectionSource.podcast,
      _ => CollectionSource.local,
    };
  }

  String get storageValue => switch (this) {
    CollectionSource.local => 'local',
    CollectionSource.community => 'community',
    CollectionSource.podcast => 'podcast',
  };
}

/// 合集数据模型
///
/// audioItemIds 已移至 Drift junction 表（`collection_audio_items`）。
///
/// 社区合集字段（source=community 时有效）：
/// - [remoteId]：后端 collection.id（UUID）
/// - [coverUrl] / [description]：后端 detail 返回的元信息
/// - [coverUrlChina]：后端提供的中国 CDN 封面镜像地址
/// - [deprecatedAt]：后端下架后的本地标记时间
///
/// 本地合集字段（source=local 时有效）：
/// - [localCoverPath]：用户自定义封面，相对应用数据目录的路径
///
/// Podcast 合集字段（source=podcast 时有效）：
/// - [podcastInputUrl]：用户输入的原始 URL（Apple Podcasts 或 RSS 直链）
/// - [podcastFeedUrl]：解析后的 RSS Feed URL
/// - [podcastMetaJson]：Feed 元信息 JSON（title/author/imageUrl/description）
/// - [podcastLastRefreshedAt]：最后一次刷新时间
/// - [podcastLastRefreshError]：最后一次刷新错误
class Collection {
  final String id;
  final String name;
  final DateTime createdDate;
  final DateTime updatedAt;
  final bool isPinned;

  /// 合集来源；默认 [CollectionSource.local] 兼容老数据
  final CollectionSource source;

  /// 社区合集在后端的 UUID；source=local/podcast 时为 null
  final String? remoteId;

  /// 合集封面图；社区合集从后端获取；podcast 合集从 feed imageUrl 获取
  final String? coverUrl;

  /// 社区合集封面图的中国 CDN 镜像地址。
  final String? coverUrlChina;

  /// 合集描述；社区合集从后端获取；podcast 合集从 feed description 获取
  final String? description;

  /// 社区合集发布者昵称；旧数据中可能为空。
  final String? authorNickname;

  /// 社区合集发布日期；历史本地副本可能为空。
  final DateTime? publishedAt;

  /// 社区合集被标记下架的时间；非 null 时 UI 置灰，sync 不再请求
  final DateTime? deprecatedAt;

  /// 本地合集自定义封面（相对应用数据目录）；未设置时为 null，显示首字母占位。
  final String? localCoverPath;

  // ── Podcast 字段 ──────────────────────────────────────────────────────

  /// 用户输入的原始 URL（Apple Podcasts 链接或直接 RSS 链接）
  final String? podcastInputUrl;

  /// 解析后的 RSS Feed URL
  final String? podcastFeedUrl;

  /// Feed 元信息 JSON（title / author / imageUrl / description 等）
  final String? podcastMetaJson;

  /// 最后一次刷新的时间；成功/失败都会更新，用于 10 分钟节流和 UI 展示
  final DateTime? podcastLastRefreshedAt;

  /// 最后一次刷新错误；成功刷新后清空
  final String? podcastLastRefreshError;

  Collection({
    required this.id,
    required this.name,
    required this.createdDate,
    DateTime? updatedAt,
    this.isPinned = false,
    this.source = CollectionSource.local,
    this.remoteId,
    this.coverUrl,
    this.coverUrlChina,
    this.description,
    this.authorNickname,
    this.publishedAt,
    this.deprecatedAt,
    this.localCoverPath,
    this.podcastInputUrl,
    this.podcastFeedUrl,
    this.podcastMetaJson,
    this.podcastLastRefreshedAt,
    this.podcastLastRefreshError,
  }) : updatedAt = updatedAt ?? createdDate;

  /// 方便判断：是否为用户自建的本地合集。
  bool get isLocal => source == CollectionSource.local;

  /// 方便判断：是否为社区合集。
  bool get isCommunity => source == CollectionSource.community;

  /// 方便判断：是否为 podcast 合集
  bool get isPodcast => source == CollectionSource.podcast;

  /// 方便判断：社区合集是否已下架
  bool get isDeprecated => deprecatedAt != null;

  /// 用于 SP → Drift 迁移时读取旧格式的 JSON
  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
    id: json['id'],
    name: json['name'],
    createdDate: DateTime.parse(json['createdDate']),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : DateTime.parse(json['createdDate']),
    isPinned: json['isPinned'] ?? json['isStarred'] ?? false,
    source: CollectionSource.fromString(json['source'] as String?),
    remoteId: json['remoteId'] as String?,
    coverUrl: json['coverUrl'] as String?,
    coverUrlChina: switch (json['coverUrlChina']) {
      final String url => url,
      _ => null,
    },
    description: json['description'] as String?,
    authorNickname: switch (json['authorNickname']) {
      final String nickname => nickname,
      _ => null,
    },
    publishedAt: switch (json['publishedAt']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    },
    deprecatedAt: json['deprecatedAt'] != null
        ? DateTime.parse(json['deprecatedAt'] as String)
        : null,
    podcastInputUrl: json['podcastInputUrl'] as String?,
    podcastFeedUrl: json['podcastFeedUrl'] as String?,
    podcastMetaJson: json['podcastMetaJson'] as String?,
    podcastLastRefreshedAt: json['podcastLastRefreshedAt'] != null
        ? DateTime.parse(json['podcastLastRefreshedAt'] as String)
        : null,
    podcastLastRefreshError: json['podcastLastRefreshError'] as String?,
  );

  /// 从旧 JSON 中提取 audioItemIds（仅迁移用）
  static List<String> audioItemIdsFromJson(Map<String, dynamic> json) {
    return List<String>.from(json['audioItemIds'] ?? []);
  }

  Collection copyWith({
    String? id,
    String? name,
    DateTime? createdDate,
    DateTime? updatedAt,
    bool? isPinned,
    CollectionSource? source,
    String? remoteId,
    String? coverUrl,
    String? coverUrlChina,
    String? description,
    String? authorNickname,
    DateTime? publishedAt,
    DateTime? deprecatedAt,
    String? localCoverPath,
    bool clearLocalCoverPath = false,
    String? podcastInputUrl,
    String? podcastFeedUrl,
    String? podcastMetaJson,
    DateTime? podcastLastRefreshedAt,
    String? podcastLastRefreshError,
    bool clearPodcastLastRefreshError = false,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      createdDate: createdDate ?? this.createdDate,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      source: source ?? this.source,
      remoteId: remoteId ?? this.remoteId,
      coverUrl: coverUrl ?? this.coverUrl,
      coverUrlChina: coverUrlChina ?? this.coverUrlChina,
      description: description ?? this.description,
      authorNickname: authorNickname ?? this.authorNickname,
      publishedAt: publishedAt ?? this.publishedAt,
      deprecatedAt: deprecatedAt ?? this.deprecatedAt,
      localCoverPath: clearLocalCoverPath
          ? null
          : localCoverPath ?? this.localCoverPath,
      podcastInputUrl: podcastInputUrl ?? this.podcastInputUrl,
      podcastFeedUrl: podcastFeedUrl ?? this.podcastFeedUrl,
      podcastMetaJson: podcastMetaJson ?? this.podcastMetaJson,
      podcastLastRefreshedAt:
          podcastLastRefreshedAt ?? this.podcastLastRefreshedAt,
      podcastLastRefreshError: clearPodcastLastRefreshError
          ? null
          : podcastLastRefreshError ?? this.podcastLastRefreshError,
    );
  }
}
