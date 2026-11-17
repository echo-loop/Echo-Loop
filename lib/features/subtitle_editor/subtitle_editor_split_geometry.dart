import 'dart:math' as math;
import 'dart:ui';

import '../../widgets/common/practice_media_split_geometry.dart';

/// 字幕编辑页左右分栏（左：画面 + 工具条 + 波形，右：句子列表）的宽度规则。
///
/// 与学习任务页不同，左栏除画面外还有固定高度的工具条和波形，因此默认宽度不按
/// 固定比例，而是让画面按视频比例刚好填满左栏剩余高度：高窗口画面自动变大、
/// 不留大片空白，竖屏视频自动把宽度让给句子列表。
abstract final class SubtitleEditorSplitGeometry {
  /// 左栏最小宽度：放得下画面开关、缩放按钮、滑杆和倍速胶囊。
  static const minMediaColumnWidth = 360.0;

  /// 右栏最小宽度：用户拖动时允许压到的下限。
  static const minSentenceColumnWidth = 360.0;

  /// 自动适配时右栏至少保留的宽度：单词 chip 换行不至于过密的舒适阅读宽度。
  static const preferredSentenceColumnWidth = 420.0;

  /// 左栏宽度的可调范围；空间不足时优先保证句子列表。
  static PracticeMediaExtentRange mediaColumnRange(double width) =>
      PracticeMediaExtentRange.sideBySideColumns(
        width: width,
        minLeadingWidth: minMediaColumnWidth,
        minTrailingWidth: minSentenceColumnWidth,
      );

  /// 左栏宽度：用户记住的比例优先，否则按「画面填满剩余高度」自动计算。
  ///
  /// [chromeHeight] 是左栏中画面以外的固定高度（工具条、波形与上下留白），
  /// [horizontalPadding] 是画面左右留白之和。
  static double resolveMediaColumnWidth({
    required Size size,
    required double chromeHeight,
    required double horizontalPadding,
    required double? videoAspectRatio,
    required double? fraction,
  }) {
    final range = mediaColumnRange(size.width);
    if (fraction != null) return range.clamp(range.available * fraction);
    final aspectRatio = videoAspectRatio != null && videoAspectRatio > 0
        ? videoAspectRatio
        : PracticeMediaSplitGeometry.fallbackVideoAspectRatio;
    final videoHeight = math.max(0.0, size.height - chromeHeight);
    final autoMax = math.max(
      range.min,
      math.min(range.max, range.available - preferredSentenceColumnWidth),
    );
    return (videoHeight * aspectRatio + horizontalPadding)
        .clamp(range.min, autoMax)
        .toDouble();
  }
}
