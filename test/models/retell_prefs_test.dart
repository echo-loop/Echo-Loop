import 'package:echo_loop/models/retell_prefs.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetellPrefs 复述模式', () {
    test('未设置时 resolve 为看英文', () {
      final settings = const RetellPrefs.empty().resolve(
        smartSpeed: 1.0,
        smartRatio: KeywordRatio.medium,
      );

      expect(settings.promptLanguage, RetellPromptLanguage.original);
    });

    test('看译文偏好可序列化往返并参与 resolve', () {
      const prefs = RetellPrefs(
        promptLanguage: RetellPromptLanguage.translation,
      );

      final restored = RetellPrefs.fromJson(prefs.toJson());

      expect(restored, prefs);
      expect(
        restored
            .resolve(smartSpeed: 1.0, smartRatio: KeywordRatio.medium)
            .promptLanguage,
        RetellPromptLanguage.translation,
      );
    });

    test('非法值视为未设置', () {
      final prefs = RetellPrefs.fromJson({'promptLanguage': 'unknown'});

      expect(prefs.promptLanguage, isNull);
    });
  });
}
