// 素材的方形圆角图标：有封面显示封面，否则显示音频 / 视频图标。
//
// 合集详情页列表项与学习页任务卡共用，保证两处外形一致。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/community_collections/models/community_asset_url.dart';
import '../features/podcast/podcast_models.dart';
import '../features/user_region/user_region_providers.dart';
import '../models/audio_item.dart';
import '../models/collection.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../services/app_network_image_cache.dart';
import 'media_type_icon.dart';

/// 方形圆角图标的圆角半径。
const double _kArtworkRadius = 8;

/// 图标中心媒体图标占整体尺寸的比例（与封面外形搭配的默认图标）。
const double _kGlyphRatio = 0.5;

/// 封面解码边长取显示尺寸的 3 倍，兼顾高分屏清晰度与解码开销。
const int _kCoverDecodeScale = 3;

/// 方形圆角素材图标。
///
/// 有封面时显示封面，封面加载中只显示中性色块（不闪现默认图标，避免「图标 → 封面」的跳动），
/// 无封面或加载失败时显示音频 / 视频图标。
class AudioArtwork extends StatelessWidget {
  final String? imageUrl;
  final bool isVideo;
  final double size;

  const AudioArtwork({
    super.key,
    required this.imageUrl,
    required this.isVideo,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kArtworkRadius),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      alignment: Alignment.center,
      child: MediaTypeIcon(
        isVideo: isVideo,
        size: size * _kGlyphRatio,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final url = imageUrl;
    if (url == null) return fallback;
    final loadingPlaceholder = Container(
      width: size,
      height: size,
      color: theme.colorScheme.surfaceContainerHighest,
    );
    final decodeSize = (size * _kCoverDecodeScale).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kArtworkRadius),
      child: CachedNetworkImage(
        key: const Key('audio_list_tile_subscribed_artwork'),
        imageUrl: url,
        cacheManager: AppNetworkImageCache.instance,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // 封面源图多为 3000×3000，按显示尺寸解码，
        // 否则每次滚动回来都要整图解码，且会挤占 Flutter 图片内存缓存。
        memCacheWidth: decodeSize,
        memCacheHeight: decodeSize,
        // 缓存命中时立即显示，去掉默认淡入造成的延迟感
        fadeInDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (_, __) => loadingPlaceholder,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

/// 已订阅合集中素材的封面地址：单集自身封面优先，其次是播客 Feed 封面或社区合集封面（按地区选 CDN）。
String? resolveSubscribedArtworkUrl({
  required AudioItem audio,
  required Collection collection,
  required bool isChinaUser,
}) {
  final episodeImageUrl = _nonBlank(audio.podcastImageUrl);
  if (episodeImageUrl != null) return episodeImageUrl;
  if (collection.isPodcast) {
    final feedImageUrl = _nonBlank(
      decodePodcastFeedMeta(collection.podcastMetaJson)?.imageUrl,
    );
    return feedImageUrl ?? _nonBlank(collection.coverUrl);
  }
  return communityAssetUrlForRegion(
    globalUrl: collection.coverUrl,
    chinaUrl: collection.coverUrlChina,
    isChinaUser: isChinaUser,
  );
}

/// 按素材 ID 展示方形图标：素材所在的已订阅合集有封面时用封面，否则用音频 / 视频图标。
/// 素材不在资料库中时同样回退到默认图标。
class AudioItemArtwork extends ConsumerWidget {
  final String audioId;
  final double size;

  const AudioItemArtwork({
    super.key,
    required this.audioId,
    required this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(
      audioLibraryProvider.select(
        (state) =>
            state.audioItems.where((item) => item.id == audioId).firstOrNull,
      ),
    );
    final subscribedCollection = ref.watch(
      collectionListProvider.select(
        (state) => state.subscribedCollectionForAudio(audioId),
      ),
    );
    final isChinaUser = ref.watch(isChinaUserProvider);

    final imageUrl = audio == null || subscribedCollection == null
        ? null
        : resolveSubscribedArtworkUrl(
            audio: audio,
            collection: subscribedCollection,
            isChinaUser: isChinaUser,
          );
    return AudioArtwork(
      imageUrl: imageUrl,
      isVideo: audio?.isVideo ?? false,
      size: size,
    );
  }
}

/// 去掉首尾空白后为空则视为缺失，避免空字符串地址触发无效的网络请求。
String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
