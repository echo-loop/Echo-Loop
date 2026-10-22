/// Onboarding 问卷的 SharedPreferences 读写。
///
/// 复用项目已有的"是否新用户"判定（`first_launch_done` + `isFirstLaunchProvider`）。
/// 本模块只负责"问卷答案"的本地持久化。
///
/// SP 设计：
/// - `onboarding_completed_at_ms` 存在性 = 是否已完成
/// - `onboarding_goal` / `onboarding_daily_minutes` 存主答案
/// - `onboarding_exam_type` 仅当 goal == exam 时存在
/// - `onboarding_goal_other_text` 历史字段，仅在 SP 中遗留时读取，新答案不再写入
/// - 不引入冗余的 `onboarding_completed` bool，避免双写不一致
/// - `onboarding_uploaded_v1` 仅记录云端上传是否成功
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_answers.dart';
import '../models/onboarding_question.dart';

/// SharedPreferences key 常量
abstract final class OnboardingSurveyKeys {
  static const goal = 'onboarding_goal';
  static const examType = 'onboarding_exam_type';
  static const goalOtherText = 'onboarding_goal_other_text';
  static const dailyMinutes = 'onboarding_daily_minutes';
  static const referralSource = 'onboarding_referral_source';
  static const completedAtMs = 'onboarding_completed_at_ms';
  static const uploaded = 'onboarding_uploaded_v1';
}

/// SP 读写封装。
///
/// 所有对 onboarding SP 的访问必须经此类，方便测试和后续重构。
class OnboardingSurveyStorage {
  OnboardingSurveyStorage(this._prefs);

  final SharedPreferences _prefs;

  /// 当前问卷是否已完成。
  ///
  /// 判定依据：[OnboardingSurveyKeys.completedAtMs] 是否存在。
  bool get isCompleted =>
      _prefs.containsKey(OnboardingSurveyKeys.completedAtMs);

  /// 同步读取静态判定（在 main 启动期使用，避免 redirect 异步等待）。
  static bool readIsCompletedSync(SharedPreferences prefs) {
    return prefs.containsKey(OnboardingSurveyKeys.completedAtMs);
  }

  /// 加载已完成的答案；未完成或字段缺失返回 null。
  ///
  /// 校验答案编码必须落在合法集合内，否则视为无效返回 null。
  /// goal == exam 时 examType 必须合法；goalOtherText 仅作兼容字段读取，
  /// 不参与必填校验。
  ///
  /// referralSource：本轮新增字段，老用户 SP 中可能不存在；缺失时返回 null
  /// 答案（视为不可用画像）但保留完成锚点，避免重复弹问卷。
  OnboardingAnswers? loadAnswers() {
    final answers = loadAnswersForSync();
    if (answers == null || !answers.isComplete) return null;
    return answers;
  }

  /// 读取可用于云端补传的答案。
  ///
  /// 旧版本可能没有新增题目字段；只返回完成锚点存在且通过选项校验的
  /// 已保存字段。没有任何有效答案时返回 null，避免发送空对象。
  OnboardingAnswers? loadAnswersForSync() {
    if (!isCompleted) return null;

    final rawGoal = _prefs.getString(OnboardingSurveyKeys.goal);
    final goal = rawGoal != null && OnboardingGoal.all.contains(rawGoal)
        ? rawGoal
        : null;

    final rawDailyMinutes = _prefs.getString(OnboardingSurveyKeys.dailyMinutes);
    final dailyMinutes =
        rawDailyMinutes != null &&
            OnboardingDailyMinutes.all.contains(rawDailyMinutes)
        ? rawDailyMinutes
        : null;

    final rawReferralSource = _prefs.getString(
      OnboardingSurveyKeys.referralSource,
    );
    final referralSource =
        rawReferralSource != null &&
            OnboardingReferralSource.all.contains(rawReferralSource)
        ? rawReferralSource
        : null;

    String? examType;
    if (goal == OnboardingGoal.exam) {
      final rawExamType = _prefs.getString(OnboardingSurveyKeys.examType);
      if (rawExamType != null && OnboardingExamType.all.contains(rawExamType)) {
        examType = rawExamType;
      }
    }

    final goalOtherText = goal == OnboardingGoal.other
        ? _prefs.getString(OnboardingSurveyKeys.goalOtherText)
        : null;

    final answers = OnboardingAnswers(
      goal: goal,
      examType: examType,
      goalOtherText: goalOtherText,
      dailyMinutes: dailyMinutes,
      referralSource: referralSource,
    );
    return answers.toJson().isEmpty ? null : answers;
  }

  /// 完成时的时间戳；未完成返回 null。
  DateTime? get completedAt {
    final ms = _prefs.getInt(OnboardingSurveyKeys.completedAtMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// 一次性写入所有答案 + 完成时间戳。
  ///
  /// 调用方必须保证 [answers.isComplete] 为 true，否则抛 [ArgumentError]。
  /// `completed_at_ms` 最后写入，作为"完成"判定锚点；写入失败不会留下半完成状态。
  Future<void> saveCompleted(OnboardingAnswers answers, {DateTime? now}) async {
    if (!answers.isComplete) {
      throw ArgumentError('OnboardingAnswers must be complete before saving');
    }
    final completedAt = now ?? DateTime.now();
    // 先写答案，再写完成锚点。如果中间失败，下次启动会被识别为未完成
    // （但因 first_launch_done 已写，仍不会再弹——失去画像但不损坏状态）
    await _prefs.setString(OnboardingSurveyKeys.goal, answers.goal!);
    await _prefs.setString(
      OnboardingSurveyKeys.dailyMinutes,
      answers.dailyMinutes!,
    );
    // 副字段按 goal 分支写入；其它分支显式清掉避免残留
    if (answers.goal == OnboardingGoal.exam) {
      await _prefs.setString(OnboardingSurveyKeys.examType, answers.examType!);
    } else {
      await _prefs.remove(OnboardingSurveyKeys.examType);
    }
    // 历史 goalOtherText 字段已弃用，新答案统一清掉，防止旧值残留。
    await _prefs.remove(OnboardingSurveyKeys.goalOtherText);
    await _prefs.setString(
      OnboardingSurveyKeys.referralSource,
      answers.referralSource!,
    );
    await _prefs.setInt(
      OnboardingSurveyKeys.completedAtMs,
      completedAt.millisecondsSinceEpoch,
    );
  }

  /// 清空所有 onboarding 数据（仅供测试和"重答问卷"功能使用）。
  Future<void> clear() async {
    await _prefs.remove(OnboardingSurveyKeys.goal);
    await _prefs.remove(OnboardingSurveyKeys.examType);
    await _prefs.remove(OnboardingSurveyKeys.goalOtherText);
    await _prefs.remove(OnboardingSurveyKeys.dailyMinutes);
    await _prefs.remove(OnboardingSurveyKeys.referralSource);
    await _prefs.remove(OnboardingSurveyKeys.completedAtMs);
    await _prefs.remove(OnboardingSurveyKeys.uploaded);
  }
}
