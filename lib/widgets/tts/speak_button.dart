/// 统一发音按钮
///
/// 点击走统一发音链路：单词优先 CDN 预录音频（本地缓存优先），缺失、多词或播放失败时
/// 走 [ttsControllerProvider] 缓存/生成。朗读期间显激活态（图标变主色），结束自动复位。
///
/// 单词、词典例句等所有发音入口统一使用本组件，保证交互一致。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/pronunciation/pronunciation_providers.dart';
import '../../providers/tts/tts_controller_provider.dart';

class SpeakButton extends ConsumerWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.speakKey,
    this.icon = Icons.volume_up,
    this.size,
    this.color,
    this.tooltip,
    this.visualDensity,
    this.padding,
    this.constraints,
    this.style,
  });

  /// 待发音文本。
  final String text;

  /// 发音项标识（默认用文本本身），用于激活态匹配——不同按钮发同一文本会共享激活态。
  final String? speakKey;

  /// 图标（默认喇叭）。
  final IconData icon;

  /// 图标尺寸。
  final double? size;

  /// 空闲态图标颜色（激活态固定用主色）。
  final Color? color;

  /// 无障碍提示。
  final String? tooltip;

  final VisualDensity? visualDensity;

  final EdgeInsetsGeometry? padding;

  /// 紧凑布局约束（如列表内联喇叭，传 `BoxConstraints()` 去掉默认 48 命中区）。
  final BoxConstraints? constraints;

  /// 按钮样式（如需在 Material 3 下固定按钮尺寸或命中区时使用）。
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = speakKey ?? text;
    final speakingKey = ref.watch(
      ttsControllerProvider.select((s) => s.speakingKey),
    );
    final localPlayingKey = ref.watch(
      textPlaybackProvider.select((s) => s.playingKey),
    );
    final isSpeaking = speakingKey == key || localPlayingKey == key;
    final theme = Theme.of(context);
    final iconColor = isSpeaking
        ? theme.colorScheme.primary
        : (color ?? theme.colorScheme.onSurfaceVariant);

    return IconButton(
      visualDensity: visualDensity ?? VisualDensity.compact,
      padding: padding ?? const EdgeInsets.all(8),
      constraints: constraints,
      tooltip: tooltip,
      iconSize: size,
      style: style,
      onPressed: text.trim().isEmpty
          ? null
          : () => ref.read(textPlaybackProvider.notifier).speak(text, key: key),
      icon: Icon(icon, color: iconColor),
    );
  }
}
