import 'package:flutter/material.dart';
import '../providers/player_provider.dart';

class PlaybackControls extends StatelessWidget {
  final PlayerProvider player;

  const PlaybackControls({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return _buildMobileLayout(context);
        } else {
          return _buildDesktopLayout(context);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：功能按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildToggleButton(
                context,
                icon: player.settings.singleSentenceMode
                    ? Icons.format_quote
                    : Icons.article,
                isActive: player.settings.singleSentenceMode,
                onPressed: () {
                  player.updateSettings(
                    player.settings.copyWith(
                      singleSentenceMode: !player.settings.singleSentenceMode,
                    ),
                  );
                },
                tooltip: 'Single Sentence Mode',
              ),
              const SizedBox(width: 4),
              _buildSpeedButton(context),
              const SizedBox(width: 4),
              _buildToggleButton(
                context,
                icon: player.settings.showTranscript
                    ? Icons.visibility
                    : Icons.visibility_off,
                isActive: player.settings.showTranscript,
                onPressed: () {
                  player.updateSettings(
                    player.settings.copyWith(
                      showTranscript: !player.settings.showTranscript,
                    ),
                  );
                },
                tooltip: 'Show Transcript',
              ),
              const SizedBox(width: 4),
              _buildToggleButton(
                context,
                icon: Icons.repeat_one,
                isActive: player.settings.loopEnabled,
                onPressed: () {
                  player.updateSettings(
                    player.settings.copyWith(
                      loopEnabled: !player.settings.loopEnabled,
                    ),
                  );
                },
                tooltip: 'Sentence Repeat',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行：播放控制按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 32,
                  onPressed: player.hasSentences
                      ? () => player.previousSentence()
                      : null,
                  tooltip: 'Previous Sentence',
                ),
                const SizedBox(width: 12),
                _buildPlayPauseButton(context),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 32,
                  onPressed: player.hasSentences
                      ? () => player.nextSentence()
                      : null,
                  tooltip: 'Next Sentence',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左侧：单句模式和速度
          _buildToggleButton(
            context,
            icon: player.settings.singleSentenceMode
                ? Icons.format_quote
                : Icons.article,
            isActive: player.settings.singleSentenceMode,
            onPressed: () {
              player.updateSettings(
                player.settings.copyWith(
                  singleSentenceMode: !player.settings.singleSentenceMode,
                ),
              );
            },
            tooltip: 'Single Sentence Mode',
          ),
          const SizedBox(width: 6),
          _buildSpeedButton(context),
          const SizedBox(width: 16),
          // 中间：播放控制
          IconButton(
            icon: const Icon(Icons.skip_previous),
            iconSize: 28,
            onPressed: player.hasSentences
                ? () => player.previousSentence()
                : null,
            tooltip: 'Previous Sentence',
          ),
          const SizedBox(width: 6),
          _buildPlayPauseButton(context),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.skip_next),
            iconSize: 28,
            onPressed: player.hasSentences ? () => player.nextSentence() : null,
            tooltip: 'Next Sentence',
          ),
          const SizedBox(width: 16),
          // 右侧：字幕和循环
          _buildToggleButton(
            context,
            icon: player.settings.showTranscript
                ? Icons.visibility
                : Icons.visibility_off,
            isActive: player.settings.showTranscript,
            onPressed: () {
              player.updateSettings(
                player.settings.copyWith(
                  showTranscript: !player.settings.showTranscript,
                ),
              );
            },
            tooltip: 'Show Transcript',
          ),
          const SizedBox(width: 6),
          _buildToggleButton(
            context,
            icon: Icons.repeat_one,
            isActive: player.settings.loopEnabled,
            onPressed: () {
              player.updateSettings(
                player.settings.copyWith(
                  loopEnabled: !player.settings.loopEnabled,
                ),
              );
            },
            tooltip: 'Sentence Repeat',
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton(BuildContext context) {
    print('isMainPlaybackPlaying: ${player.isMainPlaybackPlaying}');
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          player.isMainPlaybackPlaying ? Icons.pause : Icons.play_arrow,
        ),
        iconSize: 36,
        color: Theme.of(context).colorScheme.onPrimary,
        onPressed: () {
          if (player.isMainPlaybackPlaying) {
            player.pause();
          } else {
            player.play();
          }
        },
        tooltip: player.isMainPlaybackPlaying ? 'Pause' : 'Play',
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 22,
      color: isActive
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }

  Widget _buildSpeedButton(BuildContext context) {
    return PopupMenuButton<double>(
      icon: Text(
        '${player.settings.playbackSpeed}x',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      tooltip: 'Playback Speed',
      itemBuilder: (context) {
        return [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
          return PopupMenuItem<double>(
            value: speed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${speed}x'),
                if (speed == player.settings.playbackSpeed)
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
        player.updateSettings(player.settings.copyWith(playbackSpeed: speed));
      },
    );
  }
}
