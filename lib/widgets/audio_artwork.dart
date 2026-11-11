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
import '../theme/app_theme.dart';
import 'media_type_icon.dart';

/// 方形圆角图标的圆角半径。
const double _kArtworkRadius = 8;

/// 视频默认图标占整体尺寸的比例。video-2.svg 自身留白较少，取 0.6 与音频图标的视觉重量接近。
const double _kVideoGlyphRatio = 0.6;

/// 音频默认图标占整体尺寸的比例。waveform.svg 四周留白约 1/6，取 0.7 让波形条约占方块一半。
const double _kAudioGlyphRatio = 0.7;

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
    // 默认图标用各自的媒体类型强调色：渐变底 + 同色图标，与封面占位区分开。
    final accentColor = isVideo
        ? AppTheme.videoMediaTypeColor(theme.brightness)
        : AppTheme.audioMediaTypeColor;
    final fallback = Container(
      width: size,
      height: size,
      decoration: _fallbackDecoration(
        isVideo: isVideo,
        brightness: theme.brightness,
      ),
      alignment: Alignment.center,
      child: MediaTypeIcon(
        isVideo: isVideo,
        size: size * (isVideo ? _kVideoGlyphRatio : _kAudioGlyphRatio),
        color: accentColor,
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

/// 默认图标渐变底：与合集封面占位相同的左上到右下渐变，颜色取各媒体类型的浅色调（深色模式取深色调）。
/// 端点保持饱和，不渐隐到白色，避免在浅色卡片上发灰。
const _kAudioLightGradient = [Color(0xFFEFE6FF), Color(0xFFD9C4FD)];
const _kAudioDarkGradient = [Color(0xFF3B2A5C), Color(0xFF2A1F45)];
const _kVideoLightGradient = [Color(0xFFD5F5EF), Color(0xFFA7EDE0)];
const _kVideoDarkGradient = [Color(0xFF13453F), Color(0xFF0D2F2B)];

BoxDecoration _fallbackDecoration({
  required bool isVideo,
  required Brightness brightness,
}) {
  final isDark = brightness == Brightness.dark;
  final colors = isVideo
      ? (isDark ? _kVideoDarkGradient : _kVideoLightGradient)
      : (isDark ? _kAudioDarkGradient : _kAudioLightGradient);
  return BoxDecoration(
    borderRadius: BorderRadius.circular(_kArtworkRadius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ),
  );
}

/// 去掉首尾空白后为空则视为缺失，避免空字符串地址触发无效的网络请求。
String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
