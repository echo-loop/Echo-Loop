/// 复述播放器页面
///
/// 段落复述的核心交互页面。
/// 布局: AppBar → 进度条 → 句子列表 → (录音结果卡) → 阶段指示器 → 底部控制。
/// 支持 listening/retelling 双阶段切换、显示模式循环。
/// retelling 阶段通过 [RetellRecordingController] 驱动录音识别流程。
/// 录音回放复用 [SpeechRatingBadge] 的播放状态。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/enums.dart';
import '../features/auth/sign_in_required_dialog.dart';
import '../features/subscription/models/premium_feature.dart';
import '../features/subscription/widgets/ai_quota_exceeded_dialog.dart';
import '../features/subscription/widgets/feature_gate.dart' show openPaywall;
import '../l10n/app_localizations.dart';
import '../utils/playback_speed.dart';
import '../models/retell_review_sample.dart';
import '../models/media_learning_startup.dart';
import '../models/media_playback_state.dart';
import '../models/retell_settings.dart';
import '../models/sentence.dart';
import '../models/speech_practice_models.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_settings_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/retell_player_provider.dart';
import '../providers/media_engine/media_engine_provider.dart';
import '../providers/media_engine/media_sense_group_range_playback.dart';
import '../providers/new_user_guide_provider.dart';
import '../widgets/common/recording_button.dart' show RecordingButtonMode;
import '../providers/retell_recording_controller_provider.dart';
import '../providers/retell_review_evaluation_provider.dart';
import '../services/audio_preview_controller.dart';
import '../services/app_logger.dart';
import '../utils/wakelock_mixin.dart';
import '../router/app_router.dart';
import 'sentence_detail_screen.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/common/speech_rating_badge.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/common/repeat_practice_panel.dart';
import '../widgets/common/paragraph_practice_scaffold.dart';
import '../widgets/common/managed_media_visual_surface.dart';
import '../widgets/common/practice_media_presentation_host.dart';
import '../widgets/common/paragraph_sentence_list_card.dart';
import '../widgets/study/study_activity_detector.dart';
import '../widgets/guide_flow.dart';
import '../widgets/common/paragraph_visibility_controls.dart';
import '../widgets/retell/retell_settings_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/speech_permission_dialog.dart';
import '../widgets/practice/practice_play_count_label.dart';
import '../widgets/retell/retell_review_sheet.dart';

/// 复述录音回放使用的试听控制器。
///
/// 自动回放、用户手动点击 badge、评估弹窗里的播放按钮共用这一个 controller，
/// 三个入口因此共享同一份播放状态，图标和点击停止行为天然一致；
/// 测试中可注入包着无平台依赖 service 的替身。
final retellRecordingPreviewProvider = Provider<AudioPreviewController>((ref) {
  final preview = AudioPreviewController();
  ref.onDispose(() => unawaited(preview.dispose()));
  return preview;
});

/// 复述播放器页面
class RetellPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（独立音频路由时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  /// 视频复述进入页面后延迟准备媒体；音频任务保持 null。
  final MediaLearningStartup? mediaStartup;

  const RetellPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
    this.mediaStartup,
  });

  @override
  ConsumerState<RetellPlayerScreen> createState() => _RetellPlayerScreenState();
}

class _RetellPlayerScreenState extends ConsumerState<RetellPlayerScreen>
    with WakelockMixin {
  bool _isShowingDialog = false;

  /// 是否正在跳转到句子详情页，防止连点
  bool _isNavigatingToDetail = false;

  /// seekToSentence 同步阶段 guard（同 blind_listen 注释）。
  bool _isSeeking = false;

  /// 切段清理期间冻结录音状态副作用和自动启动。
  bool _isParagraphTransitioning = false;

  /// 新手引导：讲解按钮 / 主体播放区 Showcase key（随 State 生命周期存在）
  final GlobalKey _guideExplanationKey = GlobalKey(
    debugLabel: 'retellGuideSentenceExplanation',
  );
  final GlobalKey _guideBodyKey = GlobalKey(
    debugLabel: 'retellGuideSentenceBody',
  );

  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  /// 用户在当前段手动停止过录音 → 本段不再自动录音/倒计时
  bool _manualStoppedThisParagraph = false;
  RetellPlayerState? _latestPlayerState;
  RetellRecordingState? _latestRecordingState;
  int _autoPlaybackToken = 0;
  final SpeechRatingBadgeController _ratingBadgeController =
      SpeechRatingBadgeController();
  bool _isHandlingEvaluationComplete = false;
  bool _isShowingReviewSheet = false;

  bool _mediaStartupReady = false;
  bool _speechReady = false;
  bool _didStartPlaying = false;
  bool _isExitingMediaFullscreenForRetell = false;
  PracticeMediaPresentationSession? _mediaPresentationSession;

  /// 防止同一轮评估的状态更新叠加多个额度提示。
  bool _isShowingAiQuotaDialog = false;

  ProviderSubscription<RetellPlayerState>? _playerSubscription;
  ProviderSubscription<RetellRecordingState>? _recordingSubscription;
  ProviderSubscription<RetellReviewEvaluationState>? _reviewSubscription;

  /// 在初始化期保存 controller，销毁期不再通过已失效的 ref 访问 provider。
  late final RetellReviewEvaluationController _reviewController;
  StreamSubscription<Duration>? _silenceSkipSub;

  @override
  void initState() {
    super.initState();
    _playerSubscription = ref.listenManual<RetellPlayerState>(
      retellPlayerProvider,
      _onRetellPlayerStateChanged,
    );
    _recordingSubscription = ref.listenManual<RetellRecordingState>(
      retellRecordingControllerProvider,
      _onRetellRecordingStateChanged,
    );
    _reviewController = ref.read(retellReviewEvaluationProvider.notifier);
    _reviewSubscription = ref.listenManual<RetellReviewEvaluationState>(
      retellReviewEvaluationProvider,
      _onRetellReviewStateChanged,
    );
    _silenceSkipSub = ref
        .read(retellPlayerProvider.notifier)
        .silenceSkipEventStream
        .listen(_showSilenceSkippedSnackBar);
    _latestPlayerState = ref.read(retellPlayerProvider);
    final initialRecordingState = ref.read(retellRecordingControllerProvider);
    _latestRecordingState = initialRecordingState;
    _syncReviewAttempt(initialRecordingState);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await ensureSpeechReadyForSubStage(
        context,
        ref,
        SubStageType.retell,
      );
      if (!mounted) return;
      if (!ok) {
        await widget.mediaStartup?.cancel();
        if (!mounted) return;
        if (context.canPop()) context.pop();
        return;
      }
      _speechReady = true;
      final settings = ref.read(retellPlayerProvider).settings;
      ref
          .read(retellRecordingControllerProvider.notifier)
          .setManualMode(settings.isManualMode);
      _tryStartPlaying();
    });
  }

  /// 语音能力与视频媒体都 ready 后只启动一次；音频任务天然满足媒体条件。
  void _tryStartPlaying() {
    if (!mounted || !_speechReady || _didStartPlaying) return;
    if (widget.mediaStartup != null && !_mediaStartupReady) return;
    _didStartPlaying = true;
    ref.read(retellPlayerProvider.notifier).startPlaying();
    final playerState = _latestPlayerState;
    final recState = _latestRecordingState;
    if (playerState != null && recState != null) {
      _maybeAutoStartRecording(playerState: playerState, recState: recState);
    }
  }

  void _handleMediaStartupReady() {
    if (!mounted || _mediaStartupReady) return;
    setState(() => _mediaStartupReady = true);
    _tryStartPlaying();
  }

  Future<void> _handleMediaStartupExit() async {
    _isExiting = true;
    await widget.mediaStartup?.cancel();
    if (mounted) context.pop();
  }

  Future<void> _handleClose() async {
    if (widget.mediaStartup != null && !_mediaStartupReady) {
      await _handleMediaStartupExit();
      return;
    }
    await _handleExit();
  }

  Widget _wrapMediaStartup(Widget child) {
    final startup = widget.mediaStartup;
    if (startup == null) return child;
    return ManagedMediaVisualSurface(
      loadKey: startup.loadKey,
      load: startup.load,
      cancel: startup.cancel,
      onReady: _handleMediaStartupReady,
      child: child,
    );
  }

  @override
  void dispose() {
    _autoPlaybackToken += 1;
    _isHandlingEvaluationComplete = false;
    _reviewController.syncAttempt(null);
    unawaited(_ratingBadgeController.stop());
    _playerSubscription?.close();
    _recordingSubscription?.close();
    _reviewSubscription?.close();
    _silenceSkipSub?.cancel();
    super.dispose();
  }

  /// 弹出"已自动跳过 Xs 静音"提示
  void _showSilenceSkippedSnackBar(Duration gap) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.silenceSkipped(gap.inSeconds)),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _onRetellPlayerStateChanged(
    RetellPlayerState? prev,
    RetellPlayerState next,
  ) {
    _latestPlayerState = next;
    if (!mounted || _isExiting || prev == null) return;
    _logRetellPlayerStateTransition(prev, next);

    if (!prev.stepFinished && next.stepFinished) {
      shortenIdleTimeout(5);
      _handleCompleted();
    }

    if (prev.settings.controlMode != next.settings.controlMode) {
      final controller = ref.read(retellRecordingControllerProvider.notifier);
      controller.setManualMode(next.settings.isManualMode);
      if (next.settings.isManualMode) {
        final recState = ref.read(retellRecordingControllerProvider);
        if (recState.phase == RetellRecordingPhase.recording) {
          unawaited(controller.cancelActiveRecording());
        }
        if (next.isRetellCountdown) {
          ref.read(retellPlayerProvider.notifier).cancelCountdown();
        }
      }
    }

    if (prev.currentParagraphIndex != next.currentParagraphIndex) {
      _manualStoppedThisParagraph = false;
      if (!_isParagraphTransitioning) {
        unawaited(
          ref.read(retellRecordingControllerProvider.notifier).clearRecording(),
        );
      }
    }

    final recState = _latestRecordingState;
    if (recState != null) {
      final enteredRetelling =
          prev.phase == RetellPhase.listening &&
          next.phase == RetellPhase.retelling;
      final presentation = _mediaPresentationSession;
      if (enteredRetelling &&
          presentation != null &&
          presentation.readState().expanded) {
        unawaited(_exitFullscreenThenStartRetelling());
        return;
      }
      _maybeAutoStartRecording(playerState: next, recState: recState);
    }
  }

  /// 视频段落播完先退出全屏，再允许自动录音，保证复述控制始终可见。
  Future<void> _exitFullscreenThenStartRetelling() async {
    if (_isExitingMediaFullscreenForRetell) return;
    _isExitingMediaFullscreenForRetell = true;
    try {
      await _mediaPresentationSession?.setFullscreen(false);
      if (!mounted || _isExiting) return;
      final latestPlayer = ref.read(retellPlayerProvider);
      final latestRecording = ref.read(retellRecordingControllerProvider);
      if (latestPlayer.phase != RetellPhase.retelling) return;
      _maybeAutoStartRecording(
        playerState: latestPlayer,
        recState: latestRecording,
      );
    } finally {
      _isExitingMediaFullscreenForRetell = false;
    }
  }

  void _onRetellRecordingStateChanged(
    RetellRecordingState? prev,
    RetellRecordingState next,
  ) {
    _latestRecordingState = next;
    _syncReviewAttempt(next);
    if (!mounted || _isExiting) return;
    if (prev != null) {
      _logRetellRecordingStateTransition(prev, next);
    }
    // 评估完成（有 ASR: processing→idle，无 ASR: recording→idle）
    if (prev?.phase != RetellRecordingPhase.idle &&
        next.phase == RetellRecordingPhase.idle &&
        next.currentAttempt != null &&
        !_isParagraphTransitioning) {
      // 复述完成后一律显示全部字幕（不影响用户在复述过程中的设置）
      ref
          .read(retellPlayerProvider.notifier)
          .setDisplayModeWithoutOverride(RetellDisplayMode.showAll);

      final latestState = ref.read(retellPlayerProvider);
      if (latestState.phase == RetellPhase.retelling &&
          !latestState.isWaitingForUser &&
          !latestState.stepFinished) {
        AppLogger.log('RetellScreen', '评估完成 → 准备回听/段间停顿');
        unawaited(_handleEvaluationComplete(next.currentAttempt));
      }
    }

    final playerState = _latestPlayerState;
    if (playerState != null) {
      _maybeAutoStartRecording(playerState: playerState, recState: next);
    }
  }

  /// 将 AI 评估缓存精确绑定到 panel 中可见的录音 badge。
  void _syncReviewAttempt(RetellRecordingState recordingState) {
    final attempt = recordingState.currentAttempt;
    final showRating = ref.read(learningSettingsProvider).retellRatingEnabled;
    final isBadgeVisible =
        attempt != null &&
        (showRating ? attempt.hasFinalFeedback : attempt.hasRecording);
    final path = attempt?.filePath;
    final attemptKey = isBadgeVisible && path != null && path.isNotEmpty
        ? '${attempt.promptId}:$path'
        : null;
    ref.read(retellReviewEvaluationProvider.notifier).syncAttempt(attemptKey);
  }

  void _onRetellReviewStateChanged(
    RetellReviewEvaluationState? previous,
    RetellReviewEvaluationState next,
  ) {
    if (!mounted || _isExiting) return;
    // 流一有返回就开弹窗：`meta` 首帧（转录）已在 client 层独立成帧，
    // 因此这里的「首个带 evaluation 的帧」就是服务端最早的一次推送。
    if (next.phase == RetellReviewEvaluationPhase.streaming &&
        previous?.evaluation == null &&
        next.evaluation != null) {
      unawaited(_openRetellReviewSheet());
      return;
    }
    if (next.phase == RetellReviewEvaluationPhase.failed &&
        !_isShowingReviewSheet) {
      // 未登录与额度用尽有明确出路，走对应引导；其余仍是一次性 SnackBar。
      switch (next.errorCode) {
        case 'auth_required':
          unawaited(_showRetellReviewSignInDialog());
          return;
        case 'quota_exceeded':
          unawaited(_showRetellReviewQuotaDialog());
          return;
      }
      final message = retellReviewErrorMessage(
        AppLocalizations.of(context)!,
        next.errorCode,
        quotaReason: next.quotaReason,
      );
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// 云端 AI 复述评估的登录引导（与 AI 转录、意群共用同一个通用弹窗）。
  Future<void> _showRetellReviewSignInDialog() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await ensureSignedInForAction(
      context: context,
      ref: ref,
      title:
          l10n?.retellAiReviewSignInRequiredTitle ??
          'Sign in to use AI retell review',
      message:
          l10n?.retellAiReviewSignInRequiredMessage ??
          'AI retell review uses the cloud AI service. Sign in to get '
              'feedback on your retelling.',
    );
  }

  /// 复述评估额度用尽时先明确告知用户，再由用户选择是否进入订阅页。
  ///
  /// 用户主动点击 AI 评估时，和句子翻译/解析一致，不受全局提醒冷却期限制；
  /// 仍记录已展示时间，使其它自动触发的 AI 提醒遵守统一节流规则。
  Future<void> _showRetellReviewQuotaDialog() async {
    if (_isShowingAiQuotaDialog || !mounted) return;
    _isShowingAiQuotaDialog = true;
    try {
      await showAiQuotaExceededDialog(
        context: context,
        ref: ref,
        feature: PremiumFeature.aiRetellReview,
        reason: ref.read(retellReviewEvaluationProvider).quotaReason,
      );
    } finally {
      _isShowingAiQuotaDialog = false;
    }
  }

  /// 额度用尽引导订阅（平台是否支持订阅由 openPaywall 内部兜底）。
  Future<void> _openRetellReviewPaywall() async {
    if (!mounted) return;
    await openPaywall(context, ref);
  }

  Future<void> _openRetellReviewSheet() async {
    if (_isShowingReviewSheet || !mounted) return;
    final recordingPath = ref
        .read(retellRecordingControllerProvider)
        .currentAttempt
        ?.filePath;
    if (recordingPath == null || recordingPath.isEmpty) return;
    _isShowingReviewSheet = true;
    try {
      await showRetellReviewSheet(
        context,
        recordingPath: recordingPath,
        preview: ref.read(retellRecordingPreviewProvider),
        onBeforePlayback: _takeOverForAiReview,
        onRetry: _retryReviewEvaluation,
        onUpgrade: _openRetellReviewPaywall,
        onSignIn: _showRetellReviewSignInDialog,
      );
    } finally {
      _isShowingReviewSheet = false;
    }
  }

  Future<void> _handleAiReviewTap(SpeechPracticeAttempt? attempt) async {
    final path = attempt?.filePath;
    if (attempt == null || path == null || path.isEmpty) return;
    await _takeOverForAiReview();
    // 假数据模式下直接出弹窗，不发请求（见 [retellReviewSampleEnabled]）。
    if (retellReviewSampleEnabled) {
      ref
          .read(retellReviewEvaluationProvider.notifier)
          .loadSample(attemptKey: '${attempt.promptId}:$path');
      await _openRetellReviewSheet();
      return;
    }
    final reviewState = ref.read(retellReviewEvaluationProvider);
    if (reviewState.attemptKey == '${attempt.promptId}:$path' &&
        reviewState.hasCachedResult) {
      await _openRetellReviewSheet();
      return;
    }
    // 弹窗不在这里打开：等流的首帧到达后由 [_onRetellReviewStateChanged] 打开，
    // 等待期间 badge 上是 loading 态。
    await _startReviewEvaluation(attempt);
  }

  /// 弹窗内失败重试：此时已接管播放，不再重复 takeover。
  Future<void> _retryReviewEvaluation() => _startReviewEvaluation(
    ref.read(retellRecordingControllerProvider).currentAttempt,
  );

  Future<void> _startReviewEvaluation(SpeechPracticeAttempt? attempt) async {
    final path = attempt?.filePath;
    if (attempt == null || path == null || path.isEmpty) return;
    await ref
        .read(retellReviewEvaluationProvider.notifier)
        .evaluate(
          attemptKey: '${attempt.promptId}:$path',
          recordingPath: path,
          originalText: ref
              .read(retellPlayerProvider.notifier)
              .currentParagraphReferenceText,
          targetLanguage: ref.read(appSettingsProvider).nativeLanguage,
        );
  }

  /// AI 评估是用户主动操作：终止倒计时和自动流程，保留当前段给用户手动接管。
  Future<void> _takeOverForAiReview() async {
    _manualStoppedThisParagraph = true;
    await _cancelAutoPlayback();
    final playerState = ref.read(retellPlayerProvider);
    if (playerState.phase == RetellPhase.retelling) {
      ref
          .read(retellPlayerProvider.notifier)
          .enterWaitingForUser(stopImmediately: true);
    }
  }

  void _maybeAutoStartRecording({
    required RetellPlayerState playerState,
    required RetellRecordingState recState,
  }) {
    if (!mounted || _isShowingDialog || _isParagraphTransitioning) return;

    if (playerState.phase != RetellPhase.retelling ||
        _isExitingMediaFullscreenForRetell ||
        playerState.isWaitingForUser ||
        playerState.stepFinished ||
        playerState.settings.isManualMode ||
        _isHandlingEvaluationComplete ||
        recState.phase != RetellRecordingPhase.idle ||
        recState.awaitingSpeechTimedOut ||
        playerState.isRetellCountdown ||
        _manualStoppedThisParagraph) {
      // 仅在 retelling 阶段输出，避免 listening 阶段大量噪音
      if (playerState.phase == RetellPhase.retelling) {
        AppLogger.log(
          'RetellScreen',
          '⏭ autoRec 预检查跳过: '
              'waiting=${playerState.isWaitingForUser}, '
              'stepFinished=${playerState.stepFinished}, '
              'manual=${playerState.settings.isManualMode}, '
              'postEval=$_isHandlingEvaluationComplete, '
              'recPhase=${recState.phase.name}, '
              'timedOut=${recState.awaitingSpeechTimedOut}, '
              'countdown=${playerState.isRetellCountdown}, '
              'manualStopped=$_manualStoppedThisParagraph',
        );
      }
      return;
    }

    final promptId =
        'retell:${widget.audioItemId}:${playerState.currentParagraphIndex}';
    final referenceText = ref
        .read(retellPlayerProvider.notifier)
        .currentParagraphReferenceText;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isParagraphTransitioning || _currentPromptId() != promptId) {
        AppLogger.log('RetellScreen', '⏭ 自动录音跳过: 段落已切换');
        return;
      }
      if (_isHandlingEvaluationComplete) {
        AppLogger.log('RetellScreen', '⏭ 自动录音跳过: 评估完成处理中');
        return;
      }
      final latestRecState = ref.read(retellRecordingControllerProvider);
      if (latestRecState.phase != RetellRecordingPhase.idle) {
        AppLogger.log(
          'RetellScreen',
          '⏭ 自动录音跳过: phase=${latestRecState.phase.name}',
        );
        return;
      }
      if (latestRecState.awaitingSpeechTimedOut) {
        AppLogger.log('RetellScreen', '⏭ 自动录音跳过: 等待开口超时');
        return;
      }
      final latestState = ref.read(retellPlayerProvider);
      if (latestState.phase != RetellPhase.retelling) {
        AppLogger.log(
          'RetellScreen',
          '⏭ 自动录音跳过: retellPhase=${latestState.phase.name}',
        );
        return;
      }
      if (latestState.isWaitingForUser) {
        AppLogger.log('RetellScreen', '⏭ 自动录音跳过: waitingForUser');
        return;
      }
      if (latestState.isRetellCountdown) {
        AppLogger.log('RetellScreen', '⏭ 自动录音跳过: 倒计时中');
        return;
      }
      if (_manualStoppedThisParagraph) {
        AppLogger.log('RetellScreen', '⏭ 自动录音跳过: 本段已手动停止');
        return;
      }

      AppLogger.log(
        'RetellScreen',
        '自动开始录音: 段落${latestState.currentParagraphIndex + 1}',
      );
      _updateRecordingThresholds();
      final paragraphDuration = ref
          .read(retellPlayerProvider.notifier)
          .currentParagraphDuration;
      unawaited(
        ref
            .read(retellRecordingControllerProvider.notifier)
            .startRecording(
              promptId: promptId,
              referenceText: referenceText,
              referenceDuration: paragraphDuration,
            ),
      );
    });
  }

  /// 构造当前段落的 promptId
  String _currentPromptId() {
    final state = ref.read(retellPlayerProvider);
    return 'retell:${widget.audioItemId}:${state.currentParagraphIndex}';
  }

  /// 更新录音相关阈值
  void _updateRecordingThresholds() {
    final player = ref.read(retellPlayerProvider.notifier);
    final settings = ref.read(retellPlayerProvider).settings;
    final paragraphDuration = player.currentParagraphDuration;
    final controller = ref.read(retellRecordingControllerProvider.notifier);

    final maxRecording = settings.calculateRetellingDuration(paragraphDuration);
    AppLogger.log(
      'RetellScreen',
      '更新阈值: 静音=20s, '
          '最大录音=${maxRecording.inMilliseconds}ms',
    );
    controller.setSilenceTimeout(const Duration(seconds: 20));
    controller.setMaxRecordingDuration(maxRecording);
  }

  /// 处理录音按钮点击
  Future<void> _handleRecordTap() async {
    final beforeState = ref.read(retellPlayerProvider);
    final beforeRecState = ref.read(retellRecordingControllerProvider);
    AppLogger.log(
      'RetellScreen',
      '录音按钮点击: '
          'phase=${beforeState.phase.name}, '
          'paragraph=${beforeState.currentParagraphIndex}, '
          'countdown=${beforeState.isRetellCountdown}, '
          'waiting=${beforeState.isWaitingForUser}, '
          'manual=${beforeState.settings.isManualMode}, '
          'manualStopped=$_manualStoppedThisParagraph, '
          'recPhase=${beforeRecState.phase.name}, '
          'recPrompt=${beforeRecState.promptId ?? "none"}, '
          'attempt=${beforeRecState.currentAttempt?.status.name ?? "none"}',
    );
    await _cancelAutoPlayback();
    final state = ref.read(retellPlayerProvider);
    if (state.phase != RetellPhase.retelling) return;

    final controller = ref.read(retellRecordingControllerProvider.notifier);
    final player = ref.read(retellPlayerProvider.notifier);
    final recState = ref.read(retellRecordingControllerProvider);

    final promptId = _currentPromptId();
    if (recState.isRecordingPrompt(promptId)) {
      AppLogger.log('RetellScreen', '手动停止录音 → 进入评估');
      await controller.stopAndEvaluate(
        referenceText: player.currentParagraphReferenceText,
      );
      return;
    }

    // 自动停止刚触发（phase 已是 processing），用户也点了停止：
    // 录音已经进入评估，不再把本段标记为退出自动流程。
    if (recState.phase == RetellRecordingPhase.processing &&
        recState.promptId == promptId) {
      AppLogger.log('RetellScreen', '录音已在处理中');
      return;
    }

    // 如果在倒计时中点击录音，取消倒计时
    if (state.isRetellCountdown) {
      AppLogger.log('RetellScreen', '录音按钮点击 → 取消倒计时');
      player.cancelCountdown();
    }

    AppLogger.log(
      'RetellScreen',
      '手动开始录音: '
          '段落${ref.read(retellPlayerProvider).currentParagraphIndex + 1}, '
          'prompt=$promptId',
    );
    // 从等待态（如刚关闭设置面板）手动开始录音时退出等待，
    // 否则评估完成后自动回放/段间倒计时会被 isWaitingForUser 门控跳过。
    player.exitWaitingForUser();
    _updateRecordingThresholds();
    await controller.startRecording(
      promptId: promptId,
      referenceText: player.currentParagraphReferenceText,
      referenceDuration: player.currentParagraphDuration,
    );
  }

  /// 为播放录音回放做准备。
  ///
  /// Badge 自己负责播放和图标切换，这里只清理页面状态。
  Future<void> _prepareAttemptPlayback() async {
    final playerState = ref.read(retellPlayerProvider);
    final recState = ref.read(retellRecordingControllerProvider);
    AppLogger.log(
      'RetellScreen',
      '准备播放录音: '
          'postEval=$_isHandlingEvaluationComplete, '
          'paragraph=${playerState.currentParagraphIndex}, '
          'phase=${playerState.phase.name}, '
          'playing=${playerState.isPlaying}, '
          'countdown=${playerState.isRetellCountdown}, '
          'manual=${playerState.settings.isManualMode}, '
          'recPhase=${recState.phase.name}, '
          'attemptPrompt=${recState.currentAttempt?.promptId ?? "none"}, '
          'attemptPath=${recState.currentAttempt?.filePath ?? "none"}',
    );
    if (!_isHandlingEvaluationComplete) {
      await _cancelAutoPlayback();
    }
    if (playerState.isPlaying) {
      await ref.read(retellPlayerProvider.notifier).pause();
    }

    // 取消段间停顿倒计时
    if (playerState.isRetellCountdown) {
      AppLogger.log('RetellScreen', '播放录音 → 取消倒计时');
      ref.read(retellPlayerProvider.notifier).cancelCountdown();
    }

    if (!_isHandlingEvaluationComplete) {
      // 标记本段手动操作过 → 不再自动录音/倒计时。
      // 自动回放属于评估完成流程本身，不能污染用户手动停止标记。
      AppLogger.log('RetellScreen', '播放录音 → 等待用户操作');
      _manualStoppedThisParagraph = true;
    }
  }

  /// 处理录音评估完成后的回听和段间停顿。
  ///
  /// 首次提示只依赖 SharedPreferences 中的弹窗标记；用户选择开启时，同步更新
  /// 全局默认值和当前会话开关，然后当前段立即参与自动回放。
  Future<void> _handleEvaluationComplete(SpeechPracticeAttempt? attempt) async {
    final token = ++_autoPlaybackToken;
    final player = ref.read(retellPlayerProvider.notifier);
    _isHandlingEvaluationComplete = true;
    final stateAtStart = ref.read(retellPlayerProvider);
    AppLogger.log(
      'RetellScreen',
      '评估完成处理开始: '
          'token=$token, '
          'paragraph=${stateAtStart.currentParagraphIndex}, '
          'phase=${stateAtStart.phase.name}, '
          'manual=${stateAtStart.settings.isManualMode}, '
          'autoPlay=${stateAtStart.settings.autoPlayRecordingAfterCompletion}, '
          'attemptPrompt=${attempt?.promptId ?? "none"}, '
          'attemptStatus=${attempt?.status.name ?? "none"}, '
          'attemptPath=${attempt?.filePath ?? "none"}, '
          'hasRecording=${attempt?.hasRecording ?? false}',
    );

    try {
      await _maybeShowRetellAutoPlaybackPrompt();
      if (!_isAutoPlaybackCurrent(token)) return;

      final state = ref.read(retellPlayerProvider);
      AppLogger.log(
        'RetellScreen',
        '评估完成处理决策: '
            'token=$token, '
            'autoPlay=${state.settings.autoPlayRecordingAfterCompletion}, '
            'hasRecording=${attempt?.hasRecording ?? false}, '
            'manual=${state.settings.isManualMode}, '
            'countdown=${state.isRetellCountdown}, '
            'waiting=${state.isWaitingForUser}, '
            'badgeAttached=${_ratingBadgeController.isAttached}, '
            'badgePrompt=${_ratingBadgeController.attachedPromptId ?? "none"}, '
            'badgePath=${_ratingBadgeController.attachedFilePath ?? "none"}',
      );
      if (state.settings.autoPlayRecordingAfterCompletion &&
          attempt?.hasRecording == true) {
        await _playAttemptRecordingAutomatically(token);
        if (!_isAutoPlaybackCurrent(token)) return;
      }

      // 用户之前停止过倒计时/播放并接管本段时，本次新录音仍应自动回放；
      // 但回放完成后继续保持 waiting，不能重新启动段间倒计时。
      if (_manualStoppedThisParagraph) {
        AppLogger.log('RetellScreen', '评估完成后保持用户接管状态');
        player.enterWaitingForUser();
        return;
      }

      final latestState = ref.read(retellPlayerProvider);
      if (latestState.phase != RetellPhase.retelling ||
          latestState.isWaitingForUser ||
          latestState.stepFinished ||
          latestState.settings.isManualMode) {
        AppLogger.log(
          'RetellScreen',
          '评估完成处理结束: 不启动倒计时 '
              'phase=${latestState.phase.name}, '
              'waiting=${latestState.isWaitingForUser}, '
              'stepFinished=${latestState.stepFinished}, '
              'manual=${latestState.settings.isManualMode}',
        );
        return;
      }

      final retellRatingEnabled = ref
          .read(learningSettingsProvider)
          .retellRatingEnabled;
      final pauseScore = retellRatingEnabled ? attempt?.score : null;
      AppLogger.log('RetellScreen', '评估完成处理结束: 启动段间停顿 score=$pauseScore');
      player.startPostEvaluationPause(score: pauseScore);
    } finally {
      if (_isAutoPlaybackCurrent(token)) {
        _isHandlingEvaluationComplete = false;
        AppLogger.log('RetellScreen', '评估完成处理清理: token=$token');
      }
    }
  }

  /// 首次复述完成后询问是否开启自动回听。
  ///
  /// 仅在功能**当前关闭**且从未提示过时弹出：已开启（全局默认开或会话开）时不再询问，
  /// 避免「功能已开却问要不要开 + 保持关闭却仍自动回放」的矛盾。
  Future<void> _maybeShowRetellAutoPlaybackPrompt() async {
    final settings = ref.read(learningSettingsProvider);
    final retellSettings = ref.read(retellPlayerProvider).settings;
    if (settings.retellAutoPlaybackPromptShown ||
        retellSettings.autoPlayRecordingAfterCompletion ||
        !mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.retellAutoPlaybackPromptTitle),
        content: Text(l10n.retellAutoPlaybackPromptMessage),
        actions: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.retellAutoPlaybackKeepOff),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.retellAutoPlaybackEnable),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;

    final learningSettings = ref.read(learningSettingsProvider.notifier);
    await learningSettings.markRetellAutoPlaybackPromptShown();
    if (enabled == true) {
      await learningSettings.setAutoPlayRetellRecordingAfterCompletion(true);
      final retellState = ref.read(retellPlayerProvider);
      ref
          .read(retellPlayerProvider.notifier)
          .updateSettings(
            retellState.settings.copyWith(
              autoPlayRecordingAfterCompletion: true,
            ),
          );
    }
  }

  /// 自动播放本段录音，播放结束后才允许启动倒计时。
  Future<void> _playAttemptRecordingAutomatically(int token) async {
    try {
      AppLogger.log(
        'RetellScreen',
        '自动回放复述录音: '
            'token=$token, '
            'badgeAttached=${_ratingBadgeController.isAttached}, '
            'badgePrompt=${_ratingBadgeController.attachedPromptId ?? "none"}, '
            'badgePath=${_ratingBadgeController.attachedFilePath ?? "none"}, '
            'badgePlaying=${_ratingBadgeController.isPlaying}',
      );
      // badge 在录音 processing 态时不在树里（panel 显示 ProcessingIndicator），
      // 评估完成切到 idle 后需等其重新挂载才能播放。单帧不保证 rebuild 完成，
      // 这里有界轮询 isAttached（最多 ~30 帧），已挂载时立即短路。
      for (var i = 0; i < 30 && !_ratingBadgeController.isAttached; i++) {
        await WidgetsBinding.instance.endOfFrame;
        if (!_isAutoPlaybackCurrent(token)) return;
      }
      AppLogger.log(
        'RetellScreen',
        '自动回放 endOfFrame 后: '
            'token=$token, '
            'badgeAttached=${_ratingBadgeController.isAttached}, '
            'badgePrompt=${_ratingBadgeController.attachedPromptId ?? "none"}, '
            'badgePath=${_ratingBadgeController.attachedFilePath ?? "none"}',
      );
      await _ratingBadgeController.play();
    } catch (e) {
      AppLogger.log('RetellScreen', '自动回放复述录音失败: $e');
    } finally {
      if (!_isAutoPlaybackCurrent(token)) {
        AppLogger.log('RetellScreen', '自动回放已过期，忽略完成回调');
      }
    }
  }

  bool _isAutoPlaybackCurrent(int token) {
    return mounted && !_isExiting && token == _autoPlaybackToken;
  }

  Future<void> _cancelAutoPlayback() async {
    AppLogger.log(
      'RetellScreen',
      '取消自动回放: oldToken=$_autoPlaybackToken, '
          'postEval=$_isHandlingEvaluationComplete, '
          'badgeAttached=${_ratingBadgeController.isAttached}, '
          'badgePlaying=${_ratingBadgeController.isPlaying}',
    );
    _autoPlaybackToken += 1;
    _isHandlingEvaluationComplete = false;
    try {
      await _ratingBadgeController.stop();
    } catch (e) {
      AppLogger.log('RetellScreen', '取消自动回放失败: $e');
    }
  }

  void _logRetellPlayerStateTransition(
    RetellPlayerState prev,
    RetellPlayerState next,
  ) {
    // 仅 pauseRemaining 变化时不输出日志（倒计时期间变化太频繁）
    if (prev.currentParagraphIndex == next.currentParagraphIndex &&
        prev.playingSentenceIndex == next.playingSentenceIndex &&
        prev.phase == next.phase &&
        prev.currentRepeatCount == next.currentRepeatCount &&
        prev.displayMode == next.displayMode &&
        prev.isPlaying == next.isPlaying &&
        prev.isRetellCountdown == next.isRetellCountdown &&
        prev.isCountdownPaused == next.isCountdownPaused &&
        prev.isCountdownFastForward == next.isCountdownFastForward &&
        prev.isWaitingForUser == next.isWaitingForUser &&
        prev.stepFinished == next.stepFinished) {
      return;
    }

    AppLogger.log(
      'RetellScreen',
      '播放器状态变化: '
          'paragraph ${prev.currentParagraphIndex}→${next.currentParagraphIndex}, '
          'sentence ${prev.playingSentenceIndex}→${next.playingSentenceIndex}, '
          'phase ${prev.phase.name}→${next.phase.name}, '
          'repeat ${prev.currentRepeatCount}→${next.currentRepeatCount}, '
          'display ${prev.displayMode.name}→${next.displayMode.name}, '
          'playing ${prev.isPlaying}→${next.isPlaying}, '
          'countdown ${prev.isRetellCountdown}/${prev.isCountdownPaused}/${prev.isCountdownFastForward}'
          '→${next.isRetellCountdown}/${next.isCountdownPaused}/${next.isCountdownFastForward}, '
          'waiting ${prev.isWaitingForUser}→${next.isWaitingForUser}, '
          'remaining ${prev.pauseRemaining.inMilliseconds}'
          '→${next.pauseRemaining.inMilliseconds}ms, '
          'stepFinished ${prev.stepFinished}→${next.stepFinished}',
    );
  }

  void _logRetellRecordingStateTransition(
    RetellRecordingState prev,
    RetellRecordingState next,
  ) {
    if (prev.phase == next.phase &&
        prev.promptId == next.promptId &&
        prev.awaitingSpeechTimedOut == next.awaitingSpeechTimedOut &&
        prev.currentAttempt?.status == next.currentAttempt?.status &&
        prev.currentAttempt?.score == next.currentAttempt?.score &&
        prev.liveTranscript == next.liveTranscript) {
      return;
    }

    AppLogger.log(
      'RetellScreen',
      '录音状态变化: '
          'phase ${prev.phase.name}→${next.phase.name}, '
          'prompt ${prev.promptId ?? "none"}→${next.promptId ?? "none"}, '
          'awaitTimeout ${prev.awaitingSpeechTimedOut}→${next.awaitingSpeechTimedOut}, '
          'attempt ${prev.currentAttempt?.status.name ?? "none"}'
          '→${next.currentAttempt?.status.name ?? "none"}, '
          'score ${prev.currentAttempt?.score?.toStringAsFixed(2) ?? "null"}'
          '→${next.currentAttempt?.score?.toStringAsFixed(2) ?? "null"}, '
          'live="${next.liveTranscript}"',
    );
  }

  /// 取消录音和回放
  Future<void> _cancelRecordingAndPlayback() async {
    await _cancelAutoPlayback();
    final controller = ref.read(retellRecordingControllerProvider.notifier);
    await controller.cancelActiveRecording();
  }

  /// 处理退出
  Future<void> _handleExit() async {
    // 防重入：完成弹窗 / _exit 内 context.pop() 会被 PopScope 拦截再触发 _handleExit。
    if (_isExiting) return;
    _isExiting = true;
    await _cancelRecordingAndPlayback();
    ref.read(retellPlayerProvider.notifier).pause();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.read(learningSessionProvider);

    if (sessionState.isFreePlay) {
      final sentenceIndex = ref
          .read(retellPlayerProvider.notifier)
          .currentSentenceGlobalIndex;
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveRetellSentenceIndex(
            widget.audioItemId,
            sentenceIndex,
            isFreePlay: true,
          );
      await _exit();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.retellExitConfirmTitle),
        content: Text(l10n.retellExitConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm != true) {
      _isExiting = false;
      return;
    }

    final sentenceIndex = ref
        .read(retellPlayerProvider.notifier)
        .currentSentenceGlobalIndex;
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveRetellSentenceIndex(
          widget.audioItemId,
          sentenceIndex,
          isFreePlay: false,
        );
    await _exit();
  }

  /// 执行退出
  Future<void> _exit() async {
    _isExiting = true;
    await ref.read(retellRecordingControllerProvider.notifier).fullReset();
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 获取当前步骤的上下文信息（按 plan 派生）
  ({int stepIndex, int totalSteps, String stageName}) _getStepContext() {
    final l10n = AppLocalizations.of(context)!;
    final plan = ref.read(learningPlanForAudioProvider(widget.audioItemId));
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    final stage = progress?.currentStage ?? LearningStage.firstLearn;
    final currentSub = progress?.currentSubStage ?? SubStageType.retell;
    final planned = plan.subStagesFor(stage);
    final currentIdx = planned.indexOf(currentSub);
    return (
      stepIndex: currentIdx >= 0 ? currentIdx : planned.length,
      totalSteps: planned.length,
      stageName: reviewStageLabel(l10n, stage),
    );
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;
    final player = ref.read(retellPlayerProvider.notifier);
    player.pauseStudySession();

    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.read(learningSessionProvider);
    final retellState = ref.read(retellPlayerProvider);

    // 自由练习模式：使用公用弹窗
    if (sessionState.isFreePlay) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementRetellPassCount(widget.audioItemId);

      // 「补做」语义：用户从过去阶段的跳过卡片进入自由练习并完成 → 写入
      // stage_completions（幂等，已记录则 no-op）。让 UI 把灰色卡切到 ✅。
      final catchUpStage = sessionState.catchUpStage;
      final catchUpSub = sessionState.catchUpSubStage;
      if (catchUpStage != null && catchUpSub != null) {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .recordCompletionIfNew(
              widget.audioItemId,
              catchUpStage,
              catchUpSub,
            );
      }

      if (!mounted) {
        _isShowingDialog = false;
        return;
      }

      await handleFreePlayComplete(
        context: context,
        title: l10n.retellCompleteTitle,
        stats: [
          (value: '${retellState.totalParagraphs}', label: l10n.statParagraphs),
        ],
        replayLabel: l10n.retellPracticeAgain,
        onStudyAgain: () async {
          player.resumeStudySession();
          await ref
              .read(retellRecordingControllerProvider.notifier)
              .fullReset();
          await ref.read(retellPlayerProvider.notifier).restart();
        },
        onExit: () async {
          await ref
              .read(learningProgressNotifierProvider.notifier)
              .saveRetellSentenceIndex(
                widget.audioItemId,
                null,
                isFreePlay: true,
              );
          await _exit();
        },
      );
      _isShowingDialog = false;
      return;
    }

    // 正常学习模式：使用步骤完成弹窗
    final stepCtx = _getStepContext();

    final result = await showStepCompleteDialog(
      context: context,
      title: l10n.retellCompleteTitle,
      stats: [
        (value: '${retellState.totalParagraphs}', label: l10n.statParagraphs),
      ],
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      isLastStep: true,
    );

    _isShowingDialog = false;
    if (!mounted) return;

    await ref
        .read(learningProgressNotifierProvider.notifier)
        .incrementRetellPassCount(widget.audioItemId);

    if (result != null) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveRetellSentenceIndex(widget.audioItemId, null, isFreePlay: false);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
      await _exit();
    } else {
      // 关闭弹窗 → 留在页面，恢复页面级学习计时。
      player.resumeStudySession();
    }
  }

  /// 重播当前段落
  Future<void> _handleReplay() async {
    _manualStoppedThisParagraph = false;
    AppLogger.log('RetellScreen', '重播当前段落');
    await _cancelRecordingAndPlayback();
    await ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    await ref.read(retellPlayerProvider.notifier).replayDuringCountdown();
  }

  /// 停止倒计时意味着当前段落后续都由用户手动接管。
  void _takeOverCountdown() {
    _manualStoppedThisParagraph = true;
    ref.read(retellPlayerProvider.notifier).enterWaitingForUser();
  }

  /// 切段：retelling 阶段走 completeRetellingTurn（记录统计 + 遍数逻辑）。
  ///
  /// 最后一段时保留录音结果（badge）和手动标记，避免完成弹窗期间
  /// 触发自动录音或 badge 消失。
  Future<void> _goToNextParagraph() async {
    if (_isParagraphTransitioning) return;
    _isParagraphTransitioning = true;
    final retellState = ref.read(retellPlayerProvider);
    final isLastParagraph =
        retellState.currentParagraphIndex >= retellState.totalParagraphs - 1;

    try {
      // 先禁止清理期间的 listener 自动录音，再取消音频和录音；
      // clearRecording 会等待底层 warmup/录音会话确实结束。
      await _cancelRecordingAndPlayback();
      if (!isLastParagraph) {
        _manualStoppedThisParagraph = false;
        await ref
            .read(retellRecordingControllerProvider.notifier)
            .clearRecording();
      }

      AppLogger.log('RetellScreen', '→ 下一段 (last=$isLastParagraph)');
      if (retellState.phase == RetellPhase.retelling) {
        await ref.read(retellPlayerProvider.notifier).completeRetellingTurn();
      } else {
        await ref.read(retellPlayerProvider.notifier).goToNextParagraph();
      }

      // 最后一段仍可能需要重播；仅在 Provider 确认完成后处理完成弹窗。
      if (isLastParagraph && ref.read(retellPlayerProvider).stepFinished) {
        _handleCompleted();
      }
    } finally {
      _isParagraphTransitioning = false;
      if (mounted && !isLastParagraph) {
        final latestPlayer = ref.read(retellPlayerProvider);
        final latestRecording = ref.read(retellRecordingControllerProvider);
        _maybeAutoStartRecording(
          playerState: latestPlayer,
          recState: latestRecording,
        );
      }
    }
  }

  Future<void> _goToPreviousParagraph() async {
    if (_isParagraphTransitioning) return;
    _isParagraphTransitioning = true;
    _manualStoppedThisParagraph = false;
    AppLogger.log('RetellScreen', '→ 上一段');
    try {
      await _cancelRecordingAndPlayback();
      await ref
          .read(retellRecordingControllerProvider.notifier)
          .clearRecording();
      await ref.read(retellPlayerProvider.notifier).goToPreviousParagraph();
    } finally {
      _isParagraphTransitioning = false;
      if (mounted) {
        _maybeAutoStartRecording(
          playerState: ref.read(retellPlayerProvider),
          recState: ref.read(retellRecordingControllerProvider),
        );
      }
    }
  }

  Future<void> _openSettings() async {
    await _cancelAutoPlayback();
    final recordingState = ref.read(retellRecordingControllerProvider);
    if (recordingState.phase == RetellRecordingPhase.recording) {
      // 先进入等待态，再取消录音：避免取消触发的 idle 监听器
      // 看到 isWaitingForUser=false 而误启动段间倒计时或自动录音。
      ref
          .read(retellPlayerProvider.notifier)
          .enterWaitingForUser(stopImmediately: true);
      await ref
          .read(retellRecordingControllerProvider.notifier)
          .cancelActiveRecording();
    } else {
      ref
          .read(retellPlayerProvider.notifier)
          .enterWaitingForUser(afterCurrentParagraph: true);
    }
    if (!mounted) return;
    await showRetellSettingsSheet(context);
  }

  /// 点击句子正文 → 从该句开始播放
  ///
  /// 分场景处理：
  /// - **listening 阶段**：seekToSentence 内 _cancelAll 已经处理音频清理，
  ///   不走 enterWaitingForUser（否则 phase 短暂变 retelling 造成 UI 闪烁）。
  /// - **retelling / countdown 阶段**：先 enterWaitingForUser(stopImmediately:true)
  ///   保证状态机不在录音中，再取消录音，最后 seek。顺序参照 _handleSentenceTap
  ///   既有正确顺序：先 waiting → 后 cancel，避免 cancel 触发的 idle 监听器
  ///   误启动段间倒计时（troubleshooting 7.1 同款风险）。
  Future<void> _handleSentencePlayFrom(Sentence sentence) async {
    if (_isSeeking) return;
    _isSeeking = true;
    try {
      await _cancelAutoPlayback();
      final playerState = ref.read(retellPlayerProvider);
      final recordingState = ref.read(retellRecordingControllerProvider);

      // listening 阶段（非倒计时）：seekToSentence 直接处理，避免 phase 闪烁
      final isPureListening =
          playerState.phase == RetellPhase.listening &&
          !playerState.isRetellCountdown;

      if (!isPureListening) {
        ref
            .read(retellPlayerProvider.notifier)
            .enterWaitingForUser(stopImmediately: true);
      }

      if (recordingState.phase == RetellRecordingPhase.recording) {
        await ref
            .read(retellRecordingControllerProvider.notifier)
            .cancelActiveRecording();
      }
      await ref
          .read(retellRecordingControllerProvider.notifier)
          .clearRecording();

      // seekToSentence 内 _playCurrentParagraph 是 unawaited，
      // 调用本身在 _cancelAll + state.copyWith 后立即返回，guard 短时释放。
      await ref
          .read(retellPlayerProvider.notifier)
          .seekToSentence(sentence.index);
    } finally {
      _isSeeking = false;
    }
  }

  /// 点击句子主体（文本/书签）→ 立即停止播放 → 进入句子详情页 → 返回后刷新收藏
  Future<void> _handleSentenceDetail(Sentence sentence) async {
    if (_isNavigatingToDetail) return;
    _isNavigatingToDetail = true;
    await _cancelAutoPlayback();

    final recordingState = ref.read(retellRecordingControllerProvider);

    // 先进入等待态，再取消录音：避免取消触发的 idle 监听器
    // 看到 isWaitingForUser=false 而误启动段间倒计时或自动录音。
    ref
        .read(retellPlayerProvider.notifier)
        .enterWaitingForUser(stopImmediately: true);

    if (recordingState.phase == RetellRecordingPhase.recording) {
      await ref
          .read(retellRecordingControllerProvider.notifier)
          .cancelActiveRecording();
    }

    if (!mounted) {
      _isNavigatingToDetail = false;
      return;
    }

    final lpState = ref.read(listeningPracticeProvider);
    final audioName = lpState.currentAudioItem?.name ?? '';
    final usesMedia = widget.mediaStartup != null && _mediaStartupReady;

    await AppRoutes.pushNested(
      context,
      AppRoutes.sentenceDetailSegment,
      extra: SentenceDetailArgs(
        audioItemId: widget.audioItemId,
        audioName: audioName,
        sentenceText: sentence.text,
        sentenceIndex: sentence.index,
        totalSentenceCount: ref
            .read(retellPlayerProvider.notifier)
            .totalSentenceCount,
        startTimeMs: sentence.startTime.inMilliseconds,
        endTimeMs: sentence.endTime.inMilliseconds,
        rangePlayback: usesMedia ? _retellMediaRangePlayback : null,
        mediaSession: usesMedia ? _buildMediaSession() : null,
      ),
    );

    _isNavigatingToDetail = false;

    // 返回后刷新收藏状态（详情页可能修改了收藏）
    if (!mounted) return;
    await ref
        .read(retellPlayerProvider.notifier)
        .initializeBookmarks(widget.audioItemId);
  }

  late final MediaSenseGroupRangePlayback _retellMediaRangePlayback =
      MediaSenseGroupRangePlayback(
        engine: ref.read(mediaEngineProvider.notifier),
        playbackSpeed: () =>
            ref.read(retellPlayerProvider).settings.playbackSpeed,
      );

  SentenceDetailMediaSession? _buildMediaSession() {
    final session = _mediaPresentationSession;
    if (session == null) return null;
    return SentenceDetailMediaSession(
      readState: () {
        final state = session.readState();
        return MediaPlaybackState(
          visualTrackVisible: state.visualTrackVisible,
          visualTrackExpanded: state.expanded,
          videoSubtitleVisible: state.subtitleVisible,
        );
      },
      setVisible: session.setVisible,
      setSubtitleVisible: session.setSubtitleVisible,
      setFullscreen: session.setFullscreen,
      buildVideoView: session.buildVideoView,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 只监听非倒计时字段，排除 pauseRemaining，
    // 避免倒计时每 100ms tick 导致整个页面重建
    ref.watch(
      retellPlayerProvider.select(
        (s) => (
          s.currentParagraphIndex,
          s.totalParagraphs,
          s.playingSentenceIndex,
          s.phase,
          s.currentRepeatCount,
          s.displayMode,
          s.settings,
          s.isPlaying,
          s.isRetellCountdown,
          s.pauseDuration,
          s.isCountdownPaused,
          s.isCountdownFastForward,
          s.bookmarkedSentenceIndices,
          s.userOverrodeDisplayMode,
          s.stepFinished,
        ),
      ),
    );
    final state = ref.read(retellPlayerProvider);
    final player = ref.read(retellPlayerProvider.notifier);

    // watch 录音相关状态（仅监听 build 中实际使用的字段，避免转录更新触发重建）
    ref.watch(
      retellRecordingControllerProvider.select(
        (s) =>
            (s.phase, s.awaitingSpeechTimedOut, s.currentAttempt, s.promptId),
      ),
    );
    final retellRecState = ref.read(retellRecordingControllerProvider);
    final retellRatingEnabled = ref.watch(
      learningSettingsProvider.select((s) => s.retellRatingEnabled),
    );
    final reviewPhase = ref.watch(
      retellReviewEvaluationProvider.select((s) => s.phase),
    );

    // 录音按钮模式（RetellRecordingPhase → RecordingButtonMode）
    final recordingMode = switch (retellRecState.phase) {
      RetellRecordingPhase.recording => RecordingButtonMode.recording,
      _ => RecordingButtonMode.idle,
    };
    final isProcessing =
        retellRecState.phase == RetellRecordingPhase.processing;

    final sentences = player.currentParagraphSentences;
    final paragraphDuration = player.currentParagraphDuration;
    final keywords = player.keywordsMap;

    // 顶部进度条：多段按「段落」单调驱动（不随句子/遍数回退），单段无段落
    // 进度可言，保留原逐句行为。
    final isMultiParagraph = state.totalParagraphs > 1;
    final sentenceIdx = _globalSentenceIdx(
      sentences,
      state.playingSentenceIndex,
    );
    final progressCurrent = isMultiParagraph
        ? state.currentParagraphIndex + 1
        : sentenceIdx;
    final progressTotal = isMultiParagraph
        ? state.totalParagraphs
        : player.totalSentenceCount;
    final progressText = isMultiParagraph
        ? l10n.retellParagraphProgress(
            state.currentParagraphIndex + 1,
            state.totalParagraphs,
          )
        : l10n.intensiveListenProgress(sentenceIdx, player.totalSentenceCount);
    final notifier = ref.read(retellPlayerProvider.notifier);

    // 录音结果（从 controller state 获取）
    final currentAttempt = retellRecState.currentAttempt;

    // 新手引导：文本→开播、左侧图标→讲解。统一挂在第 1 句（idx=0），首项最显眼。
    // 盲听和复述共用同一个 flow id —— 用户先在任一页看过就不再弹另一页。
    const guideTargetLocalIdx = 0;
    final bodyStep = GuideStep(
      key: _guideBodyKey,
      description: l10n.guideSentenceTileBodyDescription,
    );
    final explanationStep = GuideStep(
      key: _guideExplanationKey,
      description: l10n.guideSentenceTileExplanationDescription,
    );
    final guideFlows = <GuideFlow>[
      GuideFlow(
        flowId: GuideFlowIds.sentenceTileTour,
        shouldRun: sentences.isNotEmpty,
        steps: [bodyStep, explanationStep],
      ),
    ];

    final mediaReady = widget.mediaStartup == null || _mediaStartupReady;
    return StudyActivityDetector(
      onActivity: player.markStudyActivity,
      child: wakelockBody(
        child: PracticeMediaPresentationHost(
          enabled:
              mediaReady &&
              ref.read(learningSessionProvider).playbackChain ==
                  LearningPlaybackChain.media,
          suppressVisualView: _isNavigatingToDetail,
          audioItemId: widget.audioItemId,
          isPlaying: state.isPlaying,
          onPlayPause: () {
            if (state.phase == RetellPhase.listening) {
              state.isPlaying
                  ? unawaited(player.pause())
                  : unawaited(player.resume());
            } else {
              _handleReplay();
            }
          },
          onSessionChanged: (session) => _mediaPresentationSession = session,
          builder: (context, presentation, mediaSurface) => LearningHotkeyScope(
            onPlayPause: () {
              if (state.phase == RetellPhase.listening) {
                state.isPlaying ? player.pause() : player.resume();
              } else if (state.isRetellCountdown) {
                _handleReplay();
              } else {
                _handleReplay();
              }
            },
            onPrevious: _goToPreviousParagraph,
            onNext: _goToNextParagraph,
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) async {
                if (didPop) return;
                await _handleClose();
              },
              child: GuideFlowSequenceHost(
                flows: guideFlows,
                child: ParagraphPracticeScaffold(
                  title: l10n.retellTitle,
                  onClose: _handleClose,
                  onOpenSettings: _openSettings,
                  current: progressCurrent,
                  total: progressTotal,
                  progressText: progressText,
                  durationText: _formatDurationText(
                    l10n,
                    paragraphDuration: paragraphDuration,
                  ),
                  elapsed: sentences.isEmpty ? null : sentences.first.startTime,
                  remaining: sentences.isEmpty
                      ? null
                      : player.totalDuration - sentences.first.startTime,
                  onSeekToIndex: isMultiParagraph
                      ? (p) => notifier.seekToParagraph(p)
                      : (i) => notifier.seekToSentence(i),
                  topContent: presentation.enabled ? mediaSurface : null,
                  bodyWrapper: _wrapMediaStartup,
                  fullscreenBody: presentation.expanded ? mediaSurface : null,
                  paragraphContent: ParagraphSentenceListCard(
                    sentences: sentences,
                    displayMode:
                        state.settings.keywordMethod != KeywordMethod.off
                        ? state.displayMode
                        : RetellDisplayMode.hideAll,
                    keywordMap: keywords,
                    playingSentenceIndex: state.phase == RetellPhase.listening
                        ? state.playingSentenceIndex
                        : -1,
                    bookmarkedSentenceIndices: state.bookmarkedSentenceIndices,
                    onSentenceExplanationTap: _handleSentenceDetail,
                    onSentencePlayFrom: _handleSentencePlayFrom,
                    onSentenceBookmarkToggle: (sentence) => ref
                        .read(retellPlayerProvider.notifier)
                        .toggleBookmark(widget.audioItemId, sentence),
                    guideTargetLocalIdx: guideTargetLocalIdx,
                    explanationAreaGuideStep: explanationStep,
                    bodyAreaGuideStep: bodyStep,
                  ),
                  contentControls:
                      state.settings.keywordMethod != KeywordMethod.off
                      ? ParagraphVisibilityControls(
                          selectedMode: state.displayMode,
                          onChanged: player.setDisplayMode,
                        )
                      : null,
                  practiceControls: RepeatPracticePanel(
                    l10n: l10n,
                    theme: theme,
                    recordingMode: recordingMode,
                    isProcessing: isProcessing,
                    currentAttempt: currentAttempt,
                    hintText: state.phase == RetellPhase.listening
                        ? (state.isPlaying
                              ? l10n.retellListeningPhase
                              : l10n.retellPreListenHint)
                        : null,
                    showCountdown: state.isRetellCountdown,
                    isInPause:
                        state.phase == RetellPhase.retelling &&
                        !state.isRetellCountdown,
                    countdownWidget: state.isRetellCountdown
                        ? Consumer(
                            builder: (context, ref, _) {
                              final s = ref.watch(
                                retellPlayerProvider.select(
                                  (s) => (
                                    total: s.pauseDuration,
                                    paused: s.isCountdownPaused,
                                    fastForward: s.isCountdownFastForward,
                                  ),
                                ),
                              );
                              return CountdownChip(
                                total: s.total,
                                isPaused: s.paused,
                                isFastForward: s.fastForward,
                                onTap: _takeOverCountdown,
                                onPause: () => ref
                                    .read(retellPlayerProvider.notifier)
                                    .pauseCountdown(),
                                onResume: () => ref
                                    .read(retellPlayerProvider.notifier)
                                    .resumeCountdown(),
                              );
                            },
                          )
                        : null,
                    onRecordTap: _handleRecordTap,
                    onBeforePlayback: _prepareAttemptPlayback,
                    showRatingBadge: retellRatingEnabled,
                    ratingBadgeController: _ratingBadgeController,
                    ratingPreviewControllerFactory: () =>
                        ref.read(retellRecordingPreviewProvider),
                    thresholds: RatingThresholds.retell,
                    showAiReviewButton: true,
                    isAiReviewLoading:
                        reviewPhase == RetellReviewEvaluationPhase.loading ||
                        reviewPhase == RetellReviewEvaluationPhase.streaming,
                    onAiReviewTap: () =>
                        unawaited(_handleAiReviewTap(currentAttempt)),
                  ),
                  canGoPrev: state.currentParagraphIndex > 0,
                  isLast:
                      state.currentParagraphIndex >= state.totalParagraphs - 1,
                  centerIcon: _isRetellMainPlaybackActive(state)
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onPrevious: _goToPreviousParagraph,
                  onNext: _goToNextParagraph,
                  onCenter: state.phase == RetellPhase.listening
                      ? (_isRetellMainPlaybackActive(state)
                            ? player.pause
                            : player.resume)
                      : _handleReplay,
                  isManualMode: state.settings.isManualMode,
                  playCountText: formatPracticePlayCount(
                    l10n,
                    currentCount: state.currentRepeatCount,
                    totalCount: state.settings.repeatCount,
                  ),
                  statusSuffixText: _formatSpeed(state.settings.playbackSpeed),
                  l10n: l10n,
                  theme: theme,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 当前播放句子的全局序号（1-based）。
///
/// [localIdx] 为 -1（未播放/录音阶段）时取当前段落首句的全局序号。
int _globalSentenceIdx(List<Sentence> paragraphSentences, int localIdx) {
  if (paragraphSentences.isEmpty) return 0;
  final pick = (localIdx >= 0 && localIdx < paragraphSentences.length)
      ? paragraphSentences[localIdx]
      : paragraphSentences.first;
  return pick.index + 1;
}

/// 友好的时长展示：不到 1 分钟显示「X秒」，否则显示「X分Y秒」
String _formatHumanDuration(AppLocalizations l10n, Duration duration) {
  final totalSec = duration.inSeconds;
  if (totalSec < 60) return l10n.retellParagraphDuration('$totalSec');
  return l10n.durationMinutesSeconds(totalSec ~/ 60, totalSec % 60);
}

/// 时长文案：仅显示当前段落时长。
String _formatDurationText(
  AppLocalizations l10n, {
  required Duration paragraphDuration,
}) => _formatHumanDuration(l10n, paragraphDuration);

/// 统一显示速度标签：始终保留一位小数。
String _formatSpeed(double speed) => formatPlaybackSpeedLabel(speed);

bool _isRetellMainPlaybackActive(RetellPlayerState state) {
  return state.phase == RetellPhase.listening &&
      state.isPlaying &&
      !state.isRetellCountdown &&
      !state.isCountdownPaused &&
      !state.isWaitingForUser;
}
