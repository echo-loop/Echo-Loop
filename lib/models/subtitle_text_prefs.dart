/// 字幕文字偏好（字号、粗细）
///
/// 只作用于学习正文（字幕列表、句子讲解、意群等），不缩放整个界面。
/// 叠加在主题基础样式之上：应用内 100% 即系统字体缩放后的基准，系统字体缩放
/// （`MediaQuery.textScaler`）照常生效，所有学习正文文字都必须跟随。
///
/// 100% 档的正文基准统一为 16pt、w400、字间距 0、行高 [subtitleBodyLineHeight]：
/// 原文正文样式一律基于 `bodyLarge`，不要再用 `bodyMedium`（14pt）或
/// `titleMedium`（w500）作正文，否则各页面字重、字间距和行距不一致。
/// 翻译、解析等次级文字不受此约束。
library;

import 'package:flutter/material.dart';

/// 字号百分比档位（相对主题基础字号）：85%~150%，每档 5%，默认 100%。
///
/// 离散档位比连续滑块更好测、更好同步，也避免出现 107% 这类无意义的值。
final subtitleFontSizePercentSteps = List<int>.unmodifiable(
  List.generate(14, (i) => 85 + 5 * i),
);

/// 默认字号百分比（100% 即主题基础字号）。
const subtitleFontSizePercentDefault = 100;

/// 字重百分比档位：50%~200%，每档 5%，默认 100%。
///
/// 以 [subtitleBaseFontWeight]（w400）为 100% 基准，样式字重 × 百分比得到最终字重。
/// 不直接用 [FontWeight]：它只有 w100~w900 九个固定值，表达不了 w430 这类中间值，
/// 精确值通过 `wght` 可变字体轴下发，见 [SubtitleTextPrefs._applyWeight]。
final subtitleFontWeightPercentSteps = List<int>.unmodifiable(
  List.generate(31, (i) => 50 + 5 * i),
);

/// 默认字重百分比（100% 即样式原字重）。
const subtitleFontWeightPercentDefault = 100;

/// 100% 对应的基准字重，与正文基准 bodyLarge 的 w400 一致。
const subtitleBaseFontWeight = 400;

/// 字重允许的最小 / 最大值（OpenType 规定的 wght 轴范围）。
const _minFontWeightValue = 100;
const _maxFontWeightValue = 900;

/// 学习正文统一行高。所有原文正文共用，避免各页面行距不一致。
const subtitleBodyLineHeight = 1.4;

/// 基础样式未声明字号时的兜底值（Material bodyMedium 默认字号）。
const _fallbackBaseFontSize = 14.0;

/// 把任意字号百分比吸附到最近的档位。
int snapSubtitleFontSizePercent(int value) {
  var best = subtitleFontSizePercentSteps.first;
  for (final step in subtitleFontSizePercentSteps) {
    if ((step - value).abs() < (best - value).abs()) best = step;
  }
  return best;
}

/// 把任意字重百分比吸附到最近的档位。
int snapSubtitleFontWeightPercent(int value) {
  var best = subtitleFontWeightPercentSteps.first;
  for (final step in subtitleFontWeightPercentSteps) {
    if ((step - value).abs() < (best - value).abs()) best = step;
  }
  return best;
}

/// 字幕文字偏好（不可变值对象）。
class SubtitleTextPrefs {
  /// 字号百分比，取值来自 [subtitleFontSizePercentSteps]；默认 100%。
  final int fontSizePercent;

  /// 字重百分比，取值来自 [subtitleFontWeightPercentSteps]；默认 100%。
  final int fontWeightPercent;

  const SubtitleTextPrefs({
    this.fontSizePercent = subtitleFontSizePercentDefault,
    this.fontWeightPercent = subtitleFontWeightPercentDefault,
  });

  /// 从持久化原始值还原；缺失或非法值回退默认。
  factory SubtitleTextPrefs.fromStored({
    int? fontSizePercent,
    int? fontWeightPercent,
  }) {
    return SubtitleTextPrefs(
      fontSizePercent: fontSizePercent == null
          ? subtitleFontSizePercentDefault
          : snapSubtitleFontSizePercent(fontSizePercent),
      fontWeightPercent: fontWeightPercent == null
          ? subtitleFontWeightPercentDefault
          : snapSubtitleFontWeightPercent(fontWeightPercent),
    );
  }

  bool get _isFontSizeDefault =>
      fontSizePercent == subtitleFontSizePercentDefault;

  bool get _isFontWeightDefault =>
      fontWeightPercent == subtitleFontWeightPercentDefault;

  /// 把字号与字重叠加到 [base] 上，其余属性保留；均为默认时原样返回。
  TextStyle applyTo(TextStyle base) {
    final sized = _isFontSizeDefault
        ? base
        : base.copyWith(
            fontSize:
                (base.fontSize ?? _fallbackBaseFontSize) *
                fontSizePercent /
                100,
          );
    return _applyWeight(sized);
  }

  /// 把字号百分比叠加到整套主题文字样式上（各档位字号同比缩放）；默认偏好时原样返回。
  ///
  /// 用于整块组件树无法逐个注入样式的场景（如词典结果面板）。
  TextTheme scaleTextTheme(TextTheme base) {
    if (_isFontSizeDefault && _isFontWeightDefault) return base;
    // 未声明字号的样式保持字号原样（TextStyle.apply 对此会断言失败）
    TextStyle? scale(TextStyle? style) {
      if (style == null) return null;
      final size = style.fontSize;
      final sized = (size == null || _isFontSizeDefault)
          ? style
          : style.copyWith(fontSize: size * fontSizePercent / 100);
      return _applyWeight(sized);
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

  /// 字重偏移按基础字重叠加，而不是直接覆盖：标题等本身 w600 的样式仍比正文粗，
  /// 只整体平移同一偏移量，保留原有层级。
  TextStyle _applyWeight(TextStyle style) {
    if (_isFontWeightDefault) return style;
    final baseValue = style.fontWeight?.value ?? subtitleBaseFontWeight;
    final targetValue = (baseValue * fontWeightPercent / 100).round().clamp(
      _minFontWeightValue,
      _maxFontWeightValue,
    );
    return style.copyWith(
      fontWeight: _nearestFontWeight(targetValue),
      fontVariations: [FontVariation('wght', targetValue.toDouble())],
    );
  }

  /// 最近的 [FontWeight] 枚举值，供不支持可变字重轴的系统字体回退使用。
  static FontWeight _nearestFontWeight(int value) {
    var best = FontWeight.values.first;
    for (final weight in FontWeight.values) {
      if ((weight.value - value).abs() < (best.value - value).abs()) {
        best = weight;
      }
    }
    return best;
  }

  @override
  bool operator ==(Object other) =>
      other is SubtitleTextPrefs &&
      other.fontSizePercent == fontSizePercent &&
      other.fontWeightPercent == fontWeightPercent;

  @override
  int get hashCode => Object.hash(fontSizePercent, fontWeightPercent);

  @override
  String toString() =>
      'SubtitleTextPrefs(fontSizePercent: $fontSizePercent, fontWeightPercent: $fontWeightPercent)';
}
