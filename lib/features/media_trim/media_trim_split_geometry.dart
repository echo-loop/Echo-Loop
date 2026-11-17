import 'dart:math' as math;

import '../../widgets/common/practice_media_split_geometry.dart';

/// 剪辑页左侧时间轴区域与右侧片段列表的宽度规则。
abstract final class MediaTrimSplitGeometry {
  static const defaultClipColumnWidth = 400.0;
  static const minTimelineColumnWidth = 480.0;
  static const minClipColumnWidth = 360.0;

  static PracticeMediaExtentRange range(double width) {
    final available = math.max(
      0.0,
      width - PracticeMediaSplitGeometry.dividerExtent,
    );
    final max = math.max(0.0, available - minClipColumnWidth);
    return PracticeMediaExtentRange(
      available: available,
      min: math.min(minTimelineColumnWidth, max),
      max: max,
    );
  }

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
