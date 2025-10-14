import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/player_provider.dart';

// 自定义 Intent
class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class PrevSentenceIntent extends Intent {
  const PrevSentenceIntent();
}

class NextSentenceIntent extends Intent {
  const NextSentenceIntent();
}

class ToggleTranscriptIntent extends Intent {
  const ToggleTranscriptIntent();
}

// 播放器快捷键作用域
class PlayerHotkeyScope extends StatelessWidget {
  final Widget child;
  final PlayerProvider player;

  const PlayerHotkeyScope({
    super.key,
    required this.child,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          // 空格：播放/暂停
          if (key == LogicalKeyboardKey.space) {
            player.isMainPlaybackPlaying ? player.pause() : player.play();
            return KeyEventResult.handled;
          }
          // 左右箭头：上一/下一句
          if (key == LogicalKeyboardKey.arrowLeft) {
            if (player.hasSentences) player.previousSentence();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            if (player.hasSentences) player.nextSentence();
            return KeyEventResult.handled;
          }
          // 上箭头：切换字幕显示
          if (key == LogicalKeyboardKey.arrowUp) {
            final s = player.settings;
            player.updateSettings(
              s.copyWith(showTranscript: !s.showTranscript),
            );
            return KeyEventResult.handled;
          }
          // 下箭头：拦截，防止列表滚动
          if (key == LogicalKeyboardKey.arrowDown) {
            return KeyEventResult.handled;
          }
          // R 键：重播当前句子
          if (key == LogicalKeyboardKey.keyR) {
            if (player.hasSentences) player.replayCurrentSentence();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): const PlayPauseIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              const PrevSentenceIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              const NextSentenceIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp):
              const ToggleTranscriptIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            PlayPauseIntent: CallbackAction<PlayPauseIntent>(
              onInvoke: (i) {
                player.isMainPlaybackPlaying ? player.pause() : player.play();
                return null;
              },
            ),
            PrevSentenceIntent: CallbackAction<PrevSentenceIntent>(
              onInvoke: (i) {
                if (player.hasSentences) player.previousSentence();
                return null;
              },
            ),
            NextSentenceIntent: CallbackAction<NextSentenceIntent>(
              onInvoke: (i) {
                if (player.hasSentences) player.nextSentence();
                return null;
              },
            ),
            ToggleTranscriptIntent: CallbackAction<ToggleTranscriptIntent>(
              onInvoke: (i) {
                final s = player.settings;
                player.updateSettings(
                  s.copyWith(showTranscript: !s.showTranscript),
                );
                return null;
              },
            ),
          },
          child: child,
        ),
      ),
    );
  }
}
