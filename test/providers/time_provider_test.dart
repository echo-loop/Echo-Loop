import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/time_provider.dart';

import '../helpers/mock_providers.dart';

void main() {
  group('nowProvider', () {
    test('未设置时光机时返回实时系统时间', () {
      final before = DateTime.now();
      final container = ProviderContainer(
        overrides: [appSettingsProvider.overrideWith(() => TestAppSettings())],
      );
      addTearDown(container.dispose);

      final now = container.read(nowProvider)();
      final after = DateTime.now();

      expect(now.isAfter(before) || now.isAtSameMomentAs(before), isTrue);
      expect(now.isBefore(after) || now.isAtSameMomentAs(after), isTrue);
    });

    test('设置时光机后返回覆写时间', () {
      final fixed = DateTime(2026, 3, 11, 22, 15);
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          appSettingsProvider.overrideWith(
            () => TestAppSettings(AppSettingsState(timeMachineDateTime: fixed)),
          ),
        ]),
      );
      addTearDown(container.dispose);

      expect(container.read(nowProvider)(), fixed);
    });
  });
}
