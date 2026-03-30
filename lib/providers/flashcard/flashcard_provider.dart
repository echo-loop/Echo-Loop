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

import '../../database/providers.dart';
import '../../models/flashcard_item.dart';
import '../../models/flashcard_settings.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../services/app_logger.dart';
import '../../services/dictionary_service.dart';
import '../../models/study_stage.dart';
import '../../services/study_time_service.dart';
import '../../services/tts_service.dart';
import '../daily_study_time_provider.dart';
import '../learning_session/countdown_controller.dart';

part 'flashcard_provider.g.dart';

// FlashcardItem 定义在 models/flashcard_item.dart

/// Flashcard 完整状态
class FlashcardState {
  /// 卡片列表
  final List<FlashcardItem> words;

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
  FlashcardItem? get currentWord =>
      words.isNotEmpty && currentIndex < words.length
      ? words[currentIndex]
      : null;

  /// 总卡片数（含已移除的）
  int get totalWordsReviewed => currentIndex + 1;

  FlashcardState copyWith({
    List<FlashcardItem>? words,
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

  /// 本轮已取消收藏的单词（用于 toggle 和防重复）
  final Set<String> _unsavedWords = {};

  /// 当前单词是否已取消收藏
  bool get isCurrentWordUnsaved {
    final key = state.currentWord?.dbKey;
    return key != null && _unsavedWords.contains(key);
  }

  /// 学习时长存储服务
  late StudyTimeService _studyTimeService;

  /// 学习计时器
  final Stopwatch _studyStopwatch = Stopwatch();

  /// 输入时间计时器（TTS + 音频播放期间运行）
  final Stopwatch _inputStopwatch = Stopwatch();

  /// 音频播放状态监听（用于输入时间追踪）
  StreamSubscription<ja.PlayerState>? _inputTimePlayerStateSub;

  /// TTS 代次计数器，切卡时递增，用于取消过期的 _speakCurrentWord
  int _speakGeneration = 0;

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
  /// [items] 闪卡项列表（单词 + 意群）
  Future<void> initialize(List<FlashcardItem> items) async {
    final sw = Stopwatch()..start();
    _countdown.cancel();

    // 加载持久化设置
    final settings = await _loadSettings();
    debugPrint('[PERF] flashcard _loadSettings: ${sw.elapsedMilliseconds}ms');

    // 排序
    final sorted = _sortItems(items, settings.sortMode);
    debugPrint('[PERF] flashcard _sortItems: ${sw.elapsedMilliseconds}ms');

    // 批量加载词典（仅对有 displayText 的项查询）
    final allTexts = sorted.map((w) => w.displayText).toList();
    final allEntries = await DictionaryService.instance.lookupAll(allTexts);
    debugPrint(
      '[PERF] flashcard lookupAll (${allTexts.length} words): ${sw.elapsedMilliseconds}ms',
    );
    final withDict = sorted
        .map((item) => item.withDictEntry(allEntries[item.displayText]))
        .toList();
    debugPrint(
      '[PERF] flashcard withDictEntry 映射: ${sw.elapsedMilliseconds}ms',
    );

    state = FlashcardState(
      words: withDict,
      currentIndex: 0,
      settings: settings,
      cardStartTime: DateTime.now(),
    );
    debugPrint('[PERF] flashcard state 赋值: ${sw.elapsedMilliseconds}ms');

    // 启动学习计时
    _studyStopwatch.reset();
    _studyStopwatch.start();

    // 启动输入时间追踪（例句音频播放）
    _startInputTimeTracking();

    _userPaused = false;
    if (items.isNotEmpty) {
      // 自动 TTS 播放（播完后内部会启动倒计时）
      _speakCurrentWord();
      // 仅在不自动播放时立即启动倒计时
      if (!state.settings.autoPlayWord) {
        _startCountdown();
      }
    }
    debugPrint('[PERF] flashcard initialize 总计: ${sw.elapsedMilliseconds}ms');
  }

  /// 翻转卡片
  ///
  /// 先同步更新状态让翻转动画立即开始，再异步停止旧播放。
  void flipCard() {
    if (state.isCompleted || state.words.isEmpty) return;

    _speakGeneration++;
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
              state.currentWord?.sentenceText != null);
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
      // 翻回正面：autoPlayWord 时隐藏倒计时，等 TTS 播完再启动
      if (state.settings.autoPlayWord) {
        _countdown.cancel();
        state = state.copyWith(
          countdownRemaining: Duration.zero,
          countdownTotal: Duration.zero,
        );
      } else {
        _startCountdown();
      }
    }

    // 异步停止旧播放（翻回正面时同时朗读新单词）
    Future.microtask(() async {
      await _stopAllPlayback();
      if (wasShowingBack) _speakCurrentWord();
    });
  }

  /// 下一张卡片
  ///
  /// 先同步更新状态让 UI 立即刷新，再异步停止旧播放 + 朗读新单词，
  /// 避免平台通道调用（TTS stop / audio stop）阻塞当前帧渲染。
  void nextCard() {
    final sw = Stopwatch()..start();
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
    _speakGeneration++;
    _countdown.cancel();
    _saveStudyTime();
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      isShowingBack: false,
      cardStartTime: DateTime.now(),
      countdownRemaining: Duration.zero,
      countdownTotal: Duration.zero,
    );
    // autoPlayWord 时先不启动倒计时，等 TTS 播完后再启动
    if (!state.settings.autoPlayWord) {
      _startCountdown();
    }
    AppLogger.log('Flashcard', 'nextCard: sync=${sw.elapsedMilliseconds}ms');

    // 2. 异步停止旧播放 + 朗读新单词（不阻塞帧渲染）
    Future.microtask(() async {
      await _stopAllPlayback();
      _speakCurrentWord();
    });
  }

  /// 上一张卡片
  ///
  /// 先同步更新状态让 UI 立即刷新，再异步停止旧播放 + 朗读新单词。
  void previousCard() {
    final sw = Stopwatch()..start();
    if (state.currentIndex <= 0) return;

    // 1. 同步更新状态 → UI 立即刷新
    _speakGeneration++;
    _countdown.cancel();
    _saveStudyTime();
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      isShowingBack: false,
      cardStartTime: DateTime.now(),
      countdownRemaining: Duration.zero,
      countdownTotal: Duration.zero,
    );
    if (!state.settings.autoPlayWord) {
      _startCountdown();
    }
    AppLogger.log('Flashcard', 'prevCard: sync=${sw.elapsedMilliseconds}ms');

    // 2. 异步停止旧播放 + 朗读新单词（不阻塞帧渲染）
    Future.microtask(() async {
      await _stopAllPlayback();
      _speakCurrentWord();
    });
  }

  /// 切换当前卡片的收藏状态
  ///
  /// 仅写 DB（软删除/恢复），不从列表移除卡片，保持正常复习流程。
  /// 退出复习后自然从收藏列表消失。
  Future<void> toggleCurrentWordSave() async {
    if (state.words.isEmpty) return;

    final item = state.words[state.currentIndex];
    final key = item.dbKey;
    final wasUnsaved = _unsavedWords.contains(key);

    if (wasUnsaved) {
      // 恢复收藏
      switch (item) {
        case FlashcardWordItem(:final savedWord):
          await ref
              .read(savedWordDaoProvider)
              .saveWord(
                word: savedWord.word,
                audioItemId: savedWord.audioItemId,
                sentenceIndex: savedWord.sentenceIndex,
                sentenceText: savedWord.sentenceText,
                sentenceStartMs: savedWord.sentenceStartMs,
                sentenceEndMs: savedWord.sentenceEndMs,
              );
        case FlashcardPhraseItem(:final savedPhrase):
          await ref
              .read(savedSenseGroupDaoProvider)
              .saveSenseGroup(
                phraseText: savedPhrase.phraseText,
                displayText: savedPhrase.displayText,
                audioItemId: savedPhrase.audioItemId,
                sentenceIndex: savedPhrase.sentenceIndex,
                sentenceText: savedPhrase.sentenceText,
                sentenceStartMs: savedPhrase.sentenceStartMs,
                sentenceEndMs: savedPhrase.sentenceEndMs,
                groupStartMs: savedPhrase.groupStartMs,
                groupEndMs: savedPhrase.groupEndMs,
              );
      }
      _unsavedWords.remove(key);
      state = state.copyWith(removedCount: state.removedCount - 1);
    } else {
      // 取消收藏
      switch (item) {
        case FlashcardWordItem():
          await ref.read(savedWordDaoProvider).removeWord(key);
        case FlashcardPhraseItem():
          await ref.read(savedSenseGroupDaoProvider).removeSenseGroup(key);
      }
      _unsavedWords.add(key);
      state = state.copyWith(removedCount: state.removedCount + 1);
    }
  }

  /// 更新设置并持久化
  Future<void> updateSettings(FlashcardSettings newSettings) async {
    _countdown.cancel();

    // 如果排序方式变了，重新排序（保留已加载的词典数据）
    if (newSettings.sortMode != state.settings.sortMode) {
      final sorted = _sortItems(state.words, newSettings.sortMode);

      state = state.copyWith(
        settings: newSettings,
        words: sorted,
        currentIndex: 0,
        isShowingBack: false,
        cardStartTime: DateTime.now(),
      );

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
  ///
  /// 暂停状态下不改变倒计时显示，保持暂停。
  void onSentencePlaybackStarted() {
    if (state.isPaused) return;
    _countdown.cancel();
    state = state.copyWith(
      countdownRemaining: Duration.zero,
      countdownTotal: Duration.zero,
    );
  }

  /// 手动例句播放结束后重新启动倒计时
  ///
  /// 暂停状态下不重启倒计时。
  void onSentencePlaybackEnded() {
    if (state.isPaused) return;
    if (state.isShowingBack && !state.isCompleted) {
      _startCountdown();
    }
  }

  /// TTS 朗读当前单词
  void speakCurrentWord() {
    _speakCurrentWord();
  }

  /// 用户在正面手动点击发音按钮。
  ///
  /// 暂停状态下只播放，不改变倒计时；非暂停状态下隐藏倒计时，播完后重启。
  Future<void> speakWordAndRestartCountdown() async {
    final wasPaused = state.isPaused;
    if (!wasPaused) {
      _countdown.cancel();
      state = state.copyWith(
        countdownRemaining: Duration.zero,
        countdownTotal: Duration.zero,
      );
    }
    final word = state.currentWord?.displayText;
    if (word != null) {
      await TtsService.instance.speak(word);
    }
    // 暂停状态下不重启倒计时；非暂停状态下播完后重启
    if (!wasPaused && state.currentWord?.displayText == word) {
      _startCountdown();
    }
  }

  /// 用户是否手动暂停（区分用户暂停和系统生命周期暂停）
  bool _userPaused = false;

  /// 暂停（AppLifecycle / 弹窗时调用）
  void pause() {
    _countdown.pause();
    _studyStopwatch.stop();
    state = state.copyWith(isPaused: true);
  }

  /// 恢复（仅在非用户手动暂停时恢复）
  void resume() {
    if (state.isCompleted || _userPaused) return;
    _studyStopwatch.start();
    state = state.copyWith(isPaused: false);
    _countdown.resume();
  }

  /// 切换暂停/恢复（用户手动操作）
  void togglePause() {
    if (state.isPaused) {
      _userPaused = false;
      _studyStopwatch.start();
      state = state.copyWith(isPaused: false);
      _countdown.resume();
    } else {
      _userPaused = true;
      pause();
    }
  }

  /// 重新开始（再来一遍）
  Future<void> reset() async {
    _countdown.cancel();
    // 先保存已累计时间
    await _saveAndRefreshStudyTime();
    await initialize(state.words);
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
      );
      return;
    }

    final seconds = _getTimerSeconds();
    final total = Duration(seconds: seconds);
    state = state.copyWith(countdownRemaining: total, countdownTotal: total);

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
        final item = state.currentWord;
        if (item == null) return 8;
        return FlashcardSettings.calculateSmartSeconds(
          wordLength: item.displayText.length,
          practiceCount: item.practiceCount,
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
  Future<void> _stopAllPlayback() async {
    await TtsService.instance.stop();
    await ref.read(audioEngineProvider.notifier).stop();
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
  /// 使用 _speakGeneration 防止快速切卡时旧的 TTS 回调继续执行。
  Future<void> _speakCurrentWord() async {
    if (!state.settings.autoPlayWord) return;
    final word = state.currentWord?.displayText;
    if (word != null) {
      final gen = _speakGeneration;
      if (!_inputStopwatch.isRunning) _inputStopwatch.start();
      await TtsService.instance.speak(word);
      // TTS 完成后检查是否已切卡，过期则跳过后续操作
      if (gen != _speakGeneration) return;
      _inputStopwatch.stop();
      await _addInputWords(1);
      // 正面 TTS 播完后启动倒计时
      if (!state.isShowingBack && !state.isCompleted) {
        _startCountdown();
      }
    }
  }

  /// 记录练习统计（翻到背面时）
  Future<void> _recordPracticeStats() async {
    final item = state.currentWord;
    if (item == null) return;

    final now = DateTime.now();
    final cardStart = state.cardStartTime ?? now;
    final studyMs = now.difference(cardStart).inMilliseconds;

    switch (item) {
      case FlashcardWordItem():
        await ref
            .read(savedWordDaoProvider)
            .updatePracticeStats(word: item.dbKey, studyMs: studyMs);
      case FlashcardPhraseItem():
        await ref
            .read(savedSenseGroupDaoProvider)
            .updatePracticeStats(phraseText: item.dbKey);
    }
  }

  /// 保存当前卡片的学习时间（切换卡片时调用）
  void _saveStudyTime() {
    // 学习时长已在 _recordPracticeStats 中记录（翻到背面时）
    // 这里只需重置 cardStartTime
  }

  /// 排序闪卡列表
  List<FlashcardItem> _sortItems(
    List<FlashcardItem> items,
    FlashcardSortMode mode,
  ) {
    final sorted = List<FlashcardItem>.from(items);
    switch (mode) {
      case FlashcardSortMode.alphabeticalAsc:
        sorted.sort(
          (a, b) => a.displayText.toLowerCase().compareTo(
            b.displayText.toLowerCase(),
          ),
        );
      case FlashcardSortMode.alphabeticalDesc:
        sorted.sort(
          (a, b) => b.displayText.toLowerCase().compareTo(
            a.displayText.toLowerCase(),
          ),
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
            viewedBack: false,
            lastPracticedAt: null,
          );
          final scoreB = FlashcardSettings.calculateSmartScore(
            practiceCount: b.practiceCount,
            viewedBack: false,
            lastPracticedAt: null,
          );
          return scoreB.compareTo(scoreA);
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

  /// 停止计时并保存已记录的学习时长 + 输入时间
  ///
  /// stats UI（柱状图等）在切回学习 tab 时由 main_shell 自动刷新，
  /// 这里只刷新 dailyStudyTimeProvider（顶部时长显示）。
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
  }

  /// 累加输入词数（stats UI 在切回学习 tab 时由 main_shell 刷新）
  Future<void> _addInputWords(int count) async {
    if (count > 0) {
      await _studyTimeService.addInputWords(count);
    }
  }
}
