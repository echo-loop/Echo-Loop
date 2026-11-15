import 'package:echo_loop/models/practice_media_split.dart';
import 'package:echo_loop/widgets/common/practice_media_split_geometry.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const divider = PracticeMediaSplitGeometry.dividerExtent;

  group('resolveAxis', () {
    test('手机竖屏、iPad 竖屏与分屏窄窗口使用上下布局', () {
      for (final size in const [
        Size(390, 760),
        Size(820, 1100),
        Size(590, 760),
      ]) {
        expect(
          PracticeMediaSplitGeometry.resolveAxis(size),
          PracticeMediaSplitAxis.stacked,
          reason: '$size',
        );
      }
    });

    test('iPad 横屏与桌面宽窗口使用左右布局', () {
      for (final size in const [Size(1180, 740), Size(1400, 860)]) {
        expect(
          PracticeMediaSplitGeometry.resolveAxis(size),
          PracticeMediaSplitAxis.sideBySide,
          reason: '$size',
        );
      }
    });

    test('宽度足够但接近方形时保持上下布局，避免拖动窗口时来回跳', () {
      expect(
        PracticeMediaSplitGeometry.resolveAxis(const Size(900, 800)),
        PracticeMediaSplitAxis.stacked,
      );
    });
  });

  group('resolveVideoExtent', () {
    test('上下布局默认按视频宽度自然铺满，不超过默认高度比例', () {
      const size = Size(390, 700);
      final range = PracticeMediaSplitGeometry.extentRange(
        axis: PracticeMediaSplitAxis.stacked,
        size: size,
        videoAspectRatio: 16 / 9,
      );
      final extent = PracticeMediaSplitGeometry.resolveVideoExtent(
        axis: PracticeMediaSplitAxis.stacked,
        range: range,
        fraction: null,
      );
      expect(extent, closeTo(390 * 9 / 16, 0.01));
    });

    test('上下布局竖屏视频默认受高度比例限制', () {
      const size = Size(820, 1000);
      final range = PracticeMediaSplitGeometry.extentRange(
        axis: PracticeMediaSplitAxis.stacked,
        size: size,
        videoAspectRatio: 9 / 16,
      );
      final extent = PracticeMediaSplitGeometry.resolveVideoExtent(
        axis: PracticeMediaSplitAxis.stacked,
        range: range,
        fraction: null,
      );
      expect(
        extent,
        closeTo(
          (1000 - divider) *
              PracticeMediaSplitGeometry.stackedDefaultMaxFraction,
          0.01,
        ),
      );
    });

    test('记住的比例超出范围时保证学习内容最小高度', () {
      const size = Size(820, 1000);
      final range = PracticeMediaSplitGeometry.extentRange(
        axis: PracticeMediaSplitAxis.stacked,
        size: size,
        videoAspectRatio: 9 / 16,
      );
      final extent = PracticeMediaSplitGeometry.resolveVideoExtent(
        axis: PracticeMediaSplitAxis.stacked,
        range: range,
        fraction: 0.95,
      );
      expect(
        extent,
        1000 - divider - PracticeMediaSplitGeometry.stackedMinContentExtent,
      );
    });

    test('左右布局按记住的比例分配宽度', () {
      const size = Size(1200, 800);
      final range = PracticeMediaSplitGeometry.extentRange(
        axis: PracticeMediaSplitAxis.sideBySide,
        size: size,
        videoAspectRatio: 16 / 9,
      );
      final extent = PracticeMediaSplitGeometry.resolveVideoExtent(
        axis: PracticeMediaSplitAxis.sideBySide,
        range: range,
        fraction: 0.5,
      );
      expect(extent, (1200 - divider) * 0.5);
      expect(range.fractionOf(extent), 0.5);
    });

    test('左右布局竖屏视频宽度不超过铺满高度时的自然宽度', () {
      const size = Size(1200, 800);
      final range = PracticeMediaSplitGeometry.extentRange(
        axis: PracticeMediaSplitAxis.sideBySide,
        size: size,
        videoAspectRatio: 9 / 16,
      );
      final extent = PracticeMediaSplitGeometry.resolveVideoExtent(
        axis: PracticeMediaSplitAxis.sideBySide,
        range: range,
        fraction: null,
      );
      expect(extent, 800 * 9 / 16);
    });

    test('空间不足以同时满足两侧最小值时优先保证学习内容', () {
      const size = Size(390, 400);
      final range = PracticeMediaSplitGeometry.extentRange(
        axis: PracticeMediaSplitAxis.stacked,
        size: size,
        videoAspectRatio: 16 / 9,
      );
      expect(
        range.max,
        400 - divider - PracticeMediaSplitGeometry.stackedMinContentExtent,
      );
      expect(range.min, range.max);
    });
  });

  group('fittedVideoSize', () {
    test('横屏视频在高区域内按宽度贴合，竖屏视频在宽区域内按高度贴合', () {
      expect(
        PracticeMediaSplitGeometry.fittedVideoSize(
          const Size(640, 800),
          16 / 9,
        ),
        const Size(640, 360),
      );
      expect(
        PracticeMediaSplitGeometry.fittedVideoSize(
          const Size(800, 320),
          9 / 16,
        ),
        const Size(180, 320),
      );
    });
  });
}
