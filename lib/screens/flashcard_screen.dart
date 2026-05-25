/// Flashcard 单词卡片复习页面
///
/// 全屏页面，显示翻转卡片 + 底部控制栏 + 倒计时进度条。
/// 支持左右滑动切换卡片、点击翻转、自动倒计时。
///
/// 所有状态从 [FlashcardNotifier] 读取，用户操作调用 Notifier 方法。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/flashcard/flashcard_provider.dart';
import '../theme/app_theme.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/flashcard/flashcard_card.dart';
import '../widgets/flashcard/flashcard_settings_sheet.dart';

/// Flashcard 复习页面
class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen>
    with WakelockMixin {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: () =>
          ref.read(flashcardNotifierProvider.notifier).onAppBackgrounded(),
      onInactive: () =>
          ref.read(flashcardNotifierProvider.notifier).onAppBackgrounded(),
      // onResume 不做任何操作 — 保持 WaitingForUser 状态
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// 退出页面前清理资源并返回
  Future<void> _handleExit() async {
    await ref.read(flashcardNotifierProvider.notifier).disposePlayer();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 监听完成状态变化，控制屏幕常亮
    ref.listen(flashcardNotifierProvider.select((s) => s.isCompleted), (
      prev,
      next,
    ) {
      if (next) {
        shortenIdleTimeout(5);
      }
    });

    // 只监听影响卡片/AppBar 的字段，排除倒计时相关字段，
    // 避免倒计时每 100ms tick 导致整个页面重建
    final state = ref.watch(
      flashcardNotifierProvider.select(
        (s) => (
          words: s.words,
          currentIndex: s.currentIndex,
          isShowingBack: s.isShowingBack,
          isCompleted: s.isCompleted,
          removedCount: s.removedCount,
          navigationDirection: s.navigationDirection,
          navigationId: s.navigationId,
        ),
      ),
    );
    final l10n = AppLocalizations.of(context)!;

    if (state.isCompleted) {
      return wakelockBody(
        child: _CompletedView(
          totalReviewed: state.words.length + state.removedCount,
          removedCount: state.removedCount,
        ),
      );
    }

    final currentWord =
        state.words.isNotEmpty && state.currentIndex < state.words.length
        ? state.words[state.currentIndex]
        : null;

    return wakelockBody(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleExit();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _handleExit,
            ),
            title: Text(
              state.words.isNotEmpty
                  ? l10n.flashcardProgress(
                      state.currentIndex + 1,
                      state.words.length,
                    )
                  : l10n.flashcardTitle,
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => _showSettings(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              // 卡片区域
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity < -200) {
                      ref
                          .read(flashcardNotifierProvider.notifier)
                          .userNextCard();
                    } else if (velocity > 200) {
                      ref
                          .read(flashcardNotifierProvider.notifier)
                          .userPreviousCard();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                      vertical: AppSpacing.m,
                    ),
                    child: currentWord != null
                        ? ClipRect(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              transitionBuilder: (child, animation) {
                                final currentKey = ValueKey(
                                  '${currentWord.dbKey}_${state.navigationId}',
                                );
                                final isIncoming = child.key == currentKey;
                                final dir = state.navigationDirection;
                                final beginX = isIncoming ? dir : -dir;
                                final offset = Tween<Offset>(
                                  begin: Offset(beginX, 0),
                                  end: Offset.zero,
                                );
                                return SlideTransition(
                                  position: offset.animate(animation),
                                  child: child,
                                );
                              },
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                              child: FlashcardCard(
                                key: ValueKey(
                                  '${currentWord.dbKey}_${state.navigationId}',
                                ),
                                item: currentWord,
                                isShowingBack: state.isShowingBack,
                                onFlip: () => ref
                                    .read(flashcardNotifierProvider.notifier)
                                    .userFlipCard(),
                                onUnsave: () => _handleUnsave(context),
                                isUnsaved: ref
                                    .read(flashcardNotifierProvider.notifier)
                                    .isCurrentWordUnsaved,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),

              // 底部控制栏：用 Consumer 隔离倒计时重建
              Consumer(
                builder: (context, ref, _) {
                  final s = ref.watch(flashcardNotifierProvider);
                  return _BottomControls(
                    currentIndex: s.currentIndex,
                    totalCount: s.words.length,
                    countdownRemaining: s.countdownRemaining,
                    countdownTotal: s.countdownTotal,
                    showCountdown: s.showCountdown,
                    onPrevious: s.currentIndex > 0
                        ? () => ref
                              .read(flashcardNotifierProvider.notifier)
                              .userPreviousCard()
                        : null,
                    onNext: () => ref
                        .read(flashcardNotifierProvider.notifier)
                        .userNextCard(),
                    onCountdownTapped: () => ref
                        .read(flashcardNotifierProvider.notifier)
                        .onCountdownTapped(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示设置弹窗
  void _showSettings(BuildContext context) {
    final notifier = ref.read(flashcardNotifierProvider.notifier);
    notifier.onSettingsOpened();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FlashcardSettingsSheet(
        settings: ref.read(flashcardNotifierProvider).settings,
        onSettingsChanged: (settings) {
          notifier.updateSettings(settings);
        },
      ),
    );
    // 关闭后不 resume — 保持 WaitingForUser
  }

  /// 切换收藏状态（不影响 phase）
  void _handleUnsave(BuildContext context) {
    ref.read(flashcardNotifierProvider.notifier).toggleCurrentWordSave();
  }
}

/// 底部控制栏（上一张 / 环形倒计时 / 下一张）
class _BottomControls extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final Duration countdownRemaining;
  final Duration countdownTotal;
  final bool showCountdown;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCountdownTapped;

  const _BottomControls({
    required this.currentIndex,
    required this.totalCount,
    required this.countdownRemaining,
    required this.countdownTotal,
    required this.showCountdown,
    this.onPrevious,
    required this.onNext,
    required this.onCountdownTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 上一张
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.arrow_back_ios_new),
              color: theme.colorScheme.onSurfaceVariant,
            ),

            // 环形倒计时（仅在 Countdown phase 显示）
            if (showCountdown)
              CountdownChip(
                total: countdownTotal,
                isPaused: false,
                onPause: onCountdownTapped,
                onResume: onCountdownTapped,
              )
            else
              const SizedBox(width: 56, height: 56),

            // 下一张
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_ios),
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 完成页面
class _CompletedView extends ConsumerWidget {
  final int totalReviewed;
  final int removedCount;

  const _CompletedView({
    required this.totalReviewed,
    required this.removedCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.flashcardComplete), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                l10n.flashcardComplete,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                l10n.flashcardWordsReviewed(totalReviewed),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (removedCount > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.flashcardWordsRemoved(removedCount),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(flashcardNotifierProvider.notifier).reset(),
                    child: Text(l10n.flashcardPracticeAgain),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(flashcardNotifierProvider.notifier)
                          .disposePlayer();
                      Navigator.of(context).pop();
                    },
                    child: Text(l10n.flashcardFinish),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
