import 'package:flutter/material.dart';

/// 学习进度配色（日间 / 夜间各一组）
///
/// active：进行中；completed：已完成；track：进度条底轨。
class LearningProgressColors {
  // 日间模式
  static const lightActive = Color(0xFF3B75C4);
  static const lightCompleted = Color(0xFF24A58B);
  static const lightTrack = Color(0xFFE5E8EE);

  // 夜间模式
  static const darkActive = Color(0xFF6A9FE6);
  static const darkCompleted = Color(0xFF45C6A8);
  static const darkTrack = Color(0xFF394252);
}

/// 按明暗主题取学习进度配色（学习页与学习日历的今日目标共用）
({Color active, Color completed, Color track}) learningProgressPalette(
  Brightness brightness,
) {
  return brightness == Brightness.dark
      ? (
          active: LearningProgressColors.darkActive,
          completed: LearningProgressColors.darkCompleted,
          track: LearningProgressColors.darkTrack,
        )
      : (
          active: LearningProgressColors.lightActive,
          completed: LearningProgressColors.lightCompleted,
          track: LearningProgressColors.lightTrack,
        );
}
