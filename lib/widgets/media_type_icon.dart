import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 根据媒体类型显示统一的音频或视频图标。
class MediaTypeIcon extends StatelessWidget {
  final bool isVideo;
  final double size;
  final Color? color;

  const MediaTypeIcon({
    super.key,
    required this.isVideo,
    this.size = 20,
    this.color,
  });

  static const audioAsset = 'assets/icon/waveform.svg';
  static const videoAsset = 'assets/icon/video-2.svg';

  @override
  Widget build(BuildContext context) {
    if (!isVideo) {
      // 音频图标保留 waveform.svg 自带的品牌紫色；叠加 colorFilter 会整体染色，因此忽略 color。
      return SvgPicture.asset(audioAsset, width: size, height: size);
    }
    final iconColor = color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      videoAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }
}
