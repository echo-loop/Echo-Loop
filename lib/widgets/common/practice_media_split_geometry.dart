import 'dart:math' as math;
import 'dart:ui';

import '../../models/practice_media_split.dart';

/// 视频尺寸在当前空间下的可调范围。
class PracticeMediaExtentRange {
  const PracticeMediaExtentRange({
    required this.available,
    required this.min,
    required this.max,
  });

  /// 左右两栏页面中左栏宽度的可调范围；空间不足时优先保证右栏最小宽度。
  factory PracticeMediaExtentRange.sideBySideColumns({
    required double width,
    required double minLeadingWidth,
    required double minTrailingWidth,
  }) {
    final available = math.max(
      0.0,
      width - PracticeMediaSplitGeometry.dividerExtent,
    );
    final max = math.max(0.0, available - minTrailingWidth);
    return PracticeMediaExtentRange(
      available: available,
      min: math.min(minLeadingWidth, max),
      max: max,
    );
  }

  /// 视频与学习内容共享的主轴长度（已扣除分隔条）。
  final double available;
  final double min;
  final double max;

  double clamp(double extent) => extent.clamp(min, max).toDouble();

  /// 把视频尺寸换算成持久化比例；可用空间为 0 时没有有意义的比例。
  double? fractionOf(double extent) {
    if (available <= 0) return null;
    final fraction = extent / available;
    return fraction > 0 && fraction < 1 ? fraction : null;
  }
}

/// 学习任务页视频分栏的布局规则。
///
/// 所有阈值集中在这里，只依据实际可用空间计算，不判断设备型号或屏幕方向；
/// 调整布局手感时只需修改本文件的常量。
abstract final class PracticeMediaSplitGeometry {
  /// 宽度至少要放得下「最小视频 + 分隔条 + 最小学习区」才切到左右布局。
  static const sideBySideMinWidth = 720.0;

  /// 可用区域宽高比达到该值才切到左右布局；略大于 1 避免近似方形窗口来回跳。
  static const sideBySideMinAspectRatio = 1.2;

  /// 上下布局：学习内容至少保留的高度。
  ///
  /// 逐句精听实测：进度行 + 紧凑盲听区（倒计时、听不懂按钮）+ 底栏的硬下限约
  /// 282，再留约两行字幕的阅读空间。由回归测试「视频拉到最大时学习区不溢出」守护。
  static const stackedMinContentExtent = 340.0;

  /// 上下布局：视频最小高度，再小就看不清画面。
  static const stackedMinVideoExtent = 120.0;

  /// 上下布局默认视频高度上限（占可用高度的比例），其余留给学习内容。
  static const stackedDefaultMaxFraction = 0.42;

  /// 左右布局：学习内容最小宽度，约为一行 40 个英文单词字符的舒适阅读宽度。
  static const sideBySideMinContentExtent = 360.0;

  /// 左右布局：视频最小宽度。
  static const sideBySideMinVideoExtent = 280.0;

  /// 左右布局默认视频宽度比例。
  static const sideBySideDefaultFraction = 0.56;

  /// 视频尚未解码出宽高比时按常见横屏视频估算。
  static const fallbackVideoAspectRatio = 16 / 9;

  /// 分隔条在主轴上占用的长度，同时是拖动热区。
  static const dividerExtent = 14.0;

  static PracticeMediaSplitAxis resolveAxis(Size size) {
    final isWideEnough = size.width >= sideBySideMinWidth;
    final isLandscape =
        size.height > 0 && size.width / size.height >= sideBySideMinAspectRatio;
    return isWideEnough && isLandscape
        ? PracticeMediaSplitAxis.sideBySide
        : PracticeMediaSplitAxis.stacked;
  }

  /// 计算视频尺寸的可调范围。
  ///
  /// 上限同时受「学习内容最小尺寸」和「视频铺满交叉轴时的自然尺寸」约束：
  /// 超过自然尺寸只会多出黑边，没有意义。空间不足时优先保证学习内容。
  static PracticeMediaExtentRange extentRange({
    required PracticeMediaSplitAxis axis,
    required Size size,
    required double? videoAspectRatio,
  }) {
    final aspectRatio = _effectiveAspectRatio(videoAspectRatio);
    final (
      mainExtent,
      naturalVideoExtent,
      minContent,
      minVideo,
    ) = switch (axis) {
      PracticeMediaSplitAxis.stacked => (
        size.height,
        size.width / aspectRatio,
        stackedMinContentExtent,
        stackedMinVideoExtent,
      ),
      PracticeMediaSplitAxis.sideBySide => (
        size.width,
        size.height * aspectRatio,
        sideBySideMinContentExtent,
        sideBySideMinVideoExtent,
      ),
    };
    final available = math.max(0.0, mainExtent - dividerExtent);
    final max = math.max(
      0.0,
      math.min(naturalVideoExtent, available - minContent),
    );
    return PracticeMediaExtentRange(
      available: available,
      min: math.min(minVideo, max),
      max: max,
    );
  }

  /// 用户记住的比例优先，否则使用默认尺寸，最终都限制在可调范围内。
  static double resolveVideoExtent({
    required PracticeMediaSplitAxis axis,
    required PracticeMediaExtentRange range,
    required double? fraction,
  }) {
    final desired = fraction != null
        ? fraction * range.available
        : _defaultVideoExtent(axis, range);
    return range.clamp(desired);
  }

  /// 上下布局默认让视频按宽度自然铺满，但不超过可用高度的固定比例；
  /// 左右布局默认按固定比例分配宽度。
  static double _defaultVideoExtent(
    PracticeMediaSplitAxis axis,
    PracticeMediaExtentRange range,
  ) => switch (axis) {
    PracticeMediaSplitAxis.stacked =>
      range.available * stackedDefaultMaxFraction,
    PracticeMediaSplitAxis.sideBySide =>
      range.available * sideBySideDefaultFraction,
  };

  /// 视频在分给它的区域内按比例完整显示时的尺寸。
  ///
  /// 画面容器只占这块区域，其余空白露出页面背景：控制按钮贴着画面，
  /// 浅色主题下也不会出现大块黑边。
  static Size fittedVideoSize(Size box, double? videoAspectRatio) {
    final aspectRatio = _effectiveAspectRatio(videoAspectRatio);
    final width = math.min(box.width, box.height * aspectRatio);
    return Size(width, width / aspectRatio);
  }

  static double _effectiveAspectRatio(double? videoAspectRatio) =>
      videoAspectRatio != null &&
          videoAspectRatio.isFinite &&
          videoAspectRatio > 0
      ? videoAspectRatio
      : fallbackVideoAspectRatio;
}
