import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playback_settings.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../theme/app_theme.dart';
import '../utils/playback_speed.dart';
import 'common/anchored_bubble.dart';
import 'settings_dialog.dart';

String _formatPlaybackSpeedLabel(double speed) =>
    formatPlaybackSpeedLabel(speed);

class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(listeningPracticeProvider);
    final controller = ref.read(listeningPracticeProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return _buildMobileLayout(context, ref, playerState, controller);
        } else {
          return _buildDesktopLayout(context, ref, playerState, controller);
        }
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildToggleButton(
                context,
                icon: playerState.settings.singleSentenceMode
                    ? Icons.format_quote
                    : Icons.article,
                isActive: playerState.settings.singleSentenceMode,
                onPressed: () {
                  controller.updateSettings(
                    playerState.settings.copyWith(
                      singleSentenceMode:
                          !playerState.settings.singleSentenceMode,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              const _SpeedButton(),
              const SizedBox(width: 12),
              _buildToggleButton(
                context,
                icon: playerState.settings.showTranscript
                    ? Icons.visibility
                    : Icons.visibility_off,
                isActive: playerState.settings.showTranscript,
                onPressed: () {
                  controller.updateSettings(
                    playerState.settings.copyWith(
                      showTranscript: !playerState.settings.showTranscript,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              const _LoopButton(),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 32,
                  onPressed: playerState.hasSentences
                      ? () => controller.previousSentence()
                      : null,
                ),
                const SizedBox(width: 12),
                _buildPlayPauseButton(context, playerState, controller),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 32,
                  onPressed: playerState.hasSentences
                      ? () => controller.nextSentence()
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildToggleButton(
            context,
            icon: playerState.settings.singleSentenceMode
                ? Icons.format_quote
                : Icons.article,
            isActive: playerState.settings.singleSentenceMode,
            onPressed: () {
              controller.updateSettings(
                playerState.settings.copyWith(
                  singleSentenceMode: !playerState.settings.singleSentenceMode,
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          const _SpeedButton(),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.skip_previous),
            iconSize: 28,
            onPressed: playerState.hasSentences
                ? () => controller.previousSentence()
                : null,
          ),
          const SizedBox(width: 6),
          _buildPlayPauseButton(context, playerState, controller),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.skip_next),
            iconSize: 28,
            onPressed: playerState.hasSentences
                ? () => controller.nextSentence()
                : null,
          ),
          const SizedBox(width: 16),
          _buildToggleButton(
            context,
            icon: playerState.settings.showTranscript
                ? Icons.visibility
                : Icons.visibility_off,
            isActive: playerState.settings.showTranscript,
            onPressed: () {
              controller.updateSettings(
                playerState.settings.copyWith(
                  showTranscript: !playerState.settings.showTranscript,
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          const _LoopButton(),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton(
    BuildContext context,
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    // 图标读 controller 的逻辑播放态（唯一真相源），不读 just_audio 的瞬时
    // `playing`——后者在自然播完后仍为 true，会让图标停在「暂停」。
    final isPlaying = playerState.isPlaying;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
        iconSize: 36,
        color: Theme.of(context).colorScheme.onPrimary,
        onPressed: () {
          if (isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        },
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon),
      iconSize: 22,
      // 激活态：浅色调底 + 主色图标（MD3 tonal toggle，轻量、不与主播放按钮抢注意力）；
      // 未激活态：灰图标无背景。
      color: isActive
          ? colorScheme.primary
          : colorScheme.onSurface.withValues(alpha: 0.6),
      style: isActive
          ? IconButton.styleFrom(backgroundColor: colorScheme.primaryContainer)
          : null,
      onPressed: onPressed,
    );
  }
}

/// 播放速度按钮：点击在按钮上方弹出速度选择气泡浮层（与循环设置浮层同一骨架）。
///
/// 锚点显示当前速度（弱化灰，与未激活切换按钮一致），用共享 [AnchoredBubble]（方向
/// 向上）弹出离散速度档位，当前档加粗高亮 + 行尾打勾，点选即生效并收起浮层。
class _SpeedButton extends ConsumerStatefulWidget {
  const _SpeedButton();

  @override
  ConsumerState<_SpeedButton> createState() => _SpeedButtonState();
}

class _SpeedButtonState extends ConsumerState<_SpeedButton> {
  final OverlayPortalController _portalController = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    final speed = ref.watch(
      listeningPracticeProvider.select((s) => s.settings.playbackSpeed),
    );
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return AnchoredBubble(
      controller: _portalController,
      direction: BubbleDirection.up,
      width: 120,
      contentBuilder: (_) => _SpeedPopup(onSelected: _portalController.hide),
      child: TextButton(
        onPressed: _portalController.toggle,
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: color,
        ),
        child: Text(
          _formatPlaybackSpeedLabel(speed),
          style: TextStyle(fontSize: 14, color: color),
        ),
      ),
    );
  }
}

/// 速度选择气泡浮层内容（气泡卡片内部内容）。
class _SpeedPopup extends ConsumerWidget {
  const _SpeedPopup({required this.onSelected});

  /// 选择后回调（用于收起浮层）。
  final VoidCallback onSelected;

  /// 可选速度档位。
  static const List<double> _speeds = kFreePlayerPlaybackSpeeds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(
      listeningPracticeProvider.select((s) => s.settings),
    );
    final controller = ref.read(listeningPracticeProvider.notifier);
    final current = settings.playbackSpeed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final speed in _speeds)
            BubbleMenuRow(
              label: _formatPlaybackSpeedLabel(speed),
              selected: speed == current,
              color: speed == current
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              trailing: speed == current
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.primary,
                    )
                  : null,
              onTap: () {
                controller.updateSettings(
                  settings.copyWith(playbackSpeed: speed),
                );
                onSelected();
              },
            ),
        ],
      ),
    );
  }
}

/// 循环设置按钮：点击在按钮上方弹出悬浮的循环设置浮层（[LoopSettingsPopup]）。
///
/// 用共享的 [AnchoredBubble]（方向向上）锚定到按钮：浮层在按钮正上方居中弹出、底部
/// 带指向按钮的向下箭头，点击外部即关闭。任一循环开启时图标高亮；仅单句循环开时用
/// repeat_one，否则用 repeat。
class _LoopButton extends ConsumerStatefulWidget {
  const _LoopButton();

  @override
  ConsumerState<_LoopButton> createState() => _LoopButtonState();
}

class _LoopButtonState extends ConsumerState<_LoopButton> {
  final OverlayPortalController _portalController = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(
      listeningPracticeProvider.select((s) => s.settings),
    );
    final isActive = settings.loopWhole || settings.loopSentence;
    final icon = settings.loopSentence && !settings.loopWhole
        ? Icons.repeat_one
        : Icons.repeat;
    final colorScheme = Theme.of(context).colorScheme;

    return AnchoredBubble(
      controller: _portalController,
      direction: BubbleDirection.up,
      width: 280,
      contentBuilder: (_) => const LoopSettingsPopup(),
      child: IconButton(
        icon: Icon(icon),
        iconSize: 22,
        // 与其它切换按钮一致：激活态浅色调底 + 主色图标，未激活态灰图标。
        color: isActive
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(alpha: 0.6),
        style: isActive
            ? IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
              )
            : null,
        onPressed: _portalController.toggle,
      ),
    );
  }
}
