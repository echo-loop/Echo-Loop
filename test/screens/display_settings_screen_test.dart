import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/screens/display_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialLearningSettingsProvider.overrideWithValue(
            LearningSettings.fromPrefsSync(prefs),
          ),
        ],
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

  bool recommendationSwitchValue(WidgetTester tester) {
    return tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;
  }

  testWidgets('默认开启显示推荐卡片', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Display Settings'), findsOneWidget);
    expect(recommendationSwitchValue(tester), isTrue);
  });

  testWidgets('关闭推荐卡片开关后写入 SP', (tester) async {
    final prefs = await pumpScreen(tester);

    await tester.tap(find.byType(Switch));
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

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(recommendationSwitchValue(tester), isTrue);
    expect(prefs.getBool(LearningSettingsKeys.showStudyRecommendation), isTrue);
  });
}
