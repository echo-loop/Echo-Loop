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
import '../models/learning_plan.dart';
import '../models/learning_progress.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/time_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/listen_and_repeat/listen_and_repeat_controller.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/subtitle_parser.dart';
import '../theme/app_theme.dart';
import '../models/blind_listen_settings.dart';
import '../models/intensive_listen_settings.dart' show PauseMode;
import '../models/retell_settings.dart' show KeywordRatio;
import '../utils/blind_listen_duration_estimator.dart';
import '../utils/paragraph_grouping.dart';
import '../utils/playback_speed_default.dart';
import '../utils/retell_duration_estimator.dart';
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
  final _keyPauseLearning = GlobalKey();

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
      defaultPlaybackSpeed: defaultPlaybackSpeedFor(
        progress.difficulty,
        progress.currentStage,
      ),
      onStartPractice: (playbackSpeed, pauseMultiplier) {
        switch (subStage) {
          case SubStageType.reviewDifficultPractice:
            _startReviewDifficultPractice(
              context,
              playbackSpeed: playbackSpeed,
              pauseMultiplier: pauseMultiplier,
            );
          case SubStageType.reviewRetellSummary:
            _startReviewRetell(
              context,
              isSummary: true,
              playbackSpeed: playbackSpeed,
            );
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
        // 盲听 = 跳过静音开启时按字幕有效时长，否则按音频总时长
        return estimateBlindListenSessionDuration(
          sentences: ref.read(listeningPracticeProvider).sentences,
          fullAudioDuration: ref.read(audioEngineProvider).totalDuration,
          skipSilenceEnabled: ref.read(appSettingsProvider).skipSilenceEnabled,
        );
      case SubStageType.reviewDifficultPractice:
        // 难句补练 = 难句总时长 × 2（盲听 + 跟读）
        final lpState = ref.read(listeningPracticeProvider);
        final difficultDuration = lpState.sentences
            .where((s) => s.isBookmarked)
            .fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);
        if (difficultDuration == Duration.zero) return null;
        return difficultDuration * 2;
      case SubStageType.reviewRetellSummary:
        // 全文复述 = 真实播放（字幕 wall-clock）+ smart 停顿
        // 全文作为单段，pauseMultiplier=-1 走 smart 模式
        final sentences = ref.read(listeningPracticeProvider).sentences;
        if (sentences.isEmpty) return null;
        return estimateRetellSessionDuration(
          sentences: sentences,
          targetSeconds: -1,
          pauseMultiplier: -1,
        );
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

    final progressForSpeed = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      stageLabel: reviewStageLabel(l10n, stage),
      estimatedDurationText: estimatedText,
      defaultPlaybackSpeed: progressForSpeed != null
          ? defaultPlaybackSpeedFor(progressForSpeed.difficulty, stage)
          : 1.0,
      onStartPractice: (targetDuration, pauseMultiplier, playbackSpeed) async {
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        final settings = BlindListenSettings.fromMultiplier(
          pauseMultiplier,
        ).copyWith(playbackSpeed: playbackSpeed);
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
  Future<void> _startReviewDifficultPractice(
    BuildContext context, {
    double playbackSpeed = 1.0,
    double pauseMultiplier = -1.0,
  }) async {
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
      // 推进后根据新位置自动进入下一子步骤（复述 / v2 review0 的全文盲听）
      _navigateToNextReviewSubStageFromPlan(context);
      return;
    }

    await ref
        .read(learningSessionProvider.notifier)
        .enterReviewDifficultPracticeMode(
          widget.audioItemId,
          lpState.sentences,
          playbackSpeed: playbackSpeed,
          pauseMultiplier: pauseMultiplier,
        );
    if (!context.mounted) return;
    context.push(
      AppRoutes.reviewDifficultPractice(
        widget.collectionId,
        widget.audioItemId,
      ),
    );
  }

  /// 自动完成难句补练后，按新的 `currentSubStage` 自动进入下一个子步骤。
  ///
  /// 处理：
  /// - v1 review0：reviewRetellParagraph → 段落复述
  /// - v2 review0：blindListen → 复习盲听
  /// - 中间轮 review1~14：blindListen / reviewRetellParagraph
  /// - 末轮 review28：blindListen / reviewRetellSummary
  /// - 跨阶段推进到 completed / firstLearn 等其它情况：不导航，回到计划页。
  void _navigateToNextReviewSubStageFromPlan(BuildContext context) {
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    if (progress == null) return;
    if (!progress.isInReviewStage) return;

    switch (progress.currentSubStage) {
      case SubStageType.blindListen:
        _startReviewBlindListen(context, stage: progress.currentStage);
      case SubStageType.reviewRetellParagraph:
        _startReviewRetell(context, isSummary: false);
      case SubStageType.reviewRetellSummary:
        _startReviewRetell(context, isSummary: true);
      default:
        // 推进后罕见落到难句补练等情况，回到计划页让用户重新选择
        break;
    }
  }

  /// 复习复述：复用 RetellPlayerScreen
  ///
  /// [isSummary] 为 true 时全文作为单个段落（reviewRetellSummary）
  Future<void> _startReviewRetell(
    BuildContext context, {
    required bool isSummary,
    double playbackSpeed = 1.0,
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
      // reviewRetellSummary：全文作为单个段落，无需选择时长；速度沿用 briefing 选定值。
      await ref.read(learningSessionProvider.notifier).enterRetellMode(
        widget.audioItemId,
        [lpState.sentences],
        playbackSpeed: playbackSpeed,
      );
      if (!context.mounted) return;
      context.push(
        AppRoutes.retellPlayer(widget.collectionId, widget.audioItemId),
      );
      return;
    }

    // reviewRetellParagraph：弹出简报面板让用户选择段落时长
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    final currentStage = progress?.currentStage;

    // 复习阶段显示阶段名；预估时长由 briefing sheet 内部按真实公式动态计算
    final l10n = AppLocalizations.of(context)!;
    final isReview =
        currentStage != null && currentStage != LearningStage.firstLearn;

    final effectiveStage = currentStage ?? LearningStage.firstLearn;
    showRetellBriefingSheet(
      context: context,
      sentences: lpState.sentences,
      defaultSeconds: retellDefaultSeconds(currentStage),
      stageLabel: isReview ? reviewStageLabel(l10n, currentStage) : null,
      defaultKeywordRatio: progress != null
          ? KeywordRatio.forDifficultyAndStage(
              progress.difficulty,
              effectiveStage,
            )
          : null,
      defaultPlaybackSpeed: progress != null
          ? defaultPlaybackSpeedFor(progress.difficulty, effectiveStage)
          : 1.0,
      onStartPractice:
          (targetDuration, pauseMultiplier, keywordRatio, playbackSpeed) async {
            final paragraphs = groupSentencesIntoParagraphs(
              lpState.sentences,
              targetDuration,
            );
            await ref
                .read(learningSessionProvider.notifier)
                .enterRetellMode(
                  widget.audioItemId,
                  paragraphs,
                  overrideKeywordRatio: keywordRatio,
                  playbackSpeed: playbackSpeed,
                );
            _applyRetellPauseMultiplier(pauseMultiplier);
            if (!context.mounted) return;
            context.push(
              AppRoutes.retellPlayer(widget.collectionId, widget.audioItemId),
            );
          },
      // 按计划学习路径才显示「跳过」按钮；自由练习路径无此回调
      onSkip: () async {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .skipCurrentSubStage(widget.audioItemId);
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
    final estimatedDuration = estimateBlindListenSessionDuration(
      sentences: sentences,
      fullAudioDuration: ref.read(audioEngineProvider).totalDuration,
      skipSilenceEnabled: ref.read(appSettingsProvider).skipSilenceEnabled,
    );

    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      estimatedDurationText: estimatedDuration != null
          ? formatEstimatedDuration(l10n, estimatedDuration)
          : null,
      onStartPractice: (targetDuration, pauseMultiplier, playbackSpeed) async {
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        final settings = BlindListenSettings.fromMultiplier(
          pauseMultiplier,
        ).copyWith(playbackSpeed: playbackSpeed);
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
      defaultPlaybackSpeed: 1.0,
      onStartPractice: (playbackSpeed, pauseMultiplier) async {
        await ref
            .read(learningSessionProvider.notifier)
            .enterIntensiveListenMode(
              widget.audioItemId,
              lpState.sentences,
              playbackSpeed: playbackSpeed,
              pauseMultiplier: pauseMultiplier,
            );
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
      defaultPlaybackSpeed: progress != null
          ? defaultPlaybackSpeedFor(
              progress.difficulty,
              LearningStage.firstLearn,
            )
          : 1.0,
      onStartPractice: (playbackSpeed, pauseMultiplier) async {
        await ref
            .read(listenAndRepeatControllerProvider.notifier)
            .initialize(
              audioItemId: widget.audioItemId,
              allSentences: lpState.sentences,
              isFreePlay: false,
              playbackSpeed: playbackSpeed,
              pauseMultiplier: pauseMultiplier,
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

    final progressForDefault = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    final stageForDefault =
        progressForDefault?.currentStage ?? LearningStage.firstLearn;
    showRetellBriefingSheet(
      context: context,
      sentences: lpState.sentences,
      defaultSeconds: retellDefaultSeconds(stageForDefault),
      defaultKeywordRatio: progressForDefault != null
          ? KeywordRatio.forDifficultyAndStage(
              progressForDefault.difficulty,
              stageForDefault,
            )
          : null,
      defaultPlaybackSpeed: progressForDefault != null
          ? defaultPlaybackSpeedFor(
              progressForDefault.difficulty,
              stageForDefault,
            )
          : 1.0,
      onStartPractice:
          (targetDuration, pauseMultiplier, keywordRatio, playbackSpeed) async {
            final paragraphs = groupSentencesIntoParagraphs(
              lpState.sentences,
              targetDuration,
            );

            await ref
                .read(learningSessionProvider.notifier)
                .enterRetellMode(
                  widget.audioItemId,
                  paragraphs,
                  overrideKeywordRatio: keywordRatio,
                  playbackSpeed: playbackSpeed,
                );
            _applyRetellPauseMultiplier(pauseMultiplier);
            if (!context.mounted) return;
            context.push(
              AppRoutes.retellPlayer(widget.collectionId, widget.audioItemId),
            );
          },
      // 按计划学习路径才显示「跳过」按钮；自由练习路径无此回调
      onSkip: () async {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .skipCurrentSubStage(widget.audioItemId);
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

    // 当前音频所属的所有合集名（按合集列表顺序），用于 AppBar 副标题
    final collectionNames = ref.watch(
      collectionListProvider.select((s) {
        final ids = s.audioToCollectionsMap[widget.audioItemId] ?? const [];
        if (ids.isEmpty) return const <String>[];
        final idSet = ids.toSet();
        return s.collections
            .where((c) => idSet.contains(c.id))
            .map((c) => c.name)
            .toList(growable: false);
      }),
    );

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
    final stepPauseLearning = GuideStep(
      key: _keyPauseLearning,
      title: l10n.guidePlanPauseLearningTitle,
      description: l10n.guidePlanPauseLearningDescription,
    );

    // 暂停学习按钮仅在已开始学习且当前未暂停时才会渲染，引导也只在此时
    // 触发；和「自由练习 / 按计划学习」flow 隔离，让用户开始学习后再看到。
    final showPauseLearningGuide =
        hasTranscript &&
        (progress?.isStarted ?? false) &&
        !(progress?.isPaused ?? false);

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
      GuideFlow(
        flowId: GuideFlowIds.learningPlanPauseLearning,
        shouldRun: showPauseLearningGuide,
        steps: [stepPauseLearning],
      ),
    ];

    return GuideFlowSequenceHost(
      flows: flows,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: _AppBarTitle(
            audioName: audioItem.name,
            collectionNames: collectionNames,
          ),
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
              audioItemId: widget.audioItemId,
              audioItemName: audioItem.name,
              startLearningStep: hasTranscript ? stepStartLearning : null,
              pauseLearningStep: showPauseLearningGuide
                  ? stepPauseLearning
                  : null,
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

/// AppBar 标题：音频名 + 所属合集副标题
///
/// 没有所属合集时只显示音频名（与原行为一致）。
/// 多合集用「、」拼接。
class _AppBarTitle extends StatelessWidget {
  final String audioName;
  final List<String> collectionNames;

  const _AppBarTitle({required this.audioName, required this.collectionNames});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (collectionNames.isEmpty) {
      return Text(audioName);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          audioName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                collectionNames.join('、'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 顶部进度卡片 — 圆环进度 + 状态文字 + 逾期徽章 + 音频元信息
class _ProgressCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // 没有 audioItem 时（理论不出现，因 progress 同源）退化到全局默认 plan。
    final plan = audioItem == null
        ? ref.watch(learningPlanProvider)
        : ref.watch(learningPlanForAudioProvider(audioItem!.id));
    final completedKeys = audioItem == null
        ? const <String>{}
        : ref
              .watch(learningProgressNotifierProvider)
              .completionsFor(audioItem!.id);
    final percent = progress?.progressPercent(plan, completedKeys) ?? 0.0;
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
    final plan = ref.watch(learningPlanForAudioProvider(audioItemId));
    final completedKeys = ref
        .watch(learningProgressNotifierProvider)
        .completionsFor(audioItemId);
    final completedCount =
        progress?.completedFirstStudySteps(plan, completedKeys) ?? 0;
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

    // 迭代顺序 = 当前 plan 顺序 + 历史外延项（已完成或已跳过但不在当前 plan 内）。
    // firstLearn 没有 plan 变体，但 helper 统一处理便于复用。
    final subStages = _orderedSubStagesForDisplay(
      plan: plan,
      stage: firstLearnStage,
      completedKeys: completedKeys,
      skippedKeys: progress?.skippedSubStageKeys ?? const {},
    );

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
                  progress?.isSubStageCompleted(
                    firstLearnStage,
                    subStage,
                    completedKeys,
                  ) ??
                  false;
              final isCurrent =
                  progress?.isCurrentSubStage(firstLearnStage, subStage) ??
                  false;
              final isSkipped =
                  progress?.isSubStageSkipped(firstLearnStage, subStage) ??
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
                if (progress?.isSubStageCompleted(
                      firstLearnStage,
                      subStage,
                      completedKeys,
                    ) ??
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

              // 已完成或过去阶段跳过的步骤都支持点击进入自由练习。
              // （过去阶段跳过的复述：用户当时关掉了复述、现在重开后想补做）
              final isPast =
                  progress != null &&
                  firstLearnStage.index < progress!.currentStage.index;
              final canFreePlay = isCompleted || isPast;
              VoidCallback? onTap;
              if (canFreePlay && subStage == SubStageType.blindListen) {
                onTap = () => _startFreePlayBlindListen(context, ref);
              } else if (canFreePlay &&
                  subStage == SubStageType.intensiveListen) {
                onTap = () => _startFreePlayIntensiveListen(context, ref);
              } else if (canFreePlay &&
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
              } else if (canFreePlay && subStage == SubStageType.retell) {
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
                isSkipped: isSkipped,
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
    final estimatedDuration = estimateBlindListenSessionDuration(
      sentences: sentences,
      fullAudioDuration: ref.read(audioEngineProvider).totalDuration,
      skipSilenceEnabled: ref.read(appSettingsProvider).skipSilenceEnabled,
    );

    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      estimatedDurationText: estimatedDuration != null
          ? formatEstimatedDuration(l10n, estimatedDuration)
          : null,
      onStartPractice: (targetDuration, pauseMultiplier, playbackSpeed) async {
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        final settings = BlindListenSettings.fromMultiplier(
          pauseMultiplier,
        ).copyWith(playbackSpeed: playbackSpeed);
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

  /// 进入自由练习精听模式（与按计划学习一致：先弹 briefing 含速度下拉）
  Future<void> _startFreePlayIntensiveListen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.sentences.isEmpty) return;

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
      defaultPlaybackSpeed: 1.0,
      onStartPractice: (playbackSpeed, pauseMultiplier) async {
        await ref
            .read(learningSessionProvider.notifier)
            .enterIntensiveListenMode(
              audioItemId,
              lpState.sentences,
              isFreePlay: true,
              playbackSpeed: playbackSpeed,
              pauseMultiplier: pauseMultiplier,
            );
        if (context.mounted) {
          context.push(
            AppRoutes.intensiveListenPlayer(collectionId, audioItemId),
          );
        }
      },
    );
  }

  /// 进入自由练习跟读模式（与按计划学习一致：先弹 briefing 含速度下拉）
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

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final difficultIndices = await BookmarkManager.loadBookmarks(
      audioItemId,
      dao: bookmarkDao,
    );
    if (!context.mounted) return;
    if (difficultIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.listenAndRepeatNoDifficultSentences,
          ),
        ),
      );
      return;
    }

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
      // 难句跟读只属于"首次学习"步骤，自由练习也按 firstLearn 算默认速度，
      // 与同 section 的复述自由练习保持一致。
      defaultPlaybackSpeed: progress != null
          ? defaultPlaybackSpeedFor(
              progress!.difficulty,
              LearningStage.firstLearn,
            )
          : 1.0,
      onStartPractice: (playbackSpeed, pauseMultiplier) async {
        await ref
            .read(listenAndRepeatControllerProvider.notifier)
            .initialize(
              audioItemId: audioItemId,
              allSentences: lpState.sentences,
              isFreePlay: true,
              playbackSpeed: playbackSpeed,
              pauseMultiplier: pauseMultiplier,
            );
        if (context.mounted) {
          context.push(
            AppRoutes.listenAndRepeatPlayer(collectionId, audioItemId),
          );
        }
      },
    );
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

    // 段落时长 default 按用户**当前**学习阶段算（review28 用户能驾驭长段），
    // 与 catchUpStage（始终 firstLearn，因为这是 firstLearn 子步骤的补练）解耦。
    // 可见词比例按 catchUpStage=firstLearn 算（补练 firstLearn 复述）。
    final progressForDefault = ref
        .read(learningProgressNotifierProvider)
        .progressMap[audioItemId];
    final stageForDefault =
        progressForDefault?.currentStage ?? LearningStage.firstLearn;
    showRetellBriefingSheet(
      context: context,
      sentences: lpState.sentences,
      defaultSeconds: retellDefaultSeconds(stageForDefault),
      defaultKeywordRatio: progressForDefault != null
          ? KeywordRatio.forDifficultyAndStage(
              progressForDefault.difficulty,
              LearningStage.firstLearn,
            )
          : null,
      defaultPlaybackSpeed: progressForDefault != null
          ? defaultPlaybackSpeedFor(
              progressForDefault.difficulty,
              LearningStage.firstLearn,
            )
          : 1.0,
      onStartPractice:
          (targetDuration, pauseMultiplier, keywordRatio, playbackSpeed) async {
            final paragraphs = groupSentencesIntoParagraphs(
              lpState.sentences,
              targetDuration,
            );

            await ref
                .read(learningSessionProvider.notifier)
                .enterRetellMode(
                  audioItemId,
                  paragraphs,
                  isFreePlay: true,
                  catchUpStage: LearningStage.firstLearn,
                  catchUpSubStage: SubStageType.retell,
                  overrideKeywordRatio: keywordRatio,
                  playbackSpeed: playbackSpeed,
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

  /// 已跳过状态：与 [isCompleted] 互斥（持久化层保证）；显示 ⏭ 灰色图标，
  /// 文案后缀「已跳过」。
  final bool isSkipped;

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
    this.isSkipped = false,
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
                        : isSkipped
                        ? theme.colorScheme.surfaceContainerHighest
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
                        : isCurrent && !isSkipped
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
                        : isSkipped
                        ? Icon(
                            Icons.remove,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
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
                              : isSkipped
                              ? theme.colorScheme.outline
                              : iconColor ?? theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSkipped
                                    ? '$name · ${AppLocalizations.of(context)!.retellSkippedSuffix}'
                                    : name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted || isSkipped
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

  /// 计算本轮次「已完成」子步骤数（基于真实完成历史 [completedKeys]）。
  int _completedSubStageCount(Set<String> completedKeys) {
    int count = 0;
    for (final sub in review.stage.allSubStages) {
      if (completedKeys.contains('${review.stage.key}:${sub.key}')) count += 1;
    }
    return count;
  }

  /// 当前复习轮次时间文案（仅当前轮次显示）。
  ///
  /// 展示优先级：已有进度→"学习中" > 未到时间倒计时 > 逾期提示 > 可复习。
  String? _reviewTimingText(
    BuildContext context, {
    required Set<String> completedKeys,
  }) {
    if (progress == null) return null;
    if (!progress!.isCurrentStage(review.stage)) return null;

    // 已有进度（至少完成 1 个子阶段）→ 显示"学习中"
    if (_completedSubStageCount(completedKeys) > 0) {
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
    final estimatedDuration = estimateBlindListenSessionDuration(
      sentences: sentences,
      fullAudioDuration: ref.read(audioEngineProvider).totalDuration,
      skipSilenceEnabled: ref.read(appSettingsProvider).skipSilenceEnabled,
    );

    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      estimatedDurationText: estimatedDuration != null
          ? formatEstimatedDuration(l10n, estimatedDuration)
          : null,
      defaultPlaybackSpeed: switch (progress) {
        null => 1.0,
        final p => defaultPlaybackSpeedFor(p.difficulty, review.stage),
      },
      onStartPractice: (targetDuration, pauseMultiplier, playbackSpeed) async {
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        final settings = BlindListenSettings.fromMultiplier(
          pauseMultiplier,
        ).copyWith(playbackSpeed: playbackSpeed);
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

    // 难句补练自由练习也按"先弹 briefing 含速度下拉"流程，与按计划学习对齐。
    final difficultDuration = lpState.sentences
        .where((s) => s.isBookmarked)
        .fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);
    final estimated = difficultDuration == Duration.zero
        ? null
        : difficultDuration * 2;
    final defaultSpeed = switch (progress) {
      null => 1.0,
      final p => defaultPlaybackSpeedFor(p.difficulty, review.stage),
    };
    showReviewBriefingSheet(
      context: context,
      stage: review.stage,
      subStage: SubStageType.reviewDifficultPractice,
      estimatedDuration: estimated,
      defaultPlaybackSpeed: defaultSpeed,
      onStartPractice: (playbackSpeed, pauseMultiplier) async {
        await ref
            .read(learningSessionProvider.notifier)
            .enterReviewDifficultPracticeMode(
              audioItemId,
              lpState.sentences,
              isFreePlay: true,
              playbackSpeed: playbackSpeed,
              pauseMultiplier: pauseMultiplier,
            );
        if (context.mounted) {
          context.push(
            AppRoutes.reviewDifficultPractice(collectionId, audioItemId),
          );
        }
      },
    );
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

    final catchUpSub = isSummary
        ? SubStageType.reviewRetellSummary
        : SubStageType.reviewRetellParagraph;

    if (isSummary) {
      // 全文复述：全文作为单个段落，无需选择时长
      await ref
          .read(learningSessionProvider.notifier)
          .enterRetellMode(
            audioItemId,
            [lpState.sentences],
            isFreePlay: true,
            catchUpStage: review.stage,
            catchUpSubStage: catchUpSub,
          );
      if (context.mounted) {
        context.push(AppRoutes.retellPlayer(collectionId, audioItemId));
      }
      return;
    }

    // 段落复述：弹出简报面板让用户选择段落时长（预估时长由 sheet 内部按真实公式动态计算）
    final progressForRetell = ref
        .read(learningProgressNotifierProvider)
        .progressMap[audioItemId];
    showRetellBriefingSheet(
      context: context,
      sentences: lpState.sentences,
      defaultSeconds: retellDefaultSeconds(review.stage),
      defaultKeywordRatio: progressForRetell != null
          ? KeywordRatio.forDifficultyAndStage(
              progressForRetell.difficulty,
              review.stage,
            )
          : null,
      defaultPlaybackSpeed: progressForRetell != null
          ? defaultPlaybackSpeedFor(progressForRetell.difficulty, review.stage)
          : 1.0,
      onStartPractice:
          (targetDuration, pauseMultiplier, keywordRatio, playbackSpeed) async {
            final paragraphs = groupSentencesIntoParagraphs(
              lpState.sentences,
              targetDuration,
            );
            await ref
                .read(learningSessionProvider.notifier)
                .enterRetellMode(
                  audioItemId,
                  paragraphs,
                  isFreePlay: true,
                  catchUpStage: review.stage,
                  catchUpSubStage: catchUpSub,
                  overrideKeywordRatio: keywordRatio,
                  playbackSpeed: playbackSpeed,
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
    final plan = ref.watch(learningPlanForAudioProvider(audioItemId));
    final completedKeys = ref
        .watch(learningProgressNotifierProvider)
        .completionsFor(audioItemId);
    // 迭代顺序 = 当前 plan 顺序 + 历史外延项（已完成 / 已跳过但不在当前 plan 内）。
    // 例如 review28 v1 用户完成了 reviewRetellSummary 后切到 v2 不会发生（v1 用户
    // 该 stage 有 completion 仍走 v1 plan），但 helper 防御性兜底。
    final subStages = _orderedSubStagesForDisplay(
      plan: plan,
      stage: review.stage,
      completedKeys: completedKeys,
      skippedKeys: progress?.skippedSubStageKeys ?? const {},
    );
    final completedCount = _completedSubStageCount(completedKeys);
    final timingText = _reviewTimingText(context, completedKeys: completedKeys);
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
                  progress?.isSubStageCompleted(
                    review.stage,
                    subStage,
                    completedKeys,
                  ) ??
                  false;
              final isCurrent =
                  progress?.isCurrentSubStage(review.stage, subStage) ?? false;
              final isSkipped =
                  progress?.isSubStageSkipped(review.stage, subStage) ?? false;

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

              // 已完成或过去阶段跳过的子步骤都支持点击进入自由练习。
              // （过去阶段跳过的复述：用户当时关掉了复述、现在重开后想补做）
              final isPast =
                  progress != null &&
                  review.stage.index < progress!.currentStage.index;
              final canFreePlay = isCompleted || isPast;
              VoidCallback? onTap;
              if (canFreePlay) {
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
                isSkipped: isSkipped,
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

/// 底部固定按钮 — 根据进度显示不同形态：
///
/// - 未开始：单按钮「开始学习」（[onPressed] 为 null 时禁用）。
/// - 进行中（未暂停）：Row[Expanded 1:暂停学习 | Expanded 2:继续学习]，比例 1:2。
/// - 进行中（已暂停）：单按钮「恢复学习」，点击直接恢复（不弹窗），随后 UI 自动
///   回到 Row 形态。
/// - 已学完：单按钮「重置学习进度」，点击弹窗确认后清除全部进度。
class _BottomButton extends ConsumerWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;
  final String audioItemId;
  final String audioItemName;
  final VoidCallback? onPressed;
  final GuideStep? startLearningStep;
  final GuideStep? pauseLearningStep;

  const _BottomButton({
    required this.l10n,
    required this.audioItemId,
    required this.audioItemName,
    this.progress,
    required this.onPressed,
    this.startLearningStep,
    this.pauseLearningStep,
  });

  Future<void> _confirmAndPause(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pauseLearningConfirmTitle),
        content: Text(l10n.pauseLearningConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.pauseLearning),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .pauseProgress(audioItemId);
    }
  }

  Future<void> _resume(WidgetRef ref) {
    return ref
        .read(learningProgressNotifierProvider.notifier)
        .resumeProgress(audioItemId);
  }

  /// 已学完状态：重置学习进度（与音频列表菜单的「重置学习进度」逻辑一致）
  Future<void> _confirmAndReset(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetLearningProgressConfirmTitle),
        content: Text(l10n.resetLearningProgressConfirmMessage(audioItemName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .deleteProgress(audioItemId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.resetLearningProgressDone)));
      }
    }
  }

  Widget _wrap(BuildContext context, Widget body) {
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
      child: SafeArea(top: false, child: body),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProgress = progress?.isStarted ?? false;
    final isPaused = progress?.isPaused ?? false;
    final isCompleted = progress?.isCompleted ?? false;

    // 已学完：只显示「重置学习进度」按钮，不再提供暂停/继续。
    if (isCompleted) {
      final theme = Theme.of(context);
      return _wrap(
        context,
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _confirmAndReset(context, ref),
            icon: Icon(Icons.restart_alt, color: theme.colorScheme.error),
            label: Text(
              l10n.resetLearningProgress,
              style: TextStyle(color: theme.colorScheme.error),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      );
    }

    // 暂停态：单按钮，文案合并「已暂停 · 恢复学习」，点击直接恢复。
    // 用 tonal 灰底突出当前是暂停态，与正常态的主色「继续学习」区分。
    if (hasProgress && isPaused) {
      final theme = Theme.of(context);
      return _wrap(
        context,
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () => _resume(ref),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            child: Text(
              '${l10n.pausedChipLabel} · ${l10n.resumeLearning}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    // 进行中（未暂停）：Row[暂停 | 继续] 1:2
    if (hasProgress) {
      final continueButton = FilledButton(
        onPressed: onPressed,
        child: Text(l10n.continueLearning),
      );
      final guidedContinue = startLearningStep != null
          ? GuideTarget(step: startLearningStep!, child: continueButton)
          : continueButton;
      final pauseButton = FilledButton.tonal(
        onPressed: () => _confirmAndPause(context, ref),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: Text(
          l10n.pauseLearning,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      final guidedPause = pauseLearningStep != null
          ? GuideTarget(step: pauseLearningStep!, child: pauseButton)
          : pauseButton;
      return _wrap(
        context,
        Row(
          children: [
            Expanded(flex: 3, child: guidedPause),
            const SizedBox(width: AppSpacing.m),
            Expanded(flex: 5, child: guidedContinue),
          ],
        ),
      );
    }

    // 未开始：单按钮「开始学习」
    final startButton = FilledButton(
      onPressed: onPressed,
      child: Text(l10n.startLearning),
    );
    final guidedStart = startLearningStep != null
        ? GuideTarget(step: startLearningStep!, child: startButton)
        : startButton;
    return _wrap(context, SizedBox(width: double.infinity, child: guidedStart));
  }
}

/// 学习计划页子步骤显示顺序：当前 plan 顺序在前，历史外延项在后。
///
/// - [plan]：按 audio 版本派生的 plan（v1/v2）
/// - [stage]：当前渲染的大阶段
/// - [completedKeys]：该 audio 的 stage_completions 集合
/// - [skippedKeys]：该 audio 的用户跳过集合
///
/// 历史外延项 = `stage.allSubStages` ∖ plan，且属于 completed 或 skipped。
/// 用于保留 v1 已完成但 v2 已移除项（如 review28 v1→v2 中的 reviewRetellSummary）
/// 的 ✅ 历史显示。当用户走 v1 plan（该 stage 有 completion）时，
/// extras 通常为空（plan 已含历史项）。
List<SubStageType> _orderedSubStagesForDisplay({
  required LearningPlan plan,
  required LearningStage stage,
  required Set<String> completedKeys,
  required Set<String> skippedKeys,
}) {
  final planned = plan.subStagesFor(stage);
  final extras = stage.allSubStages
      .where((s) {
        if (planned.contains(s)) return false;
        final key = '${stage.key}:${s.key}';
        return completedKeys.contains(key) || skippedKeys.contains(key);
      })
      .toList(growable: false);
  return [...planned, ...extras];
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
