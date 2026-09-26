import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/providers/desktop_sidebar_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to expanded and restores the saved preference', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final firstContainer = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(firstContainer.dispose);

    expect(firstContainer.read(desktopSidebarExpandedProvider), isTrue);

    await firstContainer
        .read(desktopSidebarExpandedProvider.notifier)
        .setExpanded(false);
    expect(
      preferences.getBool(DesktopSidebarExpandedNotifier.storageKey),
      isFalse,
    );

    final restoredContainer = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(restoredContainer.dispose);
    expect(restoredContainer.read(desktopSidebarExpandedProvider), isFalse);
  });

  test('loads an existing collapsed preference synchronously', () async {
    SharedPreferences.setMockInitialValues({
      DesktopSidebarExpandedNotifier.storageKey: false,
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(desktopSidebarExpandedProvider), isFalse);
  });

  test(
    'persists rapid changes in the same order as the latest state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(desktopSidebarExpandedProvider.notifier);
      final collapse = notifier.setExpanded(false);
      final expand = notifier.setExpanded(true);
      await Future.wait([collapse, expand]);

      expect(container.read(desktopSidebarExpandedProvider), isTrue);
      expect(
        preferences.getBool(DesktopSidebarExpandedNotifier.storageKey),
        isTrue,
      );
    },
  );
}
