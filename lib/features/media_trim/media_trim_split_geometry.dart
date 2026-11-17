import '../../widgets/common/practice_media_split_geometry.dart';

/// 剪辑页左右分栏（左：时间轴 + 转写，右：片段列表）的宽度规则。
abstract final class MediaTrimSplitGeometry {
  /// 未拖动过时右栏保持原有的固定宽度，窗口变宽的空间全部给时间轴。
  static const defaultClipColumnWidth = 400.0;

  /// 左栏最小宽度：时间轴仍能看清波形与片段边界。
  static const minTimelineColumnWidth = 480.0;

  /// 右栏最小宽度：与窄屏下片段列表的宽度相当，行内按钮不溢出。
  static const minClipColumnWidth = 360.0;

  static PracticeMediaExtentRange range(double width) =>
      PracticeMediaExtentRange.sideBySideColumns(
        width: width,
        minLeadingWidth: minTimelineColumnWidth,
        minTrailingWidth: minClipColumnWidth,
      );

  /// 左栏宽度：用户记住的比例优先，否则让右栏保持默认宽度。
  static double resolveTimelineWidth({
    required double width,
    required double? fraction,
  }) {
    final extentRange = range(width);
    final desired = fraction == null
        ? extentRange.available - defaultClipColumnWidth
        : extentRange.available * fraction;
    return extentRange.clamp(desired);
  }
}
