/// Onboarding 问卷 Riverpod Provider 集合
///
/// 单文件包含所有 provider，避免分散在多个小文件中。命名风格对齐
/// `lib/providers/new_user_guide_provider.dart`，使用手动 Notifier
/// （不走 riverpod_generator，简化构建链路）。
///
/// 单一 gate 体现在 `shouldShowSurveyProvider`：仅判断 `completed_at_ms`
/// 是否存在。老用户升级也会被弹出问卷，答完一次后永久过滤。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_logger.dart';
import '../data/onboarding_survey_storage.dart';
import '../models/onboarding_answers.dart';
import '../models/onboarding_question.dart';

/// SharedPreferences 实例。
///
/// 在 `main()` 加载 SP 之后通过 `ProviderScope.overrideWithValue` 注入。
/// 未 override 时抛出，避免误用未初始化的 SP。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  );
});

/// 问卷存储入口。
final onboardingStorageProvider = Provider<OnboardingSurveyStorage>((ref) {
  return OnboardingSurveyStorage(ref.read(sharedPreferencesProvider));
});

/// "问卷是否已完成"的初始值。
///
/// 在 `main()` 启动时同步读 SP（`completed_at_ms` 是否存在），通过
/// `overrideWithValue` 注入。GoRouter `redirect:` 是同步函数，
/// 必须在 main 提前读取，否则启动闪屏期间 redirect 拿不到状态。
final initialOnboardingCompletedProvider = Provider<bool>((ref) {
  throw UnimplementedError(
    'initialOnboardingCompletedProvider must be overridden in main()',
  );
});

/// 当前进程内的"问卷已完成"状态。
///
/// 启动时从 [initialOnboardingCompletedProvider] 拿到初值；用户答完
/// 问卷后由 `OnboardingAnswersNotifier.submit()` 调用 [markCompleted]
/// 翻转为 true。
class OnboardingCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(initialOnboardingCompletedProvider);

  /// 标记为已完成（仅写内存状态，不重复写 SP——SP 由 storage 层负责）。
  void markCompleted() {
    if (state) return;
    state = true;
    AppLogger.log('OnboardingSurvey', 'markCompleted');
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
      OnboardingCompletedNotifier.new,
    );

/// 当前问卷草稿答案。
///
/// 用户在两题之间切换时累积；点"完成"时调用 [submit] 写 SP +
/// 触发 [OnboardingCompletedNotifier.markCompleted]。
class OnboardingAnswersNotifier extends Notifier<OnboardingAnswers> {
  @override
  OnboardingAnswers build() => const OnboardingAnswers();

  /// 设置 Q1（学习目标）。切换 goal 时自动清掉旧分支副字段，
  /// 避免上一选项遗留 examType。
  void setGoal(String goal) {
    state = state.copyWith(
      goal: goal,
      clearExamType: goal != OnboardingGoal.exam,
      clearGoalOtherText: true,
    );
  }

  /// 设置 Q1.5（考试类型，仅 goal == exam 时使用）。
  void setExamType(String examType) {
    state = state.copyWith(examType: examType);
  }

  /// 设置 Q2（每日学习时长）。
  void setDailyMinutes(String dailyMinutes) {
    state = state.copyWith(dailyMinutes: dailyMinutes);
  }

  /// 设置 Q3（来源渠道）。切换到非"其他"渠道时清掉补充说明。
  void setReferralSource(String referralSource) {
    state = state.copyWith(
      referralSource: referralSource,
      clearReferralOtherText: referralSource != OnboardingReferralSource.other,
    );
  }

  /// 设置 Q3"其他"的补充说明。去首尾空白，超过上限的部分截断。
  void setReferralOtherText(String text) {
    final trimmed = text.trim();
    final capped =
        trimmed.length > OnboardingReferralSource.referralOtherTextMaxLength
        ? trimmed.substring(
            0,
            OnboardingReferralSource.referralOtherTextMaxLength,
          )
        : trimmed;
    state = state.copyWith(referralOtherText: capped);
  }

  /// 提交答案：写 SP（先答案后完成锚点），再翻转完成状态。
  ///
  /// 调用方必须保证两题都已答（按钮 disabled 已经保证）；否则抛错。
  Future<void> submit() async {
    final answers = state;
    if (!answers.isComplete) {
      throw StateError('Cannot submit: answers incomplete');
    }
    final storage = ref.read(onboardingStorageProvider);
    await storage.saveCompleted(answers);
    ref.read(onboardingCompletedProvider.notifier).markCompleted();
  }
}

final onboardingAnswersProvider =
    NotifierProvider<OnboardingAnswersNotifier, OnboardingAnswers>(
      OnboardingAnswersNotifier.new,
    );

/// 是否应该展示问卷（router redirect 同步判定）。
///
/// 唯一判定：问卷尚未完成（`completed_at_ms` 缺失）。
/// 老用户升级也会被弹出一次问卷；用户答完写入完成锚点后永久过滤。
final shouldShowSurveyProvider = Provider<bool>((ref) {
  return !ref.watch(onboardingCompletedProvider);
});
