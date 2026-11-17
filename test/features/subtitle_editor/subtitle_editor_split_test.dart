import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_split_geometry.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_split_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SubtitleEditorSplitGeometry', () {
    const chrome = 208.0;
    const padding = 24.0;

    double resolve(Size size, {double? aspectRatio, double? fraction}) =>
        SubtitleEditorSplitGeometry.resolveMediaColumnWidth(
          size: size,
          chromeHeight: chrome,
          horizontalPadding: padding,
          videoAspectRatio: aspectRatio,
          fraction: fraction,
        );

    test('默认让画面按比例填满左栏剩余高度', () {
      // 剩余高度 600 - 208 = 392，16:9 画面宽约 697，加左右留白。
      expect(
        resolve(const Size(1400, 600), aspectRatio: 16 / 9),
        moreOrLessEquals(392 * 16 / 9 + padding),
      );
    });

    test('高窗口画面变大，但自动适配时右栏保留舒适阅读宽度', () {
      const size = Size(1100, 1000);
      final width = resolve(size, aspectRatio: 16 / 9);
      final range = SubtitleEditorSplitGeometry.mediaColumnRange(size.width);
      expect(
        range.available - width,
        SubtitleEditorSplitGeometry.preferredSentenceColumnWidth,
      );
      // 用户拖动仍可把右栏压到最小宽度。
      expect(resolve(size, fraction: 0.99), range.max);
      expect(
        range.available - range.max,
        SubtitleEditorSplitGeometry.minSentenceColumnWidth,
      );
    });

    test('竖屏视频把宽度让给句子列表，左栏不小于最小宽度', () {
      expect(
        resolve(const Size(1280, 800), aspectRatio: 9 / 16),
        SubtitleEditorSplitGeometry.minMediaColumnWidth,
      );
    });

    test('用户记住的比例优先，并钳在可调范围内', () {
      const size = Size(1280, 800);
      final range = SubtitleEditorSplitGeometry.mediaColumnRange(size.width);
      expect(
        resolve(size, aspectRatio: 16 / 9, fraction: 0.5),
        moreOrLessEquals(range.available * 0.5),
      );
      expect(resolve(size, fraction: 0.95), range.max);
      expect(resolve(size, fraction: 0.05), range.min);
    });
  });

  group('SubtitleEditorSplitNotifier', () {
    Future<ProviderContainer> createContainer(
      Map<String, Object> values,
    ) async {
      SharedPreferences.setMockInitialValues(values);
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('保存比例后可读回，恢复自动适配时清除', () async {
      final container = await createContainer({});
      final notifier = container.read(subtitleEditorSplitProvider.notifier);
      expect(container.read(subtitleEditorSplitProvider), isNull);

      await notifier.setFraction(0.6);
      final preferences = await SharedPreferences.getInstance();
      expect(container.read(subtitleEditorSplitProvider), 0.6);
      expect(
        preferences.getDouble(SubtitleEditorSplitNotifier.storageKey),
        0.6,
      );

      await notifier.setFraction(null);
      expect(container.read(subtitleEditorSplitProvider), isNull);
      expect(
        preferences.containsKey(SubtitleEditorSplitNotifier.storageKey),
        isFalse,
      );
    });

    test('非法的历史值视为未设置', () async {
      final container = await createContainer({
        SubtitleEditorSplitNotifier.storageKey: 1.5,
      });
      expect(container.read(subtitleEditorSplitProvider), isNull);
    });
  });
}
