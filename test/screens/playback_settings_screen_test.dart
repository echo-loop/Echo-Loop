import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/screens/playback_settings_screen.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('播放设置中的逐词高亮开关默认开启并保存关闭选择', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        const PlaybackSettingsScreen(),
        overrides: dedupeOverrides([
          appSettingsProvider.overrideWith(
            () => TestAppSettings(const AppSettingsState()),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byWidgetPredicate((widget) {
      if (widget is! SwitchListTile) return false;
      final title = widget.title;
      return title is Text && title.data == 'Highlight Words During Playback';
    });
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('word_highlight_enabled'), isFalse);
  });

  testWidgets('播放设置中的暂停后从句首继续开关默认关闭并保存开启选择', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        const PlaybackSettingsScreen(),
        overrides: dedupeOverrides([
          appSettingsProvider.overrideWith(
            () => TestAppSettings(const AppSettingsState()),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byWidgetPredicate((widget) {
      if (widget is! SwitchListTile) return false;
      final title = widget.title;
      return title is Text && title.data == 'Replay from Sentence Start';
    });
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    expect(
      find.text(
        'When replaying the current sentence, playback will resume from where you paused',
      ),
      findsOneWidget,
    );

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    expect(
      find.text(
        'When replaying the current sentence, playback will start from its beginning',
      ),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('resume_from_sentence_start_enabled'), isTrue);
  });
}
