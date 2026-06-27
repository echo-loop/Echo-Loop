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
import '../l10n/app_localizations.dart';
import '../utils/playback_speed.dart';
import '../models/retell_settings.dart';
import '../models/sentence.dart';
import '../models/speech_practice_models.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_settings_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/retell_player_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../widgets/common/recording_button.dart' show RecordingButtonMode;
import '../providers/retell_recording_controller_provider.dart';
import '../services/audio_playback_service.dart';
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
import '../widgets/common/paragraph_sentence_list_card.dart';
import '../widgets/guide_flow.dart';
import '../widgets/common/paragraph_visibility_controls.dart';
import '../widgets/retell/retell_settings_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/speech_permission_dialog.dart';
import '../widgets/practice/practice_play_count_label.dart';

/// 复述录音 badge 回放使用的播放服务。
///
/// 自动回放和用户手动点击 badge 共用这一个服务，保证播放状态、
/// 停止图标和点击停止行为一致；测试中可注入无平台依赖的替身。
final retellAutoPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = AudioPlaybackService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// 复述播放器页面
class RetellPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（独立音频路由时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const RetellPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
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

  /// 新手引导：编号区 / 主体区 Showcase key（随 State 生命周期存在）
  final GlobalKey _guideNumberKey = GlobalKey(
    debugLabel: 'retellGuideSentenceNumber',
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

  ProviderSubscription<RetellPlayerState>? _playerSubscription;
  ProviderSubscription<RetellRecordingState>? _recordingSubscription;
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
    _silenceSkipSub = ref
        .read(retellPlayerProvider.notifier)
        .silenceSkipEventStream
        .listen(_showSilenceSkippedSnackBar);
    _latestPlayerState = ref.read(retellPlayerProvider);
    _latestRecordingState = ref.read(retellRecordingControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await ensureSpeechReadyForRecording(context, ref);
      if (!mounted) return;
      if (!ok) {
        if (context.canPop()) context.pop();
        return;
      }
      final settings = ref.read(retellPlayerProvider).settings;
      ref
          .read(retellRecordingControllerProvider.notifier)
          .setManualMode(settings.isManualMode);
      ref.read(retellPlayerProvider.notifier).startPlaying();
      final playerState = _latestPlayerState;
      final recState = _latestRecordingState;
      if (playerState != null && recState != null) {
        _maybeAutoStartRecording(playerState: playerState, recState: recState);
      }
    });
  }

  @override
  void dispose() {
    _autoPlaybackToken += 1;
    _isHandlingEvaluationComplete = false;
    unawaited(_ratingBadgeController.stop());
    _playerSubscription?.close();
    _recordingSubscription?.close();
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
      ref.read(learningSessionProvider.notifier).pauseStudyTimer();
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
      ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    }

    final recState = _latestRecordingState;
    if (recState != null) {
      _maybeAutoStartRecording(playerState: next, recState: recState);
    }
  }

  void _onRetellRecordingStateChanged(
    RetellRecordingState? prev,
    RetellRecordingState next,
  ) {
    _latestRecordingState = next;
    if (!mounted || _isExiting) return;
    if (prev != null) {
      _logRetellRecordingStateTransition(prev, next);
    }
    // 评估完成（有 ASR: processing→idle，无 ASR: recording→idle）
    if (prev?.phase != RetellRecordingPhase.idle &&
        next.phase == RetellRecordingPhase.idle) {
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

  void _maybeAutoStartRecording({
    required RetellPlayerState playerState,
    required RetellRecordingState recState,
  }) {
    if (!mounted || _isShowingDialog) return;

    if (playerState.phase != RetellPhase.retelling ||
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
      // 关闭弹窗 → 留在页面，不做操作
    }
  }

  /// 重播当前段落
  Future<void> _handleReplay() async {
    _manualStoppedThisParagraph = false;
    AppLogger.log('RetellScreen', '重播当前段落');
    await _cancelRecordingAndPlayback();
    ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    await ref.read(retellPlayerProvider.notifier).replayDuringCountdown();
  }

  /// 切段：retelling 阶段走 completeRetellingTurn（记录统计 + 遍数逻辑）。
  ///
  /// 最后一段时保留录音结果（badge）和手动标记，避免完成弹窗期间
  /// 触发自动录音或 badge 消失。
  Future<void> _goToNextParagraph() async {
    final retellState = ref.read(retellPlayerProvider);
    final isLastParagraph =
        retellState.currentParagraphIndex >= retellState.totalParagraphs - 1;

    if (!isLastParagraph) {
      _manualStoppedThisParagraph = false;
      ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    }

    AppLogger.log('RetellScreen', '→ 下一段 (last=$isLastParagraph)');
    await _cancelRecordingAndPlayback();

    if (retellState.phase == RetellPhase.retelling) {
      await ref.read(retellPlayerProvider.notifier).completeRetellingTurn();
    } else {
      await ref.read(retellPlayerProvider.notifier).goToNextParagraph();
    }

    // 最后一段 → 直接触发完成处理
    if (isLastParagraph) {
      _handleCompleted();
    }
  }

  Future<void> _goToPreviousParagraph() async {
    _manualStoppedThisParagraph = false;
    AppLogger.log('RetellScreen', '→ 上一段');
    await _cancelRecordingAndPlayback();
    ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    await ref.read(retellPlayerProvider.notifier).goToPreviousParagraph();
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

  /// 点击句子编号 → 从该句开始播放
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

    await context.push(
      AppRoutes.sentenceDetail,
      extra: SentenceDetailArgs(
        audioItemId: widget.audioItemId,
        audioName: audioName,
        sentenceText: sentence.text,
        sentenceIndex: sentence.index,
        startTimeMs: sentence.startTime.inMilliseconds,
        endTimeMs: sentence.endTime.inMilliseconds,
      ),
    );

    _isNavigatingToDetail = false;

    // 返回后刷新收藏状态（详情页可能修改了收藏）
    if (!mounted) return;
    await ref
        .read(retellPlayerProvider.notifier)
        .initializeBookmarks(widget.audioItemId);
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

    // 新手引导：编号→开播、文本→讲解。统一挂在第 1 句（idx=0），首项最显眼。
    // 盲听和复述共用同一个 flow id —— 用户先在任一页看过就不再弹另一页。
    const guideTargetLocalIdx = 0;
    final numberStep = GuideStep(
      key: _guideNumberKey,
      description: l10n.guideSentenceTileNumberDescription,
    );
    final bodyStep = GuideStep(
      key: _guideBodyKey,
      description: l10n.guideSentenceTileBodyDescription,
    );
    final guideFlows = <GuideFlow>[
      GuideFlow(
        flowId: GuideFlowIds.sentenceTileTour,
        shouldRun: sentences.isNotEmpty,
        steps: [numberStep, bodyStep],
      ),
    ];

    return wakelockBody(
      child: LearningHotkeyScope(
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
            await _handleExit();
          },
          child: GuideFlowSequenceHost(
            flows: guideFlows,
            child: ParagraphPracticeScaffold(
              title: l10n.retellTitle,
              onClose: _handleExit,
              onOpenSettings: _openSettings,
              current: progressCurrent,
              total: progressTotal,
              progressText: progressText,
              durationText: _formatDurationText(
                l10n,
                paragraphDuration: paragraphDuration,
                totalDuration: player.totalDuration,
                paragraphTotal: state.totalParagraphs,
              ),
              onSeekToIndex: isMultiParagraph
                  ? (p) => notifier.seekToParagraph(p)
                  : (i) => notifier.seekToSentence(i),
              paragraphContent: ParagraphSentenceListCard(
                sentences: sentences,
                displayMode: state.settings.keywordMethod != KeywordMethod.off
                    ? state.displayMode
                    : RetellDisplayMode.hideAll,
                keywordMap: keywords,
                playingSentenceIndex: state.phase == RetellPhase.listening
                    ? state.playingSentenceIndex
                    : -1,
                bookmarkedSentenceIndices: state.bookmarkedSentenceIndices,
                onSentenceTap: _handleSentenceDetail,
                onSentencePlayFrom: _handleSentencePlayFrom,
                onSentenceBookmarkToggle: (sentence) => ref
                    .read(retellPlayerProvider.notifier)
                    .toggleBookmark(widget.audioItemId, sentence),
                guideTargetLocalIdx: guideTargetLocalIdx,
                numberAreaGuideStep: numberStep,
                bodyAreaGuideStep: bodyStep,
              ),
              contentControls: state.settings.keywordMethod != KeywordMethod.off
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
                onFastForward:
                    state.isRetellCountdown && !state.isCountdownPaused
                    ? () => ref
                          .read(retellPlayerProvider.notifier)
                          .toggleCountdownFastForward()
                    : null,
                onBeforePlayback: _prepareAttemptPlayback,
                showRatingBadge: retellRatingEnabled,
                ratingBadgeController: _ratingBadgeController,
                ratingPlaybackServiceFactory: () =>
                    ref.read(retellAutoPlaybackServiceProvider),
                thresholds: RatingThresholds.retell,
              ),
              canGoPrev: state.currentParagraphIndex > 0,
              isLast: state.currentParagraphIndex >= state.totalParagraphs - 1,
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

/// 时长文案：单段时只显示总长，多段时显示「段长 / 总长」
String _formatDurationText(
  AppLocalizations l10n, {
  required Duration paragraphDuration,
  required Duration totalDuration,
  required int paragraphTotal,
}) {
  if (paragraphTotal <= 1) return _formatHumanDuration(l10n, totalDuration);
  return '${_formatHumanDuration(l10n, paragraphDuration)} / '
      '${_formatHumanDuration(l10n, totalDuration)}';
}

/// 统一显示速度标签：始终保留一位小数。
String _formatSpeed(double speed) => formatPlaybackSpeedLabel(speed);

bool _isRetellMainPlaybackActive(RetellPlayerState state) {
  return state.phase == RetellPhase.listening &&
      state.isPlaying &&
      !state.isRetellCountdown &&
      !state.isCountdownPaused &&
      !state.isWaitingForUser;
}
