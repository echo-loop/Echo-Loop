/// Flashcard 状态管理 Provider
///
/// 管理单词卡片复习的完整生命周期：卡片列表、翻转、切换、
/// 倒计时、练习统计记录。
///
/// 业务流程由 [FlashcardFlowEngine] 驱动，本 Provider 仅做连接层：
/// - 桥接 TTS / AudioEngine / DAO 等副作用
/// - 管理 UI 专属状态（words, settings, removedCount 等）
/// - 将 engine state 变化合并到 [FlashcardState] 暴露给 UI
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/providers.dart';
import '../../models/audio_item.dart' as model;
import '../../models/flashcard_item.dart';
import '../../models/flashcard_settings.dart';
import '../../models/study_stage.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/audio_engine/foreground_audio_engine_provider.dart';
import '../../services/app_logger.dart';
import '../../services/dictionary_service.dart';
import '../../services/study_time_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/flashcard/flashcard_card.dart';
import '../daily_study_time_provider.dart';
import '../notification_permission_provider.dart';
import '../saved_word_provider.dart';
import 'flashcard_flow_engine.dart';
import 'flashcard_flow_phase.dart';
import 'flashcard_flow_state.dart';

part 'flashcard_provider.g.dart';

/// Flashcard 完整状态（UI 层）
class FlashcardState {
  /// 卡片列表
  final List<FlashcardItem> words;

  /// 当前卡片索引
  final int currentIndex;

  /// 是否正在显示背面
  final bool isShowingBack;

  /// 设置
  final FlashcardSettings settings;

  /// 是否全部完成
  final bool isCompleted;

  /// 本轮取消收藏数
  final int removedCount;

  /// 当前卡片开始查看时间（用于计算学习时长）
  final DateTime? cardStartTime;

  /// 当前流程阶段（来自 engine）
  final FlashcardFlowPhase phase;

  /// 用户手动播放例句是否进行中（来自 engine）
  final bool isSentencePlaying;

  /// 切卡方向：1.0 = 下一张（右→左），-1.0 = 上一张（左→右）
  final double navigationDirection;

  /// 切卡计数：每次切卡递增，与 currentWord.dbKey 拼接生成唯一动画 key，
  /// 避免同一张卡往返时被 AnimatedSwitcher 复用旧动画
  final int navigationId;

  const FlashcardState({
    this.words = const [],
    this.currentIndex = 0,
    this.isShowingBack = false,
    this.settings = const FlashcardSettings(),
    this.isCompleted = false,
    this.removedCount = 0,
    this.cardStartTime,
    this.phase = const FlashcardIdle(),
    this.isSentencePlaying = false,
    this.navigationDirection = 1.0,
    this.navigationId = 0,
  });

  /// 当前卡片
  FlashcardItem? get currentWord =>
      words.isNotEmpty && currentIndex < words.length
      ? words[currentIndex]
      : null;

  /// 总卡片数（含已移除的）
  int get totalWordsReviewed => currentIndex + 1;

  /// 是否显示倒计时
  bool get showCountdown => phase is FlashcardCountdown;

  /// 倒计时剩余时间
  Duration get countdownRemaining => switch (phase) {
    FlashcardCountdown(:final remaining) => remaining,
    _ => Duration.zero,
  };

  /// 倒计时总时长
  Duration get countdownTotal => switch (phase) {
    FlashcardCountdown(:final total) => total,
    _ => Duration.zero,
  };

  FlashcardState copyWith({
    List<FlashcardItem>? words,
    int? currentIndex,
    bool? isShowingBack,
    FlashcardSettings? settings,
    bool? isCompleted,
    int? removedCount,
    DateTime? cardStartTime,
    bool clearCardStartTime = false,
    FlashcardFlowPhase? phase,
    bool? isSentencePlaying,
    double? navigationDirection,
    int? navigationId,
  }) {
    return FlashcardState(
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      isShowingBack: isShowingBack ?? this.isShowingBack,
      settings: settings ?? this.settings,
      isCompleted: isCompleted ?? this.isCompleted,
      removedCount: removedCount ?? this.removedCount,
      cardStartTime: clearCardStartTime
          ? null
          : (cardStartTime ?? this.cardStartTime),
      phase: phase ?? this.phase,
      isSentencePlaying: isSentencePlaying ?? this.isSentencePlaying,
      navigationDirection: navigationDirection ?? this.navigationDirection,
      navigationId: navigationId ?? this.navigationId,
    );
  }
}

/// SharedPreferences key
const _settingsKey = 'flashcard_settings';

/// Flashcard 主 Provider
@Riverpod(keepAlive: true)
class FlashcardNotifier extends _$FlashcardNotifier {
  /// 流程引擎
  late FlashcardFlowEngine _engine;

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

  @override
  FlashcardState build() {
    _studyTimeService = ref.read(studyTimeServiceProvider);
    _engine = FlashcardFlowEngine(
      onStateChanged: _onEngineStateChanged,
      callbacks: _buildCallbacks(),
      config: _buildConfig(),
    );
    ref.onDispose(() {
      _engine.dispose();
      _inputTimePlayerStateSub?.cancel();
      _saveAndRefreshStudyTime();
    });
    return const FlashcardState();
  }

  // ========== 公开方法（UI 调用） ==========

  /// 初始化 Flashcard 会话
  Future<void> initialize(List<FlashcardItem> items) async {
    final sw = Stopwatch()..start();
    // 收藏词复习用前台引擎、不上锁屏：进任务停掉媒体引擎，清除 Free Player 等残留的
    // 锁屏/通知栏卡片（非idle→idle → stopService）。见 ADR-7。
    unawaited(ref.read(audioEngineProvider.notifier).stop());
    _engine.dispose();

    // 加载持久化设置
    final settings = await _loadSettings();
    debugPrint('[PERF] flashcard _loadSettings: ${sw.elapsedMilliseconds}ms');

    debugPrint(
      '[FLASHCARD] initialize: sortMode=${settings.sortMode.name}, '
      'itemCount=${items.length}',
    );
    for (var i = 0; i < items.length && i < 5; i++) {
      final it = items[i];
      debugPrint(
        '[FLASHCARD]   [$i] ${it.displayText}: '
        'practiceCount=${it.practiceCount}, '
        'lastPracticedAt=${it.lastPracticedAt}',
      );
    }

    // 排序
    final sorted = _sortItems(items, settings.sortMode);
    debugPrint('[PERF] flashcard _sortItems: ${sw.elapsedMilliseconds}ms');

    // 批量加载词典
    final allTexts = sorted.map((w) => w.displayText).toList();
    final allEntries = DictionaryService.instance.lookupAll(allTexts);
    debugPrint(
      '[PERF] flashcard lookupAll (${allTexts.length} words): '
      '${sw.elapsedMilliseconds}ms',
    );
    final withDict = sorted
        .map((item) => item.withDictEntry(allEntries[item.displayText]))
        .toList();

    state = FlashcardState(
      words: withDict,
      currentIndex: 0,
      settings: settings,
      cardStartTime: DateTime.now(),
    );

    // 重建引擎
    _engine = FlashcardFlowEngine(
      onStateChanged: _onEngineStateChanged,
      callbacks: _buildCallbacks(),
      config: _buildConfig(),
    );

    // 启动学习计时
    _studyStopwatch.reset();
    _studyStopwatch.start();
    _startInputTimeTracking();
    ref.read(analyticsServiceProvider).track(Events.flashcardStart, {
      EventParams.totalCards: withDict.length,
    });

    // 启动第一张卡片的自动流程
    // 先 await stop，确保前一个 session 的音频彻底停止（AudioEngine keepAlive，
    // 外部可能有残留播放），避免 iOS 上 loadAudio 与 stop() 产生竞态
    if (withDict.isNotEmpty) {
      await _stopAllPlayback();
      final first = withDict.first;
      await _engine.startCard(
        word: first.displayText,
        hasSentence: first.sentenceText != null,
      );
    }
    debugPrint('[PERF] flashcard initialize 总计: ${sw.elapsedMilliseconds}ms');
  }

  /// 用户手动翻转卡片
  ///
  /// 翻转 + 进入 WaitingForUser + 触发自动播放（TTS/句子），
  /// 但不启动倒计时。
  Future<void> userFlipCard() async {
    if (state.isCompleted || state.words.isEmpty) return;
    AppLogger.log(
      'FC',
      'userFlipCard: ${state.isShowingBack ? "back→front" : "front→back"}, '
          'phase=${state.phase.runtimeType}, '
          'word=${state.currentWord?.displayText}',
    );

    final flippingToBack = !state.isShowingBack;
    if (flippingToBack) _recordPracticeStats();

    // 1. 先同步翻转 → UI 立即开始动画（不被平台通道阻塞）
    _engine.userFlipCard();
    final token = _engine.state.flowToken;
    if (!flippingToBack) {
      state = state.copyWith(isSentencePlaying: false);
    }

    // 2. 停止旧播放（不 await，避免平台通道阻塞动画帧）
    // flowToken 已递增，旧播放回调会通过 token 检查自行丢弃
    unawaited(_stopAllPlayback());

    // 3. 等待翻转动画完成后再播放
    await Future<void>.delayed(FlashcardCard.flipDuration);
    if (token != _engine.state.flowToken) return;

    // 4. 自动播放新内容
    final item = state.currentWord;
    if (item != null) {
      await _autoPlayAfterFlip(item, flippingToBack);
    }
  }

  /// 翻转后的自动播放（TTS + 句子）
  ///
  /// 在 WaitingForUser 中播放，播完仍保持 WaitingForUser，不启动倒计时。
  /// 用 engine flowToken 防止切卡/再次翻转后旧回调继续执行。
  Future<void> _autoPlayAfterFlip(FlashcardItem item, bool isBack) async {
    final token = _engine.state.flowToken;

    // 朗读单词（意群优先使用原音）
    if (state.settings.autoPlayWord) {
      AppLogger.log(
        'FC',
        'flipSpeak start: "${item.displayText}" (token=$token)',
      );
      if (!_inputStopwatch.isRunning) _inputStopwatch.start();

      var playedOriginal = false;
      if (item is FlashcardPhraseItem) {
        playedOriginal = await _playPhraseAudio(item);
      }
      if (!playedOriginal) {
        await TtsService.instance.speak(item.displayText);
      }

      _inputStopwatch.stop();
      AppLogger.log(
        'FC',
        'flipSpeak done: "${item.displayText}" (original=$playedOriginal, '
            'token=$token, current=${_engine.state.flowToken}, '
            'stale=${token != _engine.state.flowToken})',
      );
      if (token != _engine.state.flowToken) return;
      await _addInputWords(1);
    }

    // 背面自动播放例句
    if (isBack &&
        state.settings.autoPlaySentence &&
        item.sentenceText != null) {
      // 词汇播放完后短暂停顿，再播放例句
      if (state.settings.autoPlayWord) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (token != _engine.state.flowToken) return;
      }
      state = state.copyWith(isSentencePlaying: true);
      try {
        await _playSentenceAudio(item);
      } finally {
        state = state.copyWith(isSentencePlaying: false);
      }
      if (token != _engine.state.flowToken) return;
      await onSentencePlayed(item.sentenceText!);
    }
  }

  /// 用户点击下一张（恢复自动流程）
  Future<void> userNextCard() async {
    if (state.isCompleted || state.words.isEmpty) return;
    AppLogger.log(
      'FC',
      'userNextCard: idx=${state.currentIndex} → ${state.currentIndex + 1}, '
          'phase=${state.phase.runtimeType}, '
          'word=${state.currentWord?.displayText}',
    );

    if (state.currentIndex >= state.words.length - 1) {
      // 最后一张 → 完成
      _engine.markCompleted();
      _saveStudyTime();
      ref
          .read(usageTrackerProvider)
          .record(
            UsageEvent.flashcardReviewCompleted,
            analyticsParams: {
              EventParams.totalCards: state.words.length,
              EventParams.durationMs: _studyStopwatch.elapsedMilliseconds,
            },
          );
      state = state.copyWith(
        isCompleted: true,
        phase: const FlashcardSessionCompleted(),
      );
      return;
    }

    // 先同步更新 currentIndex：保证第一个 await 处 rebuild 时，
    // currentWord 已与 _slideDirection/_navCount 一致，动画方向正确。
    // 再 await stop：iOS 上确保旧音频彻底停止后再启动新卡流程。
    _saveStudyTime();
    final nextIndex = state.currentIndex + 1;
    final nextItem = state.words[nextIndex];
    state = state.copyWith(
      currentIndex: nextIndex,
      isShowingBack: false,
      cardStartTime: DateTime.now(),
      navigationDirection: 1.0,
      navigationId: state.navigationId + 1,
    );

    await _stopAllPlayback();
    await _engine.startCard(
      word: nextItem.displayText,
      hasSentence: nextItem.sentenceText != null,
    );
  }

  /// 用户点击上一张（恢复自动流程）
  Future<void> userPreviousCard() async {
    if (state.currentIndex <= 0) return;
    AppLogger.log(
      'FC',
      'userPreviousCard: idx=${state.currentIndex} → ${state.currentIndex - 1}, '
          'phase=${state.phase.runtimeType}',
    );

    // 先同步更新 currentIndex：保证第一个 await 处 rebuild 时，
    // currentWord 已与 _slideDirection/_navCount 一致，动画方向正确。
    // 再 await stop：iOS 上确保旧音频彻底停止后再启动新卡流程。
    _saveStudyTime();
    final prevIndex = state.currentIndex - 1;
    final prevItem = state.words[prevIndex];
    state = state.copyWith(
      currentIndex: prevIndex,
      isShowingBack: false,
      cardStartTime: DateTime.now(),
      navigationDirection: -1.0,
      navigationId: state.navigationId + 1,
    );

    await _stopAllPlayback();
    await _engine.startCard(
      word: prevItem.displayText,
      hasSentence: prevItem.sentenceText != null,
    );
  }

  /// 用户手动播放单词 TTS
  ///
  /// 先停止所有播放（防止与 autoPlayAfterFlip 的 TTS 并发），
  /// 再通过 engine 进入 WaitingForUser + 播放。
  Future<void> userPlayWord() async {
    final word = state.currentWord?.displayText;
    if (word == null) return;
    await _stopAllPlayback();
    state = state.copyWith(isSentencePlaying: false);
    await _engine.userPlayWord(word);
  }

  /// 用户手动播放/停止例句
  ///
  /// 统一检查所有播放路径（engine 自动播放 / notifier 翻转后播放 / 手动播放），
  /// 任何一种正在播放都先停止。
  Future<void> userPlaySentence() async {
    if (state.currentWord?.sentenceText == null) return;

    final isAnySentencePlaying =
        state.isSentencePlaying || state.phase is FlashcardPlayingSentence;

    if (isAnySentencePlaying) {
      // 停止所有播放，进入等待
      await _stopAllPlayback();
      _engine.enterWaitingForUser(FlashcardWaitingReason.userStoppedPlayback);
      state = state.copyWith(isSentencePlaying: false);
      return;
    }

    // 开始播放（通过 engine 管理状态）
    // 先 await stop，避免 iOS 上旧 stop() 在新 play() 之后到达产生竞态
    await _stopAllPlayback();
    await _engine.userToggleSentence();
  }

  /// 用户点击倒计时（进入 WaitingForUser，取消倒计时）
  void onCountdownTapped() {
    _engine.enterWaitingForUser(FlashcardWaitingReason.userTappedCountdown);
  }

  /// 用户打开设置
  void onSettingsOpened() {
    _engine.enterWaitingForUser(FlashcardWaitingReason.userOpenedSettings);
  }

  /// App 切到后台
  ///
  /// 仅暂停学习计时；不再中断流程——例句/短语音频段由静音保活在后台继续播放并经锁屏
  /// 控制（仅音频部分接入后台，单词 TTS 后台可能不发声）。前台行为不变。
  void onAppBackgrounded() {
    _studyStopwatch.stop();
  }

  /// 切换当前卡片的收藏状态（不影响 phase）
  Future<void> toggleCurrentWordSave() async {
    if (state.words.isEmpty) return;

    final item = state.words[state.currentIndex];
    final key = item.dbKey;
    final wasUnsaved = _unsavedWords.contains(key);

    if (wasUnsaved) {
      switch (item) {
        case FlashcardWordItem(:final savedWord):
          // 走 SavedWordList.saveWord 统一埋点 + 价值锚点
          await ref
              .read(savedWordListProvider.notifier)
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
          // 价值锚点：意群重新收藏时也触发通知权限 pre-prompt
          unawaited(
            ref
                .read(notificationPermissionServiceProvider)
                .maybeTriggerPrompt(),
          );
      }
      _unsavedWords.remove(key);
      state = state.copyWith(removedCount: state.removedCount - 1);
    } else {
      switch (item) {
        case FlashcardWordItem():
          await ref.read(savedWordListProvider.notifier).removeWord(key);
        case FlashcardPhraseItem():
          await ref.read(savedSenseGroupDaoProvider).removeSenseGroup(key);
      }
      _unsavedWords.add(key);
      state = state.copyWith(removedCount: state.removedCount + 1);
    }
  }

  /// 更新设置并持久化
  Future<void> updateSettings(FlashcardSettings newSettings) async {
    // 进入等待
    _engine.enterWaitingForUser(FlashcardWaitingReason.userOpenedSettings);

    // 如果排序方式变了，重新排序
    if (newSettings.sortMode != state.settings.sortMode) {
      final sorted = _sortItems(state.words, newSettings.sortMode);
      state = state.copyWith(
        settings: newSettings,
        words: sorted,
        currentIndex: 0,
        isShowingBack: false,
        cardStartTime: DateTime.now(),
      );
    } else {
      state = state.copyWith(settings: newSettings);
    }

    // 更新引擎配置
    _engine.updateConfig(_buildConfig());
    await _saveSettings(newSettings);
  }

  /// 单词 TTS 播放完成后计入 1 个输入词
  Future<void> onWordPlayed() => _addInputWords(1);

  /// 例句播放完成后计入输入词数
  Future<void> onSentencePlayed(String sentenceText) {
    final wordCount = sentenceText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return _addInputWords(wordCount);
  }

  /// 重新开始（再来一遍）
  Future<void> reset() async {
    _engine.dispose();
    await _saveAndRefreshStudyTime();
    final freshItems = await _refreshItemsFromDb();
    await initialize(freshItems);
  }

  /// 释放资源
  Future<void> disposePlayer() async {
    _inputTimePlayerStateSub?.cancel();
    _inputTimePlayerStateSub = null;
    await _saveAndRefreshStudyTime();
    _engine.dispose();
    await _stopAllPlayback();
    state = const FlashcardState();
  }

  // ========== 引擎回调 ==========

  /// 引擎状态变化回调 → 同步到 UI state
  void _onEngineStateChanged(FlashcardFlowState engineState) {
    final oldPhase = state.phase.runtimeType;
    final newPhase = engineState.phase.runtimeType;
    if (oldPhase != newPhase) {
      AppLogger.log(
        'FC',
        'phase: $oldPhase → $newPhase '
            '(word=${state.currentWord?.displayText}, '
            'idx=${state.currentIndex}, token=${engineState.flowToken})',
      );
    }
    state = state.copyWith(
      phase: engineState.phase,
      isShowingBack: engineState.isShowingBack,
      isSentencePlaying: engineState.isSentencePlaying,
    );

    // 收藏词复习改用前台引擎、不进后台、不上锁屏（用户 2026-06-27 确认，见 ADR-7）。
  }

  /// 构建引擎回调
  FlashcardFlowCallbacks _buildCallbacks() {
    return FlashcardFlowCallbacks(
      speakWord: _onSpeakWord,
      playSentence: _onPlaySentence,
      stopAllPlayback: () => _stopAllPlayback(),
      onAutoFlip: _onAutoFlip,
      onAutoNext: _onAutoNext,
    );
  }

  /// 构建引擎配置
  FlashcardFlowConfig _buildConfig() {
    return FlashcardFlowConfig(
      getTimerSeconds: ({required bool isBack}) => _getTimerSeconds(isBack),
      isManualMode: () => state.settings.isManualMode,
      isAutoPlayWord: () => state.settings.autoPlayWord,
      isAutoPlaySentence: () => state.settings.autoPlaySentence,
    );
  }

  /// TTS 回调：朗读单词（意群优先使用原音）
  Future<void> _onSpeakWord(String word, int token) async {
    AppLogger.log('FC', 'speakWord start: "$word" (token=$token)');
    if (!_inputStopwatch.isRunning) _inputStopwatch.start();

    final item = state.currentWord;
    var playedOriginal = false;
    if (item is FlashcardPhraseItem) {
      playedOriginal = await _playPhraseAudio(item);
    }
    if (!playedOriginal) {
      await TtsService.instance.speak(word);
    }

    _inputStopwatch.stop();
    AppLogger.log(
      'FC',
      'speakWord done: "$word" (original=$playedOriginal, token=$token, '
          'current=${_engine.state.flowToken}, '
          'stale=${token != _engine.state.flowToken})',
    );
    await _addInputWords(1);
  }

  /// 播放例句回调
  Future<void> _onPlaySentence(int token) async {
    final item = state.currentWord;
    if (item == null) return;
    await _playSentenceAudio(item);
    if (item.sentenceText != null) {
      await onSentencePlayed(item.sentenceText!);
    }
  }

  /// 自动翻转回调（正面倒计时到期）
  Future<void> _onAutoFlip() async {
    if (state.isCompleted || state.words.isEmpty) return;
    AppLogger.log(
      'FC',
      '_onAutoFlip: phase=${state.phase.runtimeType}, '
          'word=${state.currentWord?.displayText}',
    );

    // 记录练习统计
    _recordPracticeStats();

    // 更新 UI 翻转状态
    state = state.copyWith(isShowingBack: true);
    final token = _engine.state.flowToken;

    // 等待翻转动画完成后再播放
    await Future<void>.delayed(FlashcardCard.flipDuration);
    if (token != _engine.state.flowToken) return;

    // 启动背面自动播放
    final item = state.currentWord;
    if (item != null) {
      await _engine.startBackAutoPlay(
        word: item.displayText,
        hasSentence: item.sentenceText != null,
      );
    }
  }

  /// 自动下一张回调（背面倒计时到期）
  Future<void> _onAutoNext() async {
    AppLogger.log(
      'FC',
      '_onAutoNext: phase=${state.phase.runtimeType}, '
          'word=${state.currentWord?.displayText}',
    );
    await userNextCard();
  }

  // ========== 句子播放（从 widget 迁移） ==========

  /// 播放来源句子的原声片段
  Future<void> _playSentenceAudio(FlashcardItem item) async {
    if (item.audioItemId == null) return;

    final hasStoredTiming =
        item.sentenceStartMs != null && item.sentenceEndMs != null;
    if (!hasStoredTiming && item.sentenceIndex == null) {
      AppLogger.log(
        'FC-Audio',
        '_playSentenceAudio RETURN: no stored timing and sentenceIndex null',
      );
      return;
    }

    try {
      final engine = ref.read(foregroundAudioEngineProvider.notifier);
      final engineState = ref.read(foregroundAudioEngineProvider);

      final dao = ref.read(audioItemDaoProvider);
      final row = await dao.getById(item.audioItemId!);
      if (row == null) {
        AppLogger.log('FC-Audio', '_playSentenceAudio RETURN: row=null');
        return;
      }

      final audioItem = model.AudioItem(
        id: row.id,
        name: row.name,
        audioPath: row.audioPath,
        transcriptPath: row.transcriptPath,
        addedDate: row.addedDate,
        totalDuration: row.totalDuration,
        sentenceCount: row.sentenceCount,
        wordCount: row.wordCount,
        isPinned: row.isPinned,
        transcriptSource: model.TranscriptSource.fromIndex(
          row.transcriptSource,
        ),
        audioSha256: row.audioSha256,
        originalAudioSha256: row.originalAudioSha256,
        transcriptLanguage: row.transcriptLanguage,
      );

      final needReload = engineState.currentAudioId != item.audioItemId;
      if (needReload) {
        await engine.loadAudio(audioItem, 1.0);
      }

      Duration startTime;
      Duration endTime;

      const minDurationMs = 200;
      final storedDurationOk =
          hasStoredTiming &&
          (item.sentenceEndMs! - item.sentenceStartMs!) >= minDurationMs;

      if (hasStoredTiming && storedDurationOk) {
        startTime = Duration(milliseconds: item.sentenceStartMs!);
        endTime = Duration(milliseconds: item.sentenceEndMs!);
      } else {
        if (hasStoredTiming && !storedDurationOk) {
          AppLogger.log(
            'FC-Audio',
            'Stored timing too short: ${item.sentenceStartMs}-'
                '${item.sentenceEndMs}ms, falling back to transcript',
          );
        }
        if (item.sentenceIndex == null || row.transcriptPath == null) {
          return;
        }
        final sentences = await engine.loadTranscript(audioItem);
        if (sentences.isEmpty) return;

        final idx = item.sentenceIndex!;
        var sentence = idx < sentences.length ? sentences[idx] : null;
        final storedText = item.sentenceText;

        // 检测索引错位
        if (sentence != null &&
            storedText != null &&
            sentence.text.trim() != storedText.trim()) {
          AppLogger.log(
            'FC-Audio',
            'Index mismatch! index=$idx, trying text match',
          );
          sentence = null;
          for (final s in sentences) {
            if (s.text.trim() == storedText.trim()) {
              sentence = s;
              break;
            }
          }
        }

        if (sentence == null) return;
        startTime = sentence.startTime;
        endTime = sentence.endTime;
      }

      final sessionId = engine.newSession();
      await engine.playRangeOnce(startTime, endTime, sessionId);
    } catch (e, stackTrace) {
      AppLogger.log('FC-Audio', '_playSentenceAudio error: $e\n$stackTrace');
    }
  }

  /// 播放意群原声片段（使用 groupStartMs/groupEndMs）
  ///
  /// 返回 true 表示播放成功，false 表示原音不可用（调用方应回退 TTS）。
  Future<bool> _playPhraseAudio(FlashcardPhraseItem item) async {
    final phrase = item.savedPhrase;
    if (phrase.audioItemId == null ||
        phrase.groupStartMs == null ||
        phrase.groupEndMs == null) {
      return false;
    }

    const minDurationMs = 200;
    if (phrase.groupEndMs! - phrase.groupStartMs! < minDurationMs) {
      AppLogger.log(
        'FC-Audio',
        '_playPhraseAudio: timing too short '
            '${phrase.groupStartMs}-${phrase.groupEndMs}ms',
      );
      return false;
    }

    try {
      final engine = ref.read(foregroundAudioEngineProvider.notifier);
      final engineState = ref.read(foregroundAudioEngineProvider);

      final dao = ref.read(audioItemDaoProvider);
      final row = await dao.getById(phrase.audioItemId!);
      if (row == null) return false;

      final audioItem = model.AudioItem(
        id: row.id,
        name: row.name,
        audioPath: row.audioPath,
        transcriptPath: row.transcriptPath,
        addedDate: row.addedDate,
        totalDuration: row.totalDuration,
        sentenceCount: row.sentenceCount,
        wordCount: row.wordCount,
        isPinned: row.isPinned,
        transcriptSource: model.TranscriptSource.fromIndex(
          row.transcriptSource,
        ),
        audioSha256: row.audioSha256,
        originalAudioSha256: row.originalAudioSha256,
        transcriptLanguage: row.transcriptLanguage,
      );

      if (engineState.currentAudioId != phrase.audioItemId) {
        await engine.loadAudio(audioItem, 1.0);
      }

      final startTime = Duration(milliseconds: phrase.groupStartMs!);
      final endTime = Duration(milliseconds: phrase.groupEndMs!);
      final sessionId = engine.newSession();
      await engine.playRangeOnce(startTime, endTime, sessionId);
      return true;
    } catch (e, stackTrace) {
      AppLogger.log('FC-Audio', '_playPhraseAudio error: $e\n$stackTrace');
      return false;
    }
  }

  // ========== 内部方法 ==========

  /// 获取当前倒计时秒数
  int _getTimerSeconds(bool isBack) {
    switch (state.settings.timerMode) {
      case FlashcardTimerMode.fixed:
        return isBack
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

  /// 停止所有播放（TTS + 音频引擎）
  Future<void> _stopAllPlayback() async {
    await TtsService.instance.stop();
    await ref.read(foregroundAudioEngineProvider.notifier).stop();
  }

  /// 开始监听 AudioEngine playerState，追踪输入时间
  void _startInputTimeTracking() {
    _inputTimePlayerStateSub?.cancel();
    final engine = ref.read(foregroundAudioEngineProvider.notifier);
    _inputTimePlayerStateSub = engine.playerStateStream.listen((playerState) {
      if (playerState.playing) {
        if (!_inputStopwatch.isRunning) _inputStopwatch.start();
      } else {
        _inputStopwatch.stop();
      }
    });
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
            .updatePracticeStats(phraseText: item.dbKey, studyMs: studyMs);
    }
  }

  /// 保存当前卡片的学习时间
  void _saveStudyTime() {
    // 学习时长已在 _recordPracticeStats 中记录
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
        for (final item in sorted) {
          final score = FlashcardSettings.calculateSmartScore(
            practiceCount: item.practiceCount,
            lastPracticedAt: item.lastPracticedAt,
          );
          debugPrint(
            '[FLASHCARD] smart score: ${item.displayText} → '
            'score=${score.toStringAsFixed(2)}, '
            'practice=${item.practiceCount}, '
            'lastPracticed=${item.lastPracticedAt}',
          );
        }
        sorted.sort((a, b) {
          final scoreA = FlashcardSettings.calculateSmartScore(
            practiceCount: a.practiceCount,
            lastPracticedAt: a.lastPracticedAt,
          );
          final scoreB = FlashcardSettings.calculateSmartScore(
            practiceCount: b.practiceCount,
            lastPracticedAt: b.lastPracticedAt,
          );
          final cmp = scoreB.compareTo(scoreA);
          if (cmp != 0) return cmp;
          return b.createdAt.compareTo(a.createdAt);
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

  /// 从 DB 重新读取当前闪卡列表的最新数据
  Future<List<FlashcardItem>> _refreshItemsFromDb() async {
    final wordKeys = <String>{};
    final phraseKeys = <String>{};
    for (final item in state.words) {
      switch (item) {
        case FlashcardWordItem():
          wordKeys.add(item.dbKey);
        case FlashcardPhraseItem():
          phraseKeys.add(item.dbKey);
      }
    }

    final items = <FlashcardItem>[];

    if (wordKeys.isNotEmpty) {
      final allWords = await ref.read(savedWordDaoProvider).getAll();
      for (final w in allWords) {
        if (wordKeys.contains(w.word)) {
          items.add(FlashcardWordItem(savedWord: w));
        }
      }
    }

    if (phraseKeys.isNotEmpty) {
      final allPhrases = await ref
          .read(savedSenseGroupDaoProvider)
          .watchAll()
          .first;
      for (final p in allPhrases) {
        if (phraseKeys.contains(p.phraseText)) {
          items.add(FlashcardPhraseItem(savedPhrase: p));
        }
      }
    }

    return items;
  }

  /// 停止计时并保存已记录的学习时长 + 输入时间
  Future<void> _saveAndRefreshStudyTime() async {
    const stage = StudyStage.flashcard;
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

  /// 累加输入词数
  Future<void> _addInputWords(int count) async {
    if (count > 0) {
      await _studyTimeService.addInputWords(count);
    }
  }
}
