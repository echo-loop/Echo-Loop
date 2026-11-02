import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'package:echo_loop/features/onboarding_survey/models/onboarding_answers.dart';
import 'package:echo_loop/features/onboarding_survey/models/onboarding_question.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../helpers/mock_providers.dart';

ProviderContainer _makeContainer({
  required bool initialOnboardingCompleted,
  required SharedPreferences prefs,
}) {
  return ProviderContainer(
    overrides: dedupeOverrides([
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialOnboardingCompletedProvider.overrideWithValue(
        initialOnboardingCompleted,
      ),
    ]),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('shouldShowSurveyProvider', () {
    test('未完成 → true（无论老用户还是新用户都弹一次）', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(shouldShowSurveyProvider), isTrue);
    });

    test('已完成 → false', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: true,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(shouldShowSurveyProvider), isFalse);
    });

    test('完成后 shouldShowSurveyProvider 立即变 false', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);

      expect(container.read(shouldShowSurveyProvider), isTrue);
      container.read(onboardingCompletedProvider.notifier).markCompleted();
      expect(container.read(shouldShowSurveyProvider), isFalse);
    });
  });

  group('OnboardingAnswersNotifier', () {
    test('每次 setAnswer 累积答案', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);

      notifier.setGoal(OnboardingGoal.work);
      expect(
        container.read(onboardingAnswersProvider),
        equals(const OnboardingAnswers(goal: OnboardingGoal.work)),
      );

      notifier.setDailyMinutes(OnboardingDailyMinutes.flexible);
      expect(
        container.read(onboardingAnswersProvider),
        equals(
          const OnboardingAnswers(
            goal: OnboardingGoal.work,
            dailyMinutes: OnboardingDailyMinutes.flexible,
          ),
        ),
      );
    });

    test('setGoal 切换分支时自动清掉旧分支副字段', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);

      notifier.setGoal(OnboardingGoal.exam);
      notifier.setExamType(OnboardingExamType.ielts);
      expect(
        container.read(onboardingAnswersProvider).examType,
        equals(OnboardingExamType.ielts),
      );

      // 切到 daily：examType 应被清掉
      notifier.setGoal(OnboardingGoal.daily);
      expect(container.read(onboardingAnswersProvider).examType, isNull);

      // 切换普通分支：goalOtherText 历史字段应保持清空
      notifier.setGoal(OnboardingGoal.other);
      expect(container.read(onboardingAnswersProvider).goalOtherText, isNull);
      notifier.setGoal(OnboardingGoal.work);
      expect(container.read(onboardingAnswersProvider).goalOtherText, isNull);
    });

    test('submit 写 SP + 翻转完成态', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);
      notifier.setGoal(OnboardingGoal.exam);
      notifier.setExamType(OnboardingExamType.ielts);
      notifier.setDailyMinutes(OnboardingDailyMinutes.m20);
      notifier.setReferralSource(OnboardingReferralSource.xiaohongshu);

      await notifier.submit();

      expect(container.read(onboardingCompletedProvider), isTrue);

      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.isCompleted, isTrue);
      final loaded = storage.loadAnswers();
      expect(loaded?.goal, equals(OnboardingGoal.exam));
      expect(loaded?.examType, equals(OnboardingExamType.ielts));
      expect(loaded?.dailyMinutes, equals(OnboardingDailyMinutes.m20));
      expect(
        loaded?.referralSource,
        equals(OnboardingReferralSource.xiaohongshu),
      );
    });

    test('未完成时 submit 抛 StateError', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);
      notifier.setGoal(OnboardingGoal.daily);
      // 没设 dailyMinutes / referralSource
      expect(notifier.submit, throwsStateError);

      notifier.setDailyMinutes(OnboardingDailyMinutes.m10);
      // 仍缺 referralSource
      expect(notifier.submit, throwsStateError);
    });
  });

  group('OnboardingCompletedNotifier', () {
    test('初值来自 initialOnboardingCompletedProvider', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: true,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(onboardingCompletedProvider), isTrue);
    });

    test('markCompleted 幂等', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingCompletedProvider.notifier);
      notifier.markCompleted();
      notifier.markCompleted();
      notifier.markCompleted();
      expect(container.read(onboardingCompletedProvider), isTrue);
    });
  });

  group('Q3 "其他"补充说明', () {
    test('切换到非"其他"渠道时清空补充说明', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);

      notifier.setReferralSource(OnboardingReferralSource.other);
      notifier.setReferralOtherText('公众号');
      expect(
        container.read(onboardingAnswersProvider).referralOtherText,
        equals('公众号'),
      );

      notifier.setReferralSource(OnboardingReferralSource.friend);
      expect(
        container.read(onboardingAnswersProvider).referralOtherText,
        isNull,
      );
    });

    test('补充说明去除首尾空白并截断到上限', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);

      notifier.setReferralOtherText('  ${'甲' * 60}  ');

      expect(
        container.read(onboardingAnswersProvider).referralOtherText,
        equals('甲' * OnboardingReferralSource.referralOtherTextMaxLength),
      );
    });
  });
}
