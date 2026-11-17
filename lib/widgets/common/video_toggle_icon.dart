import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 画面开关图标：显示中为视频图标，收起时在图标上加斜线。
///
/// 剪辑页与字幕编辑页共用，颜色取自所在 [IconTheme]，与同排线条图标一致。
class VideoToggleIcon extends StatelessWidget {
  const VideoToggleIcon({super.key, required this.isVisible, this.size = 22});

  final bool isVisible;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.black;
    // video-2.svg 线宽约为视框的 1/13，22px 时约 1.67px，与页面其它线条图标一致。
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        foregroundPainter: isVisible
            ? null
            : _SlashPainter(
                color: color,
                gapColor: Theme.of(context).scaffoldBackgroundColor,
                scale: size / 22,
              ),
        child: SvgPicture.asset(
          'assets/icon/video-2.svg',
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _SlashPainter extends CustomPainter {
  const _SlashPainter({
    required this.color,
    required this.gapColor,
    required this.scale,
  });

  final Color color;

  /// 斜线两侧描一圈背景色，让斜线与图标线条分开，和系统「关闭」图标一致。
  final Color gapColor;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final from = Offset(size.width * 0.12, size.height * 0.1);
    final to = Offset(size.width * 0.88, size.height * 0.9);
    canvas
      ..drawLine(
        from,
        to,
        Paint()
          ..color = gapColor
          ..strokeWidth = 4.7 * scale
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        from,
        to,
        Paint()
          ..color = color
          ..strokeWidth = 1.67 * scale
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_SlashPainter old) =>
      old.color != color || old.gapColor != gapColor || old.scale != scale;
}
