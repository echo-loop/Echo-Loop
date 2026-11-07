import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../services/app_network_image_cache.dart';

/// 用户头像。有头像时展示网络图（使用全应用共享的图片缓存），
/// 否则回退为昵称首字；没有昵称时显示默认人像。
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.size,
    this.avatarUrl,
    this.nickname,
  });

  final double size;

  /// 为 null 表示未设置头像。服务端每次换头像都会生成新 URL，因此无需手动失效缓存。
  final String? avatarUrl;

  final String? nickname;

  @override
  Widget build(BuildContext context) {
    final placeholder = _AvatarPlaceholder(size: size, nickname: nickname);
    final url = avatarUrl;
    if (url == null) return placeholder;

    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: CachedNetworkImage(
          imageUrl: url,
          cacheManager: AppNetworkImageCache.instance,
          fit: BoxFit.cover,
          placeholder: (context, _) => placeholder,
          errorWidget: (context, _, _) => placeholder,
        ),
      ),
    );
  }
}

/// 取昵称第一个码点并大写，作为无头像时的占位字。昵称为空时返回 null。
///
/// 按码点取值，避免 emoji 等代理对字符被截断成乱码。
String? avatarInitialFor(String? nickname) {
  final trimmed = nickname?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return String.fromCharCodes([trimmed.runes.first]).toUpperCase();
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.size, required this.nickname});

  final double size;
  final String? nickname;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = avatarInitialFor(nickname);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colorScheme.secondaryContainer,
      foregroundColor: colorScheme.onSecondaryContainer,
      child: initial == null
          ? Icon(Icons.person_outline, size: size * 0.55)
          : Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
