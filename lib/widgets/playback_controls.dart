import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import 'settings_dialog.dart';

class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(listeningPracticeProvider);
    final controller = ref.read(listeningPracticeProvider.notifier);
    final engineNotifier = ref.read(audioEngineProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return _buildMobileLayout(
            context,
            ref,
            playerState,
            controller,
            engineNotifier,
          );
        } else {
          return _buildDesktopLayout(
            context,
            ref,
            playerState,
            controller,
            engineNotifier,
          );
        }
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    ListeningPracticeState playerState,
    ListeningPractice controller,
    AudioEngine engineNotifier,
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
              const SizedBox(width: 4),
              _buildSpeedButton(context, playerState, controller),
              const SizedBox(width: 4),
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
              const SizedBox(width: 4),
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
                _buildPlayPauseButton(context, controller, engineNotifier),
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
    AudioEngine engineNotifier,
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
          _buildSpeedButton(context, playerState, controller),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.skip_previous),
            iconSize: 28,
            onPressed: playerState.hasSentences
                ? () => controller.previousSentence()
                : null,
          ),
          const SizedBox(width: 6),
          _buildPlayPauseButton(context, controller, engineNotifier),
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
    ListeningPractice controller,
    AudioEngine engineNotifier,
  ) {
    final isPlaying = engineNotifier.isPlaying;
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
    return IconButton(
      icon: Icon(icon),
      iconSize: 22,
      color: isActive
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      onPressed: onPressed,
    );
  }

  Widget _buildSpeedButton(
    BuildContext context,
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    return PopupMenuButton<double>(
      icon: Text(
        '${playerState.settings.playbackSpeed}x',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      itemBuilder: (context) {
        return [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
          return PopupMenuItem<double>(
            value: speed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${speed}x'),
                if (speed == playerState.settings.playbackSpeed)
                  Icon(
                    Icons.check,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          );
        }).toList();
      },
      onSelected: (speed) {
        controller.updateSettings(
          playerState.settings.copyWith(playbackSpeed: speed),
        );
      },
    );
  }
}

/// 循环设置按钮：点击在按钮上方弹出悬浮的循环设置浮层（[LoopSettingsPopup]）。
///
/// 浮层在按钮**正上方居中**弹出、底部带指向按钮的向下箭头；浮层水平夹紧在屏幕内
/// （左右各留 [_margin]），箭头随之平移始终对准按钮中心。浮层下方铺一层透明遮罩，
/// 点击外部即关闭。任一循环开启时图标高亮；仅单句循环开时用 repeat_one，否则用 repeat。
class _LoopButton extends ConsumerStatefulWidget {
  const _LoopButton();

  @override
  ConsumerState<_LoopButton> createState() => _LoopButtonState();
}

class _LoopButtonState extends ConsumerState<_LoopButton> {
  final OverlayPortalController _portalController = OverlayPortalController();
  final GlobalKey _buttonKey = GlobalKey();

  /// 浮层宽度与屏幕安全边距。
  static const double _popupWidth = 280;
  static const double _margin = 16;

  /// 构建悬浮内容：依据按钮在屏幕中的位置定位浮层并对齐箭头。
  Widget _buildOverlay(BuildContext overlayContext) {
    final overlayBox =
        Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;
    final buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || buttonBox == null) {
      return const SizedBox.shrink();
    }

    final screen = overlayBox.size;
    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final buttonCenterX = buttonTopLeft.dx + buttonBox.size.width / 2;

    final width = math.min(_popupWidth, screen.width - _margin * 2);
    // 居中对齐按钮，再夹紧到屏幕内
    final left = (buttonCenterX - width / 2).clamp(
      _margin,
      screen.width - _margin - width,
    );
    final caretX = buttonCenterX - left;
    // 浮层底边到屏幕底部的距离：贴在按钮上方留 8px 间隙
    final bottom = screen.height - buttonTopLeft.dy + 8;

    return Stack(
      children: [
        // 透明遮罩：点击浮层外部关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _portalController.hide,
          ),
        ),
        Positioned(
          left: left,
          bottom: bottom,
          width: width,
          // 吸收浮层范围内的点击，避免穿透到遮罩误关闭
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: LoopSettingsPopup(width: width, caretX: caretX),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(
      listeningPracticeProvider.select((s) => s.settings),
    );
    final isActive = settings.loopWhole || settings.loopSentence;
    final icon = settings.loopSentence && !settings.loopWhole
        ? Icons.repeat_one
        : Icons.repeat;

    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: _buildOverlay,
      child: IconButton(
        key: _buttonKey,
        icon: Icon(icon),
        iconSize: 22,
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        onPressed: _portalController.toggle,
      ),
    );
  }
}
