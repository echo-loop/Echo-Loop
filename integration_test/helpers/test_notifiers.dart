/// 集成测试专用 Notifier 替身和 App 工厂
///
/// 提供所有 Provider 的测试实现，以及 [createTestApp] / [createTestAppWithAudio] 工厂函数。
/// 各测试 group 文件共享此模块，避免重复定义。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fluency/main.dart';
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/models/collection.dart';
import 'package:fluency/models/tag.dart';
import 'package:fluency/models/audio_engine_state.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/models/playback_settings.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/database/enums.dart';
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
import 'package:fluency/providers/package_info_provider.dart';

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
      items[index] = items[index].copyWith(
        isStarred: !items[index].isStarred,
      );
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
        firstLearnCompletedAt:
            stage == LearningStage.firstLearn ? now : progress.firstLearnCompletedAt,
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
  void toggleTextReveal() {
    state = state.copyWith(isTextRevealed: !state.isTextRevealed);
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

/// 测试用 BookmarkDao — 所有方法 no-op
///
/// 精听播放器退出时会通过 BookmarkDao 保存难句书签，
/// 集成测试中不需要真实数据库操作。
class TestBookmarkDao implements BookmarkDao {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ========== App 工厂 ==========

final _testPackageInfo = PackageInfo(
  appName: 'Fluency',
  packageName: 'top.valuespot.fluency',
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
      bookmarkDaoProvider.overrideWithValue(TestBookmarkDao()),
      packageInfoProvider.overrideWithValue(_testPackageInfo),
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
}) {
  final audioItem = createTestAudioItem();
  final collection = createTestCollection();
  final sentences = createTestSentences();
  final progress = progressOverride ?? createTestLearningProgress(
    currentStageStartedAt: DateTime.now(),
  );

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
      bookmarkDaoProvider.overrideWithValue(TestBookmarkDao()),
      packageInfoProvider.overrideWithValue(_testPackageInfo),
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
      audioIdsMap: {widget.collection.id: [widget.audioItem.id]},
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

