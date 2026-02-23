/// Mock Provider 集合
///
/// 用 Riverpod overrideWith 模式创建测试用 Notifier，
/// 避免真实 I/O（SharedPreferences、文件系统、just_audio）。
library;

import 'package:flutter/material.dart';
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/models/collection.dart';
import 'package:fluency/models/tag.dart';
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
import 'package:fluency/database/enums.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/models/sentence.dart';

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
      items[index] = items[index].copyWith(
        isStarred: !items[index].isStarred,
      );
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
    final currentTags =
        state.audioToTagsMap[audioId]?.toSet() ?? <String>{};
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
  Future<void> exitLearningMode() async {
    state = const LearningSessionState();
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
    // 测试中模拟重播：设置 isPlaying 然后立即停止
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
  void toggleTextReveal() {
    state = state.copyWith(isTextRevealed: !state.isTextRevealed);
  }

  @override
  void disposePlayer() {
    state = const IntensiveListenState();
  }
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

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Stream<Duration> get absolutePositionStream => Stream.value(Duration.zero);

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
}
