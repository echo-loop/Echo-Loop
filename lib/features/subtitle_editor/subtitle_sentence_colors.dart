import 'package:flutter/material.dart';

/// 字幕编辑器的句子主题色：按句子序号循环取色，相邻句一定不同色。
///
/// 波形上的句子区间、句内单词、句子列表的编号共用同一颜色，便于对应。
/// 只用三种冷色（蓝、紫、青）：绿 / 红留给起止边界，橙留给播放头，避免语义混淆；
/// 三色轮换能保证「上一句 / 当前句 / 下一句」两两不同。亮色主题用中等明度保证在
/// 浅灰波形底上可读，暗色主题用高明度柔和色。
abstract final class SubtitleSentenceColors {
  static const _light = [
    Color(0xFF3D6FDB),
    Color(0xFF8250D0),
    Color(0xFF0B8AA6),
  ];

  static const _dark = [
    Color(0xFF8FB0FF),
    Color(0xFFC3A4FF),
    Color(0xFF5CCBE6),
  ];

  /// 第 [index] 句（按句子列表顺序，从 0 开始）的主题色。
  static Color of(int index, Brightness brightness) {
    final palette = brightness == Brightness.dark ? _dark : _light;
    return palette[index % palette.length];
  }

  /// 以第 [index] 句主题色为主色的配色：句子行内沿用主色的控件（选中描边、
  /// 播放按钮、高亮单词、编辑入口）随之换成该句颜色，与波形对应。暗色主题的
  /// 句子色明度高，实心底上用深色前景。
  static ColorScheme schemeFor(int index, ColorScheme base) => base.copyWith(
    primary: of(index, base.brightness),
    onPrimary: base.brightness == Brightness.dark
        ? const Color(0xFF15171D)
        : Colors.white,
  );
}
