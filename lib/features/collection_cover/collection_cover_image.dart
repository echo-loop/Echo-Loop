// 合集方形封面：有图显示图片，无图或加载失败显示渐变底 + 名称首字。
//
// 「我的合集」列表、创建 / 编辑合集表单共用，保证两处外形一致。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/collection.dart';
import 'collection_cover_store.dart';

/// 封面圆角，与列表其它方形图标一致。
const double kCollectionCoverRadius = 8;

/// 封面解码边长取显示尺寸的 3 倍，兼顾高分屏清晰度与解码开销。
const int _kCoverDecodeScale = 3;

class CollectionCoverImage extends StatelessWidget {
  const CollectionCoverImage({
    super.key,
    required this.name,
    required this.size,
    required this.image,
  });

  /// 合集名称，无封面时取首字作为占位。
  final String name;
  final double size;

  /// 封面图片；null 时显示首字占位。
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final placeholder = CollectionLetterPlaceholder(name: name, size: size);
    final image = this.image;
    if (image == null) return placeholder;
    final decodeSize = (size * _kCoverDecodeScale).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(kCollectionCoverRadius),
      child: Image(
        key: const ValueKey('collection-cover-image'),
        image: ResizeImage(image, width: decodeSize, height: decodeSize),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // 本地文件解码很快，首帧前不显示空白，直接用占位垫底。
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            frame == null && !wasSynchronouslyLoaded ? placeholder : child,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

/// 渐变背景 + 合集名首字占位（与社区合集卡片的封面占位同款）。
class CollectionLetterPlaceholder extends StatelessWidget {
  const CollectionLetterPlaceholder({
    super.key,
    required this.name,
    required this.size,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed.characters.first;
    return Container(
      key: const ValueKey('collection-cover-placeholder'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kCollectionCoverRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.tertiaryContainer,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// 本地合集封面：解析 [Collection.localCoverPath] 为文件后显示。
class LocalCollectionCover extends ConsumerWidget {
  const LocalCollectionCover({
    super.key,
    required this.collection,
    required this.size,
  });

  final Collection collection;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = resolveCollectionCoverFile(
      ref.watch(appDataDirectoryPathProvider).value,
      collection.localCoverPath,
    );
    return CollectionCoverImage(
      name: collection.name,
      size: size,
      image: file == null ? null : FileImage(file),
    );
  }
}
