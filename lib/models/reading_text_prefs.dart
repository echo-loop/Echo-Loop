/// 学习内容文字偏好（字号）
///
/// 只作用于学习正文（当前试点：字幕列表），不缩放整个界面。
/// 叠加在主题基础样式之上，系统字体缩放（`MediaQuery.textScaler`）仍照常生效。
library;

import 'package:flutter/material.dart';

/// 可选字号倍率档位（相对主题基础字号）。
///
/// 85% ~ 175%，每档 5%。离散档位比连续滑块更好测、更好同步，
/// 也避免出现 1.07 这类无意义的值。按整数百分比生成，避免浮点累加误差。
final readingFontScaleSteps = List<double>.unmodifiable(
  List.generate(19, (i) => (85 + 5 * i) / 100),
);

/// 默认字号倍率。
const readingFontScaleDefault = 1.0;

/// 基础样式未声明字号时的兜底值（Material bodyMedium 默认字号）。
const _fallbackBaseFontSize = 14.0;

/// 把任意倍率吸附到最近的档位；NaN 等非法值回退默认档。
double snapReadingFontScale(double value) {
  if (!value.isFinite) return readingFontScaleDefault;
  var best = readingFontScaleSteps.first;
  for (final step in readingFontScaleSteps) {
    if ((step - value).abs() < (best - value).abs()) best = step;
  }
  return best;
}

/// 学习内容文字偏好（不可变值对象）。
class ReadingTextPrefs {
  /// 字号倍率，取值来自 [readingFontScaleSteps]。
  final double fontScale;

  const ReadingTextPrefs({this.fontScale = readingFontScaleDefault});

  /// 从持久化原始值还原；缺失或非法值回退默认。
  factory ReadingTextPrefs.fromStored({required double? scale}) {
    return ReadingTextPrefs(
      fontScale: scale == null
          ? readingFontScaleDefault
          : snapReadingFontScale(scale),
    );
  }

  /// 把字号倍率叠加到 [base] 上，其余属性保留；默认倍率时原样返回。
  TextStyle applyTo(TextStyle base) {
    if (fontScale == readingFontScaleDefault) return base;
    return base.copyWith(
      fontSize: (base.fontSize ?? _fallbackBaseFontSize) * fontScale,
    );
  }

  /// 把字号倍率叠加到整套主题文字样式上（各档位字号同比缩放）；默认倍率时原样返回。
  ///
  /// 用于整块组件树无法逐个注入样式的场景（如词典结果面板）。
  TextTheme scaleTextTheme(TextTheme base) {
    if (fontScale == readingFontScaleDefault) return base;
    // 未声明字号的样式保持原样（TextStyle.apply 对此会断言失败）
    TextStyle? scale(TextStyle? style) {
      final size = style?.fontSize;
      if (style == null || size == null) return style;
      return style.copyWith(fontSize: size * fontScale);
    }

    return base.copyWith(
      displayLarge: scale(base.displayLarge),
      displayMedium: scale(base.displayMedium),
      displaySmall: scale(base.displaySmall),
      headlineLarge: scale(base.headlineLarge),
      headlineMedium: scale(base.headlineMedium),
      headlineSmall: scale(base.headlineSmall),
      titleLarge: scale(base.titleLarge),
      titleMedium: scale(base.titleMedium),
      titleSmall: scale(base.titleSmall),
      bodyLarge: scale(base.bodyLarge),
      bodyMedium: scale(base.bodyMedium),
      bodySmall: scale(base.bodySmall),
      labelLarge: scale(base.labelLarge),
      labelMedium: scale(base.labelMedium),
      labelSmall: scale(base.labelSmall),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingTextPrefs && other.fontScale == fontScale;

  @override
  int get hashCode => fontScale.hashCode;

  @override
  String toString() => 'ReadingTextPrefs(fontScale: $fontScale)';
}
