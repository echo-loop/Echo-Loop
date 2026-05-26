/// LearningSettingsScreen Widget 测试
///
/// 覆盖：
/// - 开关初始值显示
/// - 切换开关写入 SP + 翻转 state
/// - 说明文字渲染
library;

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/screens/learning_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> buildApp({bool autoSkipRetell = false}) async {
    SharedPreferences.setMockInitialValues({
      if (autoSkipRetell) LearningSettingsKeys.autoSkipRetell: true,
    });
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialLearningSettingsProvider.overrideWithValue(
          LearningSettings.fromPrefsSync(prefs),
        ),
        analyticsOverride(),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('zh')],
        home: LearningSettingsScreen(),
      ),
    );
  }

  testWidgets('默认显示开关 OFF + 说明文字', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    // 找到 "Auto-skip" label 所在的 SwitchListTile
    final autoSkipFinder = find.byWidgetPredicate(
      (w) => w is SwitchListTile && w.title is Text && (w.title as Text).data == 'Auto-skip speaking practice',
    );
    final switchTile = tester.widget<SwitchListTile>(autoSkipFinder);
    expect(switchTile.value, isFalse);
    expect(find.textContaining('Auto-skip'), findsWidgets);
  });

  testWidgets('点击开关 → 翻转 state + 写 SP', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    // 找到 "Auto-skip Retell" 的 SwitchListTile 并点击
    final autoSkipFinder = find.byWidgetPredicate(
      (w) => w is SwitchListTile && w.title is Text && (w.title as Text).data == 'Auto-skip speaking practice',
    );
    await tester.tap(autoSkipFinder);
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(autoSkipFinder);
    expect(switchTile.value, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LearningSettingsKeys.autoSkipRetell), isTrue);
  });

  testWidgets('初始 ON 时开关显示 ON', (tester) async {
    await tester.pumpWidget(await buildApp(autoSkipRetell: true));
    await tester.pumpAndSettle();

    // 找到 "Auto-skip Retell" 的 SwitchListTile
    final autoSkipFinder = find.byWidgetPredicate(
      (w) => w is SwitchListTile && w.title is Text && (w.title as Text).data == 'Auto-skip speaking practice',
    );
    final switchTile = tester.widget<SwitchListTile>(autoSkipFinder);
    expect(switchTile.value, isTrue);
  });
}
