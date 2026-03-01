/// 学习会话层 Provider
///
/// 管理学习模式状态（盲听等），进入盲听时暂停 ListeningPractice
/// 的 stream 监听，通过 BlindListenPlayer 直接操作 AudioEngine。
/// 负责：进入/退出学习模式、保存/恢复用户播放设置、监听播放完成。
library;

import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/playback_settings.dart';
import '../../models/sentence.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learning_progress_provider.dart';
import '../listening_practice/listening_practice_provider.dart';
import 'blind_listen_player_provider.dart';
import 'intensive_listen_player_provider.dart';
import 'listen_and_repeat_player_provider.dart';
import 'retell_player_provider.dart';
import 'sentence_playback_engine.dart';
import '../../database/providers.dart';

part 'learning_session_provider.g.dart';

/// 学习模式类型
enum LearningMode {
  /// 全文盲听
  blindListen,

  /// 逐句精听
  intensiveListen,

  /// 难句跟读
  listenAndRepeat,

  /// 段级复述
  retell,
}

/// 学习会话状态
class LearningSessionState {
  /// 当前学习模式（null = 自由收听）
  final LearningMode? learningMode;

  /// 本遍盲听是否已播放完成
  final bool blindListenCompleted;

  /// 当前盲听遍数（从 1 开始，表示正在听第几遍）
  final int blindListenPassCount;

  /// 当前学习的音频 ID
  final String? audioItemId;

  /// 进入学习模式前的用户播放设置（退出时恢复）
  final PlaybackSettings? savedSettings;

  /// 是否为自由练习模式（已完成步骤的单独练习，不计入遍数、不弹完成对话框）
  final bool isFreePlay;

  /// 目标盲听遍数（暂时硬编码，后续由 AI 决定）
  final int targetBlindListenPasses;

  const LearningSessionState({
    this.learningMode,
    this.blindListenCompleted = false,
    this.blindListenPassCount = 0,
    this.audioItemId,
    this.savedSettings,
    this.isFreePlay = false,
    this.targetBlindListenPasses = 1,
  });

  /// 是否处于学习模式中
  bool get isInLearningMode => learningMode != null;

  /// 是否还有剩余遍数未完成
  ///
  /// `blindListenPassCount` 表示"正在听第几遍"，完成后才 +1，
  /// 所以用 `<` 比较：正在听的这一遍还没达到目标时返回 true。
  bool get hasRemainingPasses => blindListenPassCount < targetBlindListenPasses;

  LearningSessionState copyWith({
    LearningMode? learningMode,
    bool? blindListenCompleted,
    int? blindListenPassCount,
    String? audioItemId,
    PlaybackSettings? savedSettings,
    bool? isFreePlay,
    int? targetBlindListenPasses,
    bool clearLearningMode = false,
    bool clearSavedSettings = false,
    bool clearAudioItemId = false,
  }) {
    return LearningSessionState(
      learningMode: clearLearningMode
          ? null
          : (learningMode ?? this.learningMode),
      blindListenCompleted: blindListenCompleted ?? this.blindListenCompleted,
      blindListenPassCount: blindListenPassCount ?? this.blindListenPassCount,
      audioItemId: clearAudioItemId ? null : (audioItemId ?? this.audioItemId),
      savedSettings: clearSavedSettings
          ? null
          : (savedSettings ?? this.savedSettings),
      isFreePlay: isFreePlay ?? this.isFreePlay,
      targetBlindListenPasses:
          targetBlindListenPasses ?? this.targetBlindListenPasses,
    );
  }
}

/// 学习会话 Provider
///
/// 作为播放器之上的学习流程控制层。
/// 进入盲听模式时暂停 LP 监听、初始化 BlindListenPlayer，
/// 退出时停止盲听播放、恢复 LP 监听。
@Riverpod(keepAlive: true)
class LearningSession extends _$LearningSession {
  StreamSubscription<ja.PlayerState>? _playerStateSub;

  @override
  LearningSessionState build() {
    ref.onDispose(() {
      _playerStateSub?.cancel();
    });
    return const LearningSessionState();
  }

  /// 进入全文盲听模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听（避免 LP 干扰盲听播放）
  /// 3. 初始化 BlindListenPlayer，从数据库读取已有遍数
  /// 4. 开始监听播放完成事件
  Future<void> enterBlindListenMode(
    String audioItemId, {
    bool isFreePlay = false,
  }) async {
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 从数据库读取已完成遍数
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[audioItemId];
    final dbPassCount = progress?.blindListenPassCount ?? 0;

    // 保存用户原始设置，遍数从数据库已完成遍数 + 1 开始（当前正在听的这一遍）
    state = state.copyWith(
      learningMode: LearningMode.blindListen,
      blindListenCompleted: false,
      blindListenPassCount: dbPassCount + 1,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听，避免干扰盲听播放
    practice.suspendListeners();

    // 初始化盲听播放器，始终从音频开头播放（激励用户一次听完）
    final engineState = ref.read(audioEngineProvider);
    final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
    blindPlayer.initialize(engineState.totalDuration ?? Duration.zero);
    await blindPlayer.seekTo(Duration.zero);

    // 开始监听播放完成
    _startListeningForCompletion();
  }

  /// 再听一遍
  ///
  /// 重置完成状态，递增遍数，通过 BlindListenPlayer 从头开始播放。
  Future<void> replayBlindListen() async {
    state = state.copyWith(
      blindListenCompleted: false,
      blindListenPassCount: state.blindListenPassCount + 1,
    );

    final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
    await blindPlayer.resetAndPlay();
  }

  /// 进入逐句精听模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 初始化 IntensiveListenPlayer，从数据库读取断点句子索引
  Future<void> enterIntensiveListenMode(
    String audioItemId,
    List<Sentence> sentences, {
    bool isFreePlay = false,
  }) async {
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 从数据库读取断点句子索引
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[audioItemId];
    final startIndex = progress?.intensiveListenSentenceIndex ?? 0;

    state = state.copyWith(
      learningMode: LearningMode.intensiveListen,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();

    // 初始化精听播放器
    final intensivePlayer = ref.read(intensiveListenPlayerProvider.notifier);
    await intensivePlayer.initialize(sentences, startIndex: startIndex);
  }

  /// 进入难句跟读模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 从 BookmarkDao 读取难句索引集 → 过滤句子
  /// 4. 从 LearningProgress 读取断点 shadowingSentenceIndex
  /// 5. 根据 difficulty 计算 targetPlayCount
  /// 6. 初始化 ListenAndRepeatPlayer
  Future<void> enterListenAndRepeatMode(
    String audioItemId,
    List<Sentence> allSentences, {
    bool isFreePlay = false,
  }) async {
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 从数据库读取难句索引
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await bookmarkDao.getBookmarkedIndices(
      audioItemId,
    );

    // 过滤出难句列表
    final difficultSentences = allSentences
        .where((s) => bookmarkedIndices.contains(s.index))
        .toList();

    // 从数据库读取断点和难度
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[audioItemId];
    final startIndex = progress?.shadowingSentenceIndex ?? 0;
    final difficultyValue = progress?.difficulty.value ?? 2;
    final targetPlayCount = targetPlayCountForDifficulty(difficultyValue);

    state = state.copyWith(
      learningMode: LearningMode.listenAndRepeat,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();

    // 初始化跟读播放器
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    await player.initialize(
      difficultSentences,
      startIndex: startIndex,
      targetPlayCount: targetPlayCount,
    );
  }

  /// 进入段级复述模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 初始化 RetellPlayer（段落分组 + 关键词映射 + 断点索引）
  Future<void> enterRetellMode(
    String audioItemId,
    List<List<Sentence>> paragraphs,
    Map<int, Set<int>> keywordsMap, {
    bool isFreePlay = false,
  }) async {
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 从数据库读取断点句子索引
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[audioItemId];
    final startSentenceIndex = progress?.retellParagraphIndex;

    state = state.copyWith(
      learningMode: LearningMode.retell,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();

    // 初始化复述播放器
    final player = ref.read(retellPlayerProvider.notifier);
    player.initialize(
      paragraphs,
      keywordsMap,
      startSentenceIndex: startSentenceIndex,
    );
  }

  /// 退出学习模式
  ///
  /// 根据当前学习模式分支处理：停止播放、释放资源、恢复 LP 监听。
  Future<void> exitLearningMode() async {
    final mode = state.learningMode;

    _playerStateSub?.cancel();
    _playerStateSub = null;

    if (mode == LearningMode.blindListen) {
      // 停止盲听播放并释放资源
      final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
      await blindPlayer.pause();
      blindPlayer.disposePlayer();
    } else if (mode == LearningMode.intensiveListen) {
      // 释放精听播放器资源
      final intensivePlayer = ref.read(intensiveListenPlayerProvider.notifier);
      intensivePlayer.disposePlayer();
    } else if (mode == LearningMode.listenAndRepeat) {
      // 释放跟读播放器资源
      final player = ref.read(listenAndRepeatPlayerProvider.notifier);
      player.disposePlayer();
    } else if (mode == LearningMode.retell) {
      // 释放复述播放器资源
      final retellPlayer = ref.read(retellPlayerProvider.notifier);
      retellPlayer.disposePlayer();
    }

    // 通用：清除 clip 防止残留影响 LP 的 absolutePositionStream
    final engine = ref.read(audioEngineProvider.notifier);
    await engine.clearClip();

    // 恢复 LP 的 stream 监听
    final practice = ref.read(listeningPracticeProvider.notifier);
    practice.resumeListeners();

    // 同步精听期间新增的书签到 LP 内存状态
    await practice.syncBookmarks();

    // 停止引擎播放（确保干净退出）
    await practice.stop();

    state = const LearningSessionState();
  }

  /// 标记本遍盲听完成并持久化遍数到数据库
  Future<void> _markBlindListenCompleted() async {
    if (state.learningMode != LearningMode.blindListen) return;
    if (state.blindListenCompleted) return;

    state = state.copyWith(blindListenCompleted: true);

    // 播放完成后暂停并将进度条回到零点，等待用户下一步操作
    final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
    await blindPlayer.pause();
    await blindPlayer.seekTo(Duration.zero);

    // 持久化盲听遍数到数据库
    final audioItemId = state.audioItemId;
    if (audioItemId != null) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementBlindListenPassCount(audioItemId);
    }

    // 自由练习模式：递增会话内遍数并重置完成标志，使下一遍完成时能再次触发
    // 正常模式由对话框的 replayBlindListen() 处理递增和重置
    if (state.isFreePlay) {
      state = state.copyWith(
        blindListenCompleted: false,
        blindListenPassCount: state.blindListenPassCount + 1,
      );
    }
  }

  /// 监听音频播放完成事件
  void _startListeningForCompletion() {
    _playerStateSub?.cancel();
    final engine = ref.read(audioEngineProvider.notifier);
    _playerStateSub = engine.playerStateStream.listen((playerState) {
      if (playerState.processingState == ja.ProcessingState.completed) {
        _markBlindListenCompleted();
      }
    });
  }
}
