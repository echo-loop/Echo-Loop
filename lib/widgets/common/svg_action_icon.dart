// SVG 操作图标（AppBar 按钮、输入框前缀等）。
//
// 统一按主题颜色着色，避免每个调用点重复写 SvgPicture + ColorFilter。
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgActionIcon extends StatelessWidget {
  /// 资源路径，例如 `assets/icon/search.svg`。
  final String assetName;

  /// 图标边长。AppBar 操作按钮使用 24。
  final double size;

  /// 图标颜色；为空时跟随 [IconTheme]（AppBar、按钮内的前景色），与 Material 图标行为一致。
  final Color? color;

  const SvgActionIcon({
    super.key,
    required this.assetName,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface,
        BlendMode.srcIn,
      ),
    );
  }
}
