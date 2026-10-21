import 'dart:convert';

import 'package:echo_loop/features/user_preferences/data/local_user_preferences_store.dart';
import 'package:echo_loop/features/user_preferences/domain/user_preferences_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'captures the user preference whitelist and excludes device state',
    () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'locale': 'zh-CN',
        'native_language': 'zh-TW',
        'learning_auto_skip_retell': true,
        'learning_retell_auto_playback_prompt_shown': true,
        'demo_mode': true,
        'developer_time_machine_at_ms': 123,
        'audio_list_sort_type': 'nameAsc',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LocalUserPreferencesStore(prefs);

      final document = store.capture();
      final json = document.toJson();

      expect(document.preferences['appearance'], {
        'themeMode': 'dark',
        'locale': 'zh-CN',
        'nativeLanguage': 'zh-TW',
      });
      expect(
        (document.preferences['learning'] as Map)['autoSkipRetell'],
        isTrue,
      );
      expect(
        (document.preferences['lists'] as Map)['audioSortType'],
        'nameAsc',
      );
      expect(jsonEncode(json), isNot(contains('demo_mode')));
      expect(jsonEncode(json), isNot(contains('developer_time_machine')));
      expect(jsonEncode(json), isNot(contains('retell_auto_playback_prompt')));
    },
  );

  test(
    'applies cloud settings without touching developer or temporary state',
    () async {
      SharedPreferences.setMockInitialValues({
        'demo_mode': true,
        'developer_time_machine_at_ms': 987,
        'learning_retell_auto_playback_prompt_shown': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LocalUserPreferencesStore(prefs);

      await store.apply(
        UserPreferencesDocument({
          'appearance': {
            'themeMode': 'light',
            'locale': 'en',
            'nativeLanguage': 'zh-CN',
          },
          'learning': {'autoSkipRetell': true},
          'playback': {'skipSilenceEnabled': false},
        }),
      );

      expect(prefs.getString('theme_mode'), 'light');
      expect(prefs.getBool('learning_auto_skip_retell'), isTrue);
      expect(prefs.getBool('skip_silence_enabled'), isFalse);
      expect(prefs.getBool('demo_mode'), isTrue);
      expect(prefs.getInt('developer_time_machine_at_ms'), 987);
      expect(
        prefs.getBool('learning_retell_auto_playback_prompt_shown'),
        isTrue,
      );
    },
  );
}
