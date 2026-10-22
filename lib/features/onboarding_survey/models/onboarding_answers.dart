/// Onboarding 问卷答案模型
///
/// 不可变，用于在 Provider 中累积草稿和最终持久化。
library;

import 'package:flutter/foundation.dart';

import 'onboarding_question.dart';

@immutable
class OnboardingAnswers {
  /// Q1 学习目标编码（见 [OnboardingGoal]）；未答时为 null
  final String? goal;

  /// 当 goal == exam 时的考试类型（见 [OnboardingExamType]）；其它情况下为 null
  final String? examType;

  /// 历史字段，仅用于兼容旧版本 SP 中可能存在的“其他”自由文本。
  /// 当前 UI 不再采集，新答案不会写入。
  final String? goalOtherText;

  /// Q2 每日学习时长编码（见 [OnboardingDailyMinutes]）；未答时为 null
  final String? dailyMinutes;

  /// Q3 来源渠道编码（见 [OnboardingReferralSource]）；未答时为 null
  final String? referralSource;

  const OnboardingAnswers({
    this.goal,
    this.examType,
    this.goalOtherText,
    this.dailyMinutes,
    this.referralSource,
  });

  /// 将已有答案序列化为后端 onboarding API 接受的 JSON 对象。
  ///
  /// 旧版本可能只保存了部分题目；序列化时省略未填写字段，不补造答案。
  Map<String, Object?> toJson() => {
    if (goal != null) 'goal': goal,
    if (examType != null) 'examType': examType,
    if (goalOtherText != null) 'goalOtherText': goalOtherText,
    if (dailyMinutes != null) 'dailyMinutes': dailyMinutes,
    if (referralSource != null) 'referralSource': referralSource,
  };

  /// 全部必填项均已填齐：
  /// - goal、dailyMinutes、referralSource 必填
  /// - goal == exam 时 examType 必填
  bool get isComplete {
    if (goal == null || dailyMinutes == null || referralSource == null) {
      return false;
    }
    if (goal == OnboardingGoal.exam && examType == null) return false;
    return true;
  }

  /// copyWith 支持显式设为 null：[clearExamType] / [clearGoalOtherText]
  /// 设为 true 时把对应字段置回 null，用于切换 goal 时清掉旧分支的副字段。
  OnboardingAnswers copyWith({
    String? goal,
    String? examType,
    String? goalOtherText,
    String? dailyMinutes,
    String? referralSource,
    bool clearExamType = false,
    bool clearGoalOtherText = false,
  }) {
    return OnboardingAnswers(
      goal: goal ?? this.goal,
      examType: clearExamType ? null : (examType ?? this.examType),
      goalOtherText: clearGoalOtherText
          ? null
          : (goalOtherText ?? this.goalOtherText),
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      referralSource: referralSource ?? this.referralSource,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingAnswers &&
          other.goal == goal &&
          other.examType == examType &&
          other.goalOtherText == goalOtherText &&
          other.dailyMinutes == dailyMinutes &&
          other.referralSource == referralSource;

  @override
  int get hashCode =>
      Object.hash(goal, examType, goalOtherText, dailyMinutes, referralSource);

  @override
  String toString() =>
      'OnboardingAnswers(goal: $goal, examType: $examType, '
      'goalOtherText: $goalOtherText, dailyMinutes: $dailyMinutes, '
      'referralSource: $referralSource)';
}
