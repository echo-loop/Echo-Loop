import 'package:flutter_test/flutter_test.dart';

import 'package:fluency/database/enums.dart';
import 'package:fluency/models/learning_progress.dart';

void main() {
  final now = DateTime(2026, 2, 21);

  group('LearningProgress', () {
    test('初始状态 — 未开始', () {
      final progress = LearningProgress(audioItemId: 'audio-1', updatedAt: now);

      expect(progress.isStarted, false);
      expect(progress.isCompleted, false);
      expect(progress.progressPercent, 0.0);
      expect(progress.completedFirstStudySteps, 0);
      expect(progress.completedReviewStages, 0);
      expect(progress.totalStudyDurationMs, 0);
      expect(progress.lastStageCompletedAt, isNull);
      expect(progress.currentStageStartedAt, isNull);
    });

    test('首学第 2 个子步骤进行中', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        updatedAt: now,
      );

      expect(progress.isStarted, true);
      expect(progress.isCompleted, false);
      // 完成了 1 个子步骤，进度 = 1/totalSubStages
      final total = LearningProgress.totalSubStages;
      expect(progress.progressPercent, closeTo(1 / total, 0.001));
      expect(progress.completedFirstStudySteps, 1);
      expect(progress.completedReviewStages, 0);
    });

    test('首学全部完成，进入 review0', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewDifficultPractice,
        firstLearnCompletedAt: now,
        updatedAt: now,
      );

      expect(progress.isStarted, true);
      // 完成了 4 个子步骤，进度 = 4/totalSubStages
      final total = LearningProgress.totalSubStages;
      expect(progress.progressPercent, closeTo(4 / total, 0.001));
      expect(progress.completedFirstStudySteps, 4);
      expect(progress.completedReviewStages, 0);
    });

    test('review2 第 2 个子步骤进行中', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review2,
        currentSubStage: SubStageType.reviewDifficultPractice,
        firstLearnCompletedAt: now,
        updatedAt: now,
      );

      // 完成了：4(首学) + 2(review0) + 3(review1) + 1(review2的第1个子步骤) = 10
      final total = LearningProgress.totalSubStages;
      expect(progress.progressPercent, closeTo(10 / total, 0.001));
      expect(progress.completedFirstStudySteps, 4);
      expect(progress.completedReviewStages, 2); // review0, review1 完成
    });

    test('已完成状态', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.completed,
        currentSubStage: SubStageType.blindListen,
        firstLearnCompletedAt: now,
        updatedAt: now,
      );

      expect(progress.isStarted, true);
      expect(progress.isCompleted, true);
      expect(progress.progressPercent, 1.0);
      expect(progress.completedFirstStudySteps, 4);
      expect(progress.completedReviewStages, 7);
    });

    test('isStageCompleted 正确判断', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review2,
        currentSubStage: SubStageType.reviewDifficultPractice,
        updatedAt: now,
      );

      expect(progress.isStageCompleted(LearningStage.firstLearn), true);
      expect(progress.isStageCompleted(LearningStage.review0), true);
      expect(progress.isStageCompleted(LearningStage.review1), true);
      expect(progress.isStageCompleted(LearningStage.review2), false);
      expect(progress.isStageCompleted(LearningStage.review4), false);
    });

    test('isSubStageCompleted 正确判断', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        updatedAt: now,
      );

      // 首学中：blindListen, intensiveListen 已完成，listenAndRepeat 是当前，retell 未开始
      expect(
        progress.isSubStageCompleted(
          LearningStage.firstLearn,
          SubStageType.blindListen,
        ),
        true,
      );
      expect(
        progress.isSubStageCompleted(
          LearningStage.firstLearn,
          SubStageType.intensiveListen,
        ),
        true,
      );
      expect(
        progress.isSubStageCompleted(
          LearningStage.firstLearn,
          SubStageType.listenAndRepeat,
        ),
        false,
      );
      expect(
        progress.isSubStageCompleted(
          LearningStage.firstLearn,
          SubStageType.retell,
        ),
        false,
      );
    });

    test('isSubStageCompleted — 跨阶段判断', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        updatedAt: now,
      );

      // 首学所有子步骤都已完成
      expect(
        progress.isSubStageCompleted(
          LearningStage.firstLearn,
          SubStageType.retell,
        ),
        true,
      );
      // review0 所有子步骤都已完成
      expect(
        progress.isSubStageCompleted(
          LearningStage.review0,
          SubStageType.reviewRetellParagraph,
        ),
        true,
      );
      // review1 第一个子步骤是当前，未完成
      expect(
        progress.isSubStageCompleted(
          LearningStage.review1,
          SubStageType.blindListen,
        ),
        false,
      );
    });

    test('isCurrentStage 正确判断', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review7,
        currentSubStage: SubStageType.reviewDifficultPractice,
        updatedAt: now,
      );

      expect(progress.isCurrentStage(LearningStage.review4), false);
      expect(progress.isCurrentStage(LearningStage.review7), true);
      expect(progress.isCurrentStage(LearningStage.review14), false);
    });

    test('isCurrentSubStage 正确判断', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        updatedAt: now,
      );

      expect(
        progress.isCurrentSubStage(
          LearningStage.firstLearn,
          SubStageType.intensiveListen,
        ),
        false,
      );
      expect(
        progress.isCurrentSubStage(
          LearningStage.firstLearn,
          SubStageType.listenAndRepeat,
        ),
        true,
      );
      expect(
        progress.isCurrentSubStage(
          LearningStage.firstLearn,
          SubStageType.retell,
        ),
        false,
      );
    });

    test('copyWith 正确创建副本', () {
      final original = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.blindListen,
        difficulty: DifficultyLevel.medium,
        updatedAt: now,
      );

      final updated = original.copyWith(
        currentSubStage: SubStageType.retell,
        difficulty: DifficultyLevel.hard,
        totalStudyDurationMs: 5000,
        lastStageCompletedAt: now,
        currentStageStartedAt: now,
      );

      expect(updated.audioItemId, 'audio-1');
      expect(updated.currentStage, LearningStage.firstLearn);
      expect(updated.currentSubStage, SubStageType.retell);
      expect(updated.difficulty, DifficultyLevel.hard);
      expect(updated.totalStudyDurationMs, 5000);
      expect(updated.lastStageCompletedAt, now);
      expect(updated.currentStageStartedAt, now);
    });

    test('totalSubStages 动态计算正确', () {
      // firstLearn: 4 + review0:2 + review1/2/4/7/14: 5*3 + review28:3 = 24
      expect(LearningProgress.totalSubStages, 24);
    });
  });

  group('nextReviewAt / isReviewReadyAt / isReviewLockedAt', () {
    test('首学阶段 — nextReviewAt 为 null，isReviewReadyAt 为 true', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        updatedAt: now,
      );

      expect(progress.nextReviewAt, isNull);
      expect(progress.isReviewReadyAt(DateTime(2026, 2, 21, 10, 0)), true);
    });

    test('review0 — intervalHours=6，nextReviewAt 正确计算', () {
      final completedAt = DateTime(2026, 2, 21, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.blindListen,
        lastStageCompletedAt: completedAt,
        updatedAt: completedAt,
      );

      // review0 的 intervalHours 是 6
      final expectedReviewAt = completedAt.add(const Duration(hours: 6));
      expect(progress.nextReviewAt, expectedReviewAt);
    });

    test('review1 — 有 lastStageCompletedAt 时正确计算', () {
      final completedAt = DateTime(2026, 2, 20, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        lastStageCompletedAt: completedAt,
        updatedAt: now,
      );

      // review1 的 intervalHours = 24
      final expectedReviewAt = completedAt.add(const Duration(hours: 24));
      expect(progress.nextReviewAt, expectedReviewAt);
    });

    test('review1 — 无 lastStageCompletedAt 时 nextReviewAt 为 null', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        updatedAt: now,
      );

      expect(progress.nextReviewAt, isNull);
      expect(progress.isReviewReadyAt(DateTime(2026, 2, 21, 10, 0)), true);
    });

    test('review7 — 正确计算 168 小时间隔', () {
      final completedAt = DateTime(2026, 2, 14);
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review7,
        currentSubStage: SubStageType.blindListen,
        lastStageCompletedAt: completedAt,
        updatedAt: now,
      );

      final expectedReviewAt = completedAt.add(const Duration(hours: 168));
      expect(progress.nextReviewAt, expectedReviewAt);
    });

    test('review0 解锁边界：未到时间时锁定、边界时刻解锁、超过边界解锁', () {
      final completedAt = DateTime(2026, 2, 21, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.blindListen,
        lastStageCompletedAt: completedAt,
        updatedAt: completedAt,
      );

      final reviewAt = completedAt.add(const Duration(hours: 6));
      final before = reviewAt.subtract(const Duration(seconds: 1));
      final at = reviewAt;
      final after = reviewAt.add(const Duration(seconds: 1));

      expect(progress.isInReviewStage, true);
      expect(progress.isReviewReadyAt(before), false);
      expect(progress.isReviewLockedAt(before), true);
      expect(progress.isReviewReadyAt(at), true);
      expect(progress.isReviewLockedAt(at), false);
      expect(progress.isReviewReadyAt(after), true);
      expect(progress.isReviewLockedAt(after), false);
    });

    test('review1 解锁边界：未到时间时锁定、边界时刻解锁、超过边界解锁', () {
      final completedAt = DateTime(2026, 2, 21, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        lastStageCompletedAt: completedAt,
        updatedAt: completedAt,
      );

      final reviewAt = completedAt.add(const Duration(hours: 24));
      final before = reviewAt.subtract(const Duration(seconds: 1));
      final at = reviewAt;
      final after = reviewAt.add(const Duration(seconds: 1));

      expect(progress.isReviewReadyAt(before), false);
      expect(progress.isReviewLockedAt(before), true);
      expect(progress.isReviewReadyAt(at), true);
      expect(progress.isReviewLockedAt(at), false);
      expect(progress.isReviewReadyAt(after), true);
      expect(progress.isReviewLockedAt(after), false);
    });

    test('首学阶段 isReviewLockedAt=false', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        updatedAt: now,
      );

      expect(progress.isInReviewStage, false);
      expect(progress.isReviewLockedAt(DateTime(2026, 2, 21, 10, 0)), false);
    });

    test('review0 逾期窗口：解锁后 6 小时内不算逾期，超过才逾期', () {
      final completedAt = DateTime(2026, 2, 21, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewDifficultPractice,
        lastStageCompletedAt: completedAt,
        updatedAt: completedAt,
      );

      final reviewAt = completedAt.add(const Duration(hours: 6));
      final windowEnd = reviewAt.add(const Duration(hours: 6));
      expect(progress.reviewWindowDuration, const Duration(hours: 6));
      expect(progress.reviewWindowEndAt, windowEnd);

      final beforeWindowEnd = windowEnd.subtract(const Duration(seconds: 1));
      expect(progress.isReviewOverdueAt(beforeWindowEnd), false);
      expect(progress.isReviewOverdueAt(windowEnd), false);

      final afterWindowEnd = windowEnd.add(const Duration(seconds: 1));
      expect(progress.isReviewOverdueAt(afterWindowEnd), true);
      expect(
        progress.overdueDurationAt(afterWindowEnd),
        const Duration(seconds: 1),
      );
    });

    test('review1 逾期窗口：解锁后 24 小时内不算逾期，超过才逾期', () {
      final completedAt = DateTime(2026, 2, 21, 10, 0);
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        lastStageCompletedAt: completedAt,
        updatedAt: completedAt,
      );

      final reviewAt = completedAt.add(const Duration(hours: 24));
      final windowEnd = reviewAt.add(const Duration(hours: 24));
      expect(progress.reviewWindowDuration, const Duration(hours: 24));
      expect(progress.reviewWindowEndAt, windowEnd);

      final beforeWindowEnd = windowEnd.subtract(const Duration(seconds: 1));
      expect(progress.isReviewOverdueAt(beforeWindowEnd), false);
      expect(progress.isReviewOverdueAt(windowEnd), false);

      final afterWindowEnd = windowEnd.add(const Duration(seconds: 1));
      expect(progress.isReviewOverdueAt(afterWindowEnd), true);
      expect(
        progress.overdueDurationAt(afterWindowEnd),
        const Duration(seconds: 1),
      );
    });

    test('非复习阶段无逾期窗口，始终不逾期', () {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        updatedAt: now,
      );

      expect(progress.reviewWindowDuration, isNull);
      expect(progress.reviewWindowEndAt, isNull);
      expect(progress.isReviewOverdueAt(DateTime(2026, 2, 21, 12, 0)), false);
      expect(progress.overdueDurationAt(DateTime(2026, 2, 21, 12, 0)), isNull);
    });
  });

  group('LearningStage', () {
    test('subStageCount 正确', () {
      expect(LearningStage.firstLearn.subStageCount, 4);
      expect(LearningStage.review0.subStageCount, 2);
      expect(LearningStage.review1.subStageCount, 3);
      expect(LearningStage.review28.subStageCount, 3);
      expect(LearningStage.completed.subStageCount, 0);
    });

    test('总子步骤数 = totalSubStages', () {
      int total = 0;
      for (final stage in LearningStage.values) {
        total += stage.subStageCount;
      }
      expect(total, LearningProgress.totalSubStages);
    });

    test('fromKey 正确转换', () {
      expect(LearningStage.fromKey('firstLearn'), LearningStage.firstLearn);
      expect(LearningStage.fromKey('review7'), LearningStage.review7);
      expect(LearningStage.fromKey('completed'), LearningStage.completed);
      // 无效键返回 firstLearn
      expect(LearningStage.fromKey('invalid'), LearningStage.firstLearn);
    });

    test('label 不为空', () {
      for (final stage in LearningStage.values) {
        expect(stage.label.isNotEmpty, true);
      }
    });

    test('subStages 列表内容正确', () {
      expect(LearningStage.firstLearn.subStages, [
        SubStageType.blindListen,
        SubStageType.intensiveListen,
        SubStageType.listenAndRepeat,
        SubStageType.retell,
      ]);
      expect(LearningStage.review0.subStages, [
        SubStageType.reviewDifficultPractice,
        SubStageType.reviewRetellParagraph,
      ]);
      expect(LearningStage.review1.subStages, [
        SubStageType.blindListen,
        SubStageType.reviewDifficultPractice,
        SubStageType.reviewRetellParagraph,
      ]);
      expect(LearningStage.review28.subStages, [
        SubStageType.blindListen,
        SubStageType.reviewDifficultPractice,
        SubStageType.reviewRetellSummary,
      ]);
      expect(LearningStage.completed.subStages, isEmpty);
    });
  });

  group('SubStageType', () {
    test('fromKey 正确转换', () {
      expect(SubStageType.fromKey('blindListen'), SubStageType.blindListen);
      expect(
        SubStageType.fromKey('listenAndRepeat'),
        SubStageType.listenAndRepeat,
      );
      expect(SubStageType.fromKey('retell'), SubStageType.retell);
      expect(
        SubStageType.fromKey('reviewDifficultPractice'),
        SubStageType.reviewDifficultPractice,
      );
      // 无效键返回 blindListen
      expect(SubStageType.fromKey('invalid'), SubStageType.blindListen);
    });

    test('label 不为空', () {
      for (final subStage in SubStageType.values) {
        expect(subStage.label.isNotEmpty, true);
      }
    });
  });

  group('DifficultyLevel', () {
    test('fromValue 正确转换（5 档）', () {
      expect(DifficultyLevel.fromValue(0), DifficultyLevel.veryEasy);
      expect(DifficultyLevel.fromValue(1), DifficultyLevel.easy);
      expect(DifficultyLevel.fromValue(2), DifficultyLevel.medium);
      expect(DifficultyLevel.fromValue(3), DifficultyLevel.hard);
      expect(DifficultyLevel.fromValue(4), DifficultyLevel.veryHard);
      // 无效值返回 medium
      expect(DifficultyLevel.fromValue(99), DifficultyLevel.medium);
    });

    test('label 不为空', () {
      for (final level in DifficultyLevel.values) {
        expect(level.label.isNotEmpty, true);
      }
    });

    test('共 5 个难度等级', () {
      expect(DifficultyLevel.values.length, 5);
    });
  });
}
