/// 精听播放器页面
///
/// 逐句精听界面，支持普通模式（文字遮盖）和“听不懂”后的详情模式。
///
/// 完成处理：所有句子播完 → 完成对话框 → completeCurrentSubStage → 退出
/// 退出处理：PopScope → 保存断点 → exitLearningMode → pop
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../database/enums.dart';
import '../utils/wakelock_mixin.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_item.dart';
import '../models/sense_group_result.dart';
import '../models/sentence.dart';
import '../models/word_timestamp.dart';
import '../providers/learning_progress_provider.dart';
import '../services/transcription_api_client.dart';
import '../providers/learning_session/intensive_listen_player_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../theme/app_theme.dart';
import '../utils/sense_group_timing.dart';
import '../widgets/intensive_listen/intensive_listen_settings_sheet.dart';
import '../providers/sentence_ai_provider.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/intensive_listen/sentence_annotation_card.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/common/tappable_wrapper.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/practice/practice_normal_mode_view.dart';

/// 精听播放器页面
class IntensiveListenPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（用于返回导航，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const IntensiveListenPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<IntensiveListenPlayerScreen> createState() =>
      _IntensiveListenPlayerScreenState();
}

class _IntensiveListenPlayerScreenState
    extends ConsumerState<IntensiveListenPlayerScreen>
    with WakelockMixin {
  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  /// 是否正在显示完成弹窗，防止重复弹窗
  bool _isShowingDialog = false;

  /// 词级时间戳（从后端获取，按音频缓存）
  List<WordTimestamp>? _wordTimestamps;

  /// 当前句子的意群拆分结果
  List<SenseGroup>? _senseGroups;

  /// 当前句子的意群时间范围
  List<SenseGroupTiming>? _senseGroupTimings;

  /// 上次请求意群的句子索引（切句时重置）
  int? _lastSenseGroupSentenceIndex;

  @override
  void initState() {
    super.initState();
    // 进入后自动开始播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(intensiveListenPlayerProvider.notifier).startPlaying();
      _fetchWordTimestamps();
    });
  }

  /// 加载词级时间戳（DB 优先，未命中则从 API 拉取并保存）
  Future<void> _fetchWordTimestamps() async {
    final audioDao = ref.read(audioItemDaoProvider);
    final audioItem = await audioDao.getById(widget.audioItemId);
    if (audioItem == null) return;
    // 仅 AI 转录有词级时间戳
    if (audioItem.transcriptSource != TranscriptSource.ai.index) return;

    // 1. 优先从 audio_items 表读取
    final json = audioItem.wordTimestampsJson;
    if (json != null) {
      final words = decodeWordTimestamps(json);
      if (words != null && words.isNotEmpty) {
        if (mounted) setState(() => _wordTimestamps = words);
        return;
      }
      // JSON 解析失败，清除脏数据，走 API fallback
      await audioDao.updateWordTimestamps(widget.audioItemId, null);
    }

    // 2. DB 未命中，从 API 拉取并保存
    final sha256 = audioItem.audioSha256;
    final language = audioItem.transcriptLanguage;
    if (sha256 == null || language == null) {
      debugPrint('词级时间戳 API fallback 跳过: sha256=$sha256, language=$language');
      return;
    }

    try {
      final api = ref.read(transcriptionApiClientProvider);
      final result = await api.getTranscript(sha256, language);
      if (result.words != null && result.words!.isNotEmpty) {
        // 保存到 audio_items 表
        await audioDao.updateWordTimestamps(
          widget.audioItemId,
          encodeWordTimestamps(result.words!),
        );
        if (mounted) setState(() => _wordTimestamps = result.words);
      }
    } catch (e) {
      debugPrint('获取词级时间戳失败: $e');
    }
  }

  /// 请求 AI 拆分意群
  Future<void> _requestSenseGroups() async {
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    final sentence = player.currentSentence;
    if (sentence == null) return;

    final ai = ref.read(sentenceAiNotifierProvider);
    final result = await ai.getSenseGroups(sentence.text);

    if (!mounted) return;

    // 有词级时间戳时计算时间范围映射（支持点击播放意群）
    final sentenceIndex = ref
        .read(intensiveListenPlayerProvider)
        .currentSentenceIndex;
    final timings = _wordTimestamps != null
        ? _computeTimings(result.groups, sentence, sentenceIndex)
        : null;

    setState(() {
      _senseGroups = result.groups;
      _senseGroupTimings = timings;
      _lastSenseGroupSentenceIndex = sentenceIndex;
    });
  }

  /// 计算意群时间范围
  List<SenseGroupTiming> _computeTimings(
    List<SenseGroup> groups,
    Sentence sentence,
    int sentenceIndex,
  ) {
    final words = _wordTimestamps!;
    // 找到句子在 words 中的范围：时间范围匹配
    final startMs = sentence.startTime.inMilliseconds;
    final endMs = sentence.endTime.inMilliseconds;

    var startIdx = 0;
    var endIdx = words.length - 1;

    // 找第一个开始时间 >= 句子开始时间的词
    for (var i = 0; i < words.length; i++) {
      if (words[i].startTime.inMilliseconds >= startMs - 100) {
        startIdx = i;
        break;
      }
    }
    // 找最后一个结束时间 <= 句子结束时间的词
    for (var i = words.length - 1; i >= 0; i--) {
      if (words[i].endTime.inMilliseconds <= endMs + 100) {
        endIdx = i;
        break;
      }
    }

    return mapSenseGroupTimings(
      groups: groups,
      words: words,
      sentenceStart: sentence.startTime,
      sentenceEnd: sentence.endTime,
      sentenceStartWordIndex: startIdx,
      sentenceEndWordIndex: endIdx,
    );
  }

  /// 切句时重置意群状态
  void _resetSenseGroupsIfNeeded(int currentIndex) {
    if (_lastSenseGroupSentenceIndex != null &&
        _lastSenseGroupSentenceIndex != currentIndex) {
      _senseGroups = null;
      _senseGroupTimings = null;
      _lastSenseGroupSentenceIndex = null;
    }
  }

  /// 处理退出（close 按钮 / 系统返回）
  ///
  /// 自由练习模式直接退出；正常学习模式弹出确认对话框，
  /// 确认后保存断点和难句，再退出。
  Future<void> _handleExit() async {
    _isExiting = true;
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    await player.pause();
    if (!mounted) return;

    final session = ref.read(learningSessionProvider);
    if (session.isFreePlay) {
      await _saveSentenceProgress(isFreePlay: true);

      // 保存难句书签 + 难句数快照（与非 freePlay 路径一致）
      await _saveDifficultSentences();
      final totalDifficultCount = await _loadTotalDifficultCount();
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultCount(widget.audioItemId, totalDifficultCount);

      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exitIntensiveListenTitle),
        content: Text(l10n.exitIntensiveListenMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirmExit),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      _isExiting = false;
      return;
    }

    // 保存断点 + 难句 + 难句数快照
    await _saveSentenceProgress(isFreePlay: false);
    await _saveDifficultSentences();

    final totalDifficultCount = await _loadTotalDifficultCount();
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveDifficultCount(widget.audioItemId, totalDifficultCount);

    // 先 exitLearningMode 同步书签到 LP，再 pop 页面
    // （pop 后 widget 销毁，ref.read 可能失效）
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 保存精听断点进度
  Future<void> _saveSentenceProgress({required bool isFreePlay}) async {
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveIntensiveListenSentenceIndex(
          widget.audioItemId,
          player.currentIndex,
          isFreePlay: isFreePlay,
        );
  }

  /// 获取当前音频的难句总数（以数据库书签为准）
  ///
  /// 该值代表“全部已标记难句”，而非“本次会话临时集合”。
  Future<int> _loadTotalDifficultCount() async {
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarks = await bookmarkDao.getByAudioId(widget.audioItemId);
    return bookmarks.length;
  }

  /// 切换难句标记并即时持久化到数据库
  ///
  /// 先切换内存状态，再根据新状态决定新增或移除书签，
  /// 最后同步难句数快照到 learning_progress。
  Future<void> _toggleAndSaveDifficult() async {
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    final playerState = ref.read(intensiveListenPlayerProvider);
    final idx = playerState.currentSentenceIndex;

    // 1. 切换内存状态
    player.toggleDifficultSentence();

    // 2. 读取切换后的状态，判断是新增还是移除
    final newState = ref.read(intensiveListenPlayerProvider);
    final isNowDifficult = newState.difficultSentences.contains(idx);

    // 3. 即时持久化到 DB
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    if (isNowDifficult) {
      if (idx < player.sentences.length) {
        final sentence = player.sentences[idx];
        await BookmarkManager.addBookmarkToDb(
          widget.audioItemId,
          sentence,
          dao: bookmarkDao,
        );
      }
    } else {
      await bookmarkDao.removeBookmark(
        widget.audioItemId,
        player.sentences[idx].index,
      );
    }

    // 4. 同步难句数快照到 learning_progress（以数据库总量为准）
    final totalDifficultCount = await _loadTotalDifficultCount();
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveDifficultCount(widget.audioItemId, totalDifficultCount);
  }

  /// 保存难句书签到数据库（增量同步：新增 + 移除）
  ///
  /// 对比初始书签状态与当前 difficultSentences，
  /// 新标记的添加到数据库，取消标记的从数据库移除。
  Future<void> _saveDifficultSentences() async {
    final playerState = ref.read(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    final bookmarkDao = ref.read(bookmarkDaoProvider);

    // 初始书签集合 — 使用位置索引，与 difficultSentences 保持一致
    final initialBookmarks = <int>{
      for (final (i, s) in player.sentences.indexed)
        if (s.isBookmarked) i,
    };

    // 新增的难句书签
    final added = playerState.difficultSentences.difference(initialBookmarks);
    for (final index in added) {
      if (index < player.sentences.length) {
        final sentence = player.sentences[index];
        await BookmarkManager.addBookmarkToDb(
          widget.audioItemId,
          sentence,
          dao: bookmarkDao,
        );
      }
    }

    // 取消标记的书签 — 位置索引转换为句子索引后传给 DB
    final removedPositions = initialBookmarks.difference(
      playerState.difficultSentences,
    );
    if (removedPositions.isNotEmpty) {
      final removedSentenceIndices = <int>{
        for (final pos in removedPositions)
          if (pos < player.sentences.length) player.sentences[pos].index,
      };
      await BookmarkManager.removeBookmarksFromDb(
        widget.audioItemId,
        removedSentenceIndices,
        dao: bookmarkDao,
      );
    }
  }

  /// 进入难句跟读模式
  ///
  /// 精听完成后调用，读取难句书签并进入跟读。
  /// 0 个难句时显示 SnackBar 提示并 pop 回计划页。
  /// 返回学习计划页并自动启动下一个任务
  ///
  /// 先 go 回学习 Tab 清空导航栈，再 push 新的学习计划页（autoStart=true），
  /// 效果等同于用户在学习列表点击"继续学习"。
  void _navigateBackToPlanAndAutoStart() {
    if (!mounted) return;
    final route = widget.collectionId != null
        ? AppRoutes.learningPlan(
            widget.collectionId!,
            widget.audioItemId,
            autoStart: true,
          )
        : AppRoutes.audioLearningPlan(widget.audioItemId, autoStart: true);
    GoRouter.of(context).go(AppRoutes.study);
    GoRouter.of(context).push(route);
  }

  /// 获取当前步骤的上下文信息
  ({
    int stepIndex,
    int totalSteps,
    String stageName,
    String? nextStepName,
    bool isLastStep,
  })
  _getStepContext() {
    final l10n = AppLocalizations.of(context)!;
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    if (progress == null) {
      final subStages = LearningStage.firstLearn.subStages;
      final idx = subStages.indexOf(SubStageType.intensiveListen);
      final isLast = idx >= subStages.length - 1;
      String? nextName;
      if (!isLast) {
        final next = subStages[idx + 1];
        if (_hasPlayerScreen(next)) {
          nextName = _getSubStageName(next, l10n);
        }
      }
      return (
        stepIndex: idx,
        totalSteps: subStages.length,
        stageName: reviewStageLabel(l10n, LearningStage.firstLearn),
        nextStepName: nextName,
        isLastStep: isLast,
      );
    }

    final stage = progress.currentStage;
    final subStages = stage.subStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);
    final isLast = currentIdx >= subStages.length - 1;

    // 判断下一步是否有播放器
    String? nextStepName;
    if (!isLast) {
      final nextSubStage = subStages[currentIdx + 1];
      if (_hasPlayerScreen(nextSubStage)) {
        nextStepName = _getSubStageName(nextSubStage, l10n);
      }
    }

    return (
      stepIndex: currentIdx,
      totalSteps: subStages.length,
      stageName: reviewStageLabel(l10n, stage),
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 处理播放完成
  ///
  /// 弹出完成对话框，支持双按钮："返回计划"和"继续下一步"。
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;

    final session = ref.read(learningSessionProvider);
    final playerState = ref.read(intensiveListenPlayerProvider);

    // 保存难句书签
    await _saveDifficultSentences();
    final totalDifficultCount = await _loadTotalDifficultCount();

    if (!mounted) return;

    // 自由练习模式：弹窗询问"完成"或"再来一遍"
    if (session.isFreePlay) {
      final l10n = AppLocalizations.of(context)!;
      // 弹窗前保存统计并递增遍数
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultCount(widget.audioItemId, totalDifficultCount);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementIntensiveListenPassCount(widget.audioItemId);

      if (!mounted) return;

      await handleFreePlayComplete(
        context: context,
        title: l10n.intensiveListenCompleteTitle,
        message: l10n.intensiveListenCompleteMessage(
          playerState.totalSentences,
          totalDifficultCount,
        ),
        onStudyAgain: () async {
          ref.read(intensiveListenPlayerProvider.notifier).resetToStart();
        },
        onExit: () async {
          await ref
              .read(learningProgressNotifierProvider.notifier)
              .saveIntensiveListenSentenceIndex(
                widget.audioItemId,
                null,
                isFreePlay: true,
              );
          await ref.read(learningSessionProvider.notifier).exitLearningMode();
          if (mounted) context.pop();
        },
      );
      _isShowingDialog = false;
      return;
    }

    final stepCtx = _getStepContext();

    // 弹窗前保存统计（事实记录，不影响步骤进度）
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultCount(widget.audioItemId, totalDifficultCount);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementIntensiveListenPassCount(widget.audioItemId);
    } catch (e) {
      debugPrint('精听保存统计出错: $e');
    }

    if (!mounted) return;

    final l10nDialog = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10nDialog.intensiveListenCompleteTitle,
      contentBody: Text(
        l10nDialog.intensiveListenCompleteMessage(
          playerState.totalSentences,
          totalDifficultCount,
        ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      nextStepName: stepCtx.nextStepName,
      isLastStep: stepCtx.isLastStep,
    );

    if (!mounted || result == null) {
      _isShowingDialog = false;
      return;
    }

    // 用户确认后：清除断点 + 标记完成
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveIntensiveListenSentenceIndex(
            widget.audioItemId,
            null,
            isFreePlay: false,
          );
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('精听完成处理出错: $e');
    }

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (!mounted) return;

    if (result.action == StepCompleteAction.continueNext) {
      _navigateBackToPlanAndAutoStart();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 只监听非倒计时字段，排除 pauseRemaining / annotationReplayRemaining，
    // 避免倒计时每 100ms tick 导致整个页面（含 ListView、句子卡片）重建
    ref.watch(
      intensiveListenPlayerProvider.select(
        (s) => (
          s.currentSentenceIndex,
          s.totalSentences,
          s.currentPlayCount,
          s.settings,
          s.isPlaying,
          s.isPauseBetweenPlays,
          s.isPauseBetweenSentences,
          s.pauseDuration,
          s.annotationReplayDuration,
          s.isAnnotationMode,
          s.isAnnotationReplay,
          s.isTextRevealed,
          s.difficultSentences,
          s.isCurrentSentenceAutoMarked,
          s.isCountdownPaused,
          s.isCountdownFastForward,
          s.stepFinished,
          s.playingSenseGroupIndex,
          s.playedSenseGroupIndices,
        ),
      ),
    );
    final playerState = ref.read(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);

    // 监听自然完成信号 → 触发完成弹窗
    ref.listen(intensiveListenPlayerProvider, (prev, next) {
      if (_isExiting || prev == null) return;
      if (!prev.stepFinished && next.stepFinished) {
        ref.read(learningSessionProvider.notifier).pauseStudyTimer();
        shortenIdleTimeout(5);
        _handleCompleted();
      }
    });

    final currentSentence = player.currentSentence;

    // 切句时重置意群
    _resetSenseGroupsIfNeeded(playerState.currentSentenceIndex);

    // 句子时长（如 "3.5s"）和时间戳（如 "00:32.1 - 00:35.6"）分开传递，
    // 由 _ProgressSection 用不同样式渲染以建立视觉层级。
    final hasDuration =
        currentSentence != null && currentSentence.duration > Duration.zero;
    final durationText = hasDuration
        ? l10n.sentenceDuration(
            (currentSentence.duration.inMilliseconds / 1000.0).toStringAsFixed(
              1,
            ),
          )
        : null;

    return wakelockBody(
      child: LearningHotkeyScope(
        onPlayPause: () {
          if (playerState.isPlaying) {
            player.pause();
          } else if (playerState.isAnnotationReplay) {
            player.resume();
          } else if (playerState.isPauseBetweenPlays) {
            player.replayDuringCountdown();
          } else if (playerState.isAnnotationMode) {
            player.replayInAnnotationMode();
          } else {
            player.resume();
          }
        },
        onPrevious: () => player.goToPrevious(),
        onNext: () => player.goToNext(),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleExit();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.intensiveListenAppBarTitle),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _handleExit,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: l10n.intensiveListenSettings,
                  onPressed: () {
                    showIntensiveListenSettingsSheet(context: context);
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                // 进度条
                _ProgressSection(
                  playerState: playerState,
                  l10n: l10n,
                  durationText: durationText,
                ),

                // 主体内容
                Expanded(
                  child:
                      playerState.isAnnotationMode ||
                          playerState.isAnnotationReplay
                      ? _AnnotationWithBookmark(
                          playerState: playerState,
                          l10n: l10n,
                          theme: theme,
                          onToggleDifficult: _toggleAndSaveDifficult,
                          child: _AnnotationModeView(
                            text: currentSentence?.text ?? '',
                            isDifficult: playerState.difficultSentences
                                .contains(playerState.currentSentenceIndex),
                            isAutoMarked:
                                playerState.isCurrentSentenceAutoMarked,
                            aiNotifier: ref.read(sentenceAiNotifierProvider),
                            audioItemId: widget.audioItemId,
                            sentenceIndex: currentSentence?.index ?? playerState.currentSentenceIndex,
                            sentenceStartMs:
                                currentSentence?.startTime.inMilliseconds,
                            sentenceEndMs:
                                currentSentence?.endTime.inMilliseconds,
                            senseGroups: _senseGroups,
                            senseGroupTimings: _senseGroupTimings,
                            playingSenseGroupIndex:
                                playerState.playingSenseGroupIndex,
                            playedSenseGroupIndices:
                                playerState.playedSenseGroupIndices,
                            onTapSenseGroup: (index) {
                              if (_senseGroupTimings != null &&
                                  index < _senseGroupTimings!.length) {
                                final timing = _senseGroupTimings![index];
                                player.playSenseGroup(
                                  timing.start,
                                  timing.end,
                                  index,
                                );
                              } else if (_senseGroupTimings == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.wordTimestampsNotFound,
                                    ),
                                  ),
                                );
                              }
                            },
                            onRequestSenseGroups: _requestSenseGroups,
                            hasWordTimestamps: _wordTimestamps != null,
                          ),
                        )
                      : PracticeNormalModeView(
                          l10n: l10n,
                          theme: theme,
                          isTextRevealed: playerState.isTextRevealed,
                          countdown: Consumer(
                            builder: (context, ref, _) {
                              final s = ref.watch(
                                intensiveListenPlayerProvider.select(
                                  (s) => (
                                    show:
                                        s.isPauseBetweenPlays &&
                                        !s.settings.isManualMode,
                                    remaining: s.pauseRemaining,
                                    total: s.pauseDuration,
                                    paused: s.isCountdownPaused,
                                  ),
                                ),
                              );
                              if (!s.show) return const SizedBox.shrink();
                              return CountdownChip(
                                remaining: s.remaining,
                                total: s.total,
                                isPaused: s.paused,
                                onTap: () => s.paused
                                    ? player.resumeCountdown()
                                    : player.pauseCountdown(),
                              );
                            },
                          ),
                          alwaysShowToggleButton: false,
                          isDifficult: playerState.difficultSentences.contains(
                            playerState.currentSentenceIndex,
                          ),
                          onPeekToggle: () => player.setTextRevealed(
                            !playerState.isTextRevealed,
                          ),
                          onToggleMark: _toggleAndSaveDifficult,
                          onCantUnderstand: () => player.enterAnnotationMode(),
                          sentenceText: currentSentence?.text,
                          onWordTap: currentSentence != null
                              ? (word) => showWordDictionarySheet(
                                  context: context,
                                  word: word,
                                  audioItemId: widget.audioItemId,
                                  sentenceIndex: currentSentence.index,
                                  sentenceText: currentSentence.text,
                                  sentenceStartMs:
                                      currentSentence.startTime.inMilliseconds,
                                  sentenceEndMs:
                                      currentSentence.endTime.inMilliseconds,
                                )
                              : null,
                        ),
                ),

                // 底部统一 Padding（对齐跟读页布局）
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.m,
                    left: AppSpacing.l,
                    right: AppSpacing.l,
                    bottom: AppSpacing.m,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // === 标注模式专属 ===
                      if (playerState.isAnnotationMode &&
                          !playerState.isAnnotationReplay &&
                          !playerState.isPauseBetweenSentences)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.m),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => player.exitAnnotationMode(),
                              child: Text(l10n.intensiveListenContinue),
                            ),
                          ),
                        ),
                      if (playerState.isAnnotationReplay)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.m),
                          child: Text(
                            l10n.intensiveListenReplayingWithSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      // 倒计时区域用 Consumer 隔离，避免 tick 触发外层重建
                      if ((playerState.isAnnotationMode ||
                              playerState.isAnnotationReplay) &&
                          playerState.isPauseBetweenSentences)
                        Consumer(
                          builder: (context, ref, _) {
                            final s = ref.watch(intensiveListenPlayerProvider);
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.m,
                              ),
                              child: CountdownChip(
                                remaining: s.pauseRemaining,
                                total: s.pauseDuration,
                                isPaused: s.isCountdownPaused,
                                onTap: () => s.isCountdownPaused
                                    ? player.resumeCountdown()
                                    : player.pauseCountdown(),
                              ),
                            );
                          },
                        ),

                      // === 通用：播放控制 ===
                      _PlaybackControls(
                        playerState: playerState,
                        onPrevious: () => player.goToPrevious(),
                        onNext: () {
                          final isLast =
                              playerState.currentSentenceIndex >=
                              playerState.totalSentences - 1;
                          if (isLast) {
                            player.stopPlayback();
                            _handleCompleted();
                          } else {
                            player.goToNext();
                          }
                        },
                        onPlayPause: () {
                          if (playerState.isPlaying) {
                            player.pause();
                          } else if (playerState.isAnnotationReplay) {
                            player.resume();
                          } else if (playerState.isPauseBetweenPlays) {
                            player.replayDuringCountdown();
                          } else if (playerState.isAnnotationMode) {
                            player.replayInAnnotationMode();
                          } else {
                            player.resume();
                          }
                        },
                      ),
                      // 播放遍数（手动模式隐藏）
                      if (!playerState.settings.isManualMode)
                        Text(
                          l10n.intensiveListenPlayCount(
                            playerState.currentPlayCount,
                            playerState.settings.repeatCount,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶部进度条区域
class _ProgressSection extends StatelessWidget {
  final IntensiveListenState playerState;
  final AppLocalizations l10n;

  /// 句子时长文本（如 "2.8秒"），为 null 时不显示
  final String? durationText;

  const _ProgressSection({
    required this.playerState,
    required this.l10n,
    this.durationText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = playerState.totalSentences;
    final current = playerState.currentSentenceIndex + 1;
    final progress = total > 0 ? current / total : 0.0;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                l10n.intensiveListenProgress(current, total),
                style: subtitleStyle,
              ),
              const Spacer(),
              if (durationText case final dur?) Text(dur, style: subtitleStyle),
            ],
          ),
        ],
      ),
    );
  }
}

/// 普通模式视图（难句标记行 + 字幕区 + 偷看 + 倒计时 + 按钮行）
///
/// 倒计时使用固定 56px 高度占位，避免字幕区跳动。
/// 布局参考难句补练 PracticeNormalModeView。
/// 标注模式外层包装：在顶部显示和普通模式相同的书签标记行
class _AnnotationWithBookmark extends StatelessWidget {
  final IntensiveListenState playerState;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onToggleDifficult;
  final Widget child;

  const _AnnotationWithBookmark({
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onToggleDifficult,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDifficult = playerState.difficultSentences.contains(
      playerState.currentSentenceIndex,
    );
    final isAutoMarked = playerState.isCurrentSentenceAutoMarked;

    // 标记文案：自动标记 / 手动标记 / 未标记
    final labelText = isDifficult
        ? (isAutoMarked
              ? l10n.intensiveListenAutoMarkedDifficult
              : l10n.intensiveListenMarkedDifficult)
        : l10n.intensiveListenNotDifficult;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),
          // 书签标记行（和普通模式同位置、同样式）
          TappableWrapper(
            onTap: onToggleDifficult,
            feedbackType: TapFeedback.opacity,
            pressedOpacity: 0.4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    labelText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  isDifficult ? Icons.bookmark : Icons.bookmark_border,
                  color: isDifficult ? Colors.amber.shade700 : Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          // 标注内容
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NormalModeView extends StatelessWidget {
  final IntensiveListenState playerState;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onPeekToggle;

  /// 切换难句标记回调（用于难句标记行）
  final VoidCallback onToggleDifficult;

  /// 听不懂（进入标注模式）
  final VoidCallback onCantUnderstand;

  /// 暂停/恢复倒计时
  final VoidCallback onPauseCountdown;

  final String? sentenceText;

  /// 点击单词查词回调
  final void Function(String word)? onWordTap;

  const _NormalModeView({
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeekToggle,
    required this.onToggleDifficult,
    required this.onCantUnderstand,
    required this.onPauseCountdown,
    this.sentenceText,
    this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDifficult = playerState.difficultSentences.contains(
      playerState.currentSentenceIndex,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 难句标记行
          TappableWrapper(
            onTap: onToggleDifficult,
            feedbackType: TapFeedback.opacity,
            pressedOpacity: 0.4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    isDifficult
                        ? l10n.intensiveListenMarkedDifficult
                        : l10n.intensiveListenNotDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  isDifficult ? Icons.bookmark : Icons.bookmark_border,
                  color: isDifficult ? Colors.amber.shade700 : Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),

          // 字幕区（整个区域可点击切换字幕）
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPeekToggle,
              child: Stack(
                children: [
                  // 字幕内容偏上（-0.4 ≈ 上方 30% 位置）
                  Align(
                    alignment: const Alignment(0, -0.4),
                    child: playerState.isTextRevealed && sentenceText != null
                        ? GestureDetector(
                            onTap: () {}, // 拦截点击，不冒泡到外层
                            onLongPressStart: (details) => TextContextMenu.show(
                              context,
                              details.globalPosition,
                              sentenceText!,
                            ),
                            onSecondaryTapDown: (details) =>
                                TextContextMenu.show(
                                  context,
                                  details.globalPosition,
                                  sentenceText!,
                                ),
                            child: onWordTap != null
                                ? _TappableText(
                                    text: sentenceText!,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                          height: 1.6,
                                        ) ??
                                        const TextStyle(),
                                    onWordTap: onWordTap!,
                                  )
                                : Text(
                                    sentenceText!,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(height: 1.6),
                                    textAlign: TextAlign.center,
                                  ),
                          )
                        : _HiddenTextPlaceholder(),
                  ),
                  // 偷看字幕标签（固定在字幕区中间偏下）
                  Align(
                    alignment: const Alignment(0, 0.55),
                    child: _PeekLabel(
                      isRevealed: playerState.isTextRevealed,
                      l10n: l10n,
                      theme: theme,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部固定区：倒计时 + 按钮行
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 倒计时用 Consumer 隔离，避免 tick 触发外层重建
              SizedBox(
                height: 56,
                child: playerState.isPauseBetweenPlays
                    ? Consumer(
                        builder: (context, ref, _) {
                          final s = ref.watch(intensiveListenPlayerProvider);
                          return CountdownChip(
                            remaining: s.pauseRemaining,
                            total: s.pauseDuration,
                            isPaused: s.isCountdownPaused,
                            onTap: onPauseCountdown,
                          );
                        },
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.m),
              // 取消标记 + 听不懂按钮
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isDifficult) ...[
                      TextButton(
                        onPressed: onToggleDifficult,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          l10n.practiceRemoveMark,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                    ],
                    FilledButton.tonal(
                      onPressed: onCantUnderstand,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        l10n.intensiveListenCantUnderstand,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}

/// 隐藏文本占位（灰色线条）
class _HiddenTextPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.hearing,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: AppSpacing.l),
        // 占位灰色线条
        for (int i = 0; i < 3; i++) ...[
          Container(
            width: 200 - i * 40,
            height: 8,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}

/// 标注模式视图
///
/// 工具栏固定在顶部不随内容滚动，句子文本和解析内容在下方可滚动。
class _AnnotationModeView extends StatefulWidget {
  final String text;
  final bool isDifficult;

  /// 是否展示”自动标记为难句”文案
  final bool isAutoMarked;

  /// AI 翻译/解析服务
  final SentenceAiNotifier? aiNotifier;

  /// 来源音频 ID（用于词典弹窗收藏单词）
  final String? audioItemId;

  /// 当前句子索引
  final int? sentenceIndex;

  /// 当前句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 当前句子结束时间（毫秒）
  final int? sentenceEndMs;

  /// AI 意群拆分结果
  final List<SenseGroup>? senseGroups;

  /// 各意群时间范围
  final List<SenseGroupTiming>? senseGroupTimings;

  /// 正在播放的意群索引
  final int? playingSenseGroupIndex;

  /// 已播放过的意群索引集合
  final Set<int> playedSenseGroupIndices;

  /// 点击意群回调
  final void Function(int groupIndex)? onTapSenseGroup;

  /// 请求拆分意群回调
  final Future<void> Function()? onRequestSenseGroups;

  /// 是否有词级时间戳
  final bool hasWordTimestamps;

  const _AnnotationModeView({
    required this.text,
    required this.isDifficult,
    required this.isAutoMarked,
    this.aiNotifier,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.senseGroups,
    this.senseGroupTimings,
    this.playingSenseGroupIndex,
    this.playedSenseGroupIndices = const {},
    this.onTapSenseGroup,
    this.onRequestSenseGroups,
    this.hasWordTimestamps = false,
  });

  @override
  State<_AnnotationModeView> createState() => _AnnotationModeViewState();
}

class _AnnotationModeViewState extends State<_AnnotationModeView> {
  /// 用于访问卡片 State 以构建外部工具栏。
  /// 切句时重建 GlobalKey 确保卡片 State 重置。
  GlobalKey<SentenceAnnotationCardState> _cardKey =
      GlobalKey<SentenceAnnotationCardState>();

  /// 工具栏刷新通知器，卡片 State 变化时通知工具栏重建
  final _toolbarNotifier = _RebuildNotifier();

  @override
  void dispose() {
    _toolbarNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AnnotationModeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切句时重建 GlobalKey，确保卡片 State 重置
    if (widget.text != oldWidget.text) {
      _cardKey = GlobalKey<SentenceAnnotationCardState>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = widget.aiNotifier;
    final cachedTranslation = ai
        ?.getCachedTranslation(widget.text)
        ?.translation;
    final cachedAnalysis = ai?.getCachedAnalysis(widget.text);
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 固定工具栏（监听 notifier 刷新）
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.m),
          child: ListenableBuilder(
            listenable: _toolbarNotifier,
            builder: (context, _) {
              final cardState = _cardKey.currentState;
              if (cardState == null || !cardState.hasToolbarButtons) {
                return const SizedBox.shrink();
              }
              return cardState.buildToolbar(context);
            },
          ),
        ),
        // 可滚动内容区
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.l),
            child: SentenceAnnotationCard(
              key: _cardKey,
              text: widget.text,
              isDifficult: widget.isDifficult,
              showAutoMarkedLabel: widget.isAutoMarked,
              showToolbar: false,
              onToolbarStateChanged: _toolbarNotifier.notify,
              onRequestTranslation: ai != null
                  ? () async {
                      final result = await ai.getTranslation(widget.text);
                      return result.translation;
                    }
                  : null,
              onRequestAnalysis: ai != null
                  ? () async {
                      final result = await ai.getAnalysis(widget.text);
                      return result.toDisplayString();
                    }
                  : null,
              cachedTranslation: cachedTranslation,
              cachedAnalysis: cachedAnalysisText,
              audioItemId: widget.audioItemId,
              sentenceIndex: widget.sentenceIndex,
              sentenceStartMs: widget.sentenceStartMs,
              sentenceEndMs: widget.sentenceEndMs,
              senseGroups: widget.senseGroups,
              senseGroupTimings: widget.senseGroupTimings,
              playingSenseGroupIndex: widget.playingSenseGroupIndex,
              playedSenseGroupIndices: widget.playedSenseGroupIndices,
              onTapSenseGroup: widget.onTapSenseGroup,
              onRequestSenseGroups: widget.onRequestSenseGroups,
              hasWordTimestamps: widget.hasWordTimestamps,
            ),
          ),
        ),
      ],
    );
  }
}

/// 简单的重建通知器，用于卡片状态变化时触发工具栏重建
class _RebuildNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// 偷看字幕标签（字幕区下方，提示用户可点击）
class _PeekLabel extends StatelessWidget {
  final bool isRevealed;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PeekLabel({
    required this.isRevealed,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isRevealed
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          l10n.intensiveListenPeek,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}


/// 底部播放控制
///
/// 布局：[上一句] --- [播放/暂停] --- [下一句]
class _PlaybackControls extends StatelessWidget {
  final IntensiveListenState playerState;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;

  const _PlaybackControls({
    required this.playerState,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canGoPrev = playerState.currentSentenceIndex > 0;
    final isLastSentence =
        playerState.currentSentenceIndex >= playerState.totalSentences - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.skip_previous_rounded,
            enabled: canGoPrev,
            onTap: canGoPrev ? onPrevious : null,
          ),
          const SizedBox(width: 48),

          // 播放/暂停
          TappableWrapper(
            onTap: onPlayPause,
            feedbackType: TapFeedback.scale,
            scaleDown: 0.92,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                playerState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 28,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48),

          _NavButton(
            icon: isLastSentence
                ? Icons.check_circle_rounded
                : Icons.skip_next_rounded,
            enabled: true,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

/// 导航按钮（上一句/下一句）
///
/// 无背景图标，禁用态降低透明度。
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!enabled) {
      return AnimatedOpacity(
        opacity: 0.15,
        duration: const Duration(milliseconds: 150),
        child: Icon(icon, size: 32, color: theme.colorScheme.onSurface),
      );
    }
    return TappableWrapper(
      onTap: onTap,
      feedbackType: TapFeedback.opacityAndScale,
      pressedOpacity: 0.4,
      scaleDown: 0.85,
      child: Opacity(
        opacity: 0.6,
        child: Icon(icon, size: 32, color: theme.colorScheme.onSurface),
      ),
    );
  }
}

/// 判断子步骤是否有专用播放器页面
bool _hasPlayerScreen(SubStageType type) => switch (type) {
  SubStageType.blindListen => true,
  SubStageType.intensiveListen => true,
  SubStageType.listenAndRepeat => true,
  SubStageType.retell => true,
  SubStageType.reviewDifficultPractice => false,
  SubStageType.reviewRetellParagraph => false,
  SubStageType.reviewRetellSummary => false,
};

/// 获取子步骤的本地化名称
String _getSubStageName(SubStageType type, AppLocalizations l10n) =>
    switch (type) {
      SubStageType.blindListen => l10n.stepBlindListening,
      SubStageType.intensiveListen => l10n.stepIntensiveListening,
      SubStageType.listenAndRepeat => l10n.stepShadowing,
      SubStageType.retell => l10n.stepRetelling,
      SubStageType.reviewDifficultPractice => 'Difficult practice',
      SubStageType.reviewRetellParagraph => 'Paragraph retelling',
      SubStageType.reviewRetellSummary => 'Summary retelling',
    };
