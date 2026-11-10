import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/screens/display_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 以给定的 SP 初值渲染显示设置页，返回对应的 prefs 以便断言持久化。
  Future<SharedPreferences> pumpScreen(
    WidgetTester tester, {
    Map<String, Object> initialValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialValues);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialLearningSettingsProvider.overrideWithValue(
            LearningSettings.fromPrefsSync(prefs),
          ),
        ]),
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('zh')],
          home: DisplaySettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  /// 页面有三个开关：依次为推荐卡片、周学习时长图、变速快捷按钮。
  bool recommendationSwitchValue(WidgetTester tester) {
    return tester
        .widget<SwitchListTile>(find.byType(SwitchListTile).at(0))
        .value;
  }

  bool weeklyChartSwitchValue(WidgetTester tester) {
    return tester
        .widget<SwitchListTile>(find.byType(SwitchListTile).at(1))
        .value;
  }

  bool playbackSpeedButtonSwitchValue(WidgetTester tester) {
    return tester
        .widget<SwitchListTile>(find.byType(SwitchListTile).at(2))
        .value;
  }

  testWidgets('默认开启显示推荐卡片', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Display Settings'), findsOneWidget);
    expect(recommendationSwitchValue(tester), isTrue);
  });

  testWidgets('关闭推荐卡片开关后写入 SP', (tester) async {
    final prefs = await pumpScreen(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(recommendationSwitchValue(tester), isFalse);
    expect(
      prefs.getBool(LearningSettingsKeys.showStudyRecommendation),
      isFalse,
    );
  });

  testWidgets('已关闭时开关显示关闭，重新开启后写入 true', (tester) async {
    final prefs = await pumpScreen(
      tester,
      initialValues: {LearningSettingsKeys.showStudyRecommendation: false},
    );
    expect(recommendationSwitchValue(tester), isFalse);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(recommendationSwitchValue(tester), isTrue);
    expect(prefs.getBool(LearningSettingsKeys.showStudyRecommendation), isTrue);
  });

  testWidgets('默认开启显示周学习时长图', (tester) async {
    await pumpScreen(tester);

    expect(weeklyChartSwitchValue(tester), isTrue);
  });

  testWidgets('关闭周学习时长图开关后写入 SP，且不影响推荐卡开关', (tester) async {
    final prefs = await pumpScreen(tester);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();

    expect(weeklyChartSwitchValue(tester), isFalse);
    expect(recommendationSwitchValue(tester), isTrue);
    expect(prefs.getBool(LearningSettingsKeys.showWeeklyStudyChart), isFalse);
  });

  testWidgets('默认开启倍速调节按钮，关闭后写入 SP 且不影响其他开关', (tester) async {
    final prefs = await pumpScreen(tester);

    expect(playbackSpeedButtonSwitchValue(tester), isTrue);

    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();

    expect(playbackSpeedButtonSwitchValue(tester), isFalse);
    expect(weeklyChartSwitchValue(tester), isTrue);
    expect(
      prefs.getBool(LearningSettingsKeys.showPlaybackSpeedButton),
      isFalse,
    );
  });
}
