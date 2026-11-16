import 'package:flutter/material.dart';

/// 片段配色：按片段序号循环取色，相邻片段一定不同色。
///
/// 时间轴区间、片段列表、字幕色条共用同一颜色，便于对应。色相按"冷暖交替"排列
/// （蓝、玫红、青、琥珀、紫、绿），首尾相接时也不相近；亮色主题用中等明度保证白字
/// 可读，暗色主题用高明度柔和色配深色字。
class MediaTrimClipColor {
  const MediaTrimClipColor._(this.base, this.onBase);

  /// 实色：选中框、把手、序号底色、片段内波形。
  final Color base;

  /// 实色之上的文字和箭头。
  final Color onBase;

  static const _light = [
    Color(0xFF3D6FDB),
    Color(0xFFCC4A70),
    Color(0xFF138A7E),
    Color(0xFFB36F00),
    Color(0xFF7A56CF),
    Color(0xFF4C8A2C),
  ];

  static const _dark = [
    Color(0xFF93B2FF),
    Color(0xFFFF9AB6),
    Color(0xFF62D2C4),
    Color(0xFFF2BE5E),
    Color(0xFFC4A8FF),
    Color(0xFFA6D483),
  ];

  static const _onDark = Color(0xFF15171D);

  /// 第 [index] 个片段（按开始时间排序，从 0 开始）的颜色。
  static MediaTrimClipColor of(int index, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? _dark : _light;
    return MediaTrimClipColor._(
      palette[index % palette.length],
      isDark ? _onDark : Colors.white,
    );
  }
}
