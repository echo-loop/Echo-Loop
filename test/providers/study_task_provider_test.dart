import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/study_task_provider.dart';
import 'package:fluency/providers/time_provider.dart';

import '../helpers/mock_providers.dart';

void main() {
  group('studyTaskProvider', () {
    test('任务排序遵循：可复习 > 未到时间复习 > 首学', () {
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
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((e) => e.audioId).toList(), ['a', 'b', 'c']);
      expect(tasks[0].type, StudyTaskType.reviewReady);
      expect(tasks[1].type, StudyTaskType.reviewUpcoming);
      expect(tasks[2].type, StudyTaskType.firstStudy);
    });

    test('无进度音频默认生成首学任务', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'audio-1',
          name: 'No Progress Audio',
          audioPath: 'audios/a1.mp3',
          addedDate: now,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.first.type, StudyTaskType.firstStudy);
      expect(tasks.first.stage, LearningStage.firstLearn);
      expect(tasks.first.subStage, SubStageType.blindListen);
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
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
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
          // review1 窗口结束 = completed + 48h，这里逾期 5h
          lastStageCompletedAt: now.subtract(const Duration(hours: 53)),
          updatedAt: now,
        ),
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          // 逾期 2h
          lastStageCompletedAt: now.subtract(const Duration(hours: 50)),
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
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
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
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
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
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
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
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final completed = container.read(completedAudioProvider);
      expect(completed, isEmpty);
    });
  });
}
