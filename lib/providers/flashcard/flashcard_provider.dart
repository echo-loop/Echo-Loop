/// Flashcard 状态管理 Provider
///
/// 管理单词卡片复习的完整生命周期：卡片列表、翻转、切换、
/// 倒计时、练习统计记录。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/app_database.dart';
import '../../database/providers.dart';
import '../../models/dict_entry.dart';
import '../../models/flashcard_settings.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../services/dictionary_service.dart';
import '../../models/study_stage.dart';
import '../../services/study_time_service.dart';
import '../../services/tts_service.dart';
import '../daily_study_time_provider.dart';
import '../learning_session/countdown_controller.dart';
import '../study_stats_provider.dart';

part 'flashcard_provider.g.dart';

/// 单张卡片数据（含词典释义）
class FlashcardWordItem {
  /// 收藏单词数据
  final SavedWord savedWord;

  /// 词典条目（懒加载）
  final DictEntry? dictEntry;

  /// 词典是否已加载
  final bool dictLoaded;

  const FlashcardWordItem({
    required this.savedWord,
    this.dictEntry,
    this.dictLoaded = false,
  });

  FlashcardWordItem copyWith({
    SavedWord? savedWord,
    DictEntry? dictEntry,
    bool? dictLoaded,
  }) {
    return FlashcardWordItem(
      savedWord: savedWord ?? this.savedWord,
      dictEntry: dictEntry ?? this.dictEntry,
      dictLoaded: dictLoaded ?? this.dictLoaded,
    );
  }
}

/// Flashcard 完整状态
class FlashcardState {
  /// 卡片列表
  final List<FlashcardWordItem> words;

  /// 当前卡片索引
  final int currentIndex;

  /// 是否正在显示背面
  final bool isShowingBack;

  /// 设置
  final FlashcardSettings settings;

  /// 倒计时剩余时间
  final Duration countdownRemaining;

  /// 倒计时总时长
  final Duration countdownTotal;

  /// 是否全部完成
  final bool isCompleted;

  /// 本轮取消收藏数
  final int removedCount;

  /// 当前卡片开始查看时间（用于计算学习时长）
  final DateTime? cardStartTime;

  /// 倒计时是否暂停
  final bool isPaused;

  const FlashcardState({
    this.words = const [],
    this.currentIndex = 0,
    this.isShowingBack = false,
    this.settings = const FlashcardSettings(),
    this.countdownRemaining = Duration.zero,
    this.countdownTotal = Duration.zero,
    this.isCompleted = false,
    this.removedCount = 0,
    this.cardStartTime,
    this.isPaused = false,
  });

  /// 当前卡片
  FlashcardWordItem? get currentWord =>
      words.isNotEmpty && currentIndex < words.length
      ? words[currentIndex]
      : null;

  /// 总卡片数（含已移除的）
  int get totalWordsReviewed => currentIndex + 1;

  FlashcardState copyWith({
    List<FlashcardWordItem>? words,
    int? currentIndex,
    bool? isShowingBack,
    FlashcardSettings? settings,
    Duration? countdownRemaining,
    Duration? countdownTotal,
    bool? isCompleted,
    int? removedCount,
    DateTime? cardStartTime,
    bool clearCardStartTime = false,
    bool? isPaused,
  }) {
    return FlashcardState(
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      isShowingBack: isShowingBack ?? this.isShowingBack,
      settings: settings ?? this.settings,
      countdownRemaining: countdownRemaining ?? this.countdownRemaining,
      countdownTotal: countdownTotal ?? this.countdownTotal,
      isCompleted: isCompleted ?? this.isCompleted,
      removedCount: removedCount ?? this.removedCount,
      cardStartTime: clearCardStartTime
          ? null
          : (cardStartTime ?? this.cardStartTime),
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

/// SharedPreferences key
const _settingsKey = 'flashcard_settings';

/// Flashcard 主 Provider
@Riverpod(keepAlive: true)
class FlashcardNotifier extends _$FlashcardNotifier {
  final CountdownController _countdown = CountdownController();

  /// 学习时长存储服务
  late final StudyTimeService _studyTimeService;

  /// 学习计时器
  final Stopwatch _studyStopwatch = Stopwatch();

  /// 输入时间计时器（TTS + 音频播放期间运行）
  final Stopwatch _inputStopwatch = Stopwatch();

  /// 音频播放状态监听（用于输入时间追踪）
  StreamSubscription<ja.PlayerState>? _inputTimePlayerStateSub;

  @override
  FlashcardState build() {
    _studyTimeService = ref.read(studyTimeServiceProvider);
    ref.onDispose(() {
      _countdown.cancel();
      _inputTimePlayerStateSub?.cancel();
      _saveAndRefreshStudyTime();
    });
    return const FlashcardState();
  }

  /// 初始化 Flashcard 会话
  ///
  /// [words] 收藏单词列表快照
  Future<void> initialize(List<SavedWord> words) async {
    _countdown.cancel();

    // 加载持久化设置
    final settings = await _loadSettings();

    // 排序
    final sorted = _sortWords(words, settings.sortMode);

    // 构建卡片列表
    final items = sorted.map((w) => FlashcardWordItem(savedWord: w)).toList();

    state = FlashcardState(
      words: items,
      currentIndex: 0,
      settings: settings,
      cardStartTime: DateTime.now(),
    );

    // 启动学习计时
    _studyStopwatch.reset();
    _studyStopwatch.start();

    // 启动输入时间追踪（例句音频播放）
    _startInputTimeTracking();

    if (items.isNotEmpty) {
      // 预加载词典（当前 + 前后 2 张）
      _preloadDictionaries();
      // 自动 TTS 播放
      _speakCurrentWord();
      // 启动倒计时
      _startCountdown();
    }
  }

  /// 翻转卡片
  ///
  /// 先同步更新状态让翻转动画立即开始，再异步停止旧播放。
  void flipCard() {
    if (state.isCompleted || state.words.isEmpty) return;

    final wasShowingBack = state.isShowingBack;
    // 先更新状态 → 翻转动画立即启动
    state = state.copyWith(isShowingBack: !wasShowingBack);

    if (!wasShowingBack) {
      // 翻到背面：记录练习统计
      // 输入词数由 _BackContent 在 TTS/例句播放完成后计入
      _recordPracticeStats();

      // 有自动播放时，隐藏倒计时，等播放完成后再显示（由 onAutoPlayCompleted 触发）
      final hasAutoPlay =
          state.settings.autoPlayWord ||
          (state.settings.autoPlaySentence &&
              state.currentWord?.savedWord.sentenceText != null);
      if (hasAutoPlay) {
        _countdown.cancel();
        state = state.copyWith(
          countdownRemaining: Duration.zero,
          countdownTotal: Duration.zero,
        );
      } else {
        _startCountdown();
      }
    } else {
      // 翻回正面：朗读单词
      _startCountdown();
    }

    // 异步停止旧播放（翻回正面时同时朗读新单词）
    Future.microtask(() {
      _stopAllPlayback();
      if (wasShowingBack) _speakCurrentWord();
    });
  }

  /// 下一张卡片
  ///
  /// 先同步更新状态让 UI 立即刷新，再异步停止旧播放 + 朗读新单词，
  /// 避免平台通道调用（TTS stop / audio stop）阻塞当前帧渲染。
  void nextCard() {
    if (state.isCompleted || state.words.isEmpty) return;

    if (state.currentIndex >= state.words.length - 1) {
      // 最后一张 → 完成
      _stopAllPlayback();
      _countdown.cancel();
      _saveStudyTime();
      state = state.copyWith(isCompleted: true);
      return;
    }

    // 1. 同步更新状态 → UI 立即刷新
    _countdown.cancel();
    _saveStudyTime();
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      isShowingBack: false,
      cardStartTime: DateTime.now(),
    );
    _startCountdown();
    _preloadDictionaries();

    // 2. 异步停止旧播放 + 朗读新单词（不阻塞帧渲染）
    Future.microtask(() {
      _stopAllPlayback();
      _speakCurrentWord();
    });
  }

  /// 上一张卡片
  ///
  /// 先同步更新状态让 UI 立即刷新，再异步停止旧播放 + 朗读新单词。
  void previousCard() {
    if (state.currentIndex <= 0) return;

    // 1. 同步更新状态 → UI 立即刷新
    _countdown.cancel();
    _saveStudyTime();
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      isShowingBack: false,
      cardStartTime: DateTime.now(),
    );
    _startCountdown();
    _preloadDictionaries();

    // 2. 异步停止旧播放 + 朗读新单词（不阻塞帧渲染）
    Future.microtask(() {
      _stopAllPlayback();
      _speakCurrentWord();
    });
  }

  /// 取消收藏当前单词
  Future<void> unsaveCurrentWord() async {
    if (state.words.isEmpty) return;

    _stopAllPlayback();
    final word = state.words[state.currentIndex];
    _countdown.cancel();

    // 从 DAO 中删除
    final dao = ref.read(savedWordDaoProvider);
    await dao.removeWord(word.savedWord.word);

    // 从列表中移除
    final newWords = List<FlashcardWordItem>.from(state.words)
      ..removeAt(state.currentIndex);

    if (newWords.isEmpty) {
      state = state.copyWith(
        words: newWords,
        isCompleted: true,
        removedCount: state.removedCount + 1,
      );
      return;
    }

    final newIndex = state.currentIndex >= newWords.length
        ? newWords.length - 1
        : state.currentIndex;

    state = state.copyWith(
      words: newWords,
      currentIndex: newIndex,
      isShowingBack: false,
      removedCount: state.removedCount + 1,
      cardStartTime: DateTime.now(),
    );

    _preloadDictionaries();
    _speakCurrentWord();
    _startCountdown();
  }

  /// 更新设置并持久化
  Future<void> updateSettings(FlashcardSettings newSettings) async {
    _countdown.cancel();

    // 如果排序方式变了，重新排序
    if (newSettings.sortMode != state.settings.sortMode) {
      final savedWords = state.words.map((w) => w.savedWord).toList();
      final sorted = _sortWords(savedWords, newSettings.sortMode);
      final items = sorted.map((w) => FlashcardWordItem(savedWord: w)).toList();

      state = state.copyWith(
        settings: newSettings,
        words: items,
        currentIndex: 0,
        isShowingBack: false,
        cardStartTime: DateTime.now(),
      );

      _preloadDictionaries();
      _speakCurrentWord();
    } else {
      state = state.copyWith(settings: newSettings);
    }

    _startCountdown();

    // 持久化设置
    await _saveSettings(newSettings);
  }

  /// 单词 TTS 播放完成后计入 1 个输入词
  ///
  /// 由 _BackContent widget 在 TTS 朗读结束后调用。
  Future<void> onWordPlayed() => _addInputWords(1);

  /// 例句播放完成后计入输入词数
  ///
  /// 由 _BackContent widget 在例句音频播放结束后调用。
  Future<void> onSentencePlayed(String sentenceText) {
    final wordCount = sentenceText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return _addInputWords(wordCount);
  }

  /// 背面自动播放完成后启动倒计时
  ///
  /// 由 _BackContent widget 在 TTS + 例句全部播完后调用。
  void onAutoPlayCompleted() {
    if (state.isShowingBack && !state.isCompleted) {
      _startCountdown();
    }
  }

  /// 手动点击例句开始播放时隐藏倒计时
  void onSentencePlaybackStarted() {
    _countdown.cancel();
    state = state.copyWith(
      countdownRemaining: Duration.zero,
      countdownTotal: Duration.zero,
      isPaused: false,
    );
  }

  /// 手动例句播放结束后重新启动倒计时
  void onSentencePlaybackEnded() {
    if (state.isShowingBack && !state.isCompleted) {
      _startCountdown();
    }
  }

  /// TTS 朗读当前单词
  void speakCurrentWord() {
    _speakCurrentWord();
  }

  /// 暂停（AppLifecycle / 弹窗时调用）
  void pause() {
    _countdown.pause();
    _studyStopwatch.stop();
    state = state.copyWith(isPaused: true);
  }

  /// 恢复
  void resume() {
    if (state.isCompleted) return;
    _studyStopwatch.start();
    state = state.copyWith(isPaused: false);
    _countdown.resume();
  }

  /// 切换暂停/恢复
  void togglePause() {
    if (state.isPaused) {
      resume();
    } else {
      pause();
    }
  }

  /// 重新开始（再来一遍）
  Future<void> reset() async {
    _countdown.cancel();
    // 先保存已累计时间
    await _saveAndRefreshStudyTime();
    final savedWords = state.words.map((w) => w.savedWord).toList();
    await initialize(savedWords);
  }

  /// 释放资源
  Future<void> disposePlayer() async {
    _inputTimePlayerStateSub?.cancel();
    _inputTimePlayerStateSub = null;
    await _saveAndRefreshStudyTime();
    _countdown.cancel();
    _stopAllPlayback();
    state = const FlashcardState();
  }

  // ========== 内部方法 ==========

  /// 启动倒计时
  void _startCountdown() {
    _countdown.cancel();

    if (state.settings.isManualMode) {
      state = state.copyWith(
        countdownRemaining: Duration.zero,
        countdownTotal: Duration.zero,
        isPaused: false,
      );
      return;
    }

    final seconds = _getTimerSeconds();
    final total = Duration(seconds: seconds);
    state = state.copyWith(
      countdownRemaining: total,
      countdownTotal: total,
      isPaused: false,
    );

    _countdown.start(total, (remaining) {
      state = state.copyWith(countdownRemaining: remaining);
      if (remaining <= Duration.zero) {
        // 延迟到微任务执行，避免在 _tick() 内部重入导致新 onTick 被清空
        Future.microtask(_onCountdownExpired);
      }
    });
  }

  /// 获取当前倒计时秒数（根据正面/背面返回不同值）
  int _getTimerSeconds() {
    switch (state.settings.timerMode) {
      case FlashcardTimerMode.fixed:
        return state.isShowingBack
            ? state.settings.fixedTimerBackSeconds
            : state.settings.fixedTimerSeconds;
      case FlashcardTimerMode.smart:
        final word = state.currentWord?.savedWord;
        if (word == null) return 8;
        return FlashcardSettings.calculateSmartSeconds(
          wordLength: word.word.length,
          practiceCount: word.practiceCount,
        );
    }
  }

  /// 倒计时到期回调
  void _onCountdownExpired() {
    if (state.isShowingBack) {
      // 背面到期 → 自动下一张
      nextCard();
    } else {
      // 正面到期 → 自动翻转到背面
      flipCard();
    }
  }

  /// 停止所有播放（TTS + 音频引擎）
  void _stopAllPlayback() {
    TtsService.instance.stop();
    ref.read(audioEngineProvider.notifier).stop();
  }

  /// 开始监听 AudioEngine playerState，追踪输入时间（例句音频播放）
  void _startInputTimeTracking() {
    _inputTimePlayerStateSub?.cancel();
    final engine = ref.read(audioEngineProvider.notifier);
    _inputTimePlayerStateSub = engine.playerStateStream.listen((playerState) {
      if (playerState.playing) {
        if (!_inputStopwatch.isRunning) _inputStopwatch.start();
      } else {
        _inputStopwatch.stop();
      }
    });
  }

  /// TTS 朗读当前单词（受 autoPlayWord 设置控制）
  ///
  /// TTS 朗读期间计入输入时间。
  Future<void> _speakCurrentWord() async {
    if (!state.settings.autoPlayWord) return;
    final word = state.currentWord?.savedWord.word;
    if (word != null) {
      if (!_inputStopwatch.isRunning) _inputStopwatch.start();
      await TtsService.instance.speak(word);
      _inputStopwatch.stop();
      await _addInputWords(1);
    }
  }

  /// 预加载词典（当前 + 前后各 2 张）
  void _preloadDictionaries() {
    final start = (state.currentIndex - 2).clamp(0, state.words.length - 1);
    final end = (state.currentIndex + 2).clamp(0, state.words.length - 1);

    for (var i = start; i <= end; i++) {
      if (!state.words[i].dictLoaded) {
        _loadDictionary(i);
      }
    }
  }

  /// 加载单个词典条目
  Future<void> _loadDictionary(int index) async {
    if (index < 0 || index >= state.words.length) return;
    if (state.words[index].dictLoaded) return;

    final word = state.words[index].savedWord.word;
    final entry = await DictionaryService.instance.lookup(word);

    // 检查 state 是否仍然有效
    if (index >= state.words.length) return;
    if (state.words[index].savedWord.word != word) return;

    final newWords = List<FlashcardWordItem>.from(state.words);
    newWords[index] = newWords[index].copyWith(
      dictEntry: entry,
      dictLoaded: true,
    );
    state = state.copyWith(words: newWords);
  }

  /// 记录练习统计（翻到背面时）
  Future<void> _recordPracticeStats() async {
    final word = state.currentWord?.savedWord;
    if (word == null) return;

    final now = DateTime.now();
    final cardStart = state.cardStartTime ?? now;
    final studyMs = now.difference(cardStart).inMilliseconds;

    final dao = ref.read(savedWordDaoProvider);
    await dao.updatePracticeStats(word: word.word, studyMs: studyMs);
  }

  /// 保存当前卡片的学习时间（切换卡片时调用）
  void _saveStudyTime() {
    // 学习时长已在 _recordPracticeStats 中记录（翻到背面时）
    // 这里只需重置 cardStartTime
  }

  /// 排序单词列表
  List<SavedWord> _sortWords(List<SavedWord> words, FlashcardSortMode mode) {
    final sorted = List<SavedWord>.from(words);
    switch (mode) {
      case FlashcardSortMode.alphabeticalAsc:
        sorted.sort(
          (a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()),
        );
      case FlashcardSortMode.alphabeticalDesc:
        sorted.sort(
          (a, b) => b.word.toLowerCase().compareTo(a.word.toLowerCase()),
        );
      case FlashcardSortMode.timeAsc:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case FlashcardSortMode.timeDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case FlashcardSortMode.random:
        sorted.shuffle();
      case FlashcardSortMode.smart:
        sorted.sort((a, b) {
          final scoreA = FlashcardSettings.calculateSmartScore(
            practiceCount: a.practiceCount,
            viewedBack: a.viewedBack,
            lastPracticedAt: a.lastPracticedAt,
          );
          final scoreB = FlashcardSettings.calculateSmartScore(
            practiceCount: b.practiceCount,
            viewedBack: b.viewedBack,
            lastPracticedAt: b.lastPracticedAt,
          );
          return scoreB.compareTo(scoreA); // 分数高的在前
        });
    }
    return sorted;
  }

  /// 加载持久化设置
  Future<FlashcardSettings> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_settingsKey);
      if (jsonStr != null) {
        return FlashcardSettings.fromJson(
          json.decode(jsonStr) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('Flashcard: 加载设置失败: $e');
    }
    return const FlashcardSettings();
  }

  /// 持久化设置
  Future<void> _saveSettings(FlashcardSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, json.encode(settings.toJson()));
    } catch (e) {
      debugPrint('Flashcard: 保存设置失败: $e');
    }
  }

  /// 停止计时并保存已记录的学习时长 + 输入时间，刷新统计 UI
  Future<void> _saveAndRefreshStudyTime() async {
    const stage = StudyStage.flashcard;
    // 保存输入时间
    _inputStopwatch.stop();
    final inputSecs = _inputStopwatch.elapsed.inSeconds;
    _inputStopwatch.reset();
    if (inputSecs > 0) {
      await _studyTimeService.addInputTime(inputSecs, stage: stage);
    }

    if (!_studyStopwatch.isRunning &&
        _studyStopwatch.elapsed == Duration.zero) {
      if (inputSecs > 0) {
        ref.read(dailyStudyTimeProvider.notifier).refresh();
        ref.read(studyStatsNotifierProvider.notifier).refresh();
      }
      return;
    }
    _studyStopwatch.stop();
    final seconds = _studyStopwatch.elapsed.inSeconds;
    _studyStopwatch.reset();
    if (seconds > 0) {
      await _studyTimeService.addStudyTime(seconds, stage: stage);
    }
    ref.read(dailyStudyTimeProvider.notifier).refresh();
    ref.read(studyStatsNotifierProvider.notifier).refresh();
  }

  /// 累加输入词数并刷新统计 UI
  Future<void> _addInputWords(int count) async {
    if (count > 0) {
      await _studyTimeService.addInputWords(count);
      ref.read(studyStatsNotifierProvider.notifier).refresh();
    }
  }

}
