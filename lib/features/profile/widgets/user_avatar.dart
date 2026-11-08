import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../services/app_network_image_cache.dart';

/// 用户头像。有头像时展示网络图（使用全应用共享的图片缓存），
/// 否则在圆形底色中展示账号图标（assets/icon/account-1.svg）。
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.size, this.avatarUrl});

  final double size;

  /// 为 null 表示未设置头像。服务端每次换头像都会生成新 URL，因此无需手动失效缓存。
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = _DefaultAvatar(size: size);
    final url = avatarUrl;
    if (url == null) return placeholder;

    // 默认头像作为底层，网络图叠在上面。换头像时 gaplessPlayback 会保留上一张图，
    // 直到新图加载完成，避免中间闪一下默认头像。
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            placeholder,
            Image(
              image: CachedNetworkImageProvider(
                url,
                cacheManager: AppNetworkImageCache.instance,
              ),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // 加载失败时保留底层的默认头像。
              errorBuilder: (context, _, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // SVG 自带留白，图标略小于圆形区域，视觉上与圆形边缘留出间距。
    final iconSize = size * 0.6;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colorScheme.secondaryContainer,
      child: SvgPicture.asset(
        'assets/icon/account-1.svg',
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(
          colorScheme.onSecondaryContainer,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
