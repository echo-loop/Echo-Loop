/// 测试数据工厂（共享）
///
/// 由 `test/` 和 `integration_test/` 共同使用，消除两份 helpers 之间的重复定义。
/// `mock_providers.dart` 和 `test_notifiers.dart` 都从此处 re-export 这些工厂。
///
/// 设计原则：
/// - 所有字段都给默认值，调用方按需覆盖
/// - 不依赖任何 Provider / 状态管理 / 平台通道
/// - 默认日期取 `DateTime(2026, 1, 1)`，便于断言可重复
library;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/tag.dart';

/// 创建测试用 AudioItem
AudioItem createTestAudioItem({
  String id = 'test-audio-1',
  String name = 'Test Audio',
  String audioPath = 'audios/test.mp3',
  String? transcriptPath = 'transcripts/test.srt',
  DateTime? addedDate,
  int totalDuration = 120,
}) {
  return AudioItem(
    id: id,
    name: name,
    audioPath: audioPath,
    transcriptPath: transcriptPath,
    addedDate: addedDate ?? DateTime(2026, 1, 1),
    totalDuration: totalDuration,
  );
}

/// 创建测试用 Sentence 列表
List<Sentence> createTestSentences({int count = 5}) {
  return List.generate(count, (i) {
    return Sentence(
      index: i,
      text: 'Test sentence number ${i + 1}.',
      startTime: Duration(seconds: i * 5),
      endTime: Duration(seconds: (i + 1) * 5),
    );
  });
}

/// 创建测试用 Collection
Collection createTestCollection({
  String id = 'test-collection-1',
  String name = 'Test Collection',
  bool isPinned = false,
  DateTime? createdDate,
}) {
  return Collection(
    id: id,
    name: name,
    createdDate: createdDate ?? DateTime(2026, 1, 1),
    isPinned: isPinned,
  );
}

/// 创建测试用 Tag
Tag createTestTag({
  String id = 'test-tag-1',
  String name = 'Test Tag',
  int colorValue = 0xFFF44336,
  DateTime? createdDate,
}) {
  return Tag(
    id: id,
    name: name,
    colorValue: colorValue,
    createdDate: createdDate ?? DateTime(2026, 1, 1),
  );
}

/// 创建测试用 LearningProgress
///
/// superset 版本：除 `mock_providers.dart` 原有字段外，增加 4 个 intensive/shadowing
/// 相关可选字段，供 integration_test 使用。
LearningProgress createTestLearningProgress({
  String audioItemId = 'test-audio-1',
  LearningStage currentStage = LearningStage.firstLearn,
  SubStageType currentSubStage = SubStageType.blindListen,
  DifficultyLevel difficulty = DifficultyLevel.medium,
  DateTime? firstLearnCompletedAt,
  DateTime? lastStageCompletedAt,
  DateTime? currentStageStartedAt,
  int totalStudyDurationMs = 0,
  int blindListenPassCount = 0,
  int? intensiveListenDifficultCount,
  int? intensiveListenPassCount,
  int? shadowingPassCount,
  int? intensiveListenSentenceIndex,
  DateTime? newLearningBreakpointSavedAt,
  DateTime? freePlayBreakpointSavedAt,
  DateTime? updatedAt,
  Map<LearningStage, int>? planVersionsByStage,
}) {
  return LearningProgress(
    audioItemId: audioItemId,
    currentStage: currentStage,
    currentSubStage: currentSubStage,
    difficulty: difficulty,
    firstLearnCompletedAt: firstLearnCompletedAt,
    lastStageCompletedAt: lastStageCompletedAt,
    currentStageStartedAt: currentStageStartedAt,
    totalStudyDurationMs: totalStudyDurationMs,
    blindListenPassCount: blindListenPassCount,
    intensiveListenDifficultCount: intensiveListenDifficultCount,
    intensiveListenPassCount: intensiveListenPassCount,
    shadowingPassCount: shadowingPassCount,
    intensiveListenSentenceIndex: intensiveListenSentenceIndex,
    newLearningBreakpointSavedAt: newLearningBreakpointSavedAt,
    freePlayBreakpointSavedAt: freePlayBreakpointSavedAt,
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
    planVersionsByStage: planVersionsByStage ?? const {},
  );
}
