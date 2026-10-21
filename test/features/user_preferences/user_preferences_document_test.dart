import 'package:echo_loop/features/user_preferences/domain/user_preferences_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserPreferencesDocument', () {
    test(
      'merges independent field changes and preserves unknown cloud fields',
      () {
        final base = UserPreferencesDocument({
          'appearance': {'themeMode': 'system', 'locale': 'en'},
          'learning': {'autoSkipRetell': false, 'autoShowAiAnalysis': true},
          'futureGroup': {'enabled': true},
        });
        final local = UserPreferencesDocument({
          'appearance': {'themeMode': 'dark', 'locale': 'en'},
          'learning': {'autoSkipRetell': true, 'autoShowAiAnalysis': true},
        });
        final remote = UserPreferencesDocument({
          'appearance': {'themeMode': 'system', 'locale': 'zh-CN'},
          'learning': {'autoSkipRetell': false, 'autoShowAiAnalysis': false},
          'futureGroup': {'enabled': false, 'newField': 'preserve'},
        });

        final merged = UserPreferencesDocument.mergeLocalChanges(
          base: base,
          local: local,
          remote: remote,
        );

        expect(merged.preferences['appearance'], {
          'themeMode': 'dark',
          'locale': 'zh-CN',
        });
        expect(merged.preferences['learning'], {
          'autoSkipRetell': true,
          'autoShowAiAnalysis': false,
        });
        expect(merged.preferences['futureGroup'], {
          'enabled': false,
          'newField': 'preserve',
        });
      },
    );

    test('missing local map keys are not treated as deletions', () {
      final base = UserPreferencesDocument({
        'appearance': {'themeMode': 'dark', 'locale': 'zh-CN'},
      });
      final local = UserPreferencesDocument({
        'appearance': {'themeMode': 'dark'},
      });
      final remote = UserPreferencesDocument({
        'appearance': {'themeMode': 'dark', 'locale': 'zh-TW'},
      });

      expect(
        UserPreferencesDocument.hasLocalChanges(base: base, local: local),
        isFalse,
      );
      final merged = UserPreferencesDocument.mergeLocalChanges(
        base: base,
        local: local,
        remote: remote,
      );
      expect(merged.preferences['appearance'], {
        'themeMode': 'dark',
        'locale': 'zh-TW',
      });
    });

    test('rejects unsupported schema and non-JSON values', () {
      expect(
        () => UserPreferencesDocument.fromJson({
          'schemaVersion': 2,
          'preferences': {},
        }),
        throwsFormatException,
      );
      expect(
        () => UserPreferencesDocument({'unsupported': Object()}),
        throwsFormatException,
      );
    });
  });
}
