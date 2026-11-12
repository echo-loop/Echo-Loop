// 字幕文字偏好（字号、粗细）模型测试
//
// 验证：持久化值解析回退、字号与字重百分比吸附到档位、样式叠加规则。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/subtitle_text_prefs.dart';

void main() {
  group('SubtitleTextPrefs.fromStored 解析', () {
    test('未存过时为默认 100%', () {
      expect(SubtitleTextPrefs.fromStored(), const SubtitleTextPrefs());
      expect(const SubtitleTextPrefs().fontSizePercent, 100);
      expect(const SubtitleTextPrefs().fontWeightPercent, 100);
    });

    test('字号档位为 85%~150%，每档 5%，且包含默认 100%', () {
      expect(subtitleFontSizePercentSteps.first, 85);
      expect(subtitleFontSizePercentSteps.last, 150);
      expect(subtitleFontSizePercentSteps.length, 14);
      expect(subtitleFontSizePercentSteps, contains(100));
    });

    test('不在档位上的字号吸附到最近档位，越界取端点', () {
      expect(snapSubtitleFontSizePercent(112), 110);
      expect(snapSubtitleFontSizePercent(113), 115);
      expect(snapSubtitleFontSizePercent(10), 85);
      expect(snapSubtitleFontSizePercent(900), 150);
    });

    test('字重百分比为 50%~200%，每档 5%，默认 100%（对应 w400）', () {
      expect(subtitleFontWeightPercentSteps.first, 50);
      expect(subtitleFontWeightPercentSteps.last, 200);
      expect(subtitleFontWeightPercentSteps.length, 31);
      expect(subtitleFontWeightPercentSteps, contains(100));
      expect(subtitleBaseFontWeight, 400);
    });

    test('字重百分比非法值吸附到最近档位', () {
      expect(snapSubtitleFontWeightPercent(47), 50);
      expect(snapSubtitleFontWeightPercent(52), 50);
      expect(snapSubtitleFontWeightPercent(53), 55);
      expect(snapSubtitleFontWeightPercent(77), 75);
      expect(snapSubtitleFontWeightPercent(250), 200);
      expect(snapSubtitleFontWeightPercent(-10), 50);
    });
  });

  group('SubtitleTextPrefs.applyTo 样式叠加', () {
    const base = TextStyle(
      fontSize: 14,
      fontFamily: 'Roboto',
      color: Color(0xFF123456),
    );

    test('默认偏好不改变基础样式', () {
      expect(const SubtitleTextPrefs().applyTo(base), base);
    });

    test('字号按百分比放大，保留字体、颜色等其余属性', () {
      final style = const SubtitleTextPrefs(fontSizePercent: 150).applyTo(base);
      expect(style.fontSize, 21);
      expect(style.fontFamily, base.fontFamily);
      expect(style.color, base.color);
    });

    test('基础样式无字号时按 14 计算', () {
      final style = const SubtitleTextPrefs(fontSizePercent: 150)
          .applyTo(const TextStyle());
      expect(style.fontSize, 21);
    });

    test('字重百分比以 w400 为基准换算，并写入精确 wght 轴', () {
      // 400 × 90% = 360，枚举回退取最近的 w400
      final style = const SubtitleTextPrefs(fontWeightPercent: 90)
          .applyTo(base);
      expect(style.fontVariations, [const FontVariation('wght', 360)]);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontSize, base.fontSize);
    });

    test('字重按样式原字重换算，标题等强调样式保持层级', () {
      const title = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
      final style = const SubtitleTextPrefs(fontWeightPercent: 85)
          .applyTo(title);
      // 600 × 85% = 510，仍比正文 400 × 85% = 340 粗
      expect(style.fontVariations, [const FontVariation('wght', 510)]);
      expect(style.fontWeight, FontWeight.w500);
    });

    test('字号与字重可同时生效', () {
      final style = const SubtitleTextPrefs(
        fontSizePercent: 150,
        fontWeightPercent: 150,
      ).applyTo(base);
      expect(style.fontSize, 21);
      expect(style.fontVariations, [const FontVariation('wght', 600)]);
    });
  });

  group('SubtitleTextPrefs.scaleTextTheme 主题缩放', () {
    const base = TextTheme(
      titleLarge: TextStyle(fontSize: 22, height: 1.2),
      bodyMedium: TextStyle(fontSize: 14),
      labelSmall: TextStyle(color: Color(0xFF000000)),
    );

    test('默认偏好原样返回', () {
      expect(const SubtitleTextPrefs().scaleTextTheme(base), base);
    });

    test('带字号的档位按百分比缩放，其余属性保留', () {
      final scaled = const SubtitleTextPrefs(fontSizePercent: 150)
          .scaleTextTheme(base);
      expect(scaled.titleLarge?.fontSize, 33);
      expect(scaled.titleLarge?.height, 1.2);
      expect(scaled.bodyMedium?.fontSize, 21);
    });

    test('未声明字号的档位保持原样且不抛错', () {
      final scaled = const SubtitleTextPrefs(fontSizePercent: 150)
          .scaleTextTheme(base);
      expect(scaled.labelSmall, base.labelSmall);
    });

    test('仅调字重时字号不变，未声明字重的档位同样按百分比换算', () {
      final scaled = const SubtitleTextPrefs(fontWeightPercent: 75)
          .scaleTextTheme(base);
      expect(scaled.bodyMedium?.fontSize, 14);
      // 400 × 75% = 300
      expect(scaled.bodyMedium?.fontVariations, [
        const FontVariation('wght', 300),
      ]);
    });
  });
}
