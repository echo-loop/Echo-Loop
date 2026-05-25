/// 精听详情模式阶段状态机
library;

/// 精听详情模式阶段
sealed class IntensiveAnnotationPhase {
  const IntensiveAnnotationPhase();
}

/// 查看详情中
class InspectingAnnotation extends IntensiveAnnotationPhase {
  const InspectingAnnotation();
}

/// 带字幕重播当前句
class ReplayingWithSubtitle extends IntensiveAnnotationPhase {
  /// 剩余时长
  final Duration remaining;

  /// 总时长
  final Duration total;

  const ReplayingWithSubtitle({required this.remaining, required this.total});

  ReplayingWithSubtitle copyWith({Duration? remaining, Duration? total}) {
    return ReplayingWithSubtitle(
      remaining: remaining ?? this.remaining,
      total: total ?? this.total,
    );
  }
}

/// 详情模式下的句间等待
class WaitingAnnotationInterval extends IntensiveAnnotationPhase {
  /// 剩余时长
  final Duration remaining;

  /// 总时长
  final Duration total;

  /// 是否暂停
  final bool isPaused;

  const WaitingAnnotationInterval({
    required this.remaining,
    required this.total,
    this.isPaused = false,
  });

  WaitingAnnotationInterval copyWith({
    Duration? remaining,
    Duration? total,
    bool? isPaused,
  }) {
    return WaitingAnnotationInterval(
      remaining: remaining ?? this.remaining,
      total: total ?? this.total,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

/// 等待用户操作
class WaitingAnnotationUser extends IntensiveAnnotationPhase {
  const WaitingAnnotationUser();
}
