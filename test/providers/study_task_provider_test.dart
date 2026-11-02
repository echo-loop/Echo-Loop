import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/daos/stage_completion_dao.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/study_task_provider.dart';
import 'package:echo_loop/providers/time_provider.dart';

import '../helpers/mock_providers.dart';

void main() {
  group('studyTaskProvider', () {
    test('任务排序遵循：可复习 > 未到时间复习 > 首次学习', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Alpha',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'b',
          name: 'Beta',
          audioPath: 'audios/b.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'c',
          name: 'Gamma',
          audioPath: 'audios/c.mp3',
          addedDate: now,
        ),
      ];

      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(minutes: 2)),
        ),
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now.subtract(const Duration(minutes: 1)),
        ),
        'c': LearningProgress(
          audioItemId: 'c',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((e) => e.audioId).toList(), ['a', 'b', 'c']);
      expect(tasks[0].type, StudyTaskType.reviewReady);
      expect(tasks[1].type, StudyTaskType.reviewUpcoming);
      expect(tasks[2].type, StudyTaskType.firstStudy);
    });

    test('多个 firstLearn 音频时只显示学习进度最深的那个', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'first-shallow',
          name: 'TPO-46-C2',
          audioPath: 'audios/tpo46c2.mp3',
          addedDate: now.subtract(const Duration(days: 2)),
          totalDuration: 300,
        ),
        AudioItem(
          id: 'first-deep',
          name: 'TPO-57-C1',
          audioPath: 'audios/tpo57c1.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 280,
        ),
      ];

      final progressMap = {
        // blindListen 是首次学习最初始的子阶段，进度最浅
        'first-shallow': LearningProgress(
          audioItemId: 'first-shallow',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.blindListen,
          // 即使 updatedAt 更新，进度浅的也不应被保留
          updatedAt: now,
        ),
        // listenAndRepeat 子阶段更靠后，说明已有实际学习进度
        'first-deep': LearningProgress(
          audioItemId: 'first-deep',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.listenAndRepeat,
          updatedAt: now.subtract(const Duration(hours: 3)),
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.single.audioId, 'first-deep');
      expect(tasks.single.type, StudyTaskType.firstStudy);
      expect(tasks.single.subStage, SubStageType.listenAndRepeat);
    });

    test('无进度音频时只投放 1 个首次学习任务', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'audio-1',
          name: 'No Progress Audio',
          audioPath: 'audios/a1.mp3',
          addedDate: now,
          totalDuration: 180,
        ),
        AudioItem(
          id: 'audio-2',
          name: 'Second Audio',
          audioPath: 'audios/a2.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 240,
        ),
      ];

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.single.audioId, 'audio-1');
      expect(tasks.single.type, StudyTaskType.firstStudy);
      expect(tasks.single.stage, LearningStage.firstLearn);
      expect(tasks.single.subStage, SubStageType.blindListen);
    });

    test('存在首次学习任务时不投放新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'in-progress',
          name: 'In Progress Audio',
          audioPath: 'audios/in-progress.mp3',
          addedDate: now,
          totalDuration: 300,
        ),
        AudioItem(
          id: 'unstarted',
          name: 'Unstarted Audio',
          audioPath: 'audios/unstarted.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 120,
        ),
      ];

      final progressMap = {
        'in-progress': LearningProgress(
          audioItemId: 'in-progress',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.listenAndRepeat,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.single.audioId, 'in-progress');
    });

    test('存在 review0 任务时不投放新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'review0',
          name: 'Review 0 Audio',
          audioPath: 'audios/review0.mp3',
          addedDate: now,
          totalDuration: 300,
        ),
        AudioItem(
          id: 'unstarted',
          name: 'Unstarted Audio',
          audioPath: 'audios/unstarted.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 60,
        ),
      ];

      final progressMap = {
        'review0': LearningProgress(
          audioItemId: 'review0',
          currentStage: LearningStage.review0,
          currentSubStage: SubStageType.reviewDifficultPractice,
          lastStageCompletedAt: now.subtract(const Duration(hours: 6)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.single.audioId, 'review0');
    });

    test('仅有 review1 及之后任务且数量不超过 3 时投放 1 个新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'review-1',
          name: 'Review Audio 1',
          audioPath: 'audios/review1.mp3',
          addedDate: now,
          totalDuration: 180,
        ),
        AudioItem(
          id: 'review-2',
          name: 'Review Audio 2',
          audioPath: 'audios/review2.mp3',
          addedDate: now,
          totalDuration: 200,
        ),
        AudioItem(
          id: 'new-short',
          name: 'New Short Audio',
          audioPath: 'audios/new-short.mp3',
          addedDate: now,
          totalDuration: 90,
        ),
        AudioItem(
          id: 'new-long',
          name: 'New Long Audio',
          audioPath: 'audios/new-long.mp3',
          addedDate: now.subtract(const Duration(days: 2)),
          totalDuration: 240,
        ),
      ];

      final progressMap = {
        'review-1': LearningProgress(
          audioItemId: 'review-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
        ),
        'review-2': LearningProgress(
          audioItemId: 'review-2',
          currentStage: LearningStage.review2,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      // 两个均已就绪且未逾期，按 nextReviewAt 升序：review-2 完成更早（-2d，间隔
      // 24h → 排程更早）排在 review-1（-1d，间隔 18h）之前。
      expect(tasks.map((e) => e.audioId).toList(), [
        'review-2',
        'review-1',
        'new-short',
      ]);
      expect(tasks.last.type, StudyTaskType.firstStudy);
    });

    test('只有未到时间的 review1 任务时仍可投放新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'review-upcoming',
          name: 'Upcoming Review Audio',
          audioPath: 'audios/review-upcoming.mp3',
          addedDate: now,
          totalDuration: 180,
        ),
        AudioItem(
          id: 'new-audio',
          name: 'New Audio',
          audioPath: 'audios/new.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 100,
        ),
      ];

      final progressMap = {
        'review-upcoming': LearningProgress(
          audioItemId: 'review-upcoming',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((e) => e.audioId).toList(), [
        'review-upcoming',
        'new-audio',
      ]);
      expect(tasks.first.type, StudyTaskType.reviewUpcoming);
      expect(tasks.last.type, StudyTaskType.firstStudy);
    });

    test('在学任务超过 3 个时不投放新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        for (var i = 0; i < 4; i++)
          AudioItem(
            id: 'review-$i',
            name: 'Review Audio $i',
            audioPath: 'audios/review-$i.mp3',
            addedDate: now,
            totalDuration: 120 + i,
          ),
        AudioItem(
          id: 'unstarted',
          name: 'Unstarted Audio',
          audioPath: 'audios/unstarted.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 60,
        ),
      ];

      final progressMap = {
        for (var i = 0; i < 4; i++)
          'review-$i': LearningProgress(
            audioItemId: 'review-$i',
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            lastStageCompletedAt: now.subtract(const Duration(days: 1)),
            updatedAt: now,
          ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 4);
      expect(tasks.any((task) => task.audioId == 'unstarted'), isFalse);
    });

    test('新音频选择遵循 最短时长 -> 最早导入 -> 名称 -> id', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'duration-zero',
          name: 'Duration Zero',
          audioPath: 'audios/duration-zero.mp3',
          addedDate: now.subtract(const Duration(days: 3)),
          totalDuration: 0,
        ),
        AudioItem(
          id: 'same-duration-b',
          name: 'Bravo',
          audioPath: 'audios/bravo.mp3',
          addedDate: now.subtract(const Duration(days: 2)),
          totalDuration: 120,
        ),
        AudioItem(
          id: 'same-duration-a',
          name: 'Alpha',
          audioPath: 'audios/alpha.mp3',
          addedDate: now.subtract(const Duration(days: 2)),
          totalDuration: 120,
        ),
      ];

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.single.audioId, 'same-duration-a');
    });

    test('没有未学习音频时不投放新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'review-only',
          name: 'Review Only',
          audioPath: 'audios/review-only.mp3',
          addedDate: now,
          totalDuration: 180,
        ),
      ];

      final progressMap = {
        'review-only': LearningProgress(
          audioItemId: 'review-only',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.single.audioId, 'review-only');
    });

    test('边界时刻 now == nextReviewAt 时任务归类为可复习', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'audio-1',
          name: 'Boundary Review Audio',
          audioPath: 'audios/a1.mp3',
          addedDate: now,
        ),
      ];

      final progressMap = {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.single.type, StudyTaskType.reviewReady);
    });

    test('可复习任务内按逾期优先且逾期越久越靠前', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Overdue 5h',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'b',
          name: 'Overdue 2h',
          audioPath: 'audios/b.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'c',
          name: 'Ready Not Overdue',
          audioPath: 'audios/c.mp3',
          addedDate: now,
        ),
      ];
      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          // review1 窗口结束 = completed + 18h(间隔) + 24h(窗口) = 42h，这里逾期 5h
          lastStageCompletedAt: now.subtract(const Duration(hours: 47)),
          updatedAt: now,
        ),
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          // 窗口结束 = completed + 42h，这里逾期 2h
          lastStageCompletedAt: now.subtract(const Duration(hours: 44)),
          updatedAt: now,
        ),
        'c': LearningProgress(
          audioItemId: 'c',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          // 已解锁但还在 24h 学习窗口内
          lastStageCompletedAt: now.subtract(const Duration(hours: 30)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((e) => e.audioId).toList(), ['a', 'b', 'c']);
      expect(tasks[0].type, StudyTaskType.reviewReady);
      expect(tasks[0].isOverdue, true);
      expect(tasks[0].overdueDuration, const Duration(hours: 5));
      expect(tasks[1].isOverdue, true);
      expect(tasks[1].overdueDuration, const Duration(hours: 2));
      expect(tasks[2].isOverdue, false);
      expect(tasks[2].overdueDuration, isNull);
    });

    test('review0 采用 6 小时窗口判定逾期', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'review0 overdue',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'b',
          name: 'review0 in window',
          audioPath: 'audios/b.mp3',
          addedDate: now,
        ),
      ];
      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review0,
          currentSubStage: SubStageType.reviewDifficultPractice,
          // review0 窗口结束 = completed + 12h，这里逾期 1h
          lastStageCompletedAt: now.subtract(const Duration(hours: 13)),
          updatedAt: now,
        ),
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review0,
          currentSubStage: SubStageType.reviewDifficultPractice,
          // 已解锁但仍在 6h 窗口内
          lastStageCompletedAt: now.subtract(const Duration(hours: 7)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((e) => e.audioId).toList(), ['a', 'b']);
      expect(
        tasks.every((task) => task.type == StudyTaskType.reviewReady),
        true,
      );
      expect(tasks[0].isOverdue, true);
      expect(tasks[0].overdueDuration, const Duration(hours: 1));
      expect(tasks[1].isOverdue, false);
    });

    test('暂停学习的音频不进入任务列表', () {
      final now = DateTime(2026, 5, 16, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'paused-review',
          name: 'Paused Review',
          audioPath: 'audios/p.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'paused-first',
          name: 'Paused First',
          audioPath: 'audios/q.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'active-review',
          name: 'Active Review',
          audioPath: 'audios/r.mp3',
          addedDate: now,
        ),
      ];

      final progressMap = {
        'paused-review': LearningProgress(
          audioItemId: 'paused-review',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now,
          isPaused: true,
        ),
        'paused-first': LearningProgress(
          audioItemId: 'paused-first',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.listenAndRepeat,
          updatedAt: now,
          isPaused: true,
        ),
        'active-review': LearningProgress(
          audioItemId: 'active-review',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((t) => t.audioId).toList(), ['active-review']);
    });
  });

  group('StudyTask.hasRoundProgress', () {
    // 进入 review 新轮、v2 计划首步为难句补练（≠ allSubStages.first 盲听），
    // 且本轮无完成记录 → 不应判为"学习中"（覆盖待解锁误显 bug）。
    test('待解锁任务本轮无完成记录时 hasRoundProgress 为 false', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Alpha',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
      ];
      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review2,
          currentSubStage: SubStageType.reviewDifficultPractice,
          lastStageCompletedAt: now, // 未到下次复习时间 → 待解锁
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(
                progressMap: progressMap,
                completionsByAudio: const {'a': <String>{}},
              ),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final task = container.read(studyTaskProvider).single;
      expect(task.type, StudyTaskType.reviewUpcoming);
      expect(task.hasRoundProgress, isFalse);
    });

    // 本轮已有真实完成记录 → hasRoundProgress 为 true（"学习中"）。
    test('本轮已有完成记录时 hasRoundProgress 为 true', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Alpha',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
      ];
      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(
                progressMap: progressMap,
                completionsByAudio: const {
                  'a': {'review1:reviewDifficultPractice'},
                },
              ),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final task = container.read(studyTaskProvider).single;
      expect(task.type, StudyTaskType.reviewReady);
      expect(task.hasRoundProgress, isTrue);
    });

    // stage key 前缀匹配带冒号，'review1:' 不会误匹配 'review14:...'。
    test('其他阶段的完成记录不计入当前阶段', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Alpha',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
      ];
      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.reviewDifficultPractice,
          lastStageCompletedAt: now,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(
                progressMap: progressMap,
                // review14 的完成记录不应被 review1 误命中
                completionsByAudio: const {
                  'a': {'review14:reviewDifficultPractice'},
                },
              ),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final task = container.read(studyTaskProvider).single;
      expect(task.hasRoundProgress, isFalse);
    });
  });

  group('pendingStudyTaskCountProvider', () {
    test('不计入 reviewUpcoming 类型的任务', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Alpha',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'b',
          name: 'Beta',
          audioPath: 'audios/b.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'c',
          name: 'Gamma',
          audioPath: 'audios/c.mp3',
          addedDate: now,
        ),
      ];

      final progressMap = {
        // reviewReady：已过复习时间
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(minutes: 2)),
        ),
        // reviewUpcoming：未到复习时间
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now.subtract(const Duration(minutes: 1)),
        ),
        // firstStudy：首次学习
        'c': LearningProgress(
          audioItemId: 'c',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      // studyTaskProvider 包含 3 个任务（reviewReady + reviewUpcoming + firstStudy）
      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 3);

      // pendingStudyTaskCountProvider 应只计算 reviewReady + firstStudy = 2
      final count = container.read(pendingStudyTaskCountProvider);
      expect(count, 2);
    });

    test('全部为 reviewUpcoming 时返回 0', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Upcoming Only',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
      ];

      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.single.type, StudyTaskType.reviewUpcoming);

      final count = container.read(pendingStudyTaskCountProvider);
      expect(count, 0);
    });
  });

  group('completedAudioProvider', () {
    test('已完成音频正确返回', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Completed',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'b',
          name: 'In Progress',
          audioPath: 'audios/b.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'c',
          name: 'Also Completed',
          audioPath: 'audios/c.mp3',
          addedDate: now,
        ),
      ];
      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.completed,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now,
        ),
        'c': LearningProgress(
          audioItemId: 'c',
          currentStage: LearningStage.completed,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final completed = container.read(completedAudioProvider);
      expect(completed.length, 2);
      expect(completed[0].audioName, 'Completed');
      expect(completed[1].audioName, 'Also Completed');
    });

    test('无已完成音频时返回空列表', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'First Study',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
      ];

      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          nowProvider.overrideWithValue(() => now),
        ]),
      );
      addTearDown(container.dispose);

      final completed = container.read(completedAudioProvider);
      expect(completed, isEmpty);
    });
  });

  group('selectStudyRecommendation', () {
    final now = DateTime(2026, 10, 11, 12);

    AudioItem material(String id, String name) => AudioItem(
      id: id,
      name: name,
      audioPath: 'materials/$id.mp3',
      addedDate: now,
    );

    RecentCompletion completion(String audioId, DateTime completedAt) =>
        RecentCompletion(
          audioId: audioId,
          audioName: audioId,
          stage: 'firstLearn',
          subStage: 'blindListen',
          completedAt: completedAt,
          durationMs: 1000,
        );

    test('选择最近活动材料并排除已完成和最近完成材料', () {
      final materials = [
        material('free-play', 'Free Play'),
        material('planned', 'Planned'),
        material('completed', 'Completed'),
        material('recently-completed', 'Recently Completed'),
        material('updated-only', 'Updated Only'),
      ];
      final progress = {
        'planned': LearningProgress(
          audioItemId: 'planned',
          newLearningBreakpointSavedAt: now.add(const Duration(hours: 8)),
          updatedAt: now.add(const Duration(hours: 9)),
        ),
        'completed': LearningProgress(
          audioItemId: 'completed',
          currentStage: LearningStage.completed,
          updatedAt: now.add(const Duration(hours: 12)),
        ),
        'updated-only': LearningProgress(
          audioItemId: 'updated-only',
          updatedAt: now.add(const Duration(hours: 20)),
        ),
      };

      final result = selectStudyRecommendation(
        materials: materials,
        progressByAudioId: progress,
        playbackSavedAtByAudioId: {
          'free-play': now.add(const Duration(hours: 7)),
          'recently-completed': now.add(const Duration(hours: 30)),
        },
        latestCompletionAtByAudioId: {
          'planned': now.add(const Duration(hours: 10)),
        },
        recentCompletions: [
          completion('recently-completed', now.add(const Duration(hours: 11))),
        ],
      );

      expect(result?.id, 'planned');
    });

    test('随心听播放、两类学习断点和完成记录都能标记最近学习', () {
      AudioItem? select({
        Map<String, LearningProgress> progress = const {},
        Map<String, DateTime> playbackTimes = const {},
        Map<String, DateTime> completionTimes = const {},
      }) {
        return selectStudyRecommendation(
          materials: [material('a', 'Alpha')],
          progressByAudioId: progress,
          playbackSavedAtByAudioId: playbackTimes,
          latestCompletionAtByAudioId: completionTimes,
          recentCompletions: const [],
        );
      }

      expect(select(playbackTimes: {'a': now})?.id, 'a');
      expect(
        select(
          progress: {
            'a': LearningProgress(
              audioItemId: 'a',
              newLearningBreakpointSavedAt: now,
              updatedAt: now.add(const Duration(days: 1)),
            ),
          },
        )?.id,
        'a',
      );
      expect(
        select(
          progress: {
            'a': LearningProgress(
              audioItemId: 'a',
              freePlayBreakpointSavedAt: now,
              updatedAt: now,
            ),
          },
        )?.id,
        'a',
      );
      expect(select(completionTimes: {'a': now})?.id, 'a');
    });

    test('没有最近学习候选时选择最近完成锚点之后的首个未完成材料', () {
      final materials = [
        material('delta', 'Delta'),
        material('charlie', 'Charlie'),
        material('alpha', 'Alpha'),
        material('bravo', 'Bravo'),
      ];

      final result = selectStudyRecommendation(
        materials: materials,
        progressByAudioId: const {},
        playbackSavedAtByAudioId: const {},
        latestCompletionAtByAudioId: const {},
        recentCompletions: [
          completion('bravo', now),
          completion('charlie', now.subtract(const Duration(hours: 1))),
        ],
      );

      expect(result?.id, 'delta');
    });

    test('没有可匹配的最近完成材料时选择名称排序后的第一条', () {
      final result = selectStudyRecommendation(
        materials: [
          material('lower', 'alpha'),
          material('upper', 'Alpha'),
          material('z', 'Zulu'),
        ],
        progressByAudioId: const {},
        playbackSavedAtByAudioId: const {},
        latestCompletionAtByAudioId: const {},
        recentCompletions: [completion('removed', now)],
      );

      expect(result?.id, 'lower');
    });

    test('回退时跳过已完成材料，全部完成时不返回推荐', () {
      final materials = [
        material('completed-first', 'Alpha'),
        material('available', 'Bravo'),
      ];
      final completedProgress = {
        'completed-first': LearningProgress(
          audioItemId: 'completed-first',
          currentStage: LearningStage.completed,
          updatedAt: now,
        ),
      };

      final available = selectStudyRecommendation(
        materials: materials,
        progressByAudioId: completedProgress,
        playbackSavedAtByAudioId: const {},
        latestCompletionAtByAudioId: const {},
        recentCompletions: const [],
      );
      final allCompleted = selectStudyRecommendation(
        materials: [materials.first],
        progressByAudioId: completedProgress,
        playbackSavedAtByAudioId: const {},
        latestCompletionAtByAudioId: const {},
        recentCompletions: const [],
      );

      expect(available?.id, 'available');
      expect(allCompleted, isNull);
    });

    test('最近完成锚点后的回退也跳过更早已完成的材料', () {
      final materials = [
        material('anchor', 'Alpha'),
        material('completed-after-anchor', 'Bravo'),
        material('available', 'Charlie'),
      ];

      final result = selectStudyRecommendation(
        materials: materials,
        progressByAudioId: {
          'completed-after-anchor': LearningProgress(
            audioItemId: 'completed-after-anchor',
            currentStage: LearningStage.completed,
            updatedAt: now,
          ),
        },
        playbackSavedAtByAudioId: const {},
        latestCompletionAtByAudioId: const {},
        recentCompletions: [completion('anchor', now)],
      );

      expect(result?.id, 'available');
    });

    test('最近完成锚点之后没有材料时不循环', () {
      final result = selectStudyRecommendation(
        materials: [material('last', 'Zulu'), material('first', 'Alpha')],
        progressByAudioId: const {},
        playbackSavedAtByAudioId: const {},
        latestCompletionAtByAudioId: const {},
        recentCompletions: [completion('last', now)],
      );

      expect(result, isNull);
    });

    test('没有最近完成记录时取名称排序第一条，空材料列表返回 null', () {
      final first = selectStudyRecommendation(
        materials: [material('z', 'Zulu'), material('a', 'alpha')],
        progressByAudioId: const {},
        playbackSavedAtByAudioId: const {},
        latestCompletionAtByAudioId: const {},
        recentCompletions: const [],
      );
      final empty = selectStudyRecommendation(
        materials: const [],
        progressByAudioId: const {},
        playbackSavedAtByAudioId: const {},
        latestCompletionAtByAudioId: const {},
        recentCompletions: const [],
      );

      expect(first?.id, 'a');
      expect(empty, isNull);
    });
  });
}
