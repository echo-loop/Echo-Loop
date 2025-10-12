import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../providers/player_provider.dart';

class SettingsDialog extends StatelessWidget {
  final PlayerProvider player;

  const SettingsDialog({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: ListenableBuilder(
          listenable: player,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                AppBar(
                  title: Text(l10n.settings),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                // 设置内容
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSentenceRepeatSettings(context, l10n),
                        const SizedBox(height: 16),
                        _buildAudioLoopSettings(context, l10n),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 句子重复设置
  Widget _buildSentenceRepeatSettings(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.autoPlayNextSentence,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Switch(
              value: player.settings.autoPlayNextSentenceEnabled,
              onChanged: (value) {
                player.updateSettings(
                  player.settings.copyWith(autoPlayNextSentenceEnabled: value),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.sentenceRepeat,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Switch(
              value: player.settings.loopEnabled,
              onChanged: (value) {
                player.updateSettings(
                  player.settings.copyWith(loopEnabled: value),
                );
              },
            ),
          ],
        ),
        if (player.settings.loopEnabled) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.repeatCount),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<int>(
                  value: player.settings.loopCount,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  menuMaxHeight: 300,
                  items: List.generate(20, (i) => i + 1).map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text('$count ${l10n.times}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      player.updateSettings(
                        player.settings.copyWith(loopCount: value),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.intervalTime),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<int>(
                  value: player.settings.pauseInterval.inSeconds,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  menuMaxHeight: 300,
                  items: List.generate(31, (i) => i).map((seconds) {
                    return DropdownMenuItem(
                      value: seconds,
                      child: Text('$seconds ${l10n.seconds}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      player.updateSettings(
                        player.settings.copyWith(
                          pauseInterval: Duration(seconds: value),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 音频循环设置
  Widget _buildAudioLoopSettings(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.audioLoop,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Switch(
              value: player.settings.loopAudioEnabled,
              onChanged: (value) {
                player.updateSettings(
                  player.settings.copyWith(loopAudioEnabled: value),
                );
              },
            ),
          ],
        ),
        if (player.settings.loopAudioEnabled) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.loopTimes),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<int>(
                  value: player.settings.loopAudio,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  menuMaxHeight: 300,
                  items: [
                    ...List.generate(10, (i) => i + 1).map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${l10n.times}'),
                      );
                    }),
                    DropdownMenuItem(value: 0, child: Text(l10n.infiniteLoop)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      player.updateSettings(
                        player.settings.copyWith(loopAudio: value),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
