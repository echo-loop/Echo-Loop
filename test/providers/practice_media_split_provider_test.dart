import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/providers/practice_media_split_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> createContainer(
    Map<String, Object> initialValues,
  ) async {
    SharedPreferences.setMockInitialValues(initialValues);
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('两种分栏方向各自记住比例，重新读取后恢复', () async {
    final container = await createContainer({});
    final notifier = container.read(practiceMediaSplitProvider.notifier);

    await notifier.setVideoFraction(PracticeMediaSplitAxis.stacked, 0.3);
    await notifier.setVideoFraction(PracticeMediaSplitAxis.sideBySide, 0.6);

    final preferences = await SharedPreferences.getInstance();
    final restored = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(restored.dispose);
    expect(
      restored.read(practiceMediaSplitProvider),
      const PracticeMediaSplit(
        stackedVideoFraction: 0.3,
        sideBySideVideoFraction: 0.6,
      ),
    );
  });

  test('恢复默认时删除对应方向的本地值，不影响另一方向', () async {
    final container = await createContainer({
      PracticeMediaSplitNotifier.stackedStorageKey: 0.3,
      PracticeMediaSplitNotifier.sideBySideStorageKey: 0.6,
    });

    await container
        .read(practiceMediaSplitProvider.notifier)
        .setVideoFraction(PracticeMediaSplitAxis.stacked, null);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.containsKey(PracticeMediaSplitNotifier.stackedStorageKey),
      isFalse,
    );
    expect(
      container.read(practiceMediaSplitProvider).sideBySideVideoFraction,
      0.6,
    );
  });

  test('非法的历史值视为未设置', () async {
    final container = await createContainer({
      PracticeMediaSplitNotifier.stackedStorageKey: 1.5,
    });

    expect(
      container.read(practiceMediaSplitProvider).stackedVideoFraction,
      isNull,
    );
  });
}
