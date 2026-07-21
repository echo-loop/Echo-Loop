/// Podcast feature 数据模型
library;

/// Feed 元信息（从 RSS channel 或 iTunes lookup 提取）
class PodcastFeedMeta {
  final String title;
  final String? author;
  final String? description;
  final String? imageUrl;
  final String feedUrl;

  const PodcastFeedMeta({
    required this.title,
    required this.feedUrl,
    this.author,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'description': description,
    'imageUrl': imageUrl,
    'feedUrl': feedUrl,
  };

  factory PodcastFeedMeta.fromJson(Map<String, dynamic> json) =>
      PodcastFeedMeta(
        title: json['title'] as String,
        feedUrl: json['feedUrl'] as String,
        author: json['author'] as String?,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
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
  });
}
