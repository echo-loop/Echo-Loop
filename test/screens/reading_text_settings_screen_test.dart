// 文字大小设置页测试
//
// 验证：调整字号后，底部预览文本即时重绘，且偏好被持久化。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/models/reading_text_prefs.dart';
import 'package:echo_loop/screens/reading_text_settings_screen.dart';

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
      const ReadingTextSettingsScreen(),
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

TextStyle? _previewStyle(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining(_previewPrefix)).style;

void main() {
  testWidgets('点放大字号：预览即时变大并持久化', (tester) async {
    final prefs = await _pumpScreen(tester);
    final before = _previewStyle(tester)?.fontSize ?? 0;

    await tester.tap(find.byTooltip('Larger text'));
    await tester.pumpAndSettle();

    expect(_previewStyle(tester)?.fontSize, closeTo(before * 1.05, 0.001));
    expect(find.text('105%'), findsOneWidget);
    expect(prefs.getDouble('reading_font_scale'), 1.05);
  });

  testWidgets('预览在设置卡下方：调整字号时控件位置不变', (tester) async {
    await _pumpScreen(tester);
    final sliderTop = tester.getTopLeft(find.byType(Slider)).dy;
    final previewTop = tester
        .getTopLeft(find.textContaining(_previewPrefix))
        .dy;
    expect(previewTop, greaterThan(sliderTop));

    await tester.tap(find.byTooltip('Larger text'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(Slider)).dy, sliderTop);
  });

  testWidgets('已是最大档时放大按钮不可用', (tester) async {
    await _pumpScreen(tester, {
      'reading_font_scale': readingFontScaleSteps.last,
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
