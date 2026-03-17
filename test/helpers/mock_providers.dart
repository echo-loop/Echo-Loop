/// Mock Provider 集合
///
/// 用 Riverpod overrideWith 模式创建测试用 Notifier，
/// 避免真实 I/O（SharedPreferences、文件系统、just_audio）。
library;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/models/collection.dart';
import 'package:fluency/models/tag.dart';
import 'package:fluency/models/difficult_practice_settings.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/models/playback_settings.dart';
import 'package:fluency/models/audio_engine_state.dart';
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
import 'package:fluency/models/retell_settings.dart';
import 'package:fluency/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:fluency/providers/daily_study_time_provider.dart';
import 'package:fluency/providers/speech_practice_session_provider.dart';
import 'package:fluency/providers/listen_and_repeat_turn_controller_provider.dart';
import 'package:fluency/models/speech_practice_models.dart';
import 'package:fluency/providers/transcription_task_provider.dart';
import 'package:fluency/services/transcription_api_client.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/models/app_update_info.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/providers/app_update_provider.dart';

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

// ========== 测试 Notifier ==========

/// 测试用 AppUpdate — 不访问网络和 SharedPreferences
class TestAppUpdate extends AppUpdate {
  @override
  AppUpdateState build() => const AppUpdateInitial();

  @override
  Future<AppUpdateResult> manualCheck() async {
    return const AppUpdateResult(type: AppUpdateType.none);
  }

  @override
  Future<void> dismiss() async {
    state = const AppUpdateDismissed();
  }
}

/// 测试用 AppSettings — 不访问 SharedPreferences
class TestAppSettings extends AppSettings {
  final AppSettingsState _initialState;

  TestAppSettings([this._initialState = const AppSettingsState()]);

  @override
  AppSettingsState build() => _initialState;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
  }

  @override
  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
  }

  @override
  Future<void> setTimeMachineDateTime(DateTime? value) async {
    state = state.copyWith(
      timeMachineDateTime: value,
      clearTimeMachineDateTime: value == null,
    );
  }
}

/// 测试用 AudioLibrary — 不访问文件系统
class TestAudioLibrary extends AudioLibrary {
  final AudioLibraryState _initialState;

  TestAudioLibrary([this._initialState = const AudioLibraryState()]);

  @override
  AudioLibraryState build() => _initialState;

  @override
  Future<void> loadLibrary() async {
    // 测试中不做任何 I/O
  }

  /// 直接设置音频列表（测试用）
  void setItems(List<AudioItem> items) {
    state = state.copyWith(audioItems: items);
  }

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
  Future<void> toggleStar(String id) async {
    final items = [...state.audioItems];
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(isStarred: !items[index].isStarred);
      state = state.copyWith(audioItems: items);
    }
  }
}

/// 测试用 CollectionList — 不访问 StorageService
class TestCollectionList extends CollectionList {
  final CollectionState _initialState;

  TestCollectionList([this._initialState = const CollectionState()]);

  @override
  CollectionState build() => _initialState;

  @override
  Future<void> loadCollections() async {
    // 测试中不做任何 I/O
  }

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

  @override
  void toggleViewMode() {
    state = state.copyWith(
      viewMode: state.viewMode == CollectionViewMode.grid
          ? CollectionViewMode.list
          : CollectionViewMode.grid,
    );
  }

  @override
  void setSortType(CollectionSortType type) {
    state = state.copyWith(sortType: type);
  }
}

/// 测试用 TagList — 不访问数据库
class TestTagList extends TagList {
  final TagState _initialState;

  TestTagList([this._initialState = const TagState()]);

  @override
  TagState build() => _initialState;

  @override
  Future<void> loadTags() async {
    // 测试中不做任何 I/O
  }

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

/// 测试用 ListeningPractice — 不访问音频引擎
class TestListeningPractice extends ListeningPractice {
  final ListeningPracticeState _initialState;

  TestListeningPractice([this._initialState = const ListeningPracticeState()]);

  @override
  ListeningPracticeState build() => _initialState;

  @override
  Future<void> loadAudio(AudioItem audioItem) async {
    // 测试中不做任何 I/O
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
  void suspendListeners() {
    // 测试中不做任何操作
  }

  @override
  void resumeListeners() {
    // 测试中不做任何操作
  }

  @override
  Future<void> syncBookmarks() async {
    // 测试中不做任何操作
  }
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
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
  );
}

/// 测试用 LearningProgressNotifier — 不访问数据库
class TestLearningProgressNotifier extends LearningProgressNotifier {
  final LearningProgressState _initialState;

  TestLearningProgressNotifier([
    this._initialState = const LearningProgressState(),
  ]);

  @override
  LearningProgressState build() => _initialState;

  @override
  Future<void> loadAll() async {
    // 测试中不做任何 I/O
  }

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
    // 测试中的简化实现
  }

  @override
  Future<LearningProgress?> getLatestByAudioId(String audioItemId) async {
    return state.progressMap[audioItemId];
  }

  @override
  Future<void> setDifficulty(
    String audioItemId,
    DifficultyLevel difficulty,
  ) async {
    // 测试中的简化实现
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
  Future<void> deleteProgress(String audioItemId) async {
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap.remove(audioItemId);
    state = state.copyWith(progressMap: newMap);
  }
}

/// 测试用 LearningSession — 不依赖音频引擎
class TestLearningSession extends LearningSession {
  final LearningSessionState _initialState;

  TestLearningSession([this._initialState = const LearningSessionState()]);

  @override
  LearningSessionState build() => _initialState;

  @override
  Future<void> enterBlindListenMode(
    String audioItemId, {
    bool isFreePlay = false,
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
  Future<void> replayBlindListen() async {
    state = state.copyWith(blindListenCompleted: false);
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
  Future<void> exitLearningMode() async {
    state = const LearningSessionState();
  }

  @override
  void addInputWords(int count) {
    // 测试中不访问 StudyStatsNotifier
  }

  @override
  void addOutputWords(int count) {
    // 测试中不访问 StudyStatsNotifier
  }

  @override
  void recordLearnedSentence(String text) {
    // 测试中不访问 LearnedVocabularyTracker
  }

  @override
  void recordLearnedSentences(Iterable<Sentence> sentences) {
    // 测试中不访问 LearnedVocabularyTracker
  }
}

/// 测试用 BlindListenPlayer — 不依赖音频引擎
class TestBlindListenPlayer extends BlindListenPlayer {
  final BlindListenPlayerState _initialState;

  TestBlindListenPlayer([this._initialState = const BlindListenPlayerState()]);

  @override
  BlindListenPlayerState build() => _initialState;

  @override
  void initialize(Duration totalDuration) {
    state = BlindListenPlayerState(totalDuration: totalDuration);
  }

  @override
  Future<void> play() async {
    state = state.copyWith(isPlaying: true, isCompleted: false);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration pos) async {
    state = state.copyWith(position: pos, isCompleted: false);
  }

  @override
  void onDragStart() {
    state = state.copyWith(isDragging: true);
  }

  @override
  void onDragUpdate(Duration pos) {
    state = state.copyWith(position: pos);
  }

  @override
  Future<void> onDragEnd(Duration pos) async {
    state = state.copyWith(isDragging: false, position: pos);
  }

  @override
  Future<void> resetAndPlay() async {
    state = state.copyWith(
      position: Duration.zero,
      isPlaying: true,
      isCompleted: false,
    );
  }

  @override
  void disposePlayer() {
    state = const BlindListenPlayerState();
  }
}

/// 测试用 IntensiveListenPlayer — 不依赖音频引擎
class TestIntensiveListenPlayer extends IntensiveListenPlayer {
  final IntensiveListenState _initialState;
  final List<Sentence> _testSentences;

  TestIntensiveListenPlayer([
    this._initialState = const IntensiveListenState(),
    this._testSentences = const [],
  ]);

  @override
  IntensiveListenState build() => _initialState;

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
    // 测试中模拟重播：设置 isPlaying 然后立即停止
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
  void disposePlayer() {
    state = const IntensiveListenState();
  }
}

/// 测试用 ListenAndRepeatPlayer — 不依赖音频引擎
class TestListenAndRepeatPlayer extends ListenAndRepeatPlayer {
  final ListenAndRepeatPlayerState _initialState;
  List<Sentence> _testSentences;

  TestListenAndRepeatPlayer([
    this._initialState = const ListenAndRepeatPlayerState(),
    this._testSentences = const [],
  ]);

  @override
  ListenAndRepeatPlayerState build() => _initialState;

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
    _testSentences = sentences.map((s) => s.copyWith()).toList();
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
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
      );
    }
  }

  @override
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex > 0) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex - 1,
        currentPlayCount: 1,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
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
  Future<void> completePausedTurn() async {
    if (state.isPauseBetweenSentences) {
      if (state.currentSentenceIndex >= state.totalSentences - 1) {
        state = state.copyWith(
          isCompleted: true,
          isPlaying: false,
          isPauseBetweenPlays: false,
          isPauseBetweenSentences: false,
        );
        return;
      }

      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
      );
      return;
    }

    state = state.copyWith(
      currentPlayCount: state.currentPlayCount + 1,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
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
        isCompleted: true,
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
}

/// 测试用 ReviewDifficultPractice — 不依赖音频引擎
class TestReviewDifficultPractice extends ReviewDifficultPractice {
  final ReviewDifficultPracticeState _initialState;
  List<Sentence> _testSentences;

  TestReviewDifficultPractice([
    this._initialState = const ReviewDifficultPracticeState(),
    this._testSentences = const [],
  ]);

  @override
  ReviewDifficultPracticeState build() => _initialState;

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
    _testSentences = sentences.map((s) => s.copyWith()).toList();
    final validIndex = _testSentences.isEmpty
        ? 0
        : startIndex.clamp(0, _testSentences.length - 1);
    state = ReviewDifficultPracticeState(
      currentSentenceIndex: validIndex,
      totalSentences: _testSentences.length,
    );
  }

  @override
  Future<void> startPlaying() async {
    if (_testSentences.isEmpty) {
      state = state.copyWith(isCompleted: true);
      return;
    }
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
  void updateSettings(DifficultPracticeSettings newSettings) {
    state = state.copyWith(settings: newSettings, isPlaying: false);
  }

  @override
  Sentence? removeDifficultMark() {
    if (_testSentences.isEmpty) return null;

    final removedIndex = state.currentSentenceIndex;
    final removed = _testSentences[removedIndex];
    _testSentences = List.from(_testSentences)..removeAt(removedIndex);

    if (_testSentences.isEmpty) {
      state = state.copyWith(
        isCompleted: true,
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
  Future<void> completePausedTurn() async {
    // 测试用：不执行实际逻辑
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
    _testSentences = [];
    state = const ReviewDifficultPracticeState();
  }
}

/// 测试用 DailyStudyTime — 不依赖 SharedPreferences
class TestDailyStudyTime extends DailyStudyTime {
  @override
  Future<int> build() async => 0;

  @override
  Future<void> refresh() async {}
}

/// 测试用 AudioEngine — 不依赖 just_audio
class TestAudioEngine extends AudioEngine {
  final AudioEngineState _initialState;
  bool _isPlaying;

  TestAudioEngine({
    AudioEngineState initialState = const AudioEngineState(),
    bool isPlaying = false,
  }) : _initialState = initialState,
       _isPlaying = isPlaying;

  @override
  AudioEngineState build() => _initialState;

  @override
  bool get isPlaying => _isPlaying;

  /// 测试中直接设置播放状态
  set isPlaying(bool value) => _isPlaying = value;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Stream<Duration> get absolutePositionStream => Stream.value(Duration.zero);

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  Future<void> play() async {
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
  }

  @override
  Future<void> seek(Duration pos) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  int newSession() => 0;

  @override
  bool isActiveSession(int id) => true;

  @override
  Future<void> clearClip() async {}
}

/// 测试用 TranscriptionTaskManager — 不执行真实转录
class TestTranscriptionTaskManager extends TranscriptionTaskManager {
  final Map<String, TranscriptionTaskState> _initialState;

  TestTranscriptionTaskManager([this._initialState = const {}]);

  @override
  Map<String, TranscriptionTaskState> build() => Map.of(_initialState);

  @override
  Future<void> startTranscription(AudioItem audioItem, String language) async {
    // 测试中不执行真实转录
  }

  @override
  void cancelTranscription(String audioId) {
    state = Map.of(state)..remove(audioId);
  }

  @override
  void clearState(String audioId) {
    state = Map.of(state)..remove(audioId);
  }
}

/// 测试用 RetellPlayer — 不依赖音频引擎
class TestRetellPlayer extends RetellPlayer {
  final RetellPlayerState _initialState;
  List<List<Sentence>> _testParagraphs;
  Map<int, Set<int>> _testKeywords;

  TestRetellPlayer([
    this._initialState = const RetellPlayerState(),
    this._testParagraphs = const [],
    this._testKeywords = const {},
  ]);

  @override
  RetellPlayerState build() => _initialState;

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
  int? get currentParagraphFirstSentenceIndex {
    final sentences = currentParagraphSentences;
    return sentences.isNotEmpty ? sentences.first.index : null;
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
    if (_testParagraphs.isEmpty) {
      state = state.copyWith(isCompleted: true);
      return;
    }
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
      state = state.copyWith(isCompleted: true, isPlaying: false);
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
    state = state.copyWith(settings: newSettings);
  }

  @override
  void regenerateKeywords() {}

  @override
  void disposePlayer() {
    _testParagraphs = [];
    _testKeywords = {};
    state = const RetellPlayerState();
  }
}

/// 测试用 SpeechPracticeSession — 不依赖平台通道
class TestSpeechPracticeSession extends SpeechPracticeSession {
  @override
  SpeechPracticeSessionState build() => const SpeechPracticeSessionState();

  @override
  Future<void> startRecording({required String promptId}) async {}

  @override
  Future<SpeechPracticeAttempt?> stopRecordingAndEvaluate({
    required String promptId,
    required String referenceText,
  }) async => null;

  @override
  Future<void> cancelActiveRecording() async {}

  @override
  Future<void> stopAttemptPlayback() async {}

  @override
  Future<void> playAttempt(String promptId) async {}

  @override
  Future<void> disposeSession() async {}

  @override
  bool isRecordingPrompt(String promptId) => false;

  @override
  SpeechPracticeAttempt? attemptFor(String promptId) => null;
}

/// 测试用 ListenAndRepeatTurnController — 不依赖平台通道
class TestListenAndRepeatTurnController extends ListenAndRepeatTurnController {
  /// 初始阶段（默认 idle）
  final ListenAndRepeatTurnPhase initialPhase;

  TestListenAndRepeatTurnController({
    this.initialPhase = ListenAndRepeatTurnPhase.idle,
  });

  @override
  ListenAndRepeatTurnState build() =>
      ListenAndRepeatTurnState(phase: initialPhase);

  @override
  void setOnContinue(Future<void> Function()? callback) {}

  @override
  Future<void> ensureTurn({
    required String promptId,
    required String referenceText,
    bool allowAutoFallback = true,
    Duration sentenceDuration = Duration.zero,
  }) async {}

  @override
  Future<void> ensureAutoTurn({
    required String promptId,
    required String referenceText,
    Duration sentenceDuration = Duration.zero,
  }) async {}

  @override
  Future<void> startManualRecording({
    required String promptId,
    required String referenceText,
    Duration sentenceDuration = Duration.zero,
  }) async {}

  @override
  void clearTurn() {
    state = const ListenAndRepeatTurnState();
  }

  @override
  Future<void> handleManualStop() async {}

  @override
  Future<void> handleContinue() async {}

  @override
  void pauseReviewCountdown() {}

  @override
  void resumeReviewCountdown() {}

  @override
  void fastForwardReviewCountdown() {}

  @override
  void resetReviewCountdownOnPlayback() {}

  @override
  void activateReviewCountdown({required String promptId}) {}

  @override
  void enterProcessing(String promptId) {}
}

/// 测试用 TranscriptionApiClient Provider 值
TranscriptionApiClient createTestTranscriptionApiClient() {
  return TranscriptionApiClient(baseUrl: 'https://test.local');
}
