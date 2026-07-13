/// Shimmer 骨架屏占位组件
///
/// 在内容加载中时显示闪烁的占位条，提供视觉反馈。
/// 可用于 AI 翻译、解析等异步内容区域的加载态。
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shimmer 骨架屏占位
class ShimmerPlaceholder extends StatefulWidget {
  /// 是否只显示单行占位；默认两行，翻译等短内容可使用单行。
  final bool singleLine;

  const ShimmerPlaceholder({super.key, this.singleLine = false});

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child!,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBar(width: double.infinity),
          if (!widget.singleLine) ...[
            const SizedBox(height: AppSpacing.s),
            _shimmerBar(width: 200),
          ],
        ],
      ),
    );
  }

  Widget _shimmerBar({required double width}) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
