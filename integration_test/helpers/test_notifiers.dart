/// 集成测试专用 Notifier 替身和 App 工厂
///
/// 提供所有 Provider 的测试实现，以及 [createTestApp] / [createTestAppWithAudio] 工厂函数。
/// 各测试 group 文件共享此模块，避免重复定义。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fluency/main.dart';
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/models/collection.dart';
import 'package:fluency/models/tag.dart';
import 'package:fluency/models/audio_engine_state.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/models/playback_settings.dart';
import 'package:fluency/models/blind_listen_settings.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/database/app_database.dart'
    show Bookmark, BookmarksCompanion, SavedWord;
import 'package:fluency/database/daos/bookmark_dao.dart';
import 'package:fluency/database/providers.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/tag_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/blind_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/listen_and_repeat_player_provider.dart';
import 'package:fluency/providers/learning_session/retell_player_provider.dart';
import 'package:fluency/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:fluency/providers/speech_practice_session_provider.dart';
import 'package:fluency/providers/package_info_provider.dart';
import 'package:fluency/models/retell_settings.dart';
import 'package:fluency/models/speech_practice_models.dart';
import 'package:fluency/database/daos/sentence_ai_cache_dao.dart';
import 'package:fluency/services/sentence_ai_api_client.dart';
import 'package:fluency/services/speech_practice_platform.dart';
import 'package:fluency/providers/sentence_ai_provider.dart';
import 'package:fluency/providers/daily_study_time_provider.dart';
import 'package:fluency/providers/saved_word_provider.dart';
import 'package:fluency/providers/flashcard/flashcard_provider.dart';
import 'package:fluency/models/flashcard_settings.dart';

/// 测试用 SavedWordList（返回空列表，不依赖数据库）
class TestSavedWordList extends SavedWordList {
  @override
  Stream<List<SavedWord>> build() => Stream.value([]);
}

/// 测试用 DailyStudyTime（直接返回 0，不依赖 SharedPreferences）
class TestDailyStudyTime extends DailyStudyTime {
  @override
  Future<int> build() async => 0;
}

/// Mock SentenceAiCacheDao（集成测试用）
class _MockSentenceAiCacheDao extends Mock implements SentenceAiCacheDao {}

/// Mock SentenceAiApiClient（集成测试用）
class _MockSentenceAiApiClient extends Mock implements SentenceAiApiClient {}

/// 集成测试用录音识别后端替身。
class TestSpeechPracticePlatform implements SpeechPracticeBackend {
  TestSpeechPracticePlatform({
    this.permissions = const SpeechPracticePermissionState(
      microphone: SpeechPracticePermissionStatus.granted,
      speech: SpeechPracticePermissionStatus.granted,
    ),
  });

  final _controller = StreamController<SpeechPracticeEvent>.broadcast();
  SpeechPracticePermissionState permissions;
  final Map<String, String> transcriptsByPath = {};
  String? lastPromptId;
  int _counter = 0;

  @override
  bool get isSupported => true;

  @override
  Stream<SpeechPracticeEvent> get events => _controller.stream;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async {
    return permissions;
  }

  @override
  Future<SpeechPracticePermissionState> requestPermissions() async {
    return permissions;
  }

  @override
  Future<void> warmup({String locale = 'en-US'}) async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    lastPromptId = promptId;
    _counter += 1;
    final path = '/tmp/test-recording-$_counter.caf';
    transcriptsByPath[path] = '';
    return path;
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    if (_counter == 0) return const SpeechPracticeStopResult();
    final filePath = '/tmp/test-recording-$_counter.caf';
    scheduleMicrotask(() {
      _controller.add(
        SpeechPracticeEvent(
          type: SpeechPracticeEventType.finalTranscriptReady,
          promptId: lastPromptId ?? 'prompt',
          transcript: transcriptsByPath[filePath] ?? '',
        ),
      );
    });
    return SpeechPracticeStopResult(filePath: filePath);
  }

  @override
  Future<void> cancelSession() async {
    lastPromptId = null;
  }

  @override
  Future<void> deleteRecording(String filePath) async {
    transcriptsByPath.remove(filePath);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

// ========== 测试数据工厂 ==========

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
  bool isStarred = false,
  DateTime? createdDate,
}) {
  return Collection(
    id: id,
    name: name,
    createdDate: createdDate ?? DateTime(2026, 1, 1),
    isStarred: isStarred,
  );
}

/// 创建测试用 LearningProgress
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
  DateTime? updatedAt,
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
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
  );
}

// ========== 测试 Notifier ==========

/// 测试用 AppSettings — 不访问 SharedPreferences
class TestAppSettings extends AppSettings {
  @override
  AppSettingsState build() => const AppSettingsState();

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
  }

  @override
  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
  }
}

/// 测试用 AudioLibrary — 不访问文件系统
///
/// 支持通过 [addAudioItem] 预置音频，[getItemById] 按 ID 查找。
class TestAudioLibrary extends AudioLibrary {
  @override
  AudioLibraryState build() => const AudioLibraryState();

  @override
  Future<void> loadLibrary() async {}

  @override
  Future<void> addAudioItem(AudioItem item) async {
    state = state.copyWith(audioItems: [...state.audioItems, item]);
  }

  @override
  Future<void> removeAudioItem(String id) async {
    state = state.copyWith(
      audioItems: state.audioItems.where((item) => item.id != id).toList(),
    );
  }

  @override
  Future<void> updateAudioItem(AudioItem updatedItem) async {
    final items = [...state.audioItems];
    final index = items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      items[index] = updatedItem;
      state = state.copyWith(audioItems: items);
    }
  }

  @override
  AudioItem? getItemById(String id) {
    try {
      return state.audioItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> toggleStar(String id) async {
    final items = [...state.audioItems];
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(isStarred: !items[index].isStarred);
      state = state.copyWith(audioItems: items);
    }
  }
}

/// 测试用 CollectionList — 不访问数据库
class TestCollectionList extends CollectionList {
  @override
  CollectionState build() => const CollectionState();

  @override
  Future<void> loadCollections() async {}

  @override
  Future<void> createCollection(String name) async {
    final collection = Collection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdDate: DateTime.now(),
    );
    state = state.copyWith(
      rawCollections: [...state.rawCollections, collection],
    );
  }

  @override
  Future<void> deleteCollection(String id) async {
    state = state.copyWith(
      rawCollections: state.rawCollections.where((c) => c.id != id).toList(),
    );
  }

  @override
  Future<void> toggleStar(String id) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(
        isStarred: !collections[index].isStarred,
      );
      state = state.copyWith(rawCollections: collections);
    }
  }
}

/// 测试用 TagList — 不访问数据库
class TestTagList extends TagList {
  @override
  TagState build() => const TagState();

  @override
  Future<void> loadTags() async {}

  @override
  Future<void> createTag(String name, int colorValue) async {
    final tag = Tag(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: colorValue,
      createdDate: DateTime.now(),
    );
    state = state.copyWith(tags: [...state.tags, tag]);
  }

  @override
  Future<void> deleteTag(String id) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap)
      ..remove(id);
    state = state.copyWith(
      tags: state.tags.where((t) => t.id != id).toList(),
      audioIdsMap: newMap,
    );
  }

  @override
  Future<void> addAudioToTag(String tagId, String audioId) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[tagId] ?? []);
    if (!ids.contains(audioId)) {
      ids.add(audioId);
      newMap[tagId] = ids;
      state = state.copyWith(audioIdsMap: newMap);
    }
  }

  @override
  Future<void> removeAudioFromTag(String tagId, String audioId) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[tagId] ?? []);
    ids.remove(audioId);
    newMap[tagId] = ids;
    state = state.copyWith(audioIdsMap: newMap);
  }

  @override
  Future<void> removeAudioFromAllTags(String audioId) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    for (final key in newMap.keys) {
      newMap[key] = List<String>.from(newMap[key]!)..remove(audioId);
    }
    state = state.copyWith(audioIdsMap: newMap);
  }

  @override
  Future<void> updateAudioTagMembership(
    String audioId,
    Set<String> targetTagIds,
  ) async {
    final currentTags = state.audioToTagsMap[audioId]?.toSet() ?? <String>{};
    final toAdd = targetTagIds.difference(currentTags);
    final toRemove = currentTags.difference(targetTagIds);

    for (final tagId in toAdd) {
      await addAudioToTag(tagId, audioId);
    }
    for (final tagId in toRemove) {
      await removeAudioFromTag(tagId, audioId);
    }
  }
}

/// 测试用 ListeningPractice — 不访问音频引擎
///
/// 支持通过 [loadAudio] 预置句子数据（学习流程测试需要）。
class TestListeningPractice extends ListeningPractice {
  @override
  ListeningPracticeState build() => const ListeningPracticeState();

  @override
  Future<void> loadAudio(AudioItem audioItem) async {
    // 保留 currentAudioItem，不做真实 I/O
    state = state.copyWith(currentAudioItem: audioItem);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setPlaylistMode(PlaylistMode mode) async {
    state = state.copyWith(playlistMode: mode);
  }

  @override
  Future<void> saveCurrentPlaybackState() async {}

  @override
  Future<void> updateSettings(PlaybackSettings newSettings) async {
    state = state.copyWith(settings: newSettings);
  }

  @override
  void suspendListeners() {}

  @override
  void resumeListeners() {}

  @override
  Future<void> syncBookmarks() async {}

  /// 设置测试用句子列表（供外部调用预置数据）
  void setTestSentences(List<Sentence> sentences) {
    state = state.copyWith(sentences: sentences);
  }
}

/// 测试用 LearningProgressNotifier — 不访问数据库
///
/// 支持完整的进度管理方法，用于学习流程闭环测试。
class TestLearningProgressNotifier extends LearningProgressNotifier {
  @override
  LearningProgressState build() => const LearningProgressState();

  @override
  Future<void> loadAll() async {}

  @override
  Future<LearningProgress> ensureProgress(String audioItemId) async {
    final existing = state.progressMap[audioItemId];
    if (existing != null) return existing;

    final now = DateTime.now();
    final progress = LearningProgress(
      audioItemId: audioItemId,
      currentStageStartedAt: now,
      updatedAt: now,
    );
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress;
    state = state.copyWith(progressMap: newMap);
    return progress;
  }

  @override
  Future<void> completeCurrentSubStage(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null || progress.isCompleted) return;

    final now = DateTime.now();
    final stage = progress.currentStage;
    final subStages = stage.subStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);

    LearningProgress updated;
    if (currentIdx + 1 < subStages.length) {
      // 同阶段内推进子步骤
      updated = progress.copyWith(
        currentSubStage: subStages[currentIdx + 1],
        currentStageStartedAt: now,
        updatedAt: now,
      );
    } else {
      // 进入下一个大阶段
      final nextStage = LearningStage.values[stage.index + 1];
      updated = progress.copyWith(
        currentStage: nextStage,
        currentSubStage: nextStage.subStages.first,
        lastStageCompletedAt: now,
        currentStageStartedAt: now,
        firstLearnCompletedAt: stage == LearningStage.firstLearn
            ? now
            : progress.firstLearnCompletedAt,
        updatedAt: now,
      );
    }

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> setDifficulty(
    String audioItemId,
    DifficultyLevel difficulty,
  ) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      difficulty: difficulty,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> incrementBlindListenPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      blindListenPassCount: progress.blindListenPassCount + 1,
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> saveIntensiveListenSentenceIndex(
    String audioItemId,
    int? sentenceIndex,
  ) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      intensiveListenSentenceIndex: sentenceIndex,
      clearIntensiveListenSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> saveShadowingSentenceIndex(
    String audioItemId,
    int? sentenceIndex,
  ) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      shadowingSentenceIndex: sentenceIndex,
      clearShadowingSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> saveDifficultCount(String audioItemId, int count) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      intensiveListenDifficultCount: count,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> incrementIntensiveListenPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      intensiveListenPassCount: (progress.intensiveListenPassCount ?? 0) + 1,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> incrementShadowingPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      shadowingPassCount: (progress.shadowingPassCount ?? 0) + 1,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> saveRetellParagraphIndex(
    String audioItemId,
    int? paragraphIndex,
  ) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      retellParagraphIndex: paragraphIndex,
      clearRetellParagraphIndex: paragraphIndex == null,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> incrementRetellPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      retellPassCount: (progress.retellPassCount ?? 0) + 1,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> saveDifficultPracticeSentenceIndex(
    String audioItemId,
    int? sentenceIndex,
  ) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      difficultPracticeSentenceIndex: sentenceIndex,
      clearDifficultPracticeSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> deleteProgress(String audioItemId) async {
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap.remove(audioItemId);
    state = state.copyWith(progressMap: newMap);
  }

  /// 直接设置进度（测试辅助方法）
  void setProgress(LearningProgress progress) {
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[progress.audioItemId] = progress;
    state = state.copyWith(progressMap: newMap);
  }
}

/// 测试用 AudioEngine — 不依赖 just_audio
class TestAudioEngine extends AudioEngine {
  @override
  AudioEngineState build() => const AudioEngineState();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Stream<Duration> get absolutePositionStream => Stream.value(Duration.zero);

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration pos) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  int newSession() => 0;

  @override
  bool isActiveSession(int id) => true;

  /// 设置总时长（测试辅助方法）
  void setTotalDuration(Duration duration) {
    state = state.copyWith(totalDuration: duration);
  }
}

/// 测试用 LearningSession — 不依赖音频引擎
class TestLearningSession extends LearningSession {
  @override
  LearningSessionState build() => const LearningSessionState();

  @override
  Future<void> enterBlindListenMode(
    String audioItemId, {
    bool isFreePlay = false,
    required List<List<Sentence>> paragraphs,
    BlindListenSettings? settings,
  }) async {
    state = state.copyWith(
      learningMode: LearningMode.blindListen,
      audioItemId: audioItemId,
      isFreePlay: isFreePlay,
    );
  }

  @override
  Future<void> enterIntensiveListenMode(
    String audioItemId,
    List<Sentence> sentences, {
    bool isFreePlay = false,
  }) async {
    state = state.copyWith(
      learningMode: LearningMode.intensiveListen,
      audioItemId: audioItemId,
      isFreePlay: isFreePlay,
    );
  }

  @override
  Future<void> enterListenAndRepeatMode(
    String audioItemId,
    List<Sentence> sentences, {
    bool isFreePlay = false,
  }) async {
    state = state.copyWith(
      learningMode: LearningMode.listenAndRepeat,
      audioItemId: audioItemId,
      isFreePlay: isFreePlay,
    );
  }

  @override
  Future<void> enterReviewDifficultPracticeMode(
    String audioItemId,
    List<Sentence> allSentences, {
    bool isFreePlay = false,
  }) async {
    state = state.copyWith(
      learningMode: LearningMode.reviewDifficultPractice,
      audioItemId: audioItemId,
      isFreePlay: isFreePlay,
    );
  }

  @override
  Future<void> enterRetellMode(
    String audioItemId,
    List<List<Sentence>> paragraphs,
    Map<int, Set<int>> keywordsMap, {
    bool isFreePlay = false,
  }) async {
    state = state.copyWith(
      learningMode: LearningMode.retell,
      audioItemId: audioItemId,
      isFreePlay: isFreePlay,
    );
  }

  @override
  Future<void> replayBlindListen() async {
    state = state.copyWith(blindListenCompleted: false);
  }

  @override
  Future<void> exitLearningMode() async {
    state = const LearningSessionState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(LearningSessionState newState) {
    state = newState;
  }
}

/// 测试用 BlindListenPlayer — 不依赖音频引擎
class TestBlindListenPlayer extends BlindListenPlayer {
  @override
  BlindListenPlayerState build() => const BlindListenPlayerState();

  @override
  Future<void> startPlaying() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> resume() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> restart() async {
    state = const BlindListenPlayerState();
    state = state.copyWith(isPlaying: true);
  }

  @override
  void disposePlayer() {
    state = const BlindListenPlayerState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(BlindListenPlayerState newState) {
    state = newState;
  }
}

/// 测试用 IntensiveListenPlayer — 不依赖音频引擎
class TestIntensiveListenPlayer extends IntensiveListenPlayer {
  List<Sentence> _testSentences = [];

  @override
  IntensiveListenState build() => const IntensiveListenState();

  @override
  Sentence? get currentSentence =>
      _testSentences.isNotEmpty &&
          state.currentSentenceIndex < _testSentences.length
      ? _testSentences[state.currentSentenceIndex]
      : null;

  @override
  List<Sentence> get sentences => List.unmodifiable(_testSentences);

  @override
  int get currentIndex => state.currentSentenceIndex;

  @override
  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
  }) async {
    _testSentences = List.of(sentences);
    state = IntensiveListenState(
      currentSentenceIndex: startIndex,
      totalSentences: sentences.length,
    );
  }

  @override
  void updateSettings(IntensiveListenSettings newSettings) {
    state = state.copyWith(settings: newSettings);
  }

  @override
  Future<void> startPlaying() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> resume() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> goToNext() async {
    if (state.currentSentenceIndex < state.totalSentences - 1) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isAnnotationReplay: false,
        isTextRevealed: false,
      );
    }
  }

  @override
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex > 0) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex - 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isAnnotationReplay: false,
        isTextRevealed: false,
      );
    }
  }

  @override
  void enterAnnotationMode() {
    final newDifficult = Set<int>.from(state.difficultSentences);
    newDifficult.add(state.currentSentenceIndex);
    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: false,
      difficultSentences: newDifficult,
    );
  }

  @override
  Future<void> exitAnnotationMode() async {
    state = state.copyWith(
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isPlaying: true,
    );
  }

  @override
  Future<void> replayInAnnotationMode() async {
    if (!state.isAnnotationMode) return;
    state = state.copyWith(isPlaying: true);
  }

  @override
  void toggleDifficultSentence() {
    final idx = state.currentSentenceIndex;
    final newSet = Set<int>.from(state.difficultSentences);
    if (newSet.contains(idx)) {
      newSet.remove(idx);
    } else {
      newSet.add(idx);
    }
    state = state.copyWith(difficultSentences: newSet);
  }

  @override
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  @override
  void disposePlayer() {
    _testSentences = [];
    state = const IntensiveListenState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(IntensiveListenState newState) {
    state = newState;
  }

  /// 设置测试句子（测试辅助方法）
  void setTestSentences(List<Sentence> sentences) {
    _testSentences = List.of(sentences);
  }
}

/// 测试用 ListenAndRepeatPlayer — 不依赖音频引擎
class TestListenAndRepeatPlayer extends ListenAndRepeatPlayer {
  List<Sentence> _testSentences = [];

  @override
  ListenAndRepeatPlayerState build() => const ListenAndRepeatPlayerState();

  @override
  Sentence? get currentSentence =>
      _testSentences.isNotEmpty &&
          state.currentSentenceIndex < _testSentences.length
      ? _testSentences[state.currentSentenceIndex]
      : null;

  @override
  List<Sentence> get sentences => List.unmodifiable(_testSentences);

  @override
  int get currentIndex => state.currentSentenceIndex;

  @override
  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
    int targetPlayCount = 3,
  }) async {
    _testSentences = List.of(sentences);
    state = ListenAndRepeatPlayerState(
      currentSentenceIndex: startIndex.clamp(0, sentences.length - 1),
      totalSentences: sentences.length,
      targetPlayCount: targetPlayCount,
    );
  }

  @override
  Future<void> startPlaying() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  @override
  Future<void> resume() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  void updateSettings(IntensiveListenSettings newSettings) {
    state = state.copyWith(settings: newSettings);
  }

  @override
  Future<void> goToNext() async {
    if (state.currentSentenceIndex < state.totalSentences - 1) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
      );
    }
  }

  @override
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex > 0) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex - 1,
        currentPlayCount: 1,
      );
    }
  }

  @override
  void pauseCountdown() {
    state = state.copyWith(isCountdownPaused: true);
  }

  @override
  void resumeCountdown() {
    state = state.copyWith(isCountdownPaused: false);
  }

  @override
  void toggleCountdownFastForward() {
    state = state.copyWith(
      isCountdownFastForward: !state.isCountdownFastForward,
      isCountdownPaused: false,
    );
  }

  @override
  Sentence? removeDifficultMark() {
    if (_testSentences.isEmpty) return null;

    final removedIndex = state.currentSentenceIndex;
    final removed = _testSentences[removedIndex];
    _testSentences = List.from(_testSentences)..removeAt(removedIndex);

    if (_testSentences.isEmpty) {
      state = state.copyWith(
        isPlaying: false,
        totalSentences: 0,
      );
      return removed;
    }

    final newIndex = removedIndex >= _testSentences.length
        ? _testSentences.length - 1
        : removedIndex;

    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: _testSentences.length,
      currentPlayCount: 1,
      isPlaying: false,
    );

    return removed;
  }

  @override
  void disposePlayer() {
    _testSentences = [];
    state = const ListenAndRepeatPlayerState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(ListenAndRepeatPlayerState newState) {
    state = newState;
  }

  /// 设置测试句子（测试辅助方法）
  void setTestSentences(List<Sentence> sentences) {
    _testSentences = List.of(sentences);
  }
}

/// 测试用 RetellPlayer — 不依赖音频引擎
class TestRetellPlayer extends RetellPlayer {
  List<List<Sentence>> _testParagraphs = [];
  Map<int, Set<int>> _testKeywords = {};

  @override
  RetellPlayerState build() => const RetellPlayerState();

  @override
  List<Sentence> get currentParagraphSentences =>
      _testParagraphs.isNotEmpty &&
          state.currentParagraphIndex < _testParagraphs.length
      ? _testParagraphs[state.currentParagraphIndex]
      : [];

  @override
  List<List<Sentence>> get paragraphs => List.unmodifiable(_testParagraphs);

  @override
  Map<int, Set<int>> get keywordsMap => Map.unmodifiable(_testKeywords);

  @override
  Duration get currentParagraphDuration {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return Duration.zero;
    return sentences.last.endTime - sentences.first.startTime;
  }

  @override
  void initialize(
    List<List<Sentence>> paragraphs,
    Map<int, Set<int>> keywordsMap, {
    int? startSentenceIndex,
  }) {
    _testParagraphs = paragraphs;
    _testKeywords = keywordsMap;
    var safeIndex = 0;
    if (startSentenceIndex != null && paragraphs.isNotEmpty) {
      for (var i = 0; i < paragraphs.length; i++) {
        if (paragraphs[i].any((s) => s.index == startSentenceIndex)) {
          safeIndex = i;
          break;
        }
      }
    }
    state = RetellPlayerState(
      currentParagraphIndex: safeIndex,
      totalParagraphs: paragraphs.length,
    );
  }

  @override
  Future<void> startPlaying() async {
    if (_testParagraphs.isEmpty) return;
    state = state.copyWith(
      phase: RetellPhase.listening,
      isPlaying: true,
      playingSentenceIndex: 0,
    );
  }

  @override
  Future<void> restart() async {
    state = RetellPlayerState(
      currentParagraphIndex: 0,
      totalParagraphs: _testParagraphs.length,
      settings: state.settings,
      displayMode: RetellDisplayMode.keywordsOnly,
      phase: RetellPhase.listening,
      isPlaying: true,
      playingSentenceIndex: 0,
    );
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(isPlaying: false, isRetellCountdown: false);
  }

  @override
  Future<void> resume() async {
    if (state.phase == RetellPhase.listening) {
      state = state.copyWith(isPlaying: true);
    }
  }

  @override
  Future<void> goToNextParagraph() async {
    if (state.currentParagraphIndex >= state.totalParagraphs - 1) {
      state = state.copyWith(isPlaying: false, isRetellCountdown: false);
      return;
    }
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex + 1,
      phase: RetellPhase.listening,
      currentRepeatCount: 1,
      playingSentenceIndex: 0,
      isRetellCountdown: false,
      isPlaying: true,
      displayMode: RetellDisplayMode.keywordsOnly,
    );
  }

  @override
  Future<void> goToPreviousParagraph() async {
    if (state.currentParagraphIndex <= 0) return;
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex - 1,
      phase: RetellPhase.listening,
      currentRepeatCount: 1,
      playingSentenceIndex: 0,
      isRetellCountdown: false,
      isPlaying: true,
      displayMode: RetellDisplayMode.keywordsOnly,
    );
  }

  @override
  void pauseCountdown() {
    state = state.copyWith(isCountdownPaused: true);
  }

  @override
  void resumeCountdown() {
    state = state.copyWith(isCountdownPaused: false);
  }

  @override
  void toggleCountdownFastForward() {
    state = state.copyWith(
      isCountdownFastForward: !state.isCountdownFastForward,
    );
  }

  @override
  Future<void> replayDuringCountdown() async {
    state = state.copyWith(
      phase: RetellPhase.listening,
      isRetellCountdown: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      isPlaying: true,
    );
  }

  @override
  void setDisplayMode(RetellDisplayMode mode) {
    state = state.copyWith(displayMode: mode);
  }

  @override
  void updateSettings(RetellSettings newSettings) {
    final ratioChanged =
        newSettings.keywordRatio != state.settings.keywordRatio;
    state = state.copyWith(settings: newSettings);
    if (ratioChanged) {
      regenerateKeywords();
    }
  }

  @override
  void regenerateKeywords() {
    // 测试环境不实际重新生成，保持已设置的关键词
  }

  @override
  void disposePlayer() {
    _testParagraphs = [];
    _testKeywords = {};
    state = const RetellPlayerState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(RetellPlayerState newState) {
    state = newState;
  }

  /// 设置测试段落数据（测试辅助方法）
  void setTestParagraphs(List<List<Sentence>> paragraphs) {
    _testParagraphs = paragraphs;
  }

  /// 设置测试关键词数据（测试辅助方法）
  void setTestKeywords(Map<int, Set<int>> keywords) {
    _testKeywords = keywords;
  }
}

/// 测试用 ReviewDifficultPractice — 不依赖音频引擎
class TestReviewDifficultPractice extends ReviewDifficultPractice {
  List<Sentence> _testSentences = [];

  @override
  ReviewDifficultPracticeState build() => const ReviewDifficultPracticeState();

  @override
  Sentence? get currentSentence =>
      _testSentences.isNotEmpty &&
          state.currentSentenceIndex < _testSentences.length
      ? _testSentences[state.currentSentenceIndex]
      : null;

  @override
  List<Sentence> get sentences => List.unmodifiable(_testSentences);

  @override
  int get currentIndex => state.currentSentenceIndex;

  @override
  void initialize(List<Sentence> sentences, {int startIndex = 0}) {
    _testSentences = List.of(sentences);
    final validIndex = _testSentences.isEmpty
        ? 0
        : startIndex.clamp(0, _testSentences.length - 1);
    state = ReviewDifficultPracticeState(
      currentSentenceIndex: validIndex,
      totalSentences: sentences.length,
    );
  }

  @override
  Future<void> startPlaying() async {
    if (_testSentences.isEmpty) return;
    state = state.copyWith(isPlaying: true);
  }

  @override
  void pause() {
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> resume() async {
    if (state.isAnnotationMode) {
      // 跟读模式恢复：从第 1 遍重新开始
      state = state.copyWith(isPlaying: true, currentPlayCount: 1);
      return;
    }
    state = state.copyWith(isPlaying: true);
  }

  @override
  void enterAnnotationMode() {
    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: true,
      currentPlayCount: 1,
      isTextRevealed: false,
    );
  }

  @override
  Future<void> skipShadowReading() async {
    state = state.copyWith(
      isAnnotationMode: false,
      isPlaying: false,
      isPauseBetweenPlays: false,
    );
  }

  @override
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  @override
  Sentence? removeDifficultMark() {
    if (_testSentences.isEmpty) return null;

    final removedIndex = state.currentSentenceIndex;
    final removed = _testSentences[removedIndex];
    _testSentences = List.from(_testSentences)..removeAt(removedIndex);

    if (_testSentences.isEmpty) {
      state = state.copyWith(
        isPlaying: false,
        totalSentences: 0,
      );
      return removed;
    }

    final newIndex = removedIndex >= _testSentences.length
        ? _testSentences.length - 1
        : removedIndex;

    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: _testSentences.length,
      currentPlayCount: 1,
      isPlaying: false,
      isAnnotationMode: false,
      isTextRevealed: false,
    );

    return removed;
  }

  @override
  Future<void> goToNext() async {
    if (state.currentSentenceIndex < state.totalSentences - 1) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isTextRevealed: false,
      );
    }
  }

  @override
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex > 0) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex - 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isTextRevealed: false,
      );
    }
  }

  @override
  void disposePlayer() {
    _testSentences = [];
    state = const ReviewDifficultPracticeState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(ReviewDifficultPracticeState newState) {
    state = newState;
  }

  /// 设置测试句子（测试辅助方法）
  void setTestSentences(List<Sentence> sentences) {
    _testSentences = List.of(sentences);
  }
}

/// 测试用 BookmarkDao — 支持 watchByAudioId 返回可控 Stream
///
/// 精听播放器退出时会通过 BookmarkDao 保存难句书签，
/// 学习计划页通过 watchByAudioId 实时查询难句数。
/// [bookmarkCount] 控制 watchByAudioId 返回的书签数量。
class TestBookmarkDao implements BookmarkDao {
  /// 设置书签数量，watchByAudioId 会返回对应数量的 mock 书签
  int bookmarkCount = 0;

  /// 内存存储：audioItemId → sentenceIndex 集合
  final Map<String, Set<int>> _store = {};

  @override
  Future<List<Bookmark>> getByAudioId(String audioItemId) {
    final indices = _store[audioItemId] ?? {};
    // 返回 mock Bookmark 列表（只需长度正确）
    final bookmarks = indices
        .map(
          (i) => Bookmark(
            id: i,
            audioItemId: audioItemId,
            sentenceIndex: i,
            sentenceText: 'test sentence $i',
            startTime: 0.0,
            endTime: 1.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            syncStatus: 0,
          ),
        )
        .toList();
    return Future.value(bookmarks);
  }

  @override
  Future<Set<int>> getBookmarkedIndices(String audioItemId) {
    return Future.value(_store[audioItemId] ?? {});
  }

  @override
  Future<void> addBookmark(BookmarksCompanion entry) {
    final audioId = entry.audioItemId.value;
    final index = entry.sentenceIndex.value;
    _store.putIfAbsent(audioId, () => {});
    _store[audioId]!.add(index);
    return Future.value();
  }

  @override
  Future<void> removeBookmark(String audioItemId, int sentenceIndex) {
    _store[audioItemId]?.remove(sentenceIndex);
    return Future.value();
  }

  @override
  Future<void> removeBookmarks(String audioItemId, Set<int> sentenceIndices) {
    _store[audioItemId]?.removeAll(sentenceIndices);
    return Future.value();
  }

  @override
  Future<void> removeAllForAudio(String audioItemId) {
    _store.remove(audioItemId);
    return Future.value();
  }

  @override
  Future<void> batchInsert(List<BookmarksCompanion> entries) {
    for (final entry in entries) {
      final audioId = entry.audioItemId.value;
      final index = entry.sentenceIndex.value;
      _store.putIfAbsent(audioId, () => {});
      _store[audioId]!.add(index);
    }
    return Future.value();
  }

  @override
  Stream<List<BookmarkWithAudio>> watchAllWithAudioName() {
    final allBookmarks = <BookmarkWithAudio>[];
    for (final entry in _store.entries) {
      for (final index in entry.value) {
        allBookmarks.add(
          BookmarkWithAudio(
            bookmark: Bookmark(
              id: index,
              audioItemId: entry.key,
              sentenceIndex: index,
              sentenceText: 'test sentence $index',
              startTime: 0.0,
              endTime: 1.0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              syncStatus: 0,
            ),
            audioName: 'Test Audio',
          ),
        );
      }
    }
    return Stream.value(allBookmarks);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName.toString();
    if (memberName.contains('watchByAudioId')) {
      // watchByAudioId 返回 Stream<List<Bookmark>>
      return Stream.value(List.generate(bookmarkCount, (i) => null));
    }
    return null;
  }
}

// ========== Flashcard 测试替身 ==========

/// 集成测试用 FlashcardNotifier — 不访问 SharedPreferences / TTS / 音频引擎
class TestFlashcardNotifier extends FlashcardNotifier {
  @override
  FlashcardState build() => const FlashcardState();

  @override
  Future<void> initialize(List<SavedWord> words) async {
    final items = words.map((w) => FlashcardWordItem(savedWord: w)).toList();
    state = FlashcardState(words: items, currentIndex: 0);
  }

  @override
  void flipCard() {
    if (state.isCompleted || state.words.isEmpty) return;
    state = state.copyWith(isShowingBack: !state.isShowingBack);
  }

  @override
  void nextCard() {
    if (state.currentIndex >= state.words.length - 1) {
      state = state.copyWith(isCompleted: true);
      return;
    }
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      isShowingBack: false,
    );
  }

  @override
  void previousCard() {
    if (state.currentIndex <= 0) return;
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      isShowingBack: false,
    );
  }

  @override
  void pause() => state = state.copyWith(isPaused: true);

  @override
  void resume() => state = state.copyWith(isPaused: false);

  @override
  void togglePause() => state = state.copyWith(isPaused: !state.isPaused);

  @override
  Future<void> disposePlayer() async => state = const FlashcardState();

  @override
  Future<void> reset() async {
    final words = state.words;
    state = FlashcardState(words: words, currentIndex: 0);
  }

  @override
  Future<void> unsaveCurrentWord() async {
    if (state.words.isEmpty) return;
    final newWords = List<FlashcardWordItem>.from(state.words)
      ..removeAt(state.currentIndex);
    final newIndex =
        state.currentIndex >= newWords.length && newWords.isNotEmpty
        ? newWords.length - 1
        : state.currentIndex;
    if (newWords.isEmpty) {
      state = state.copyWith(
        words: newWords,
        isCompleted: true,
        removedCount: state.removedCount + 1,
      );
    } else {
      state = state.copyWith(
        words: newWords,
        currentIndex: newIndex,
        isShowingBack: false,
        removedCount: state.removedCount + 1,
      );
    }
  }

  @override
  Future<void> updateSettings(FlashcardSettings newSettings) async {
    state = state.copyWith(settings: newSettings);
  }

  @override
  void speakCurrentWord() {}

  @override
  Future<void> onWordPlayed() async {}

  @override
  Future<void> onSentencePlayed(String sentenceText) async {}

  /// 直接设置状态（测试用）
  void setState(FlashcardState newState) => state = newState;
}

// ========== App 工厂 ==========

final _testPackageInfo = PackageInfo(
  appName: 'Fluency',
  packageName: 'top.echo-loop',
  version: '1.0.0',
  buildNumber: '1',
);

/// 创建集成测试用的 App，注入所有 Provider 测试替身
Widget createTestApp() {
  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith(() => TestAppSettings()),
      audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
      collectionListProvider.overrideWith(() => TestCollectionList()),
      tagListProvider.overrideWith(() => TestTagList()),
      listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
      learningProgressNotifierProvider.overrideWith(
        () => TestLearningProgressNotifier(),
      ),
      learningSessionProvider.overrideWith(() => TestLearningSession()),
      blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
      intensiveListenPlayerProvider.overrideWith(
        () => TestIntensiveListenPlayer(),
      ),
      listenAndRepeatPlayerProvider.overrideWith(
        () => TestListenAndRepeatPlayer(),
      ),
      retellPlayerProvider.overrideWith(() => TestRetellPlayer()),
      reviewDifficultPracticeProvider.overrideWith(
        () => TestReviewDifficultPractice(),
      ),
      bookmarkDaoProvider.overrideWithValue(TestBookmarkDao()),
      packageInfoProvider.overrideWithValue(_testPackageInfo),
      sentenceAiNotifierProvider.overrideWithValue(
        SentenceAiNotifier(
          cacheDao: _MockSentenceAiCacheDao(),
          apiClient: _MockSentenceAiApiClient(),
        ),
      ),
      dailyStudyTimeProvider.overrideWith(() => TestDailyStudyTime()),
      savedWordListProvider.overrideWith(() => TestSavedWordList()),
      flashcardNotifierProvider.overrideWith(() => TestFlashcardNotifier()),
      speechPracticeBackendProvider.overrideWithValue(
        TestSpeechPracticePlatform(),
      ),
    ],
    child: const FluencyApp(),
  );
}

/// 创建预置音频数据的集成测试 App
///
/// 预置内容：
/// - 1 个 AudioItem（id='test-audio-1'，含 transcriptPath）
/// - 1 个 Collection（id='test-collection-1'）
/// - 1 个 LearningProgress（firstLearn / blindListen 阶段）
/// - 5 个 Sentence（通过 ListeningPractice）
/// - AudioEngine totalDuration = 25 秒
///
/// 可通过 [progressOverride] 自定义初始进度。
Widget createTestAppWithAudio({
  LearningProgress? progressOverride,
  AudioItem? audioItemOverride,
}) {
  final audioItem = audioItemOverride ?? createTestAudioItem();
  final collection = createTestCollection();
  final sentences = createTestSentences();
  final progress =
      progressOverride ??
      createTestLearningProgress(currentStageStartedAt: DateTime.now());

  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith(() => TestAppSettings()),
      audioLibraryProvider.overrideWith(() {
        final notifier = TestAudioLibrary();
        // addPostFrameCallback 中 build() 已返回，此时可安全设置状态
        // 但 overrideWith 在 build() 之后才有 state，
        // 所以改为直接在 build() 中返回包含数据的初始状态
        return notifier;
      }),
      collectionListProvider.overrideWith(() => TestCollectionList()),
      tagListProvider.overrideWith(() => TestTagList()),
      listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
      learningProgressNotifierProvider.overrideWith(
        () => TestLearningProgressNotifier(),
      ),
      learningSessionProvider.overrideWith(() => TestLearningSession()),
      blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
      intensiveListenPlayerProvider.overrideWith(
        () => TestIntensiveListenPlayer(),
      ),
      listenAndRepeatPlayerProvider.overrideWith(
        () => TestListenAndRepeatPlayer(),
      ),
      retellPlayerProvider.overrideWith(() => TestRetellPlayer()),
      reviewDifficultPracticeProvider.overrideWith(
        () => TestReviewDifficultPractice(),
      ),
      bookmarkDaoProvider.overrideWithValue(TestBookmarkDao()),
      packageInfoProvider.overrideWithValue(_testPackageInfo),
      sentenceAiNotifierProvider.overrideWithValue(
        SentenceAiNotifier(
          cacheDao: _MockSentenceAiCacheDao(),
          apiClient: _MockSentenceAiApiClient(),
        ),
      ),
      dailyStudyTimeProvider.overrideWith(() => TestDailyStudyTime()),
      savedWordListProvider.overrideWith(() => TestSavedWordList()),
      flashcardNotifierProvider.overrideWith(() => TestFlashcardNotifier()),
      speechPracticeBackendProvider.overrideWithValue(
        TestSpeechPracticePlatform(),
      ),
    ],
    child: _AudioPreloadWrapper(
      audioItem: audioItem,
      collection: collection,
      sentences: sentences,
      progress: progress,
    ),
  );
}

/// 预加载音频数据的 Wrapper
///
/// 在 App 启动后通过 [ProviderScope.containerOf] 获取 notifier，
/// 预置测试数据，然后渲染 [FluencyApp]。
class _AudioPreloadWrapper extends ConsumerStatefulWidget {
  final AudioItem audioItem;
  final Collection collection;
  final List<Sentence> sentences;
  final LearningProgress progress;

  const _AudioPreloadWrapper({
    required this.audioItem,
    required this.collection,
    required this.sentences,
    required this.progress,
  });

  @override
  ConsumerState<_AudioPreloadWrapper> createState() =>
      _AudioPreloadWrapperState();
}

class _AudioPreloadWrapperState extends ConsumerState<_AudioPreloadWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadData();
    });
  }

  void _preloadData() {
    // 预置音频
    final audioLib =
        ref.read(audioLibraryProvider.notifier) as TestAudioLibrary;
    audioLib.addAudioItem(widget.audioItem);

    // 预置合集（含音频关联）
    final collectionList =
        ref.read(collectionListProvider.notifier) as TestCollectionList;
    collectionList.state = collectionList.state.copyWith(
      rawCollections: [widget.collection],
      audioIdsMap: {
        widget.collection.id: [widget.audioItem.id],
      },
    );

    // 预置学习进度
    final progressNotifier =
        ref.read(learningProgressNotifierProvider.notifier)
            as TestLearningProgressNotifier;
    progressNotifier.setProgress(widget.progress);

    // 预置句子数据
    final practice =
        ref.read(listeningPracticeProvider.notifier) as TestListeningPractice;
    practice.setTestSentences(widget.sentences);

    // 预置 AudioEngine 总时长（25 秒 = 5 句 × 5 秒）
    final engine = ref.read(audioEngineProvider.notifier) as TestAudioEngine;
    engine.setTotalDuration(const Duration(seconds: 25));
  }

  @override
  Widget build(BuildContext context) {
    return const FluencyApp();
  }
}
