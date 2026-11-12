/// 字幕列表内的单句 AI 译文。
///
/// 替换句子正文展示译文：加载中显示骨架，不回退显示英文，避免破坏「看译文」练习意图。
/// 额度用尽时就地提示并可点击订阅（不弹窗打断）；普通失败可点击重试；
/// 未登录交给宿主处理（引导登录并回退模式）；宿主不处理时不占位。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/subscription/widgets/feature_gate.dart' show openPaywall;
import '../../l10n/app_localizations.dart';
import '../../models/sentence.dart';
import '../../providers/sentence_ai_prewarm.dart';
import '../../providers/sentence_ai_provider.dart';
import '../../providers/sentence_translation_provider.dart';
import 'shimmer_placeholder.dart';

/// 单句译文文本。
class SentenceTranslationText extends ConsumerWidget {
  const SentenceTranslationText({
    super.key,
    required this.target,
    required this.textStyle,
    this.onSignInRequired,
  });

  /// 原文下方附加译文的弱化样式：字号略小、次要文字色。
  static TextStyle secondaryStyle(ThemeData theme, TextStyle textStyle) {
    return textStyle.copyWith(
      fontSize: (textStyle.fontSize ?? 16) * 0.875,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// 译文对应的句子（含翻译上下文定位信息）。
  final SentenceAiPrewarmTarget target;

  /// 与原文一致的正文样式。
  final TextStyle textStyle;

  /// 译文因未登录（[AiFeatureAuthRequiredException]）失败时回调。
  ///
  /// 为空表示宿主不处理登录（如收藏句的附加译文），未登录时不显示任何内容。
  final VoidCallback? onSignInRequired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sentenceTranslationProvider(target);
    final onSignInRequired = this.onSignInRequired;
    if (onSignInRequired != null) {
      ref.listen(provider, (_, next) {
        if (next.error is AiFeatureAuthRequiredException) onSignInRequired();
      });
    }
    final translation = ref.watch(provider);
    final text = translation.value;
    if (text != null && text.isNotEmpty) {
      return Text(text, style: textStyle);
    }
    if (translation.error is AiFeatureAuthRequiredException) {
      // 宿主处理登录时会回退模式，保持占位即可；不处理时不占位。
      return onSignInRequired == null
          ? const SizedBox.shrink()
          : const ShimmerPlaceholder(singleLine: true);
    }
    if (!translation.hasError) {
      return const ShimmerPlaceholder(singleLine: true);
    }
    final l10n = AppLocalizations.of(context)!;
    final (message, onTap) = switch (translation.error) {
      AiFeatureQuotaExceededException() => (
        l10n.sentenceTranslationQuotaExceeded,
        () => unawaited(openPaywall(context, ref)),
      ),
      _ => (l10n.sentenceTranslationLoadFailed, () => ref.invalidate(provider)),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        message,
        style: textStyle.copyWith(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

/// 字幕列表中收藏句原文下方的弱化译文构建器（随心听、全文盲听共用）。
///
/// 仅收藏句返回译文，其余返回 null 不占位；可见句才订阅译文流，已缓存的直接命中。
/// 不处理登录（宿主仅在已登录时启用），额度用尽时就地提示订阅。
Widget? Function(Sentence sentence, TextStyle textStyle)
bookmarkedSentenceTranslationBuilder({
  required ThemeData theme,
  required String audioItemId,
  required Set<int> bookmarkedSentenceIndices,
}) {
  return (sentence, textStyle) {
    if (!bookmarkedSentenceIndices.contains(sentence.index)) return null;
    return SentenceTranslationText(
      target: SentenceAiPrewarmTarget(
        text: sentence.text,
        audioItemId: audioItemId,
        sentenceIndex: sentence.index,
      ),
      textStyle: SentenceTranslationText.secondaryStyle(theme, textStyle),
    );
  };
}
