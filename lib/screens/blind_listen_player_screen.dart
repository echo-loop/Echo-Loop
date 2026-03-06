/// 盲听播放器页面
///
/// 极简播放器界面，仅包含播放/暂停按钮和进度条。
/// 不显示字幕、句子列表、设置等元素。
///
/// 播放完成后根据目标遍数决定行为：
/// - 未达目标遍数：显示 5 秒倒计时 → 自动播放下一遍
/// - 已达/超过目标遍数：弹完成对话框（难度选择 + 双按钮）
/// - 自由练习模式：无倒计时，弹完成/再听一遍对话框
///
/// 完成对话框支持三种操作：
/// - 再听一遍：重播当前盲听
/// - 返回计划：保存进度后返回学习计划页
/// - 继续下一步：直接跳转到下一个子步骤的播放器
///
/// 进度条使用 BlindListenPlayer 的 drag-safe 状态驱动，
/// 拖动期间只更新显示位置不 seek，松手后再执行实际 seek。
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/blind_listen_player_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/blind_listen_complete_dialog.dart';

/// 盲听播放器页面
class BlindListenPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（用于返回导航，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const BlindListenPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<BlindListenPlayerScreen> createState() =>
      _BlindListenPlayerScreenState();
}

class _BlindListenPlayerScreenState
    extends ConsumerState<BlindListenPlayerScreen> {
  /// 是否正在显示完成对话框（防止重复弹出）
  bool _isShowingDialog = false;

  /// 倒计时剩余时长（null = 不显示倒计时）
  Duration? _countdownRemaining;

  /// 倒计时总时长
  static const _countdownTotal = Duration(seconds: 5);

  /// 倒计时定时器（100ms 精度）
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // 进入后自动开始播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(blindListenPlayerProvider.notifier).play();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 处理播放完成
  ///
  /// 根据目标遍数决定行为：
  /// - 未达目标遍数 → 显示 5 秒倒计时 → 自动播放下一遍
  /// - 已达/超过目标遍数 → 弹完成对话框（难度选择 + 再听一遍）
  void _handlePlaybackCompleted() {
    if (_isShowingDialog || _countdownRemaining != null) return;

    final session = ref.read(learningSessionProvider);

    // 自由练习模式：弹窗询问"完成"或"再听一遍"
    if (session.isFreePlay) {
      _showFreePlayCompleteDialog();
      return;
    }

    if (session.hasRemainingPasses) {
      // 未达目标遍数 → 倒计时 → 自动播放下一遍
      _startCountdown();
    } else {
      // 达到目标遍数 → 弹完成对话框
      _showCompleteDialog();
    }
  }

  /// 自由练习完成对话框
  Future<void> _showFreePlayCompleteDialog() async {
    _isShowingDialog = true;
    final l10n = AppLocalizations.of(context)!;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FreePlayCompleteDialog(
        title: l10n.blindListenComplete,
      ),
    );

    _isShowingDialog = false;
    if (!mounted) return;

    if (result == true) {
      // 完成退出
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
    } else {
      // 再听一遍
      await ref.read(learningSessionProvider.notifier).replayBlindListen();
    }
  }

  /// 开始 5 秒倒计时，结束后自动播放下一遍
  void _startCountdown() {
    setState(() {
      _countdownRemaining = _countdownTotal;
    });

    const tick = Duration(milliseconds: 100);
    _countdownTimer = Timer.periodic(tick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _countdownRemaining! - tick;
      if (next <= Duration.zero) {
        timer.cancel();
        setState(() {
          _countdownRemaining = null;
        });
        // 倒计时结束 → 自动播放下一遍
        ref.read(learningSessionProvider.notifier).replayBlindListen();
      } else {
        setState(() {
          _countdownRemaining = next;
        });
      }
    });
  }

  /// 跳过倒计时，直接开始下一遍
  void _skipCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _countdownRemaining = null;
    });
    // 跳过倒计时 → 自动播放下一遍
    ref.read(learningSessionProvider.notifier).replayBlindListen();
  }

  /// 获取当前步骤的上下文信息
  ///
  /// [nextStepName] 为 null 表示下一步没有播放器或不存在。
  /// [isLastStep] 为 true 表示当前是阶段的最后一步。
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
      return (
        stepIndex: 0,
        totalSteps: LearningStage.firstLearn.subStageCount,
        stageName: LearningStage.firstLearn.label,
        nextStepName: _hasPlayerScreen(SubStageType.intensiveListen)
            ? _getSubStageName(SubStageType.intensiveListen, l10n)
            : null,
        isLastStep: false,
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
      stageName: stage.label,
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 显示完成对话框
  Future<void> _showCompleteDialog() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    final session = ref.read(learningSessionProvider);
    final stepCtx = _getStepContext();

    // 复习模式下不显示难度选择器
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    final isReview = progress?.isInReviewStage ?? false;

    final result = await showBlindListenCompleteDialog(
      context: context,
      passCount: session.blindListenPassCount,
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      nextStepName: stepCtx.nextStepName,
      isLastStep: stepCtx.isLastStep,
      showDifficultySelector: !isReview,
    );

    _isShowingDialog = false;
    if (!mounted) return;

    if (result == null) {
      // 用户选择"再听一遍"
      await ref.read(learningSessionProvider.notifier).replayBlindListen();
    } else {
      // 保存难度（仅首学模式）→ 推进子步骤
      try {
        if (!isReview) {
          await ref
              .read(learningProgressNotifierProvider.notifier)
              .setDifficulty(widget.audioItemId, result.difficulty);
        }
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .completeCurrentSubStage(widget.audioItemId);
      } catch (e) {
        debugPrint('盲听完成处理出错: $e');
      }

      if (result.continueToNext) {
        // 继续下一步：退出盲听模式 → 进入下一步模式 → 替换路由
        await _navigateToNextStep();
      } else {
        // 返回计划页
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      }
    }
  }

  /// 导航到下一个子步骤
  ///
  /// 完成盲听后，根据新的当前子步骤进入对应播放器。
  /// 使用 pushReplacement 替换当前路由，避免返回栈堆积。
  Future<void> _navigateToNextStep() async {
    // 读取更新后的进度（completeCurrentSubStage 已推进到下一步）
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    if (progress == null || !mounted) {
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
      return;
    }

    final nextSubStage = progress.currentSubStage;

    if (nextSubStage == SubStageType.intensiveListen) {
      // 退出盲听模式 → LP 恢复 → 读取句子 → 进入精听模式
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (!mounted) return;

      final lpState = ref.read(listeningPracticeProvider);
      if (lpState.sentences.isEmpty) {
        if (mounted) context.pop();
        return;
      }

      await ref
          .read(learningSessionProvider.notifier)
          .enterIntensiveListenMode(widget.audioItemId, lpState.sentences);
      if (mounted) {
        context.pushReplacement(
          AppRoutes.intensiveListenPlayer(
            widget.collectionId,
            widget.audioItemId,
          ),
        );
      }
    } else if (nextSubStage == SubStageType.reviewDifficultPractice) {
      // 复习盲听后 → 进入难句补练
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (!mounted) return;

      final lpState = ref.read(listeningPracticeProvider);
      if (lpState.sentences.isEmpty) {
        if (mounted) context.pop();
        return;
      }

      await ref
          .read(learningSessionProvider.notifier)
          .enterReviewDifficultPracticeMode(
            widget.audioItemId,
            lpState.sentences,
          );
      if (mounted) {
        context.pushReplacement(
          AppRoutes.reviewDifficultPractice(
            widget.collectionId,
            widget.audioItemId,
          ),
        );
      }
    } else {
      // 其他子步骤 → 返回计划页
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
    }
  }

  /// 格式化时长为 mm:ss
  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 监听学习会话状态
    final session = ref.watch(learningSessionProvider);
    final playerState = ref.watch(blindListenPlayerProvider);

    // 当盲听完成时触发处理
    ref.listen<LearningSessionState>(learningSessionProvider, (prev, next) {
      if (next.blindListenCompleted && !(prev?.blindListenCompleted ?? false)) {
        _handlePlaybackCompleted();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        // 自由练习模式直接退出，不弹确认对话框
        // 正常学习模式播放中弹出退出确认对话框
        if (playerState.isPlaying && !session.isFreePlay) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.exitBlindListenTitle),
              content: Text(l10n.exitBlindListenMessage),
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
          if (confirm != true || !mounted) return;
        }

        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.blindListenAppBarTitle),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              // 触发 PopScope 的 onPopInvokedWithResult
              Navigator.of(context).maybePop();
            },
          ),
        ),
        body: Column(
          children: [
            // 中央区域 — 大播放按钮 + 耳机图标
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 耳机图标
                    Icon(
                      Icons.headphones,
                      size: 80,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 播放/暂停按钮
                    GestureDetector(
                      onTap: () {
                        final player = ref.read(
                          blindListenPlayerProvider.notifier,
                        );
                        if (playerState.isPlaying) {
                          player.pause();
                        } else {
                          player.play();
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          playerState.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          size: 40,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),

                    // 倒计时信息区域（固定高度，避免布局跳动）
                    SizedBox(
                      height: 64,
                      child: _countdownRemaining != null
                          ? _CountdownIndicator(
                              remaining: _countdownRemaining!,
                              total: _countdownTotal,
                              l10n: l10n,
                              onSkip: _skipCountdown,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // 底部进度条
            _ProgressSection(formatDuration: _formatDuration),
          ],
        ),
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
  SubStageType.reviewDifficultPractice => true,
  SubStageType.reviewRetellParagraph => true,
  SubStageType.reviewRetellSummary => true,
};

/// 获取子步骤的本地化名称
String _getSubStageName(SubStageType type, AppLocalizations l10n) =>
    switch (type) {
      SubStageType.blindListen => l10n.stepBlindListening,
      SubStageType.intensiveListen => l10n.stepIntensiveListening,
      SubStageType.listenAndRepeat => l10n.stepShadowing,
      SubStageType.retell => l10n.stepRetelling,
      SubStageType.reviewDifficultPractice => l10n.reviewDifficultPracticeTitle,
      SubStageType.reviewRetellParagraph => l10n.stepRetelling,
      SubStageType.reviewRetellSummary => l10n.stepRetelling,
    };

/// 底部进度条区域 — 完全由 BlindListenPlayer 状态驱动
class _ProgressSection extends ConsumerWidget {
  final String Function(Duration) formatDuration;

  const _ProgressSection({required this.formatDuration});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playerState = ref.watch(blindListenPlayerProvider);
    final blindPlayer = ref.read(blindListenPlayerProvider.notifier);

    final totalMs = playerState.totalDuration.inMilliseconds;
    final posMs = playerState.position.inMilliseconds.clamp(0, totalMs);
    final progress = totalMs > 0 ? posMs / totalMs : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
              thumbColor: theme.colorScheme.primary,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChangeStart: (_) => blindPlayer.onDragStart(),
              onChanged: (value) {
                final pos = Duration(milliseconds: (value * totalMs).round());
                blindPlayer.onDragUpdate(pos);
              },
              onChangeEnd: (value) {
                final pos = Duration(milliseconds: (value * totalMs).round());
                blindPlayer.onDragEnd(pos);
              },
            ),
          ),
          // 时间标签
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDuration(Duration(milliseconds: posMs)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatDuration(playerState.totalDuration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 内联倒计时指示器 — 文字标签 + 线性进度条 + 跳过按钮
class _CountdownIndicator extends StatelessWidget {
  final Duration remaining;
  final Duration total;
  final AppLocalizations l10n;
  final VoidCallback onSkip;

  const _CountdownIndicator({
    required this.remaining,
    required this.total,
    required this.l10n,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = total.inMilliseconds;
    final remainingMs = remaining.inMilliseconds;
    final progress = totalMs > 0 ? 1.0 - (remainingMs / totalMs) : 1.0;
    final seconds = (remainingMs / 1000).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.blindListenCountdown(seconds),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        TextButton(onPressed: onSkip, child: Text(l10n.skipCountdown)),
      ],
    );
  }
}

/// 盲听自由练习完成对话框
///
/// 返回 `true` 表示完成退出，`false` 表示再听一遍。
class _FreePlayCompleteDialog extends StatelessWidget {
  final String title;

  const _FreePlayCompleteDialog({required this.title});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Flexible(child: Text(title)),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.done),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.listenAgain),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
