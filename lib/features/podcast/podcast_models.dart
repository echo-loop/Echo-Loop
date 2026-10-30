/// Podcast feature 数据模型
library;

/// Feed 元信息（从 RSS channel 或 iTunes lookup 提取）
class PodcastFeedMeta {
  final String title;
  final String? author;
  final String? description;
  final String? imageUrl;
  final String feedUrl;
  final List<String> categories;
  final String? language;
  final String? copyright;
  final String? websiteUrl;
  final String? explicit;

  const PodcastFeedMeta({
    required this.title,
    required this.feedUrl,
    this.author,
    this.description,
    this.imageUrl,
    this.categories = const [],
    this.language,
    this.copyright,
    this.websiteUrl,
    this.explicit,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'description': description,
    'imageUrl': imageUrl,
    'feedUrl': feedUrl,
    'categories': categories,
    'language': language,
    'copyright': copyright,
    'websiteUrl': websiteUrl,
    'explicit': explicit,
  };

  factory PodcastFeedMeta.fromJson(Map<String, dynamic> json) =>
      PodcastFeedMeta(
        title: json['title'] as String,
        feedUrl: json['feedUrl'] as String,
        author: json['author'] as String?,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        categories: switch (json['categories']) {
          final List<dynamic> raw => raw.whereType<String>().toList(),
          _ => const <String>[],
        },
        language: json['language'] as String?,
        copyright: json['copyright'] as String?,
        websiteUrl: json['websiteUrl'] as String?,
        explicit: json['explicit'] as String?,
      );
}

/// RSS feed 解析结果
class PodcastFeedResult {
  final PodcastFeedMeta meta;
  final List<PodcastEpisode> episodes;

  const PodcastFeedResult({required this.meta, required this.episodes});
}

/// iTunes Search API 返回的单条播客结果
///
/// 对应 `https://itunes.apple.com/search?media=podcast&entity=podcast`
/// 结果项。仅保留订阅与展示所需字段；只有拿到 [feedUrl] 的结果才有意义
/// （可直接交给通用导入流程），无 feedUrl 的结果在服务层已被过滤。
class PodcastSearchResult {
  /// iTunes trackId（转为字符串，用作列表 key 与订阅中状态标识）
  final String id;

  /// 播客标题（collectionName）
  final String title;

  /// 作者/主播（artistName），可能缺失
  final String? author;

  /// RSS feed 地址，订阅时直接作为输入 URL
  final String feedUrl;

  /// 封面图（artworkUrl600 优先，回退 artworkUrl100）
  final String? artworkUrl;

  /// Apple Podcasts 网页地址（collectionViewUrl），可能缺失
  final String? applePodcastUrl;

  const PodcastSearchResult({
    required this.id,
    required this.title,
    required this.feedUrl,
    this.author,
    this.artworkUrl,
    this.applePodcastUrl,
  });
}

/// 播客预览页入参（承载展示信息 + 订阅所需 URL）。
///
/// 让「精选 Podcast / Apple 搜索结果（PodcastSearchResult）/
/// 用户粘贴链接」三种来源共用同一预览页与订阅主干：
/// - 展示字段（[title]/[imageUrl]/[description]/[author]）供 header 首帧渲染，
///   feed 拉取成功后再用 [PodcastFeedMeta] 覆盖。
/// - [subscriptionInputUrl] 作为订阅输入 URL（交给 `createAndFetch`）与预览
///   provider 的 family key：RSS 优先，否则 Apple 链接。
class PodcastPreviewArg {
  final String title;
  final String? imageUrl;
  final String? description;
  final String? author;

  /// 已知 RSS feed 地址（搜索结果或解析后的用户链接）。
  final String? feedUrl;

  /// Apple Podcasts 网页地址，无 RSS 时用于解析。
  final String? applePodcastUrl;

  const PodcastPreviewArg({
    required this.title,
    this.imageUrl,
    this.description,
    this.author,
    this.feedUrl,
    this.applePodcastUrl,
  });

  /// 订阅输入 URL / 预览 provider family key：RSS 优先，否则 Apple。
  String get subscriptionInputUrl {
    final feed = feedUrl?.trim() ?? '';
    if (feed.isNotEmpty) return feed;
    return applePodcastUrl?.trim() ?? '';
  }
}

/// 单个 podcast episode
class PodcastEpisode {
  final String guid;
  final String title;
  final String enclosureUrl;
  final String enclosureType;
  final DateTime? pubDate;
  final int? durationSeconds;
  final String? description;
  final String? imageUrl;
  final String? link;

  /// RSS `<podcast:transcript>` 字幕地址；无受支持格式时为 null。
  final String? transcriptUrl;

  /// 字幕格式，规范化为 `srt` 或 `vtt`；与 [transcriptUrl] 同时存在或同时为 null。
  final String? transcriptFormat;

  const PodcastEpisode({
    required this.guid,
    required this.title,
    required this.enclosureUrl,
    required this.enclosureType,
    this.pubDate,
    this.durationSeconds,
    this.description,
    this.imageUrl,
    this.link,
    this.transcriptUrl,
    this.transcriptFormat,
  });
}
