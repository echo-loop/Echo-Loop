/// 精听详情模式状态
library;

import 'intensive_annotation_phase.dart';

/// 精听详情模式状态
class IntensiveAnnotationState {
  /// 当前阶段
  final IntensiveAnnotationPhase phase;

  const IntensiveAnnotationState({this.phase = const InspectingAnnotation()});

  IntensiveAnnotationState copyWith({IntensiveAnnotationPhase? phase}) {
    return IntensiveAnnotationState(phase: phase ?? this.phase);
  }
}
