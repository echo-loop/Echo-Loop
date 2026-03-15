/// 收藏句子复习页面
///
/// 从 Favorites Tab 进入，加载所有收藏句子，按音频分组乱序后逐句复习。
/// 交互模式与难句补练页面（ReviewDifficultPracticeScreen）一致：
/// 盲听 1 遍 → 句间停顿 → 自动推进；偷看字幕、听不懂进入跟读模式。
///
/// 额外功能：
/// - 显示当前句子来源音频名称
/// - 跨音频自动切换（loadAudio）
/// - 取消收藏当前句子
/// - 完成后支持"再来一遍"（重新乱序）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/common/countdown_chip.dart';
import '../providers/learning_session/bookmark_review_provider.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/difficult_practice/difficult_practice_settings_sheet.dart';
import '../widgets/intensive_listen/sentence_annotation_card.dart';
import '../widgets/player_hotkey_scope.dart';

/// 收藏句子复习页面
class BookmarkReviewScreen extends ConsumerStatefulWidget {
  const BookmarkReviewScreen({super.key});

  @override
  ConsumerState<BookmarkReviewScreen> createState() =>
      _BookmarkReviewScreenState();
}

class _BookmarkReviewScreenState extends ConsumerState<BookmarkReviewScreen>
    with WakelockMixin {
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookmarkReviewProvider.notifier).startPlaying();
    });
  }

  @override
  void dispose() {
    // dispose 时清理 provider 资源
    // 使用 addPostFrameCallback 避免在 dispose 中直接读取 ref
    super.dispose();
  }

  /// 处理退出
  Future<void> _handleExit() async {
    final player = ref.read(bookmarkReviewProvider.notifier);
    player.pause();
    if (!mounted) return;

    // 收藏复习无需保存断点，直接退出
    player.disposePlayer();
    if (mounted) context.pop();
  }

  /// 取消当前句子的收藏
  Future<void> _handleRemoveBookmark() async {
    final player = ref.read(bookmarkReviewProvider.notifier);
    final removed = player.removeBookmark();

    if (removed != null) {
      final bookmarkDao = ref.read(bookmarkDaoProvider);
      await bookmarkDao.removeBookmark(
        removed.audioItemId,
        removed.originalSentenceIndex,
      );
    }

    // 如果还有句子且未完成，自动开始播放下一句
    final playerState = ref.read(bookmarkReviewProvider);
    if (!playerState.isCompleted && playerState.totalSentences > 0) {
      await player.startPlaying();
    }
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    final playerState = ref.read(bookmarkReviewProvider);
    final l10n = AppLocalizations.of(context)!;

    final result = await showFreePlayCompleteDialog(
      context: context,
      title: l10n.bookmarkReviewComplete,
      message: l10n.bookmarkReviewCompleteMessage(playerState.totalSentences),
      replayLabel: l10n.bookmarkReviewAgain,
    );

    _isShowingDialog = false;
    if (!mounted) return;

    if (result == true) {
      // 完成退出
      ref.read(bookmarkReviewProvider.notifier).disposePlayer();
      if (mounted) context.pop();
    } else {
      // 再来一遍
      await ref.read(bookmarkReviewProvider.notifier).resetToStart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final playerState = ref.watch(bookmarkReviewProvider);
    final player = ref.read(bookmarkReviewProvider.notifier);

    // 监听完成状态
    ref.listen<ReviewDifficultPracticeState>(bookmarkReviewProvider, (
      prev,
      next,
    ) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _handleCompleted();
      }
    });

    final currentBookmark = player.currentBookmarkSentence;
    final currentSentence = currentBookmark?.sentence;

    // 句子时长和时间戳
    final hasDuration =
        currentSentence != null && currentSentence.duration > Duration.zero;
    final durationText = hasDuration
        ? l10n.sentenceDuration(
            (currentSentence.duration.inMilliseconds / 1000.0).toStringAsFixed(
              1,
            ),
          )
        : null;
    final timestampText = hasDuration
        ? '${_formatTimestamp(currentSentence.startTime)}'
              ' - ${_formatTimestamp(currentSentence.endTime)}'
        : null;

    return LearningHotkeyScope(
      onPlayPause: () {
        if (playerState.isPauseBetweenPlays) {
          player.replayDuringCountdown();
        } else if (playerState.isPlaying) {
          player.pause();
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
            title: Text(l10n.bookmarkReviewTitle),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _handleExit,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: l10n.difficultPracticeSettings,
                onPressed: () =>
                    showBookmarkReviewSettingsSheet(context: context),
              ),
            ],
          ),
          body: Column(
            children: [
              // 进度区域
              _ProgressSection(
                playerState: playerState,
                audioName: currentBookmark?.audioName,
                l10n: l10n,
                durationText: durationText,
                timestampText: timestampText,
              ),

              // 主体内容：盲听/跟读 双态切换
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: playerState.isAnnotationMode
                      ? _ShadowReadingView(
                          key: const ValueKey('shadow'),
                          text: currentSentence?.text ?? '',
                          playerState: playerState,
                          l10n: l10n,
                          onRemoveBookmark: _handleRemoveBookmark,
                          onPauseCountdown: () => playerState.isCountdownPaused
                              ? player.resumeCountdown()
                              : player.pauseCountdown(),
                          aiNotifier: ref.read(sentenceAiNotifierProvider),
                          audioItemId: currentBookmark?.audioItemId,
                          sentenceIndex: currentBookmark?.originalSentenceIndex,
                        )
                      : _NormalModeView(
                          key: const ValueKey('normal'),
                          playerState: playerState,
                          l10n: l10n,
                          theme: theme,
                          onPeekToggle: () => player.setTextRevealed(
                            !playerState.isTextRevealed,
                          ),
                          onCantUnderstand: () => player.enterAnnotationMode(),
                          onRemoveBookmark: _handleRemoveBookmark,
                          onPauseCountdown: () => playerState.isCountdownPaused
                              ? player.resumeCountdown()
                              : player.pauseCountdown(),
                          sentenceText: currentSentence?.text,
                        ),
                ),
              ),

              // 底部播放控制
              _PlaybackControls(
                playerState: playerState,
                onPrevious: () => player.goToPrevious(),
                onNext: () => player.goToNext(),
                onPlayPause: () {
                  if (playerState.isPauseBetweenPlays) {
                    player.replayDuringCountdown();
                  } else if (playerState.isPlaying) {
                    player.pause();
                  } else {
                    player.resume();
                  }
                },
              ),

              // 遍数
              if (playerState.isAnnotationMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: Text(
                    l10n.listenAndRepeatPlayCount(
                      playerState.currentPlayCount,
                      playerState.targetRepeatCount,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                )
              else if (playerState.settings.blindListenRepeatCount > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: Text(
                    l10n.listenAndRepeatPlayCount(
                      playerState.currentPlayCount,
                      playerState.settings.blindListenRepeatCount,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: AppSpacing.m),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部进度条区域（含音频来源名称）
class _ProgressSection extends StatelessWidget {
  final ReviewDifficultPracticeState playerState;
  final String? audioName;
  final AppLocalizations l10n;
  final String? durationText;
  final String? timestampText;

  const _ProgressSection({
    required this.playerState,
    this.audioName,
    required this.l10n,
    this.durationText,
    this.timestampText,
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
    final timestampStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                l10n.bookmarkReviewProgress(current, total),
                style: subtitleStyle,
              ),
              const Spacer(),
              if (durationText case final dur?) Text(dur, style: subtitleStyle),
              if (timestampText case final ts?) ...[
                const SizedBox(width: 6),
                Text(ts, style: timestampStyle),
              ],
            ],
          ),
          // 来源音频名称
          if (audioName != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.bookmarkReviewFromAudio(audioName!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 普通模式视图（文字遮盖 / 偷看）
class _NormalModeView extends StatelessWidget {
  final ReviewDifficultPracticeState playerState;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onPeekToggle;
  final VoidCallback onCantUnderstand;
  final VoidCallback onRemoveBookmark;
  final VoidCallback onPauseCountdown;
  final String? sentenceText;

  const _NormalModeView({
    super.key,
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeekToggle,
    required this.onCantUnderstand,
    required this.onRemoveBookmark,
    required this.onPauseCountdown,
    this.sentenceText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 收藏标记行（点击取消收藏）
          GestureDetector(
            onTap: onRemoveBookmark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    l10n.intensiveListenMarkedDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.bookmark, color: Colors.amber, size: 18),
              ],
            ),
          ),

          // 遮盖/偷看区域
          Expanded(
            child: Center(
              child: playerState.isTextRevealed && sentenceText != null
                  ? Text(
                      sentenceText!,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
                      textAlign: TextAlign.center,
                    )
                  : _HiddenTextPlaceholder(),
            ),
          ),

          // 倒计时控制 + 盲听状态标签
          SizedBox(
            height: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (playerState.isPauseBetweenPlays)
                  CountdownChip(
                    remaining: playerState.pauseRemaining,
                    total: playerState.pauseDuration,
                    isPaused: playerState.isCountdownPaused,
                    onTap: onPauseCountdown,
                  ),
                if (playerState.isPlaying)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.headphones,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(
                        l10n.reviewDifficultPracticeBlindListen,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.m),

          // 偷看/听不懂按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onPeekToggle,
                child: _ActionChip(
                  icon: playerState.isTextRevealed
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  label: l10n.intensiveListenPeek,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              FilledButton.tonal(
                onPressed: onCantUnderstand,
                child: Text(l10n.intensiveListenCantUnderstand),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
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

/// 跟读模式视图
class _ShadowReadingView extends StatelessWidget {
  final String text;
  final ReviewDifficultPracticeState playerState;
  final AppLocalizations l10n;
  final VoidCallback onRemoveBookmark;
  final VoidCallback onPauseCountdown;
  final SentenceAiNotifier? aiNotifier;
  final String? audioItemId;
  final int? sentenceIndex;

  const _ShadowReadingView({
    super.key,
    required this.text,
    required this.playerState,
    required this.l10n,
    required this.onRemoveBookmark,
    required this.onPauseCountdown,
    this.aiNotifier,
    this.audioItemId,
    this.sentenceIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ai = aiNotifier;
    final cachedTranslation = ai?.getCachedTranslation(text)?.translation;
    final cachedAnalysis = ai?.getCachedAnalysis(text);
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 句子卡片（含 AI 翻译/解析）
          Expanded(
            child: SingleChildScrollView(
              child: SentenceAnnotationCard(
                key: ValueKey(text),
                text: text,
                isDifficult: true,
                onToggle: onRemoveBookmark,
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                onRequestTranslation: ai != null
                    ? () async {
                        final result = await ai.getTranslation(text);
                        return result.translation;
                      }
                    : null,
                onRequestAnalysis: ai != null
                    ? () async {
                        final result = await ai.getAnalysis(text);
                        return result.toDisplayString();
                      }
                    : null,
                cachedTranslation: cachedTranslation,
                cachedAnalysis: cachedAnalysisText,
              ),
            ),
          ),

          // 底部固定区域：跟读提示 / 倒计时
          SizedBox(
            height: 124,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (playerState.isPauseBetweenPlays) ...[
                  Text(
                    l10n.listenAndRepeatYourTurnHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  CountdownChip(
                    remaining: playerState.pauseRemaining,
                    total: playerState.pauseDuration,
                    isPaused: playerState.isCountdownPaused,
                    onTap: onPauseCountdown,
                  ),
                ],
                if (playerState.isPlaying) ...[
                  Text(
                    l10n.listenAndRepeatListenHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Icon(
                    Icons.headphones,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.m),
        ],
      ),
    );
  }
}

/// 操作按钮（偷看字幕）
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部播放控制
class _PlaybackControls extends StatelessWidget {
  final ReviewDifficultPracticeState playerState;
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
    final canGoNext =
        playerState.currentSentenceIndex < playerState.totalSentences - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.l,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.skip_previous_rounded,
            enabled: canGoPrev,
            onTap: canGoPrev ? onPrevious : null,
          ),
          const SizedBox(width: 48),

          GestureDetector(
            onTap: onPlayPause,
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
            icon: Icons.skip_next_rounded,
            enabled: canGoNext,
            onTap: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

/// 导航按钮
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 0.6 : 0.15,
        duration: const Duration(milliseconds: 150),
        child: Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// 格式化时间戳为 MM:SS.m 格式
String _formatTimestamp(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  final tenths = (d.inMilliseconds % 1000) ~/ 100;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$mm:$ss.$tenths';
  }
  return '$mm:$ss.$tenths';
}
