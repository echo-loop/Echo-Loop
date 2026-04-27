// 学习计划表页面
//
// 展示音频的完整学习流程：首次学习（4步）和复习（7步）。
// 从 LearningProgressNotifier 读取真实进度数据，
// 步骤卡片支持三态：已完成、当前、未开始。
// 导航路径：合集详情 → 学习计划表 → 播放器
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../database/enums.dart';
import '../models/audio_item.dart';
import '../models/learning_progress.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/time_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/listen_and_repeat/listen_and_repeat_controller.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/subtitle_parser.dart';
import '../theme/app_theme.dart';
import '../models/blind_listen_settings.dart';
import '../models/intensive_listen_settings.dart' show PauseMode;
import '../models/retell_settings.dart';
import '../utils/keyword_extraction.dart';
import '../utils/paragraph_grouping.dart';
import '../widgets/blind_listen_paragraph_sheet.dart';
import '../widgets/intensive_listen/intensive_listen_briefing_sheet.dart';
import '../widgets/listen_and_repeat/listen_and_repeat_briefing_sheet.dart';
import '../providers/learning_session/retell_player_provider.dart';
import '../widgets/retell/retell_briefing_sheet.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/speech_permission_dialog.dart';
import '../widgets/guide_flow.dart';
import '../widgets/manage_subtitles_sheet.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../database/providers.dart';
import '../providers/learning_session/sentence_playback_engine.dart';

/// 实时查询指定音频的书签数量（难句数）
///
/// 使用 StreamProvider 监听 bookmarks 表变化，确保难句数实时更新。
final _bookmarkCountProvider = StreamProvider.family.autoDispose<int, String>((
  ref,
  audioItemId,
) {
  final bookmarkDao = ref.watch(bookmarkDaoProvider);
  return bookmarkDao
      .watchByAudioId(audioItemId)
      .map((bookmarks) => bookmarks.length);
});

/// 学习计划表页面
class LearningPlanScreen extends ConsumerStatefulWidget {
  /// 合集 ID（从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  /// 是否自动启动当前学习任务
  final bool autoStart;

  const LearningPlanScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
    this.autoStart = false,
  });

  @override
  ConsumerState<LearningPlanScreen> createState() => _LearningPlanScreenState();
}

class _LearningPlanScreenState extends ConsumerState<LearningPlanScreen> {
  /// autoStart 是否已触发
  bool _autoStartTriggered = false;

  /// loadAudio 的 Future，用于在读取 sentences 前确保音频加载完成
  Future<void>? _loadAudioFuture;

  /// 首次学习区域是否展开（首次学习阶段默认展开，进入复习阶段后默认折叠）
  bool? _isFirstLearnExpanded;

  /// 各复习轮次的展开状态（key 为复习大阶段）
  final Map<LearningStage, bool> _reviewRoundExpandedMap = {};

  // Guide step keys
  final _keyFreePlay = GlobalKey();
  final _keyStartLearning = GlobalKey();
  final _keyAddSubtitle = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保学习进度记录存在
      ref
          .read(learningProgressNotifierProvider.notifier)
          .ensureProgress(widget.audioItemId);

      // 检查并加载音频数据
      final audioItem = ref
          .read(audioLibraryProvider.notifier)
          .getItemById(widget.audioItemId);
      if (audioItem == null) return;

      // 始终调用 loadAudio：同一音频时只重新读取字幕，不重新加载音频文件
      _loadAudioFuture = ref
          .read(listeningPracticeProvider.notifier)
          .loadAudio(audioItem);

      // 监听字幕变化（上传/AI转录完成后重新加载字幕）
      ref.listenManual(
        audioLibraryProvider.select(
          (s) => s.audioItems
              .where((i) => i.id == widget.audioItemId)
              .firstOrNull
              ?.transcriptPath,
        ),
        (prev, next) {
          if (prev != next && next != null) {
            final updated = ref
                .read(audioLibraryProvider.notifier)
                .getItemById(widget.audioItemId);
            if (updated != null) {
              _loadAudioFuture = ref
                  .read(listeningPracticeProvider.notifier)
                  .loadAudio(updated);
            }
          }
        },
      );
    });
  }

  /// 等待音频加载完成，返回 LP 状态。
  ///
  /// 如果加载后 audioItemId 不匹配（加载失败等），返回 null。
  Future<ListeningPracticeState?> _ensureAudioLoaded() async {
    await _loadAudioFuture;
    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.currentAudioItem?.id != widget.audioItemId) return null;
    return lpState;
  }

  /// 处理"开始学习/继续学习"按钮点击
  void _handleStartLearning(BuildContext context, LearningProgress? progress) {
    final now = ref.read(nowProvider)();
    if (progress?.isReviewLockedAt(now) ?? false) return;

    if (progress != null &&
        progress.currentStage.index >= LearningStage.review0.index &&
        progress.currentStage.index <= LearningStage.review28.index) {
      _startReviewSubStage(context, progress);
      return;
    }

    final currentSubStage =
        progress?.currentSubStage ?? SubStageType.blindListen;

    if (currentSubStage == SubStageType.blindListen) {
      _startBlindListen(context, progress);
    } else if (currentSubStage == SubStageType.intensiveListen) {
      _startIntensiveListen(context);
    } else if (currentSubStage == SubStageType.listenAndRepeat) {
      _startListenAndRepeat(context);
    } else if (currentSubStage == SubStageType.retell) {
      _startRetelling(context);
    } else {
      // 其他子步骤 → 直接导航到播放器
      if (widget.collectionId != null) {
        context.push(
          AppRoutes.player(widget.collectionId!, widget.audioItemId),
        );
      } else {
        context.push(AppRoutes.audioPlayer(widget.audioItemId));
      }
    }
  }

  /// 复习阶段：按 subStage 分发到真实页面。
  ///
  /// 盲听和段落复述自带段落选择弹窗，无需再展示复习简报；
  /// 其余子阶段先展示复习简报弹窗。
  void _startReviewSubStage(BuildContext context, LearningProgress progress) {
    final subStage = progress.currentSubStage;

    // 段落复述自带时长选择弹窗，无需再展示复习简报
    if (subStage == SubStageType.reviewRetellParagraph) {
      _startReviewRetell(context, isSummary: false);
      return;
    }

    // 盲听自带段落选择弹窗，阶段名和预估时长直接显示在弹窗上
    if (subStage == SubStageType.blindListen) {
      _startReviewBlindListen(context, stage: progress.currentStage);
      return;
    }

    // 预估时长
    final estimatedDuration = _estimateReviewDuration(subStage);

    showReviewBriefingSheet(
      context: context,
      stage: progress.currentStage,
      subStage: subStage,
      estimatedDuration: estimatedDuration,
      onStartPractice: () {
        switch (subStage) {
          case SubStageType.reviewDifficultPractice:
            _startReviewDifficultPractice(context);
          case SubStageType.reviewRetellSummary:
            _startReviewRetell(context, isSummary: true);
          default:
            // 不应到达，回退到计划页
            break;
        }
      },
    );
  }

  /// 预估复习子步骤时长
  Duration? _estimateReviewDuration(SubStageType subStage) {
    switch (subStage) {
      case SubStageType.blindListen:
        // 盲听 = 音频时长
        return ref.read(audioEngineProvider).totalDuration;
      case SubStageType.reviewDifficultPractice:
        // 难句补练 = 难句总时长 × 2（盲听 + 跟读）
        final lpState = ref.read(listeningPracticeProvider);
        final difficultDuration = lpState.sentences
            .where((s) => s.isBookmarked)
            .fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);
        if (difficultDuration == Duration.zero) return null;
        return difficultDuration * 2;
      case SubStageType.reviewRetellSummary:
        // 全文复述 = 音频时长 × 4（听 + 停顿复述）
        final totalDuration = ref.read(audioEngineProvider).totalDuration;
        return totalDuration != null ? totalDuration * 4 : null;
      default:
        return null;
    }
  }

  /// 复习盲听：弹段落选择弹窗后进入段落播放
  ///
  /// [stage] 当前复习阶段，用于在弹窗上显示阶段名和预估时长。
  Future<void> _startReviewBlindListen(
    BuildContext context, {
    required LearningStage stage,
  }) async {
    final lpState = await _ensureAudioLoaded();
    if (!context.mounted) return;
    final sentences = lpState?.sentences ?? const [];
    if (sentences.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final estimatedDuration = _estimateReviewDuration(SubStageType.blindListen);
    final estimatedText = estimatedDuration != null
        ? formatEstimatedDuration(l10n, estimatedDuration)
        : null;

    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      stageLabel: reviewStageLabel(l10n, stage),
      estimatedDurationText: estimatedText,
      onStartPractice: (targetDuration, pauseMultiplier) async {
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        final settings = BlindListenSettings.fromMultiplier(pauseMultiplier);
        await ref
            .read(learningSessionProvider.notifier)
            .enterBlindListenMode(
              widget.audioItemId,
              paragraphs: paragraphs,
              settings: settings,
            );
        if (!context.mounted) return;
        context.push(
          AppRoutes.blindListenPlayer(widget.collectionId, widget.audioItemId),
        );
      },
    );
  }

  /// 复习难句补练：进入 ReviewDifficultPracticeScreen
  ///
  /// 先检查书签数量，无难句时自动完成并跳到下一复述子阶段。
  Future<void> _startReviewDifficultPractice(BuildContext context) async {
    final allowed = await ensureSpeechReadyForRecording(context, ref);
    if (!allowed || !context.mounted) return;

    final lpState = await _ensureAudioLoaded();
    if (!context.mounted || lpState == null) return;
    final l10n = AppLocalizations.of(context)!;

    if (lpState.sentences.isEmpty) {
      // 无字幕 → 跳过
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reviewDifficultPracticeNone)),
        );
      }
      return;
    }

    // 检查书签数量（难句数）
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarks = await BookmarkManager.loadBookmarks(
      widget.audioItemId,
      dao: bookmarkDao,
    );
    if (!context.mounted) return;

    if (bookmarks.isEmpty) {
      // 无难句 → 自动完成补练，推进到下一子阶段
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.reviewDifficultPracticeNone)));
      // 根据新的 currentSubStage 导航到对应复述入口
      _navigateToReviewRetellFromPlan(context);
      return;
    }

    await ref
        .read(learningSessionProvider.notifier)
        .enterReviewDifficultPracticeMode(
          widget.audioItemId,
          lpState.sentences,
        );
    if (!context.mounted) return;
    context.push(
      AppRoutes.reviewDifficultPractice(
        widget.collectionId,
        widget.audioItemId,
      ),
    );
  }

  /// 从计划页导航到复习复述（跳过难句补练后使用）
  void _navigateToReviewRetellFromPlan(BuildContext context) {
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    if (progress == null) return;

    final nextSubStage = progress.currentSubStage;
    if (nextSubStage == SubStageType.reviewRetellParagraph) {
      _startReviewRetell(context, isSummary: false);
    } else if (nextSubStage == SubStageType.reviewRetellSummary) {
      _startReviewRetell(context, isSummary: true);
    }
  }

  /// 复习复述：复用 RetellPlayerScreen
  ///
  /// [isSummary] 为 true 时全文作为单个段落（reviewRetellSummary）
  Future<void> _startReviewRetell(
    BuildContext context, {
    required bool isSummary,
  }) async {
    final allowed = await ensureSpeechReadyForRecording(context, ref);
    if (!allowed || !context.mounted) return;

    final lpState = await _ensureAudioLoaded();
    if (!context.mounted || lpState == null) return;

    if (lpState.sentences.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.intensiveListenNoSubtitle,
            ),
          ),
        );
      }
      return;
    }

    if (isSummary) {
      // reviewRetellSummary：全文作为单个段落，无需选择时长
      final keywordsMap = extractKeywords(
        lpState.sentences,
        ratio: KeywordRatio.oneThird,
      );
      await ref.read(learningSessionProvider.notifier).enterRetellMode(
        widget.audioItemId,
        [lpState.sentences],
        keywordsMap,
      );
      if (!context.mounted) return;
      context.push(
        AppRoutes.retellPlayer(widget.collectionId, widget.audioItemId),
      );
      return;
    }

    // reviewRetellParagraph：弹出简报面板让用户选择段落时长
    final currentStage = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId]
        ?.currentStage;

    // 复习阶段显示阶段名和预估时长
    final l10n = AppLocalizations.of(context)!;
    final isReview =
        currentStage != null && currentStage != LearningStage.firstLearn;
    final totalDuration = ref.read(audioEngineProvider).totalDuration;
    final retellEstimate = totalDuration != null ? totalDuration * 3 : null;

    showRetellBriefingSheet(
      context: context,
      sentences: lpState.sentences,
      defaultSeconds: retellDefaultSeconds(currentStage),
      stageLabel: isReview ? reviewStageLabel(l10n, currentStage) : null,
      estimatedDurationText: retellEstimate != null
          ? formatEstimatedDuration(l10n, retellEstimate)
          : null,
      onStartPractice: (targetDuration, pauseMultiplier) async {
        final paragraphs = groupSentencesIntoParagraphs(
          lpState.sentences,
          targetDuration,
        );
        final keywordsMap = extractKeywords(
          lpState.sentences,
          ratio: KeywordRatio.oneThird,
        );
        await ref
            .read(learningSessionProvider.notifier)
            .enterRetellMode(widget.audioItemId, paragraphs, keywordsMap);
        _applyRetellPauseMultiplier(pauseMultiplier);
        if (!context.mounted) return;
        context.push(
          AppRoutes.retellPlayer(widget.collectionId, widget.audioItemId),
        );
      },
    );
  }

  /// 将弹窗选择的停顿倍数应用到 RetellPlayer 的初始设置
  ///
  /// -1.0 = 智能模式（默认），>0 = 段长倍数模式
  void _applyRetellPauseMultiplier(double pauseMultiplier) {
    if (pauseMultiplier >= 0) {
      final player = ref.read(retellPlayerProvider.notifier);
      final current = ref.read(retellPlayerProvider).settings;
      player.updateSettings(
        current.copyWith(
          pauseMode: PauseMode.multiplier,
          pauseMultiplier: pauseMultiplier,
        ),
      );
    }
  }

  /// 进入全文盲听
  ///
  /// 先弹简报弹窗，点"开始练习"后等待音频加载，
  /// 有字幕时再弹段落选择弹窗，无字幕时直接进入极简播放。
  Future<void> _startBlindListen(
    BuildContext context,
    LearningProgress? progress,
  ) async {
    // 等待音频加载完成，获取字幕
    final lpState = await _ensureAudioLoaded();
    if (!context.mounted) return;
    final sentences = lpState?.sentences ?? const [];

    if (sentences.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final totalDuration = ref.read(audioEngineProvider).totalDuration;

    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      estimatedDurationText: totalDuration != null
          ? formatEstimatedDuration(l10n, totalDuration)
          : null,
      onStartPractice: (targetDuration, pauseMultiplier) async {
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        final settings = BlindListenSettings.fromMultiplier(pauseMultiplier);
        await ref
            .read(learningSessionProvider.notifier)
            .enterBlindListenMode(
              widget.audioItemId,
              paragraphs: paragraphs,
              settings: settings,
            );
        if (!context.mounted) return;
        context.push(
          AppRoutes.blindListenPlayer(widget.collectionId, widget.audioItemId),
        );
      },
    );
  }

  /// 进入逐句精听
  Future<void> _startIntensiveListen(BuildContext context) async {
    final lpState = await _ensureAudioLoaded();
    if (!context.mounted || lpState == null) return;
    final l10n = AppLocalizations.of(context)!;

    // 无字幕则提示用户上传
    if (lpState.sentences.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.intensiveListenNoSubtitle),
          content: Text(l10n.intensiveListenNoSubtitleMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    // 预估时长：每句 = 句子时长 × 2（听 + 停顿处理）
    final totalSentenceDuration = lpState.sentences.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final intensiveEstimate = totalSentenceDuration * 2;

    showIntensiveListenBriefingSheet(
      context: context,
      sentenceCount: lpState.sentences.length,
      estimatedDuration: intensiveEstimate,
      onStartPractice: () async {
        await ref
            .read(learningSessionProvider.notifier)
            .enterIntensiveListenMode(widget.audioItemId, lpState.sentences);
        if (!context.mounted) return;
        context.push(
          AppRoutes.intensiveListenPlayer(
            widget.collectionId,
            widget.audioItemId,
          ),
        );
      },
    );
  }

  /// 进入难句跟读
  Future<void> _startListenAndRepeat(BuildContext context) async {
    final allowed = await ensureSpeechReadyForRecording(context, ref);
    if (!allowed || !context.mounted) return;

    final lpState = await _ensureAudioLoaded();
    if (!context.mounted || lpState == null) return;
    final l10n = AppLocalizations.of(context)!;

    if (lpState.sentences.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.intensiveListenNoSubtitle),
          content: Text(l10n.intensiveListenNoSubtitleMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final difficultIndices = await BookmarkManager.loadBookmarks(
      widget.audioItemId,
      dao: bookmarkDao,
    );
    if (!context.mounted) return;

    if (difficultIndices.isEmpty) {
      // 无难句 → 自动完成跟读，推进到复述
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listenAndRepeatNoDifficultSentences)),
      );
      _startRetelling(context);
      return;
    }

    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    final playCount = targetPlayCountForDifficulty(
      progress?.difficulty.index ?? 2,
    );

    final difficultDuration = difficultIndices.fold<Duration>(
      Duration.zero,
      (sum, idx) =>
          sum +
          (idx < lpState.sentences.length
              ? lpState.sentences[idx].duration
              : Duration.zero),
    );
    final repeatEstimate = difficultDuration * playCount * 2;

    showListenAndRepeatBriefingSheet(
      context: context,
      difficultCount: difficultIndices.length,
      playCount: playCount,
      estimatedDuration: repeatEstimate,
      onStartPractice: () async {
        await ref
            .read(listenAndRepeatControllerProvider.notifier)
            .initialize(
              audioItemId: widget.audioItemId,
              allSentences: lpState.sentences,
              isFreePlay: false,
            );
        if (!context.mounted) return;
        context.push(
          AppRoutes.listenAndRepeatPlayer(
            widget.collectionId,
            widget.audioItemId,
          ),
        );
      },
    );
  }

  /// 进入段落复述
  Future<void> _startRetelling(BuildContext context) async {
    final allowed = await ensureSpeechReadyForRecording(context, ref);
    if (!allowed || !context.mounted) return;

    final lpState = await _ensureAudioLoaded();
    if (!context.mounted || lpState == null) return;
    final l10n = AppLocalizations.of(context)!;

    // 无字幕则提示
    if (lpState.sentences.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.intensiveListenNoSubtitle),
          content: Text(l10n.intensiveListenNoSubtitleMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    final totalDuration = ref.read(audioEngineProvider).totalDuration;
    final retellEstimate = totalDuration != null ? totalDuration * 3 : null;

    showRetellBriefingSheet(
      context: context,
      sentences: lpState.sentences,
      defaultSeconds: retellDefaultSeconds(LearningStage.firstLearn),
      estimatedDurationText: retellEstimate != null
          ? formatEstimatedDuration(l10n, retellEstimate)
          : null,
      onStartPractice: (targetDuration, pauseMultiplier) async {
        final paragraphs = groupSentencesIntoParagraphs(
          lpState.sentences,
          targetDuration,
        );
        final keywordsMap = extractKeywords(
          lpState.sentences,
          ratio: KeywordRatio.oneThird,
        );

        await ref
            .read(learningSessionProvider.notifier)
            .enterRetellMode(widget.audioItemId, paragraphs, keywordsMap);
        _applyRetellPauseMultiplier(pauseMultiplier);
        if (!context.mounted) return;
        context.push(
          AppRoutes.retellPlayer(widget.collectionId, widget.audioItemId),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final audioItem = ref.watch(
      audioLibraryProvider.select(
        (s) =>
            s.audioItems.where((i) => i.id == widget.audioItemId).firstOrNull,
      ),
    );

    // 监听学习进度
    final progress = ref.watch(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[widget.audioItemId],
      ),
    );
    final now = ref.watch(nowProvider)();

    // audioItem 找不到时显示错误页面
    if (audioItem == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.audioFileNotFound)),
      );
    }

    // autoStart：正常渲染计划页，同时自动触发 _handleStartLearning（弹 briefing sheet）
    if (widget.autoStart && !_autoStartTriggered) {
      _autoStartTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleStartLearning(context, progress);
      });
    }

    final reviewStages = _buildReviewStages(l10n);

    final hasTranscript = audioItem.hasTranscript;
    final isLockedReview = progress?.isReviewLockedAt(now) ?? false;

    final stepFreePlay = GuideStep(
      key: _keyFreePlay,
      title: l10n.guidePlanFreePlayTitle,
      description: l10n.guidePlanFreePlayDescription,
    );
    final stepStartLearning = GuideStep(
      key: _keyStartLearning,
      title: l10n.guidePlanStartLearningTitle,
      description: l10n.guidePlanStartLearningDescription,
    );
    final stepAddSubtitle = GuideStep(
      key: _keyAddSubtitle,
      title: l10n.guidePlanAddSubtitleTitle,
      description: l10n.guidePlanAddSubtitleDescription,
    );

    final flows = <GuideFlow>[
      GuideFlow(
        flowId: GuideFlowIds.learningPlanWithTranscript,
        shouldRun: hasTranscript,
        steps: [stepFreePlay, stepStartLearning],
      ),
      GuideFlow(
        flowId: GuideFlowIds.learningPlanNoTranscript,
        shouldRun: !hasTranscript,
        steps: [stepAddSubtitle],
      ),
    ];

    return GuideFlowSequenceHost(
      flows: flows,
      child: Scaffold(
        appBar: AppBar(
          title: Text(audioItem.name),
          actions: [
            GuideTarget(
              step: stepFreePlay,
              child: TextButton.icon(
                onPressed: () {
                  if (widget.collectionId != null) {
                    context.push(
                      AppRoutes.player(
                        widget.collectionId!,
                        widget.audioItemId,
                      ),
                    );
                  } else {
                    context.push(AppRoutes.audioPlayer(widget.audioItemId));
                  }
                },
                icon: const Icon(Icons.headphones),
                label: Text(l10n.freePlay),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.m),
                children: [
                  _ProgressCard(
                    l10n: l10n,
                    progress: progress,
                    audioItem: audioItem,
                    now: now,
                  ),
                  if (!hasTranscript) ...[
                    const SizedBox(height: AppSpacing.s),
                    _NoTranscriptBanner(
                      l10n: l10n,
                      audioItem: audioItem,
                      addSubtitleStep: stepAddSubtitle,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.l),
                  _FirstStudySection(
                    l10n: l10n,
                    progress: progress,
                    collectionId: widget.collectionId,
                    audioItemId: widget.audioItemId,
                    isExpanded: _isFirstLearnExpanded ??=
                        progress?.isCurrentStage(LearningStage.firstLearn) ??
                        true,
                    onToggle: () => setState(
                      () => _isFirstLearnExpanded =
                          !(_isFirstLearnExpanded ?? true),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  ...List.generate(reviewStages.length, (index) {
                    final review = reviewStages[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == reviewStages.length - 1
                            ? 0
                            : AppSpacing.m,
                      ),
                      child: _ReviewRoundSection(
                        l10n: l10n,
                        progress: progress,
                        review: review,
                        now: now,
                        collectionId: widget.collectionId,
                        audioItemId: widget.audioItemId,
                        isExpanded: _isReviewRoundExpanded(
                          review.stage,
                          progress,
                        ),
                        onToggle: () =>
                            _toggleReviewRoundExpanded(review.stage),
                      ),
                    );
                  }),
                ],
              ),
            ),
            _BottomButton(
              l10n: l10n,
              progress: progress,
              startLearningStep: hasTranscript ? stepStartLearning : null,
              onPressed: hasTranscript && !isLockedReview
                  ? () => _handleStartLearning(context, progress)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建复习阶段列表（review0 ~ review28，共 7 个）
  List<_ReviewStageData> _buildReviewStages(AppLocalizations l10n) {
    return [
      _ReviewStageData(
        name: l10n.reviewRound0,
        interval: l10n.reviewIntervalNow,
        stage: LearningStage.review0,
      ),
      _ReviewStageData(
        name: l10n.reviewRound1,
        interval: l10n.reviewInterval1d,
        stage: LearningStage.review1,
      ),
      _ReviewStageData(
        name: l10n.reviewRound2,
        interval: l10n.reviewInterval2d,
        stage: LearningStage.review2,
      ),
      _ReviewStageData(
        name: l10n.reviewRound4,
        interval: l10n.reviewInterval4d,
        stage: LearningStage.review4,
      ),
      _ReviewStageData(
        name: l10n.reviewRound7,
        interval: l10n.reviewInterval7d,
        stage: LearningStage.review7,
      ),
      _ReviewStageData(
        name: l10n.reviewRound14,
        interval: l10n.reviewInterval14d,
        stage: LearningStage.review14,
      ),
      _ReviewStageData(
        name: l10n.reviewRound28,
        interval: l10n.reviewInterval28d,
        stage: LearningStage.review28,
      ),
    ];
  }

  /// 读取复习轮次展开态（仅首次按默认规则初始化）
  ///
  /// 默认规则：
  /// - 已完成轮次：折叠
  /// - 当前进行中轮次：展开
  /// - 未来轮次：折叠
  bool _isReviewRoundExpanded(LearningStage stage, LearningProgress? progress) {
    return _reviewRoundExpandedMap.putIfAbsent(
      stage,
      () => progress?.isCurrentStage(stage) ?? false,
    );
  }

  /// 切换单个复习轮次的展开态
  void _toggleReviewRoundExpanded(LearningStage stage) {
    setState(() {
      _reviewRoundExpandedMap[stage] =
          !(_reviewRoundExpandedMap[stage] ?? false);
    });
  }
}

/// 顶部进度卡片 — 圆环进度 + 状态文字 + 逾期徽章 + 音频元信息
class _ProgressCard extends StatelessWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;
  final AudioItem? audioItem;
  final DateTime now;

  const _ProgressCard({
    required this.l10n,
    this.progress,
    this.audioItem,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = progress?.progressPercent ?? 0.0;
    final percentText = '${(percent * 100).round()}%';

    final isInProgress = _isInProgress();
    final overdueText = _getOverdueText();
    // 第一行徽章：进行中显示 In Progress，否则显示逾期
    final badgeText = isInProgress ? l10n.learningInProgress : overdueText;
    final badgeIsError = !isInProgress && overdueText != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            // 左侧：圆环进度
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                painter: _ProgressRingPainter(
                  progress: percent,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  progressColor: theme.colorScheme.primary,
                ),
                child: Center(
                  child: Text(
                    percentText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            // 右侧：三行信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第一行：大阶段 + 逾期徽章
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _getStageText(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: AppSpacing.s),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: badgeIsError
                                ? theme.colorScheme.error.withValues(alpha: 0.1)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: badgeIsError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: badgeIsError
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // 第二行：子阶段
                  if (_getSubStageText() case final subStage?) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subStage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  // 第三行：音频元信息
                  if (audioItem != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _buildAudioInfo(theme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建音频元信息行
  Widget _buildAudioInfo(ThemeData theme) {
    final item = audioItem!;
    final chips = <Widget>[];

    if (item.totalDuration > 0) {
      chips.add(
        _InfoChip(
          icon: Icons.timer_outlined,
          label: SubtitleParser.formatDuration(
            Duration(seconds: item.totalDuration),
          ),
          theme: theme,
        ),
      );
    }
    if (item.sentenceCount > 0) {
      chips.add(
        _InfoChip(
          icon: Icons.format_list_numbered,
          label: l10n.sentenceCountLabel(item.sentenceCount),
          theme: theme,
        ),
      );
    }
    if (item.wordCount > 0) {
      chips.add(
        _InfoChip(
          icon: Icons.text_fields,
          label: l10n.wordCountLabel(item.wordCount),
          theme: theme,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.xs,
      children: chips,
    );
  }

  /// 第一行：大阶段文字
  String _getStageText() {
    if (progress == null || !progress!.isStarted) {
      return l10n.learningPlanNotStarted;
    }
    if (progress!.isCompleted) {
      return l10n.learningCompleted;
    }
    return reviewStageLabel(l10n, progress!.currentStage);
  }

  /// 第二行：子阶段文字（未开始/已完成时返回 null）
  String? _getSubStageText() {
    if (progress == null || !progress!.isStarted || progress!.isCompleted) {
      return null;
    }
    final subStageName = switch (progress!.currentSubStage) {
      SubStageType.blindListen => l10n.stepBlindListening,
      SubStageType.intensiveListen => l10n.stepIntensiveListening,
      SubStageType.listenAndRepeat => l10n.stepShadowing,
      SubStageType.retell => l10n.stepRetelling,
      SubStageType.reviewDifficultPractice => l10n.reviewDifficultPracticeTitle,
      SubStageType.reviewRetellParagraph => l10n.retellBriefingTitle,
      SubStageType.reviewRetellSummary => l10n.retellBriefingTitle,
    };
    return subStageName;
  }

  /// 是否正在学习中（当前阶段已完成至少 1 个子阶段）
  bool _isInProgress() {
    if (progress == null || !progress!.isStarted || progress!.isCompleted) {
      return false;
    }
    return progress!.currentSubStageIndex > 0;
  }

  /// 获取逾期文案（未逾期返回 null）
  String? _getOverdueText() {
    if (progress == null || !progress!.isReviewOverdueAt(now)) return null;
    final overdue = progress!.overdueDurationAt(now);
    if (overdue == null || overdue.inDays > 7) return l10n.reviewDue;
    if (overdue.inDays > 0) return l10n.overdueDays(overdue.inDays);
    final hours = overdue.inHours.clamp(1, 999);
    return l10n.overdueHours(hours);
  }
}

/// 圆环进度绘制器
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  _ProgressRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 6.0;

    // 背景圆环
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度圆弧
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 首次学习区域 — 默认展开，显示 4 个步骤
///
/// 已完成的盲听步骤支持点击进入自由练习模式。
class _FirstStudySection extends ConsumerWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;

  /// 合集 ID（导航用，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID（导航用）
  final String audioItemId;

  /// 是否展开
  final bool isExpanded;

  /// 折叠/展开切换回调
  final VoidCallback onToggle;

  const _FirstStudySection({
    required this.l10n,
    this.progress,
    required this.collectionId,
    required this.audioItemId,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final completedCount = progress?.completedFirstStudySteps ?? 0;
    final firstLearnStage = LearningStage.firstLearn;
    final isFirstLearnCompleted =
        progress?.isStageCompleted(LearningStage.firstLearn) ?? false;

    /// 子步骤的 UI 数据映射
    final stepDataMap = {
      SubStageType.blindListen: _StepData(
        icon: Icons.headphones,
        iconColor: Colors.blue,
        name: l10n.stepBlindListening,
        description: l10n.stepBlindListeningDesc,
      ),
      SubStageType.intensiveListen: _StepData(
        icon: Icons.hearing,
        iconColor: Colors.indigo,
        name: l10n.stepIntensiveListening,
        description: l10n.stepIntensiveListeningDesc,
      ),
      SubStageType.listenAndRepeat: _StepData(
        icon: Icons.record_voice_over,
        iconColor: Colors.orange,
        name: l10n.stepShadowing,
        description: l10n.stepShadowingDesc,
      ),
      SubStageType.retell: _StepData(
        icon: Icons.chat,
        iconColor: Colors.teal,
        name: l10n.stepRetelling,
        description: l10n.stepRetellingDesc,
      ),
    };

    final subStages = firstLearnStage.subStages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行（可点击展开/折叠）
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                const Text('🌱', style: TextStyle(fontSize: 20)),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.firstStudy,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isFirstLearnCompleted ? Colors.green : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        isFirstLearnCompleted
                            ? '✅'
                            : progress?.isCurrentStage(
                                    LearningStage.firstLearn,
                                  ) ??
                                  false
                            ? '📖'
                            : '🔒',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Text(
                  l10n.stepProgress(completedCount, subStages.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isFirstLearnCompleted
                        ? Colors.green
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展开的步骤列表（无动画，直接切换）
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.s),
          Column(
            children: List.generate(subStages.length, (index) {
              final subStage = subStages[index];
              final stepData = stepDataMap[subStage]!;
              final isCompleted =
                  progress?.isSubStageCompleted(firstLearnStage, subStage) ??
                  false;
              final isCurrent =
                  progress?.isCurrentSubStage(firstLearnStage, subStage) ??
                  false;

              // 各步骤显示完成统计
              String? subtitle;
              if (subStage == SubStageType.blindListen) {
                // 盲听：已听遍数 + 难度
                final passCount = progress?.blindListenPassCount ?? 0;
                final parts = <String>[];
                if (passCount > 0) {
                  parts.add(l10n.blindListenPassInfo(passCount));
                }
                if (progress?.isSubStageCompleted(firstLearnStage, subStage) ??
                    false) {
                  parts.add(
                    l10n.difficultyLabel(
                      _difficultyName(l10n, progress!.difficulty),
                    ),
                  );
                }
                if (parts.isNotEmpty) {
                  subtitle = parts.join(' · ');
                }
              } else if (subStage == SubStageType.intensiveListen) {
                // 精听：仅当前或已完成步骤显示统计
                if (isCompleted || isCurrent) {
                  subtitle = _buildIntensiveListenSubtitle(ref, l10n);
                }
              } else if (subStage == SubStageType.listenAndRepeat) {
                // 跟读：已完成且无难句时显示自动完成提示
                final bookmarkCount =
                    ref
                        .watch(_bookmarkCountProvider(audioItemId))
                        .valueOrNull ??
                    0;
                if (isCompleted && bookmarkCount == 0) {
                  subtitle = l10n.autoCompletedNoDifficult;
                } else if (isCompleted || isCurrent) {
                  subtitle = _buildShadowingSubtitle(ref, l10n);
                }
              } else if (subStage == SubStageType.retell) {
                // 复述：仅当前或已完成步骤显示统计
                if (isCompleted || isCurrent) {
                  subtitle = _buildRetellSubtitle(l10n);
                }
              }

              // 已完成步骤支持点击进入自由练习
              VoidCallback? onTap;
              if (isCompleted && subStage == SubStageType.blindListen) {
                onTap = () => _startFreePlayBlindListen(context, ref);
              } else if (isCompleted &&
                  subStage == SubStageType.intensiveListen) {
                onTap = () => _startFreePlayIntensiveListen(context, ref);
              } else if (isCompleted &&
                  subStage == SubStageType.listenAndRepeat) {
                // 无难句自动完成的跟读步骤：点击只显示提示
                final bookmarkCount =
                    ref
                        .watch(_bookmarkCountProvider(audioItemId))
                        .valueOrNull ??
                    0;
                if (bookmarkCount == 0) {
                  onTap = () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.autoCompletedNoDifficult)),
                    );
                  };
                } else {
                  onTap = () => _startFreePlayListenAndRepeat(context, ref);
                }
              } else if (isCompleted && subStage == SubStageType.retell) {
                onTap = () => _startFreePlayRetell(context, ref);
              }

              return _StepCard(
                stepNumber: index + 1,
                icon: stepData.icon,
                iconColor: stepData.iconColor,
                name: stepData.name,
                description: stepData.description,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                isFirst: index == 0,
                isLast: index == subStages.length - 1,
                subtitle: subtitle,
                onTap: onTap,
              );
            }),
          ),
        ],
      ],
    );
  }

  /// 构建精听卡片副标题（实时难句数 + 总完成遍数）
  String? _buildIntensiveListenSubtitle(WidgetRef ref, AppLocalizations l10n) {
    final parts = <String>[];

    // 实时查询书签数量（难句数）
    final bookmarkCount =
        ref.watch(_bookmarkCountProvider(audioItemId)).valueOrNull ?? 0;
    if (bookmarkCount > 0) {
      parts.add(l10n.difficultSentenceCount(bookmarkCount));
    }

    // 精听总完成遍数
    if (progress?.intensiveListenPassCount case final count? when count > 0) {
      parts.add(l10n.intensiveListenPassInfo(count));
    }

    return parts.isNotEmpty ? parts.join(' · ') : null;
  }

  /// 构建跟读卡片副标题（实时难句数 + 总完成遍数）
  String? _buildShadowingSubtitle(WidgetRef ref, AppLocalizations l10n) {
    final parts = <String>[];

    // 实时查询书签数量（难句数）
    final bookmarkCount =
        ref.watch(_bookmarkCountProvider(audioItemId)).valueOrNull ?? 0;
    if (bookmarkCount > 0) {
      parts.add(l10n.difficultSentenceCount(bookmarkCount));
    }

    // 跟读总完成遍数
    if (progress?.shadowingPassCount case final count? when count > 0) {
      parts.add(l10n.shadowingPassInfo(count));
    }

    return parts.isNotEmpty ? parts.join(' · ') : null;
  }

  /// 进入自由练习盲听模式
  Future<void> _startFreePlayBlindListen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final sentences = ref.read(listeningPracticeProvider).sentences;
    if (sentences.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final totalDuration = ref.read(audioEngineProvider).totalDuration;

    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      estimatedDurationText: totalDuration != null
          ? formatEstimatedDuration(l10n, totalDuration)
          : null,
      onStartPractice: (targetDuration, pauseMultiplier) async {
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        final settings = BlindListenSettings.fromMultiplier(pauseMultiplier);
        await ref
            .read(learningSessionProvider.notifier)
            .enterBlindListenMode(
              audioItemId,
              isFreePlay: true,
              paragraphs: paragraphs,
              settings: settings,
            );
        if (context.mounted) {
          context.push(AppRoutes.blindListenPlayer(collectionId, audioItemId));
        }
      },
    );
  }

  /// 进入自由练习精听模式（直接进入，不弹 briefing sheet）
  Future<void> _startFreePlayIntensiveListen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.sentences.isEmpty) return;

    await ref
        .read(learningSessionProvider.notifier)
        .enterIntensiveListenMode(
          audioItemId,
          lpState.sentences,
          isFreePlay: true,
        );
    if (context.mounted) {
      context.push(AppRoutes.intensiveListenPlayer(collectionId, audioItemId));
    }
  }

  /// 进入自由练习跟读模式（直接进入，不弹 briefing sheet）
  Future<void> _startFreePlayListenAndRepeat(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      SubStageType.listenAndRepeat,
    );
    if (!allowed || !context.mounted) return;

    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.sentences.isEmpty) return;

    await ref
        .read(listenAndRepeatControllerProvider.notifier)
        .initialize(
          audioItemId: audioItemId,
          allSentences: lpState.sentences,
          isFreePlay: true,
        );
    if (context.mounted) {
      context.push(AppRoutes.listenAndRepeatPlayer(collectionId, audioItemId));
    }
  }

  /// 构建复述卡片副标题（总完成遍数）
  String? _buildRetellSubtitle(AppLocalizations l10n) {
    if (progress?.retellPassCount case final count? when count > 0) {
      return l10n.retellPassInfo(count);
    }
    return null;
  }

  /// 进入自由练习复述模式（弹 briefing sheet 选择段落时长）
  void _startFreePlayRetell(BuildContext context, WidgetRef ref) {
    _startFreePlayRetellAsync(context, ref);
  }

  /// 进入自由练习复述前先检查本地 ASR，避免步骤卡片直达绕过拦截。
  Future<void> _startFreePlayRetellAsync(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      SubStageType.retell,
    );
    if (!allowed || !context.mounted) return;

    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.sentences.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final totalDuration = ref.read(audioEngineProvider).totalDuration;
    final retellEstimate = totalDuration != null ? totalDuration * 3 : null;

    showRetellBriefingSheet(
      context: context,
      sentences: lpState.sentences,
      defaultSeconds: retellDefaultSeconds(LearningStage.firstLearn),
      estimatedDurationText: retellEstimate != null
          ? formatEstimatedDuration(l10n, retellEstimate)
          : null,
      onStartPractice: (targetDuration, pauseMultiplier) async {
        final paragraphs = groupSentencesIntoParagraphs(
          lpState.sentences,
          targetDuration,
        );
        final keywordsMap = extractKeywords(
          lpState.sentences,
          ratio: KeywordRatio.oneThird,
        );

        await ref
            .read(learningSessionProvider.notifier)
            .enterRetellMode(
              audioItemId,
              paragraphs,
              keywordsMap,
              isFreePlay: true,
            );
        if (pauseMultiplier >= 0) {
          final player = ref.read(retellPlayerProvider.notifier);
          final current = ref.read(retellPlayerProvider).settings;
          player.updateSettings(
            current.copyWith(
              pauseMode: PauseMode.multiplier,
              pauseMultiplier: pauseMultiplier,
            ),
          );
        }
        if (context.mounted) {
          context.push(AppRoutes.retellPlayer(collectionId, audioItemId));
        }
      },
    );
  }
}

/// 步骤数据模型（内部使用）
class _StepData {
  final IconData icon;
  final Color? iconColor;
  final String name;
  final String description;

  const _StepData({
    required this.icon,
    this.iconColor,
    required this.name,
    required this.description,
  });
}

/// 单个步骤卡片 — 支持三态：已完成、当前、未开始
class _StepCard extends StatelessWidget {
  final int stepNumber;
  final IconData icon;
  final Color? iconColor;
  final String name;
  final String description;
  final bool isCompleted;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;

  /// 可选的附加信息（如"已听 X 遍"）
  final String? subtitle;

  /// 点击回调（如已完成的盲听步骤可点击进入自由练习）
  final VoidCallback? onTap;

  const _StepCard({
    required this.stepNumber,
    required this.icon,
    this.iconColor,
    required this.name,
    required this.description,
    required this.isCompleted,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间线（圆形指示器垂直居中）
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // 上方竖线（第一个卡片用透明占位）
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? (theme.brightness == Brightness.dark
                              ? Colors.transparent
                              : Colors.green.shade50)
                        : isCurrent
                        ? null
                        : theme.colorScheme.surfaceContainerHighest,
                    border: isCompleted
                        ? Border.all(
                            color: theme.brightness == Brightness.dark
                                ? Colors.green.shade400
                                : Colors.green,
                            width: 1.5,
                          )
                        : isCurrent
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: theme.brightness == Brightness.dark
                                ? Colors.green.shade300
                                : Colors.green.shade700,
                          )
                        : Text(
                            '$stepNumber',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                // 下方竖线（最后一个卡片用透明占位）
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          // 右侧卡片内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s),
              child: Card(
                clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: isCompleted
                              ? (iconColor ?? theme.colorScheme.primary)
                                    .withAlpha(100)
                              : iconColor ?? theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted
                                      ? theme.colorScheme.outline
                                      : null,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isCompleted
                                      ? theme.colorScheme.outline
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  subtitle!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个复习轮次的数据模型
class _ReviewStageData {
  final String name;
  final String interval;
  final LearningStage stage;

  const _ReviewStageData({
    required this.name,
    required this.interval,
    required this.stage,
  });
}

/// 单个复习轮次区块（与首次学习同级）
///
/// 视觉与首次学习区块保持一致：标题行可独立折叠/展开，展开后显示子阶段。
class _ReviewRoundSection extends ConsumerWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;
  final _ReviewStageData review;
  final DateTime now;

  /// 合集 ID（导航用）
  final String? collectionId;

  /// 音频项 ID（导航用）
  final String audioItemId;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ReviewRoundSection({
    required this.l10n,
    this.progress,
    required this.review,
    required this.now,
    required this.collectionId,
    required this.audioItemId,
    required this.isExpanded,
    required this.onToggle,
  });

  /// 计算当前轮次已完成子阶段数
  int _completedSubStageCount() {
    if (progress == null) return 0;
    if (progress!.isStageCompleted(review.stage)) {
      return review.stage.subStageCount;
    }
    if (progress!.isCurrentStage(review.stage)) {
      return progress!.currentSubStageIndex
          .clamp(0, review.stage.subStageCount)
          .toInt();
    }
    return 0;
  }

  /// 当前复习轮次时间文案（仅当前轮次显示）。
  ///
  /// 展示优先级：已有进度→"学习中" > 未到时间倒计时 > 逾期提示 > 可复习。
  String? _reviewTimingText(BuildContext context) {
    if (progress == null) return null;
    if (!progress!.isCurrentStage(review.stage)) return null;

    // 已有进度（至少完成 1 个子阶段）→ 显示"学习中"
    if (_completedSubStageCount() > 0) {
      return l10n.learningInProgress;
    }

    final nextReview = progress!.nextReviewAt;
    if (nextReview == null) return null;

    if (now.isBefore(nextReview)) {
      final diff = nextReview.difference(now);
      if (diff.inDays > 0) {
        return l10n.reviewUnlockIn(diff.inDays);
      }
      return l10n.reviewUnlockInHours(diff.inHours.clamp(1, 999));
    }

    if (progress!.isReviewOverdueAt(now)) {
      return _formatOverdueText(context, progress!.overdueDurationAt(now));
    }

    return l10n.reviewDue;
  }

  /// 解锁状态文案（非当前轮次、非已完成轮次显示）。
  ///
  /// 已完成：不显示文案（由 ✅ emoji 传达）。
  /// 当前轮次：由 _reviewTimingText 处理。
  /// 未来阶段：返回 null，回退到固定间隔文案。
  String? _unlockStatusText() {
    if (progress == null) return null;
    // 已完成的轮次：不显示文案（✅ emoji 已传达完成语义）
    if (progress!.isStageCompleted(review.stage)) return null;
    // 当前轮次由 _reviewTimingText 处理
    if (progress!.isCurrentStage(review.stage)) return null;
    // 未来阶段：返回 null，由固定间隔文案兜底
    return null;
  }

  /// 逾期措辞：短期保留时间信息，长期只显示"待复习"。
  ///
  /// - 无时长 / >7天 → "待复习"
  /// - ≤7天 → "待复习 · X天前到期"
  /// - <1天 → "待复习 · X小时前到期"
  String _formatOverdueText(BuildContext context, Duration? overdue) {
    // 无时长信息或长期逾期（>7天）只显示"待复习"
    if (overdue == null || overdue.inDays > 7) {
      return l10n.reviewDue;
    }
    if (overdue.inDays > 0) {
      return l10n.overdueDays(overdue.inDays);
    }
    final hours = overdue.inHours.clamp(1, 999);
    return l10n.overdueHours(hours);
  }

  /// 复习子阶段名称与描述映射
  _StepData _subStageData(BuildContext context, SubStageType subStage) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return switch (subStage) {
      SubStageType.blindListen => _StepData(
        icon: Icons.headphones,
        iconColor: Colors.blue,
        name: l10n.stepBlindListening,
        description: isZh
            ? '再次盲听，感受理解力的变化'
            : 'Listen again to feel how your comprehension has improved',
      ),
      SubStageType.intensiveListen => _StepData(
        icon: Icons.hearing,
        iconColor: Colors.indigo,
        name: l10n.stepIntensiveListening,
        description: l10n.stepIntensiveListeningDesc,
      ),
      SubStageType.listenAndRepeat => _StepData(
        icon: Icons.record_voice_over,
        iconColor: Colors.orange,
        name: l10n.stepShadowing,
        description: l10n.stepShadowingDesc,
      ),
      SubStageType.retell => _StepData(
        icon: Icons.chat,
        iconColor: Colors.teal,
        name: l10n.stepRetelling,
        description: l10n.stepRetellingDesc,
      ),
      SubStageType.reviewDifficultPractice => _StepData(
        icon: Icons.fitness_center,
        iconColor: Colors.orange,
        name: isZh ? '难句补练' : 'Difficult sentence practice',
        description: isZh
            ? '重听难句，听不懂就跟读补练'
            : 'Re-listen to difficult sentences; shadow the ones you still miss',
      ),
      SubStageType.reviewRetellParagraph => _StepData(
        icon: Icons.chat,
        iconColor: Colors.teal,
        name: isZh ? '段落复述' : 'Paragraph Retelling',
        description: isZh
            ? '再次复述，提升理解和表达能力'
            : 'Retell again to improve comprehension and expression',
      ),
      SubStageType.reviewRetellSummary => _StepData(
        icon: Icons.summarize,
        iconColor: Colors.cyan,
        name: isZh ? '全文复述' : 'Full Text Retelling',
        description: isZh
            ? '概述全文，梳理整体脉络，检验学习效果'
            : 'Summarize the full text, grasp its overall flow, and check how well you have learned it.',
      ),
    };
  }

  /// 进入自由练习盲听模式（复习阶段的全文盲听）
  Future<void> _startFreePlayBlindListen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final sentences = ref.read(listeningPracticeProvider).sentences;
    if (sentences.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final totalDuration = ref.read(audioEngineProvider).totalDuration;

    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      estimatedDurationText: totalDuration != null
          ? formatEstimatedDuration(l10n, totalDuration)
          : null,
      onStartPractice: (targetDuration, pauseMultiplier) async {
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        final settings = BlindListenSettings.fromMultiplier(pauseMultiplier);
        await ref
            .read(learningSessionProvider.notifier)
            .enterBlindListenMode(
              audioItemId,
              isFreePlay: true,
              paragraphs: paragraphs,
              settings: settings,
            );
        if (context.mounted) {
          context.push(AppRoutes.blindListenPlayer(collectionId, audioItemId));
        }
      },
    );
  }

  /// 进入自由练习难句补练模式
  Future<void> _startFreePlayDifficultPractice(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      SubStageType.reviewDifficultPractice,
    );
    if (!allowed || !context.mounted) return;

    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.sentences.isEmpty) return;

    await ref
        .read(learningSessionProvider.notifier)
        .enterReviewDifficultPracticeMode(
          audioItemId,
          lpState.sentences,
          isFreePlay: true,
        );
    if (context.mounted) {
      context.push(
        AppRoutes.reviewDifficultPractice(collectionId, audioItemId),
      );
    }
  }

  /// 进入自由练习复述模式（段落复述 / 全文复述）
  Future<void> _startFreePlayRetell(
    BuildContext context,
    WidgetRef ref, {
    required bool isSummary,
  }) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      isSummary
          ? SubStageType.reviewRetellSummary
          : SubStageType.reviewRetellParagraph,
    );
    if (!allowed || !context.mounted) return;

    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.sentences.isEmpty) return;

    if (isSummary) {
      // 全文复述：全文作为单个段落，无需选择时长
      final keywordsMap = extractKeywords(
        lpState.sentences,
        ratio: KeywordRatio.oneThird,
      );
      await ref
          .read(learningSessionProvider.notifier)
          .enterRetellMode(
            audioItemId,
            [lpState.sentences],
            keywordsMap,
            isFreePlay: true,
          );
      if (context.mounted) {
        context.push(AppRoutes.retellPlayer(collectionId, audioItemId));
      }
      return;
    }

    // 段落复述：弹出简报面板让用户选择段落时长
    final l10n = AppLocalizations.of(context)!;
    final totalDuration = ref.read(audioEngineProvider).totalDuration;
    final retellEstimate = totalDuration != null ? totalDuration * 3 : null;

    showRetellBriefingSheet(
      context: context,
      sentences: lpState.sentences,
      defaultSeconds: retellDefaultSeconds(review.stage),
      estimatedDurationText: retellEstimate != null
          ? formatEstimatedDuration(l10n, retellEstimate)
          : null,
      onStartPractice: (targetDuration, pauseMultiplier) async {
        final paragraphs = groupSentencesIntoParagraphs(
          lpState.sentences,
          targetDuration,
        );
        final keywordsMap = extractKeywords(
          lpState.sentences,
          ratio: KeywordRatio.oneThird,
        );
        await ref
            .read(learningSessionProvider.notifier)
            .enterRetellMode(
              audioItemId,
              paragraphs,
              keywordsMap,
              isFreePlay: true,
            );
        if (pauseMultiplier >= 0) {
          final player = ref.read(retellPlayerProvider.notifier);
          final current = ref.read(retellPlayerProvider).settings;
          player.updateSettings(
            current.copyWith(
              pauseMode: PauseMode.multiplier,
              pauseMultiplier: pauseMultiplier,
            ),
          );
        }
        if (context.mounted) {
          context.push(AppRoutes.retellPlayer(collectionId, audioItemId));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subStages = review.stage.subStages;
    final completedCount = _completedSubStageCount();
    final timingText = _reviewTimingText(context);
    final unlockText = _unlockStatusText();
    // 当前轮次显示实时状态，其余轮次显示解锁状态，都没有则显示固定间隔
    final statusText = timingText ?? unlockText ?? review.interval;
    final isCompleted = progress?.isStageCompleted(review.stage) ?? false;
    final isCurrent = progress?.isCurrentStage(review.stage) ?? false;
    final isFuture = !isCompleted && !isCurrent;
    // 标题颜色：已完成→绿色，当前→默认，未来→弱化
    final titleColor = isCompleted
        ? Colors.green
        : isFuture
        ? theme.colorScheme.onSurfaceVariant
        : null;
    // 状态文案颜色：已完成→绿色，当前轮次→onSurfaceVariant，固定间隔→onSurfaceVariant
    final statusColor = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: isFuture ? 0.7 : 1.0,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  const Text('🔁', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          isCompleted
                              ? '✅'
                              : isCurrent
                              ? '📖'
                              : '🔒',
                          style: const TextStyle(fontSize: 16),
                        ),
                        // 状态文案内联到标题行（已完成阶段不显示）
                        if (!isCompleted) ...[
                          const SizedBox(width: AppSpacing.s),
                          Text(
                            statusText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    l10n.stepProgress(completedCount, subStages.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCompleted
                          ? Colors.green
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.s),
          Column(
            children: List.generate(subStages.length, (index) {
              final subStage = subStages[index];
              final subStageData = _subStageData(context, subStage);
              final isCompleted =
                  progress?.isSubStageCompleted(review.stage, subStage) ??
                  false;
              final isCurrent =
                  progress?.isCurrentSubStage(review.stage, subStage) ?? false;

              // 难句补练步骤：显示难句数量或自动完成提示
              String? subtitle;
              if (subStage == SubStageType.reviewDifficultPractice) {
                final bookmarkCount =
                    ref
                        .watch(_bookmarkCountProvider(audioItemId))
                        .valueOrNull ??
                    0;
                if (isCompleted && bookmarkCount == 0) {
                  subtitle = l10n.autoCompletedNoDifficultReview;
                } else if (bookmarkCount > 0) {
                  subtitle = l10n.difficultSentenceCount(bookmarkCount);
                }
              }

              // 已完成的复习子步骤支持点击进入自由练习
              VoidCallback? onTap;
              if (isCompleted) {
                // 无难句自动完成的补练步骤：点击只显示提示
                final bookmarkCount =
                    ref
                        .watch(_bookmarkCountProvider(audioItemId))
                        .valueOrNull ??
                    0;
                if (subStage == SubStageType.reviewDifficultPractice &&
                    bookmarkCount == 0) {
                  onTap = () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.autoCompletedNoDifficultReview),
                      ),
                    );
                  };
                } else {
                  onTap = switch (subStage) {
                    SubStageType.blindListen => () => _startFreePlayBlindListen(
                      context,
                      ref,
                    ),
                    SubStageType.reviewDifficultPractice =>
                      () => _startFreePlayDifficultPractice(context, ref),
                    SubStageType.reviewRetellParagraph =>
                      () =>
                          _startFreePlayRetell(context, ref, isSummary: false),
                    SubStageType.reviewRetellSummary =>
                      () => _startFreePlayRetell(context, ref, isSummary: true),
                    _ => null,
                  };
                }
              }

              return _StepCard(
                stepNumber: index + 1,
                icon: subStageData.icon,
                iconColor: subStageData.iconColor,
                name: subStageData.name,
                description: subStageData.description,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                isFirst: index == 0,
                isLast: index == subStages.length - 1,
                subtitle: subtitle,
                onTap: onTap,
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// 音频信息行 — 显示时长、句子数、单词数
/// 单个信息标签
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// 无字幕提醒横幅 — 提示用户需要上传字幕，支持直接打开字幕管理
class _NoTranscriptBanner extends StatelessWidget {
  final AppLocalizations l10n;
  final AudioItem audioItem;
  final GuideStep addSubtitleStep;

  const _NoTranscriptBanner({
    required this.l10n,
    required this.audioItem,
    required this.addSubtitleStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.onErrorContainer,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                l10n.noTranscriptWarning,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            GuideTarget(
              step: addSubtitleStep,
              child: FilledButton.icon(
                onPressed: () => _showManageSubtitlesSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addSubtitle),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.onErrorContainer,
                  foregroundColor: theme.colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.xs,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageSubtitlesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ManageSubtitlesSheet(audioItem: audioItem),
    );
  }
}

/// 底部固定按钮 — 根据进度显示不同文案
///
/// [onPressed] 为 null 时按钮禁用（例如无字幕时）。
class _BottomButton extends StatelessWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;
  final VoidCallback? onPressed;
  final GuideStep? startLearningStep;

  const _BottomButton({
    required this.l10n,
    this.progress,
    required this.onPressed,
    this.startLearningStep,
  });

  @override
  Widget build(BuildContext context) {
    final buttonText = (progress != null && progress!.isStarted)
        ? l10n.continueLearning
        : l10n.startLearning;

    final button = FilledButton(onPressed: onPressed, child: Text(buttonText));
    final guidedButton = startLearningStep != null
        ? GuideTarget(step: startLearningStep!, child: button)
        : button;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(width: double.infinity, child: guidedButton),
      ),
    );
  }
}

/// 难度等级本地化名称
String _difficultyName(AppLocalizations l10n, DifficultyLevel level) =>
    switch (level) {
      DifficultyLevel.veryEasy => l10n.difficultyVeryEasy,
      DifficultyLevel.easy => l10n.difficultyEasy,
      DifficultyLevel.medium => l10n.difficultyMedium,
      DifficultyLevel.hard => l10n.difficultyHard,
      DifficultyLevel.veryHard => l10n.difficultyVeryHard,
    };
