import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'package:echo_loop/features/onboarding_survey/models/onboarding_answers.dart';
import 'package:echo_loop/features/onboarding_survey/models/onboarding_question.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unit 测试 SP 读写、完成判定锚点、答案校验。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingSurveyStorage', () {
    test('completed_at_ms 缺失时 isCompleted 为 false', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.isCompleted, isFalse);
      expect(storage.loadAnswers(), isNull);
      expect(storage.completedAt, isNull);
    });

    test('saveCompleted 同时写入主答案和时间戳', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      final now = DateTime(2026, 4, 25, 10, 0, 0);
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.work,
          dailyMinutes: OnboardingDailyMinutes.m20,
          referralSource: OnboardingReferralSource.friend,
        ),
        now: now,
      );

      expect(storage.isCompleted, isTrue);
      expect(storage.completedAt, equals(now));
      final loaded = storage.loadAnswers();
      expect(loaded, isNotNull);
      expect(loaded!.goal, equals(OnboardingGoal.work));
      expect(loaded.dailyMinutes, equals(OnboardingDailyMinutes.m20));
      expect(loaded.referralSource, equals(OnboardingReferralSource.friend));
      expect(loaded.examType, isNull);
      expect(loaded.goalOtherText, isNull);
    });

    test('exam 分支：examType 必填，缺失时 saveCompleted 抛错', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(
        () => storage.saveCompleted(
          const OnboardingAnswers(
            goal: OnboardingGoal.exam,
            dailyMinutes: OnboardingDailyMinutes.m10,
            referralSource: OnboardingReferralSource.appStore,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('exam 分支：examType 一并存读', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.exam,
          examType: OnboardingExamType.ielts,
          dailyMinutes: OnboardingDailyMinutes.m20,
          referralSource: OnboardingReferralSource.xiaohongshu,
        ),
      );
      final loaded = storage.loadAnswers();
      expect(loaded?.goal, equals(OnboardingGoal.exam));
      expect(loaded?.examType, equals(OnboardingExamType.ielts));
      expect(
        loaded?.referralSource,
        equals(OnboardingReferralSource.xiaohongshu),
      );
    });

    test('toJson 序列化答案并省略未填写字段', () {
      const answers = OnboardingAnswers(
        goal: OnboardingGoal.exam,
        examType: OnboardingExamType.ielts,
        dailyMinutes: OnboardingDailyMinutes.m20,
        referralSource: OnboardingReferralSource.xiaohongshu,
      );

      expect(answers.toJson(), {
        'goal': OnboardingGoal.exam,
        'examType': OnboardingExamType.ielts,
        'dailyMinutes': OnboardingDailyMinutes.m20,
        'referralSource': OnboardingReferralSource.xiaohongshu,
      });
    });

    test('同步读取保留旧用户已有的有效部分答案', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.completedAtMs: DateTime(
          2026,
        ).millisecondsSinceEpoch,
        OnboardingSurveyKeys.goal: OnboardingGoal.work,
        OnboardingSurveyKeys.dailyMinutes: OnboardingDailyMinutes.m20,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);

      expect(storage.loadAnswers(), isNull);
      expect(storage.loadAnswersForSync()?.toJson(), {
        'goal': OnboardingGoal.work,
        'dailyMinutes': OnboardingDailyMinutes.m20,
      });
    });

    test('没有有效答案时同步读取返回 null', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.completedAtMs: DateTime(
          2026,
        ).millisecondsSinceEpoch,
        OnboardingSurveyKeys.goal: 'invalid',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(OnboardingSurveyStorage(prefs).loadAnswersForSync(), isNull);
    });

    test('exam → 切到非 exam 时 SP 清掉 examType 残留', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      // 先写一次 exam
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.exam,
          examType: OnboardingExamType.cet,
          dailyMinutes: OnboardingDailyMinutes.m10,
          referralSource: OnboardingReferralSource.appStore,
        ),
      );
      // 再写一次 daily —— examType 应被清除
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.daily,
          dailyMinutes: OnboardingDailyMinutes.m10,
          referralSource: OnboardingReferralSource.appStore,
        ),
      );
      expect(prefs.getString(OnboardingSurveyKeys.examType), isNull);
      expect(storage.loadAnswers()?.examType, isNull);
    });

    test('other 分支：不再要求 goalOtherText，保存时会清掉旧文本', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(OnboardingSurveyKeys.goalOtherText, '旧文本');
      final storage = OnboardingSurveyStorage(prefs);
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.other,
          goalOtherText: '  考公务员  ',
          dailyMinutes: OnboardingDailyMinutes.m10,
          referralSource: OnboardingReferralSource.other,
        ),
      );
      expect(prefs.getString(OnboardingSurveyKeys.goalOtherText), isNull);
      final loaded = storage.loadAnswers();
      expect(loaded?.goal, equals(OnboardingGoal.other));
      expect(loaded?.goalOtherText, isNull);
      expect(loaded?.dailyMinutes, equals(OnboardingDailyMinutes.m10));
    });

    test('content 分支：影视博客可以正常保存和读取', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.content,
          dailyMinutes: OnboardingDailyMinutes.m20,
          referralSource: OnboardingReferralSource.youtube,
        ),
      );
      final loaded = storage.loadAnswers();
      expect(loaded?.goal, equals(OnboardingGoal.content));
      expect(loaded?.dailyMinutes, equals(OnboardingDailyMinutes.m20));
      expect(loaded?.goalOtherText, isNull);
      expect(loaded?.referralSource, equals(OnboardingReferralSource.youtube));
    });

    test('未完成的答案不能保存', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(
        () => storage.saveCompleted(const OnboardingAnswers()),
        throwsArgumentError,
      );
      expect(
        () => storage.saveCompleted(
          const OnboardingAnswers(goal: OnboardingGoal.exam),
        ),
        throwsArgumentError,
      );
      // referralSource 缺失也属于未完成
      expect(
        () => storage.saveCompleted(
          const OnboardingAnswers(
            goal: OnboardingGoal.daily,
            dailyMinutes: OnboardingDailyMinutes.m10,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('flexible 时长可以正常保存和读取', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.daily,
          dailyMinutes: OnboardingDailyMinutes.flexible,
          referralSource: OnboardingReferralSource.friend,
        ),
      );
      final loaded = storage.loadAnswers();
      expect(loaded?.dailyMinutes, equals(OnboardingDailyMinutes.flexible));
    });

    test('非法答案编码会被识别为无效，loadAnswers 返回 null', () async {
      // 模拟 SP 中存在非法编码（例如 schema 漂移或人为篡改）
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.goal: 'unknown_goal',
        OnboardingSurveyKeys.dailyMinutes: '99',
        OnboardingSurveyKeys.referralSource: OnboardingReferralSource.appStore,
        OnboardingSurveyKeys.completedAtMs: 1000,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.isCompleted, isTrue); // 锚点存在仍视为完成（防重复弹）
      expect(storage.loadAnswers(), isNull); // 但答案不可用
    });

    test('exam 分支但 examType 非法时 loadAnswers 返回 null', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.goal: OnboardingGoal.exam,
        OnboardingSurveyKeys.examType: 'unknown_exam',
        OnboardingSurveyKeys.dailyMinutes: OnboardingDailyMinutes.m10,
        OnboardingSurveyKeys.referralSource: OnboardingReferralSource.appStore,
        OnboardingSurveyKeys.completedAtMs: 1000,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.loadAnswers(), isNull);
    });

    test('referralSource 缺失（老用户升级残留）时 loadAnswers 返回 null', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.goal: OnboardingGoal.daily,
        OnboardingSurveyKeys.dailyMinutes: OnboardingDailyMinutes.m10,
        OnboardingSurveyKeys.completedAtMs: 1000,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.isCompleted, isTrue); // 防重复弹
      expect(storage.loadAnswers(), isNull); // 但画像不可用
    });

    test('referralSource 非法时 loadAnswers 返回 null', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.goal: OnboardingGoal.daily,
        OnboardingSurveyKeys.dailyMinutes: OnboardingDailyMinutes.m10,
        OnboardingSurveyKeys.referralSource: 'unknown_channel',
        OnboardingSurveyKeys.completedAtMs: 1000,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.loadAnswers(), isNull);
    });

    test('只有锚点没有答案字段时，loadAnswers 返回 null（不抛异常）', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.completedAtMs: 1000,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.isCompleted, isTrue);
      expect(storage.loadAnswers(), isNull);
    });

    test('clear 清空所有 onboarding key', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.exam,
          examType: OnboardingExamType.toefl,
          dailyMinutes: OnboardingDailyMinutes.m10,
          referralSource: OnboardingReferralSource.reddit,
        ),
      );
      await prefs.setBool(OnboardingSurveyKeys.uploaded, true);
      await storage.clear();
      expect(storage.isCompleted, isFalse);
      expect(storage.loadAnswers(), isNull);
      expect(prefs.getString(OnboardingSurveyKeys.examType), isNull);
      expect(prefs.getString(OnboardingSurveyKeys.referralSource), isNull);
      expect(prefs.getBool(OnboardingSurveyKeys.uploaded), isNull);
    });

    test('readIsCompletedSync 静态方法可在 main() 同步调用', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.completedAtMs: 12345,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(OnboardingSurveyStorage.readIsCompletedSync(prefs), isTrue);
    });
  });

  group('OnboardingAnswers', () {
    test('isComplete 普通分支需要 goal + dailyMinutes + referralSource', () {
      expect(const OnboardingAnswers().isComplete, isFalse);
      expect(
        const OnboardingAnswers(goal: OnboardingGoal.work).isComplete,
        isFalse,
      );
      // 缺 referralSource 不算完成
      expect(
        const OnboardingAnswers(
          goal: OnboardingGoal.work,
          dailyMinutes: OnboardingDailyMinutes.m10,
        ).isComplete,
        isFalse,
      );
      expect(
        const OnboardingAnswers(
          goal: OnboardingGoal.work,
          dailyMinutes: OnboardingDailyMinutes.m10,
          referralSource: OnboardingReferralSource.friend,
        ).isComplete,
        isTrue,
      );
    });

    test('isComplete: exam 分支必须有 examType', () {
      expect(
        const OnboardingAnswers(
          goal: OnboardingGoal.exam,
          dailyMinutes: OnboardingDailyMinutes.m10,
          referralSource: OnboardingReferralSource.appStore,
        ).isComplete,
        isFalse,
      );
      expect(
        const OnboardingAnswers(
          goal: OnboardingGoal.exam,
          examType: OnboardingExamType.ielts,
          dailyMinutes: OnboardingDailyMinutes.m10,
          referralSource: OnboardingReferralSource.appStore,
        ).isComplete,
        isTrue,
      );
    });

    test('isComplete: other 分支不再要求 goalOtherText', () {
      expect(
        const OnboardingAnswers(
          goal: OnboardingGoal.other,
          dailyMinutes: OnboardingDailyMinutes.m10,
          referralSource: OnboardingReferralSource.other,
        ).isComplete,
        isTrue,
      );
      expect(
        const OnboardingAnswers(
          goal: OnboardingGoal.other,
          goalOtherText: '   ',
          dailyMinutes: OnboardingDailyMinutes.m10,
          referralSource: OnboardingReferralSource.other,
        ).isComplete,
        isTrue,
      );
    });

    test('copyWith 不会清空已设置的字段', () {
      const original = OnboardingAnswers(goal: OnboardingGoal.exam);
      final updated = original.copyWith(
        dailyMinutes: OnboardingDailyMinutes.m20,
        referralSource: OnboardingReferralSource.appStore,
      );
      expect(updated.goal, equals(OnboardingGoal.exam));
      expect(updated.dailyMinutes, equals(OnboardingDailyMinutes.m20));
      expect(updated.referralSource, equals(OnboardingReferralSource.appStore));
    });

    test('copyWith.clearExamType 把 examType 置回 null', () {
      const original = OnboardingAnswers(
        goal: OnboardingGoal.exam,
        examType: OnboardingExamType.ielts,
      );
      final cleared = original.copyWith(
        goal: OnboardingGoal.daily,
        clearExamType: true,
      );
      expect(cleared.goal, equals(OnboardingGoal.daily));
      expect(cleared.examType, isNull);
    });

    test('相同字段值的实例相等', () {
      const a = OnboardingAnswers(
        goal: OnboardingGoal.work,
        dailyMinutes: OnboardingDailyMinutes.m30,
        referralSource: OnboardingReferralSource.friend,
      );
      const b = OnboardingAnswers(
        goal: OnboardingGoal.work,
        dailyMinutes: OnboardingDailyMinutes.m30,
        referralSource: OnboardingReferralSource.friend,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
