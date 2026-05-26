/// 测试用 Notifier 替身（共享）
///
/// 供 `test/helpers/mock_providers.dart` 和 `integration_test/helpers/test_notifiers.dart`
/// 共同使用，消除两份 helpers 之间的重复定义。
///
/// 命名约定：
/// - 类名以 `Fake` 开头，区别于两侧的特化 wrapper
/// - 所有方法提供默认实现（no-op 或内存状态），不访问 I/O / 平台通道
/// - 构造函数接受可选初始状态，方便测试定制
library;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;

// Re-export types used by wrapper classes (needed because Dart doesn't re-export transitive imports)
export 'package:echo_loop/providers/settings_provider.dart'
    show AppSettingsState;
export 'package:echo_loop/providers/audio_library_provider.dart'
    show AudioLibraryState;
export 'package:echo_loop/providers/collection_provider.dart'
    show CollectionState;
export 'package:echo_loop/providers/tag_provider.dart' show TagState;
export 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart'
    show ListeningPracticeState;
export 'package:echo_loop/providers/learning_progress_provider.dart'
    show LearningProgressState;
export 'package:echo_loop/providers/learning_session/learning_session_provider.dart'
    show LearningSessionState;
export 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart'
    show BlindListenPlayerState;
export 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart'
    show IntensiveListenState;
export 'package:echo_loop/providers/learning_session/retell_player_provider.dart'
    show RetellPlayerState;
export 'package:echo_loop/providers/learning_session/review_difficult_practice_provider.dart'
    show ReviewDifficultPracticeState;
export 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart'
    show AudioEngineState;
export 'package:echo_loop/providers/offline_asr_settings_provider.dart'
    show OfflineAsrSettingsState, AsrBackend;
export 'package:echo_loop/services/asr/offline_asr_engine.dart'
    show AsrModelInfo, AsrModelType;
export 'package:echo_loop/database/app_database.dart' show SavedWord;
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/blind_listen_settings.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/models/difficult_practice_settings.dart';
import 'package:echo_loop/models/flashcard_item.dart';
import 'package:echo_loop/models/flashcard_settings.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/models/tag.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/daily_study_time_provider.dart';
import 'package:echo_loop/providers/flashcard/flashcard_flow_phase.dart';
import 'package:echo_loop/providers/flashcard/flashcard_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';
import 'package:echo_loop/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_engine.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/tag_provider.dart';
import 'package:echo_loop/services/asr/offline_asr_engine.dart';
import 'package:echo_loop/services/study_time_service.dart';

// ========== FakeAppSettings ==========

/// 测试用 AppSettings — 不访问 SharedPreferences
class FakeAppSettings extends AppSettings {
  final AppSettingsState initialState;

  FakeAppSettings([this.initialState = const AppSettingsState()]);

  @override
  AppSettingsState build() => initialState;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
  }

  @override
  Future<void> setLocale(Locale? locale) async {
    state = locale == null
        ? state.copyWith(clearLocale: true)
        : state.copyWith(locale: locale);
  }

  @override
  Future<void> setNativeLanguage(String lang) async {
    state = state.copyWith(nativeLanguage: lang);
  }

  @override
  Future<void> setTimeMachineDateTime(DateTime? value) async {
    state = state.copyWith(
      timeMachineDateTime: value,
      clearTimeMachineDateTime: value == null,
    );
  }
}

// ========== FakeAudioLibrary ==========

/// 测试用 AudioLibrary — 不访问文件系统
class FakeAudioLibrary extends AudioLibrary {
  final AudioLibraryState initialState;

  FakeAudioLibrary([this.initialState = const AudioLibraryState()]);

  @override
  AudioLibraryState build() => initialState;

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
  Future<void> togglePin(String id) async {
    final items = [...state.audioItems];
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(isPinned: !items[index].isPinned);
      state = state.copyWith(audioItems: items);
    }
  }

  /// 直接设置音频列表（测试用）
  void setItems(List<AudioItem> items) {
    state = state.copyWith(audioItems: items);
  }

  /// 按 ID 查找（测试用）
  AudioItem? getItemById(String id) {
    try {
      return state.audioItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ========== FakeCollectionList ==========

/// 测试用 CollectionList — 不访问数据库
class FakeCollectionList extends CollectionList {
  final CollectionState initialState;

  FakeCollectionList([this.initialState = const CollectionState()]);

  @override
  CollectionState build() => initialState;

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
  Future<void> renameCollection(String id, String newName) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(name: newName);
      state = state.copyWith(rawCollections: collections);
    }
  }

  @override
  Future<void> togglePin(String id) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(
        isPinned: !collections[index].isPinned,
      );
      state = state.copyWith(rawCollections: collections);
    }
  }

  @override
  void setSortType(CollectionSortType type) {
    state = state.copyWith(sortType: type);
  }
}

// ========== FakeTagList ==========

/// 测试用 TagList — 不访问数据库
class FakeTagList extends TagList {
  final TagState initialState;

  FakeTagList([this.initialState = const TagState()]);

  @override
  TagState build() => initialState;

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
  Future<void> renameTag(String id, String newName) async {
    final tags = [...state.tags];
    final index = tags.indexWhere((t) => t.id == id);
    if (index != -1) {
      tags[index] = tags[index].copyWith(name: newName);
      state = state.copyWith(tags: tags);
    }
  }

  @override
  Future<void> updateTagColor(String id, int colorValue) async {
    final tags = [...state.tags];
    final index = tags.indexWhere((t) => t.id == id);
    if (index != -1) {
      tags[index] = tags[index].copyWith(colorValue: colorValue);
      state = state.copyWith(tags: tags);
    }
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

// ========== FakeListeningPractice ==========

/// 测试用 ListeningPractice — 不访问音频引擎
class FakeListeningPractice extends ListeningPractice {
  final ListeningPracticeState initialState;

  FakeListeningPractice([this.initialState = const ListeningPracticeState()]);

  @override
  ListeningPracticeState build() => initialState;

  @override
  Future<void> loadAudio(
    AudioItem audioItem, {
    bool forceTranscriptReload = false,
  }) async {
    state = state.copyWith(currentAudioItem: audioItem);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> seekAbsolute(Duration absolutePosition) async {}

  @override
  Future<void> selectFullSentence(int index, {bool autoPlay = true}) async {
    state = state.copyWith(currentFullIndex: index);
  }

  @override
  Future<void> selectBookmarkedSentence(
    int index, {
    bool autoPlay = true,
  }) async {
    state = state.copyWith(currentBookmarkIndex: index);
  }

  @override
  Future<void> nextSentence() async {}

  @override
  Future<void> previousSentence() async {}

  @override
  Future<void> replayCurrentSentence() async {}

  @override
  Future<void> toggleBookmark(int index) async {
    final bookmarks = Set<int>.from(state.bookmarkedIndices);
    if (bookmarks.contains(index)) {
      bookmarks.remove(index);
    } else {
      bookmarks.add(index);
    }
    state = state.copyWith(bookmarkedIndices: bookmarks);
  }

  @override
  Future<void> updateSettings(PlaybackSettings newSettings) async {
    state = state.copyWith(settings: newSettings);
  }

  @override
  void setAutoScroll(bool enabled) {
    state = state.copyWith(autoScrollEnabled: enabled);
  }

  @override
  Future<void> setPlaylistMode(PlaylistMode mode) async {
    state = state.copyWith(playlistMode: mode);
  }

  @override
  Future<void> saveCurrentPlaybackState() async {}

  @override
  void suspendListeners() {}

  @override
  void resumeListeners() {}

  @override
  Future<void> syncBookmarks() async {}

  /// 设置测试用句子列表
  void setTestSentences(List<Sentence> sentences) {
    state = state.copyWith(sentences: sentences);
  }
}

// ========== FakeLearningProgressNotifier ==========

/// 测试用 LearningProgressNotifier — 不访问数据库
///
/// 支持完整的进度管理方法，用于学习流程闭环测试。
class FakeLearningProgressNotifier extends LearningProgressNotifier {
  final LearningProgressState initialState;

  FakeLearningProgressNotifier([
    this.initialState = const LearningProgressState(),
  ]);

  @override
  LearningProgressState build() => initialState;

  @override
  Future<void> loadAll() async {}

  @override
  Future<LearningProgress> ensureProgress(String audioItemId) async {
    final existing = state.progressMap[audioItemId];
    if (existing != null) return existing;
    final progress = LearningProgress(
      audioItemId: audioItemId,
      updatedAt: DateTime.now(),
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
    final subStages = stage.allSubStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);
    LearningProgress updated;
    if (currentIdx + 1 < subStages.length) {
      updated = progress.copyWith(
        currentSubStage: subStages[currentIdx + 1],
        currentStageStartedAt: now,
        updatedAt: now,
      );
    } else {
      final nextStage = LearningStage.values[stage.index + 1];
      updated = progress.copyWith(
        currentStage: nextStage,
        currentSubStage: nextStage.allSubStages.first,
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
    // 同步写入 stage_completions 内存集合
    final newCompletions = Map<String, Set<String>>.from(
      state.completionsByAudio,
    );
    final keys = Set<String>.from(newCompletions[audioItemId] ?? const {});
    keys.add('${stage.key}:${progress.currentSubStage.key}');
    newCompletions[audioItemId] = keys;
    state = state.copyWith(
      progressMap: newMap,
      completionsByAudio: newCompletions,
    );
  }

  @override
  Future<LearningProgress?> getLatestByAudioId(String audioItemId) async {
    return state.progressMap[audioItemId];
  }

  @override
  Future<LearningProgress> getLatestOrEnsureProgress(String audioItemId) async {
    final existing = state.progressMap[audioItemId];
    if (existing != null) return existing;
    return ensureProgress(audioItemId);
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
  Future<void> deleteProgress(String audioItemId) async {
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap.remove(audioItemId);
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> pauseProgress(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null || progress.isPaused) return;
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      isPaused: true,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> resumeProgress(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null || !progress.isPaused) return;
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      isPaused: false,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> saveBlindListenSentenceIndex(
    String audioItemId,
    int? paragraphIndex, {
    required bool isFreePlay,
  }) async {}

  @override
  Future<void> saveIntensiveListenSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    if (isFreePlay) {
      newMap[audioItemId] = progress.copyWith(
        freePlayIntensiveListenSentenceIndex: sentenceIndex,
        clearFreePlayIntensiveListenSentenceIndex: sentenceIndex == null,
        freePlayBreakpointSavedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      newMap[audioItemId] = progress.copyWith(
        intensiveListenSentenceIndex: sentenceIndex,
        clearIntensiveListenSentenceIndex: sentenceIndex == null,
        newLearningBreakpointSavedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> saveShadowingSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    if (isFreePlay) {
      newMap[audioItemId] = progress.copyWith(
        freePlayShadowingSentenceIndex: sentenceIndex,
        clearFreePlayShadowingSentenceIndex: sentenceIndex == null,
        freePlayBreakpointSavedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      newMap[audioItemId] = progress.copyWith(
        shadowingSentenceIndex: sentenceIndex,
        clearShadowingSentenceIndex: sentenceIndex == null,
        newLearningBreakpointSavedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> saveRetellSentenceIndex(
    String audioItemId,
    int? paragraphIndex, {
    required bool isFreePlay,
  }) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    if (isFreePlay) {
      newMap[audioItemId] = progress.copyWith(
        freePlayRetellSentenceIndex: paragraphIndex,
        clearFreePlayRetellSentenceIndex: paragraphIndex == null,
        freePlayBreakpointSavedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      newMap[audioItemId] = progress.copyWith(
        retellSentenceIndex: paragraphIndex,
        clearRetellSentenceIndex: paragraphIndex == null,
        newLearningBreakpointSavedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> saveDifficultPracticeSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    if (isFreePlay) {
      newMap[audioItemId] = progress.copyWith(
        freePlayDifficultPracticeSentenceIndex: sentenceIndex,
        clearFreePlayDifficultPracticeSentenceIndex: sentenceIndex == null,
        freePlayBreakpointSavedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      newMap[audioItemId] = progress.copyWith(
        difficultPracticeSentenceIndex: sentenceIndex,
        clearDifficultPracticeSentenceIndex: sentenceIndex == null,
        newLearningBreakpointSavedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    state = state.copyWith(progressMap: newMap);
  }

  /// 直接设置进度（测试辅助方法）
  void setProgress(LearningProgress progress) {
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[progress.audioItemId] = progress;
    state = state.copyWith(progressMap: newMap);
  }

  /// 直接设置 stage_completions（测试辅助方法）
  void setCompletionKeys(String audioItemId, Set<String> keys) {
    final newMap = Map<String, Set<String>>.from(state.completionsByAudio);
    newMap[audioItemId] = keys;
    state = state.copyWith(completionsByAudio: newMap);
  }
}

// ========== FakeLearningSession ==========

/// 测试用 LearningSession — 不依赖音频引擎
class FakeLearningSession extends LearningSession {
  final LearningSessionState initialState;

  FakeLearningSession([this.initialState = const LearningSessionState()]);

  @override
  LearningSessionState build() => initialState;

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
    double playbackSpeed = 1.0,
    double pauseMultiplier = -1.0,
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
    double playbackSpeed = 1.0,
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
    double playbackSpeed = 1.0,
    double pauseMultiplier = -1.0,
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
    List<List<Sentence>> paragraphs, {
    bool isFreePlay = false,
    LearningStage? catchUpStage,
    SubStageType? catchUpSubStage,
    KeywordRatio? overrideKeywordRatio,
    double playbackSpeed = 1.0,
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

  @override
  void addOutputWords(int count) {}

  /// 直接设置 state（测试辅助方法）
  void setState(LearningSessionState newState) => state = newState;
}

// ========== FakeBlindListenPlayer ==========

/// 测试用 BlindListenPlayer — 不依赖音频引擎
class FakeBlindListenPlayer extends BlindListenPlayer {
  final BlindListenPlayerState initialState;

  FakeBlindListenPlayer([this.initialState = const BlindListenPlayerState()]);

  @override
  BlindListenPlayerState build() => initialState;

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
  Future<void> initializeBookmarks(String audioItemId) async {}

  @override
  void disposePlayer() {
    state = const BlindListenPlayerState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(BlindListenPlayerState newState) => state = newState;
}

// ========== FakeIntensiveListenPlayer ==========

/// 测试用 IntensiveListenPlayer — 不依赖音频引擎
class FakeIntensiveListenPlayer extends IntensiveListenPlayer {
  final IntensiveListenState initialState;
  List<Sentence> testSentences;

  FakeIntensiveListenPlayer([
    this.initialState = const IntensiveListenState(),
    this.testSentences = const [],
  ]);

  @override
  IntensiveListenState build() => initialState;

  @override
  Sentence? get currentSentence =>
      testSentences.isNotEmpty &&
          state.currentSentenceIndex < testSentences.length
      ? testSentences[state.currentSentenceIndex]
      : null;

  @override
  List<Sentence> get sentences => List.unmodifiable(testSentences);

  @override
  int get currentIndex => state.currentSentenceIndex;

  @override
  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
    double playbackSpeed = 1.0,
    double pauseMultiplier = -1.0,
  }) async {
    testSentences = List.of(sentences);
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
  void enterWaitingForUserInBlindMode() {
    if (state.annotationState != null) return;
    state = state.copyWith(isPlaying: false);
  }

  @override
  void onAnnotationUserInteraction() {
    state = state.copyWith(isPlaying: false);
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
        isCurrentSentenceAutoMarked: false,
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
        isCurrentSentenceAutoMarked: false,
      );
    }
  }

  @override
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;
    final newDifficult = Set<int>.from(state.difficultSentences);
    final wasAlreadyDifficult = newDifficult.contains(
      state.currentSentenceIndex,
    );
    newDifficult.add(state.currentSentenceIndex);
    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      pauseRemaining: Duration.zero,
      pauseDuration: Duration.zero,
      difficultSentences: newDifficult,
      isCurrentSentenceAutoMarked: !wasAlreadyDifficult,
    );
  }

  @override
  Future<void> exitAnnotationMode() async {
    state = state.copyWith(
      isAnnotationMode: true,
      isAnnotationReplay: true,
      isPlaying: true,
      annotationReplayRemaining: const Duration(seconds: 3),
      annotationReplayDuration: const Duration(seconds: 3),
      isCurrentSentenceAutoMarked: false,
    );
  }

  @override
  Future<void> replayInAnnotationMode() async {
    if (!state.isAnnotationMode) return;
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> replayDuringCountdown() async {
    if (state.isAnnotationMode) {
      state = state.copyWith(
        isPlaying: true,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isAnnotationReplay: true,
        annotationReplayRemaining: const Duration(seconds: 3),
        annotationReplayDuration: const Duration(seconds: 3),
      );
      return;
    }
    state = state.copyWith(
      isPlaying: true,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
    );
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
    state = state.copyWith(
      difficultSentences: newSet,
      isCurrentSentenceAutoMarked: false,
    );
  }

  @override
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  @override
  void stopPlayback() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isAnnotationReplay: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
    );
  }

  @override
  Future<void> resetToStart() async {
    state = state.copyWith(
      currentSentenceIndex: 0,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isTextRevealed: false,
      difficultSentences: {},
      isPlaying: true,
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
  void disposePlayer() {
    testSentences = [];
    state = const IntensiveListenState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(IntensiveListenState newState) => state = newState;

  /// 设置测试句子（测试辅助方法）
  void setTestSentences(List<Sentence> sentences) {
    testSentences = List.of(sentences);
  }
}

// ========== FakeRetellPlayer ==========

/// 测试用 RetellPlayer — 不依赖音频引擎
class FakeRetellPlayer extends RetellPlayer {
  final RetellPlayerState initialState;
  List<List<Sentence>> testParagraphs;
  Map<int, Set<int>> testKeywords;

  FakeRetellPlayer([
    this.initialState = const RetellPlayerState(),
    this.testParagraphs = const [],
    this.testKeywords = const {},
  ]);

  @override
  RetellPlayerState build() => initialState;

  @override
  List<Sentence> get currentParagraphSentences =>
      testParagraphs.isNotEmpty &&
          state.currentParagraphIndex < testParagraphs.length
      ? testParagraphs[state.currentParagraphIndex]
      : [];

  @override
  List<List<Sentence>> get paragraphs => List.unmodifiable(testParagraphs);

  @override
  Map<int, Set<int>> get keywordsMap => Map.unmodifiable(testKeywords);

  @override
  Duration get currentParagraphDuration {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return Duration.zero;
    return sentences.last.endTime - sentences.first.startTime;
  }

  @override
  int? get currentSentenceGlobalIndex {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return null;
    final localIdx = state.playingSentenceIndex >= 0
        ? state.playingSentenceIndex.clamp(0, sentences.length - 1)
        : 0;
    return sentences[localIdx].index;
  }

  @override
  void initialize(
    List<List<Sentence>> paragraphs, {
    int? startSentenceIndex,
    KeywordRatio? autoRatio,
    double playbackSpeed = 1.0,
  }) {
    testParagraphs = paragraphs;
    testKeywords = const {};
    var safeIndex = 0;
    if (startSentenceIndex != null && paragraphs.isNotEmpty) {
      for (var i = 0; i < paragraphs.length; i++) {
        if (paragraphs[i].any((s) => s.index == startSentenceIndex)) {
          safeIndex = i;
          break;
        }
      }
    }
    final initialSettings = autoRatio == null
        ? const RetellSettings()
        : const RetellSettings().copyWith(keywordRatio: autoRatio);
    state = RetellPlayerState(
      currentParagraphIndex: safeIndex,
      totalParagraphs: paragraphs.length,
      settings: initialSettings.copyWith(playbackSpeed: playbackSpeed),
    );
  }

  @override
  Future<void> startPlaying() async {
    if (testParagraphs.isEmpty) return;
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
      totalParagraphs: testParagraphs.length,
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
    if (ratioChanged) regenerateKeywords();
  }

  @override
  void regenerateKeywords() {}

  @override
  void disposePlayer() {
    testParagraphs = [];
    testKeywords = {};
    state = const RetellPlayerState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(RetellPlayerState newState) => state = newState;

  /// 设置测试段落数据（测试辅助方法）
  void setTestParagraphs(List<List<Sentence>> paragraphs) {
    testParagraphs = paragraphs;
  }

  /// 设置测试关键词数据（测试辅助方法）
  void setTestKeywords(Map<int, Set<int>> keywords) {
    testKeywords = keywords;
  }
}

// ========== FakeReviewDifficultPractice ==========

/// 测试用 ReviewDifficultPractice — 不依赖音频引擎
class FakeReviewDifficultPractice extends ReviewDifficultPractice {
  final ReviewDifficultPracticeState initialState;
  List<Sentence> testSentences;
  RepeatFlowEngine? testRepeatEngine;

  FakeReviewDifficultPractice([
    this.initialState = const ReviewDifficultPracticeState(),
    this.testSentences = const [],
  ]);

  @override
  ReviewDifficultPracticeState build() => initialState;

  @override
  Sentence? get currentSentence =>
      testSentences.isNotEmpty &&
          state.currentSentenceIndex < testSentences.length
      ? testSentences[state.currentSentenceIndex]
      : null;

  @override
  List<Sentence> get sentences => List.unmodifiable(testSentences);

  @override
  RepeatFlowEngine? get repeatEngine {
    if (!state.isAnnotationMode) return null;
    final sentence = currentSentence;
    if (sentence == null) return null;
    testRepeatEngine ??= RepeatFlowEngine(
      onStateChanged: (_) {},
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async {},
        startRecording:
            ({
              required String promptId,
              required String referenceText,
              required Duration maxDuration,
              Duration? referenceDuration,
            }) {},
        cancelRecording: () async {},
        stopAndEvaluate: ({required String referenceText}) async {},
        clearRecording: () {},
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => false,
      ),
    );
    testRepeatEngine!.prepare(
      sentences: [sentence],
      config: RepeatFlowConfig(
        audioItemId: 'test-audio',
        getRepeatCount: (_) => 3,
        getIntervalDuration: (_) => const Duration(seconds: 3),
        isManualMode: () => state.isManualMode,
      ),
    );
    return testRepeatEngine;
  }

  @override
  int get currentIndex => state.currentSentenceIndex;

  @override
  void initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
    double playbackSpeed = 1.0,
    double pauseMultiplier = -1.0,
  }) {
    testSentences = List.of(sentences);
    final validIndex = testSentences.isEmpty
        ? 0
        : startIndex.clamp(0, testSentences.length - 1);
    state = ReviewDifficultPracticeState(
      currentSentenceIndex: validIndex,
      totalSentences: sentences.length,
      settings: DifficultPracticeSettings(playbackSpeed: playbackSpeed),
    );
  }

  @override
  Future<void> startPlaying() async {
    if (testSentences.isEmpty) return;
    state = state.copyWith(isPlaying: true);
  }

  @override
  void pause() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  @override
  void stopPlayback() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  @override
  Future<void> resume() async {
    if (state.isAnnotationMode) {
      state = state.copyWith(isPlaying: true, currentPlayCount: 1);
      return;
    }
    state = state.copyWith(isPlaying: true);
  }

  @override
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;
    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: true,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
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
  void enterWaitingForUserInBlindMode() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  @override
  Future<void> updateSettings(DifficultPracticeSettings newSettings) async {
    state = state.copyWith(settings: newSettings, isPlaying: false);
  }

  @override
  Sentence? removeDifficultMark() {
    if (testSentences.isEmpty) return null;
    final removedIndex = state.currentSentenceIndex;
    final removed = testSentences[removedIndex];
    testSentences = List.from(testSentences)..removeAt(removedIndex);
    if (testSentences.isEmpty) {
      state = state.copyWith(isPlaying: false, totalSentences: 0);
      return removed;
    }
    final newIndex = removedIndex >= testSentences.length
        ? testSentences.length - 1
        : removedIndex;
    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: testSentences.length,
      currentPlayCount: 1,
      isPlaying: false,
      isAnnotationMode: false,
      isTextRevealed: false,
    );
    return removed;
  }

  @override
  Future<void> toggleCurrentBookmark(String audioItemId) async {
    final sentence = currentSentence;
    if (sentence == null) return;
    testSentences[state.currentSentenceIndex] = sentence.copyWith(
      isBookmarked: !sentence.isBookmarked,
    );
    state = state.copyWith(bookmarkVersion: state.bookmarkVersion + 1);
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
  Future<void> replayDuringCountdown() async {
    if (state.isAnnotationMode) {
      state = state.copyWith(
        isPlaying: true,
        currentPlayCount: 1,
        isPauseBetweenPlays: false,
      );
    } else {
      state = state.copyWith(
        isPlaying: true,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
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
  void disposePlayer() {
    testSentences = [];
    state = const ReviewDifficultPracticeState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(ReviewDifficultPracticeState newState) => state = newState;

  /// 设置测试句子（测试辅助方法）
  void setTestSentences(List<Sentence> sentences) {
    testSentences = List.of(sentences);
  }
}

// ========== FakeAudioEngine ==========

/// 测试用 AudioEngine — 不依赖 just_audio
class FakeAudioEngine extends AudioEngine {
  final AudioEngineState engineInitialState;
  bool playingState;
  double playbackSpeed = 1.0;

  FakeAudioEngine({
    AudioEngineState initialState = const AudioEngineState(),
    bool isPlaying = false,
  }) : engineInitialState = initialState,
       playingState = isPlaying;

  @override
  AudioEngineState build() => engineInitialState;

  @override
  bool get isPlaying => playingState;

  set isPlaying(bool value) => playingState = value;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Stream<Duration> get absolutePositionStream => Stream.value(Duration.zero);

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  Future<void> play() async {
    playingState = true;
  }

  @override
  Future<void> pause() async {
    playingState = false;
  }

  @override
  Future<void> stop() async {
    playingState = false;
  }

  @override
  Future<void> seek(Duration pos) async {}

  @override
  Future<void> setSpeed(double speed) async {
    playbackSpeed = speed;
  }

  @override
  int newSession() => 0;

  @override
  bool isActiveSession(int id) => true;

  @override
  Future<void> clearClip() async {}

  /// 设置总时长（测试辅助方法）
  void setTotalDuration(Duration duration) {
    state = state.copyWith(totalDuration: duration);
  }
}

// ========== FakeFlashcardNotifier ==========

/// 测试用 FlashcardNotifier — 不访问 SharedPreferences / TTS / 音频引擎
class FakeFlashcardNotifier extends FlashcardNotifier {
  @override
  FlashcardState build() => const FlashcardState();

  @override
  Future<void> initialize(List<FlashcardItem> items) async {
    state = FlashcardState(words: items, currentIndex: 0);
  }

  @override
  Future<void> userFlipCard() async {
    if (state.isCompleted || state.words.isEmpty) return;
    state = state.copyWith(isShowingBack: !state.isShowingBack);
  }

  @override
  Future<void> userNextCard() async {
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
  Future<void> userPreviousCard() async {
    if (state.currentIndex <= 0) return;
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      isShowingBack: false,
    );
  }

  @override
  void onAppBackgrounded() {
    state = state.copyWith(
      phase: const FlashcardWaitingForUser(
        FlashcardWaitingReason.appBackgrounded,
      ),
    );
  }

  @override
  void onSettingsOpened() {
    state = state.copyWith(
      phase: const FlashcardWaitingForUser(
        FlashcardWaitingReason.userOpenedSettings,
      ),
    );
  }

  @override
  Future<void> userPlayWord() async {}

  @override
  Future<void> userPlaySentence() async {}

  @override
  Future<void> disposePlayer() async => state = const FlashcardState();

  @override
  Future<void> reset() async {
    final words = state.words;
    state = FlashcardState(words: words, currentIndex: 0);
  }

  @override
  Future<void> toggleCurrentWordSave() async {
    if (state.words.isEmpty) return;
    final newWords = List<FlashcardItem>.from(state.words)
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
  Future<void> onWordPlayed() async {}

  @override
  Future<void> onSentencePlayed(String sentenceText) async {}

  /// 直接设置状态（测试用）
  void setState(FlashcardState newState) => state = newState;
}

// ========== FakeDailyStudyTime ==========

/// 测试用 DailyStudyTime — 不依赖 SharedPreferences
class FakeDailyStudyTime extends DailyStudyTime {
  @override
  Future<int> build() async => 0;

  @override
  Future<void> refresh() async {}
}

// ========== FakeOfflineAsrSettings ==========

/// 测试用 OfflineAsrSettings — 不执行模型下载/平台调用
class FakeOfflineAsrSettings extends OfflineAsrSettingsNotifier {
  final OfflineAsrSettingsState initialState;

  FakeOfflineAsrSettings([
    this.initialState = const OfflineAsrSettingsState(
      enabled: false,
      backend: AsrBackend.platform,
      engineReady: false,
      recommendedModel: AsrModelInfo(
        id: 'test-model',
        displayName: 'Test Model',
        type: AsrModelType.moonshine,
      ),
    ),
  ]);

  @override
  OfflineAsrSettingsState build() => initialState;

  @override
  Future<void> enable() async {
    state = state.copyWith(enabled: true);
  }

  @override
  Future<void> disable() async {
    state = state.copyWith(enabled: false);
  }

  @override
  Future<void> retryDownload() async {}

  @override
  Future<void> loadEngine() async {
    state = state.copyWith(engineReady: true);
  }
}

// ========== FakeStudyTimeService ==========

/// 无操作 StudyTimeService — 所有写入静默忽略，查询返回零值
class FakeStudyTimeService implements StudyTimeService {
  @override
  Future<int> getStudyTime(DateTime date) async => 0;
  @override
  Future<int> getTodayStudyTime() async => 0;
  @override
  Future<void> addStudyTime(
    int seconds, {
    DateTime? date,
    StudyStage? stage,
  }) async {}
  @override
  Future<int> getStudyStreak({DateTime? now}) async => 0;
  @override
  Future<List<int>> getWeeklyStudyTimes({DateTime? now}) async =>
      List.filled(7, 0);
  @override
  Future<int> getWeekTotalStudyTime({DateTime? now}) async => 0;
  @override
  Future<int> getInputWords(DateTime date) async => 0;
  @override
  Future<int> getTodayInputWords() async => 0;
  @override
  Future<void> addInputWords(int count, {DateTime? date}) async {}
  @override
  Future<int> getOutputWords(DateTime date) async => 0;
  @override
  Future<int> getTodayOutputWords() async => 0;
  @override
  Future<void> addOutputWords(int count, {DateTime? date}) async {}
  @override
  Future<int> getInputTime(DateTime date) async => 0;
  @override
  Future<int> getTodayInputTime() async => 0;
  @override
  Future<void> addInputTime(
    int seconds, {
    DateTime? date,
    StudyStage? stage,
  }) async {}
  @override
  Future<List<int>> getWeeklyInputTimes({DateTime? now}) async =>
      List.filled(7, 0);
  @override
  Future<int> getOutputTime(DateTime date) async => 0;
  @override
  Future<int> getTodayOutputTime() async => 0;
  @override
  Future<void> addOutputTime(
    int seconds, {
    DateTime? date,
    StudyStage? stage,
  }) async {}
  @override
  Future<List<int>> getWeeklyOutputTimes({DateTime? now}) async =>
      List.filled(7, 0);
  @override
  Future<List<DailyStageStudyRecordData>> getStageBreakdown(
    DateTime date,
  ) async => [];
  @override
  Future<DailyTotalData?> getDayTotal(DateTime date) async => null;
}
