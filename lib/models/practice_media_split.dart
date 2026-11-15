/// 学习任务页视频与学习内容的分栏方向。
enum PracticeMediaSplitAxis {
  /// 视频在上、学习内容在下，拖动分隔条调整视频高度。
  stacked,

  /// 视频在左、学习内容在右，拖动分隔条调整视频宽度。
  sideBySide,
}

/// 用户拖动后记住的视频尺寸。
///
/// 按可用空间的比例保存而非像素，窗口缩放后视频随之等比变化；两种分栏方向
/// 各自独立记忆，互不覆盖。null 表示用户未调整过，使用布局默认值。
class PracticeMediaSplit {
  const PracticeMediaSplit({
    this.stackedVideoFraction,
    this.sideBySideVideoFraction,
  });

  static const empty = PracticeMediaSplit();

  /// 上下布局时视频高度占可用高度的比例。
  final double? stackedVideoFraction;

  /// 左右布局时视频宽度占可用宽度的比例。
  final double? sideBySideVideoFraction;

  double? fractionFor(PracticeMediaSplitAxis axis) => switch (axis) {
    PracticeMediaSplitAxis.stacked => stackedVideoFraction,
    PracticeMediaSplitAxis.sideBySide => sideBySideVideoFraction,
  };

  PracticeMediaSplit withFraction(
    PracticeMediaSplitAxis axis,
    double? fraction,
  ) => switch (axis) {
    PracticeMediaSplitAxis.stacked => PracticeMediaSplit(
      stackedVideoFraction: fraction,
      sideBySideVideoFraction: sideBySideVideoFraction,
    ),
    PracticeMediaSplitAxis.sideBySide => PracticeMediaSplit(
      stackedVideoFraction: stackedVideoFraction,
      sideBySideVideoFraction: fraction,
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is PracticeMediaSplit &&
      other.stackedVideoFraction == stackedVideoFraction &&
      other.sideBySideVideoFraction == sideBySideVideoFraction;

  @override
  int get hashCode =>
      Object.hash(stackedVideoFraction, sideBySideVideoFraction);
}
