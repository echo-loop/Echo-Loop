import 'package:echo_loop/features/media_trim/media_trim_split_geometry.dart';
import 'package:echo_loop/features/media_trim/media_trim_split_provider.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MediaTrimSplitGeometry', () {
    test('默认右栏保持 400px，拖动范围保留两栏最小宽度', () {
      const width = 1280.0;
      final range = MediaTrimSplitGeometry.range(width);
      final defaultWidth = MediaTrimSplitGeometry.resolveTimelineWidth(
        width: width,
        fraction: null,
      );
      expect(range.available - defaultWidth, 400);
      expect(
        MediaTrimSplitGeometry.resolveTimelineWidth(width: width, fraction: 0),
        MediaTrimSplitGeometry.minTimelineColumnWidth,
      );
      expect(
        MediaTrimSplitGeometry.resolveTimelineWidth(width: width, fraction: 1),
        range.max,
      );
    });

    test('保存比例随窗口宽度变化并受最小宽度限制', () {
      const fraction = 0.65;
      expect(
        MediaTrimSplitGeometry.resolveTimelineWidth(
          width: 1280,
          fraction: fraction,
        ),
        closeTo((1280 - 14) * fraction, 0.001),
      );
      final narrowRange = MediaTrimSplitGeometry.range(960);
      expect(
        MediaTrimSplitGeometry.resolveTimelineWidth(
          width: 960,
          fraction: fraction,
        ),
        narrowRange.max,
      );
    });
  });

  group('MediaTrimSplitNotifier', () {
    test('保存、重载与复位比例', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      ProviderContainer createContainer() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );

      final first = createContainer();
      addTearDown(first.dispose);
      await first.read(mediaTrimSplitProvider.notifier).setFraction(0.6);
      expect(first.read(mediaTrimSplitProvider), 0.6);

      final second = createContainer();
      addTearDown(second.dispose);
      expect(second.read(mediaTrimSplitProvider), 0.6);
      await second.read(mediaTrimSplitProvider.notifier).setFraction(null);
      expect(second.read(mediaTrimSplitProvider), isNull);
      expect(
        preferences.containsKey(MediaTrimSplitNotifier.storageKey),
        isFalse,
      );
    });

    test('非法存储值视为默认布局', () async {
      SharedPreferences.setMockInitialValues({
        MediaTrimSplitNotifier.storageKey: 1.2,
      });
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
      expect(container.read(mediaTrimSplitProvider), isNull);
    });
  });
}
