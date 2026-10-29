// 学习内容文字偏好（字号）模型测试
//
// 验证：持久化值解析回退、字号吸附到档位、样式叠加规则。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/reading_text_prefs.dart';

void main() {
  group('ReadingTextPrefs.fromStored 解析', () {
    test('未存过时为标准字号', () {
      expect(
        ReadingTextPrefs.fromStored(scale: null),
        const ReadingTextPrefs(),
      );
      expect(const ReadingTextPrefs().fontScale, 1.0);
    });

    test('合法值原样还原', () {
      expect(ReadingTextPrefs.fromStored(scale: 1.3).fontScale, 1.3);
    });

    test('档位为 85%~175%，每档 5%，且包含默认 100%', () {
      final percents = readingFontScaleSteps.map((s) => (s * 100).round());
      expect(percents.first, 85);
      expect(percents.last, 175);
      expect(percents.toSet().length, readingFontScaleSteps.length);
      final list = percents.toList();
      for (var i = 1; i < list.length; i++) {
        expect(list[i] - list[i - 1], 5);
      }
      expect(readingFontScaleSteps, contains(readingFontScaleDefault));
    });

    test('不在档位上的字号吸附到最近档位，越界取端点', () {
      expect(snapReadingFontScale(1.12), 1.1);
      expect(snapReadingFontScale(1.13), 1.15);
      expect(snapReadingFontScale(0.1), readingFontScaleSteps.first);
      expect(snapReadingFontScale(9), readingFontScaleSteps.last);
      expect(snapReadingFontScale(double.nan), 1.0);
    });
  });

  group('ReadingTextPrefs.applyTo 样式叠加', () {
    const base = TextStyle(
      fontSize: 14,
      fontFamily: 'Roboto',
      color: Color(0xFF123456),
    );

    test('默认偏好不改变基础样式', () {
      expect(const ReadingTextPrefs().applyTo(base), base);
    });

    test('字号按倍率放大，保留字体、颜色等其余属性', () {
      final style = const ReadingTextPrefs(fontScale: 1.5).applyTo(base);
      expect(style.fontSize, 21);
      expect(style.fontFamily, base.fontFamily);
      expect(style.color, base.color);
    });

    test('基础样式无字号时按 14 计算', () {
      final style = const ReadingTextPrefs(
        fontScale: 1.5,
      ).applyTo(const TextStyle());
      expect(style.fontSize, 21);
    });
  });

  group('ReadingTextPrefs.scaleTextTheme 主题缩放', () {
    const base = TextTheme(
      titleLarge: TextStyle(fontSize: 22, height: 1.2),
      bodyMedium: TextStyle(fontSize: 14),
      labelSmall: TextStyle(color: Color(0xFF000000)),
    );

    test('默认偏好原样返回', () {
      expect(const ReadingTextPrefs().scaleTextTheme(base), base);
    });

    test('带字号的档位按倍率缩放，其余属性保留', () {
      final scaled = const ReadingTextPrefs(
        fontScale: 1.5,
      ).scaleTextTheme(base);
      expect(scaled.titleLarge?.fontSize, 33);
      expect(scaled.titleLarge?.height, 1.2);
      expect(scaled.bodyMedium?.fontSize, 21);
    });

    test('未声明字号的档位保持原样且不抛错', () {
      final scaled = const ReadingTextPrefs(
        fontScale: 1.5,
      ).scaleTextTheme(base);
      expect(scaled.labelSmall, base.labelSmall);
    });
  });
}
