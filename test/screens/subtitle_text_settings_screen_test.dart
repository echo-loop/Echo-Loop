// 字幕文字设置页测试
//
// 验证：调整字号与粗细后，底部预览文本即时重绘，且偏好被持久化。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/models/subtitle_text_prefs.dart';
import 'package:echo_loop/screens/subtitle_text_settings_screen.dart';

import '../helpers/test_app.dart';

/// 预览文本开头，用来定位预览并读取其渲染样式。
const _previewPrefix = 'Learning a language';

Future<SharedPreferences> _pumpScreen(
  WidgetTester tester, [
  Map<String, Object> stored = const {},
]) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    createTestApp(
      const SubtitleTextSettingsScreen(),
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

TextStyle? _previewStyle(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining(_previewPrefix)).style;

/// 字号滑块在前，粗细滑块在后。
Finder _fontSizeSlider() => find.byType(Slider).first;
Finder _fontWeightSlider() => find.byType(Slider).last;

void main() {
  testWidgets('点放大字号：预览即时变大并持久化', (tester) async {
    final prefs = await _pumpScreen(tester);
    final before = _previewStyle(tester)?.fontSize ?? 0;

    await tester.tap(find.byTooltip('Larger text'));
    await tester.pumpAndSettle();

    expect(_previewStyle(tester)?.fontSize, closeTo(before * 1.05, 0.001));
    expect(find.text('105%'), findsOneWidget);
    expect(prefs.getInt('subtitle_font_size_percent'), 105);
  });

  testWidgets('预览在设置卡下方：调整字号时控件位置不变', (tester) async {
    await _pumpScreen(tester);
    final sliderTop = tester.getTopLeft(_fontSizeSlider()).dy;
    final previewTop = tester
        .getTopLeft(find.textContaining(_previewPrefix))
        .dy;
    expect(previewTop, greaterThan(sliderTop));

    await tester.tap(find.byTooltip('Larger text'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(_fontSizeSlider()).dy, sliderTop);
  });

  testWidgets('默认粗细为 100%，拖动粗细滑块即时生效并持久化', (tester) async {
    final prefs = await _pumpScreen(tester);
    expect(find.text('100%'), findsNWidgets(2)); // 字号与粗细各一行

    // 滑块值为档位下标：120% 对应下标 14（(120 - 50) / 5）
    tester.widget<Slider>(_fontWeightSlider()).onChanged!(14);
    await tester.pumpAndSettle();

    expect(find.text('120%'), findsOneWidget);
    expect(_previewStyle(tester)?.fontVariations, [
      const FontVariation('wght', 480),
    ]);
    expect(prefs.getInt('subtitle_font_weight_percent'), 120);
  });

  testWidgets('点加粗按钮：粗细逐档加重并持久化', (tester) async {
    final prefs = await _pumpScreen(tester);

    await tester.tap(find.byTooltip('Bolder'));
    await tester.pumpAndSettle();

    expect(find.text('105%'), findsOneWidget);
    expect(prefs.getInt('subtitle_font_weight_percent'), 105);
  });

  testWidgets('粗细已是最细 / 最粗档时对应按钮不可用', (tester) async {
    await _pumpScreen(tester, {'subtitle_font_weight_percent': 200});

    IconButton button(String tooltip) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );
    expect(button('Bolder').onPressed, isNull);
    expect(button('Lighter').onPressed, isNotNull);
  });

  testWidgets('字号与粗细滑轨起止位置一致', (tester) async {
    await _pumpScreen(tester);

    final sizeRect = tester.getRect(_fontSizeSlider());
    final weightRect = tester.getRect(_fontWeightSlider());
    expect(weightRect.left, sizeRect.left);
    expect(weightRect.right, sizeRect.right);

    // 两侧按钮尺寸一致：字形盒不能撑大按钮（高亮圆也随按钮变大）
    Size buttonSize(String tooltip) => tester.getSize(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );
    expect(buttonSize('Bolder'), buttonSize('Larger text'));
    expect(buttonSize('Lighter'), buttonSize('Smaller text'));
    expect(buttonSize('Bolder'), buttonSize('Lighter'));
  });

  testWidgets('已是最大档时放大按钮不可用', (tester) async {
    await _pumpScreen(tester, {
      'subtitle_font_size_percent': subtitleFontSizePercentSteps.last,
    });

    final increase = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Larger text'),
        matching: find.byType(IconButton),
      ),
    );
    expect(increase.onPressed, isNull);
  });
}
