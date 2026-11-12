/// 字幕列表内的单句 AI 译文。
///
/// 替换句子正文展示译文：加载中显示骨架，不回退显示英文，避免破坏「看译文」练习意图。
/// 额度用尽时就地提示并可点击订阅（不弹窗打断）；普通失败可点击重试；
/// 未登录交给宿主处理（引导登录并回退模式）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/subscription/widgets/feature_gate.dart' show openPaywall;
import '../../l10n/app_localizations.dart';
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
    required this.onSignInRequired,
  });

  /// 译文对应的句子（含翻译上下文定位信息）。
  final SentenceAiPrewarmTarget target;

  /// 与原文一致的正文样式。
  final TextStyle textStyle;

  /// 译文因未登录（[AiFeatureAuthRequiredException]）失败时回调。
  final VoidCallback onSignInRequired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sentenceTranslationProvider(target);
    ref.listen(provider, (_, next) {
      if (next.error is AiFeatureAuthRequiredException) onSignInRequired();
    });
    final translation = ref.watch(provider);
    final text = translation.value;
    if (text != null && text.isNotEmpty) {
      return Text(text, style: textStyle);
    }
    // 未登录时宿主会回退看英文，保持占位即可。
    if (!translation.hasError ||
        translation.error is AiFeatureAuthRequiredException) {
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
