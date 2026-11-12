import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/screens/sound_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('zh')],
          home: SoundSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool soundEffectsSwitchValue(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  testWidgets('音效开关默认开启，关闭后持久化', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpScreen(tester);
    expect(soundEffectsSwitchValue(tester), isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(soundEffectsSwitchValue(tester), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sound_effects_enabled'), isFalse);
  });

  testWidgets('读取已保存的关闭状态', (tester) async {
    SharedPreferences.setMockInitialValues({'sound_effects_enabled': false});
    await pumpScreen(tester);

    expect(soundEffectsSwitchValue(tester), isFalse);
  });
}
