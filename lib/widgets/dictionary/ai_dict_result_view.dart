/// AI 词典结果视图
///
/// 按后端 v2 [DictionaryEntry] 结构分层渲染，强调清晰的视觉层级：
/// 顶部音标 → 词义区（序号 + 词性 + 释义 + 用法 + 例句 + 近反义 chips，主内容）
/// → 补充卡片（常见搭配 / 词族 / 词源 / 学习提示）。空字段整段隐藏。
/// 状态：加载中 shimmer、失败重试、需登录、空结果。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echo_loop/widgets/common/svg_action_icon.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dictionary/dictionary_entry.dart';
import '../../models/dictionary/dictionary_lookup_result.dart';
import '../../providers/dictionary/lookup_controller.dart';
import '../../features/subscription/models/premium_feature.dart';
import '../../features/subscription/models/ai_quota_rejection.dart';
import '../../features/subscription/utils/ai_quota_copy.dart';
import '../../providers/pronunciation/pronunciation_providers.dart';
import '../../providers/tts/tts_controller_provider.dart';
import '../../theme/app_theme.dart';
import '../common/shimmer_placeholder.dart';
import 'ai_multi_word_result_view.dart';
import 'pos_tag.dart';

/// AI 词典结果视图
class AiDictResultView extends StatelessWidget {
  /// 当前源的查询态
  final SourceLookupState? state;

  /// 重试回调（失败态）
  final VoidCallback onRetry;

  /// 去登录回调（未登录态）
  final VoidCallback onSignIn;

  /// 升级订阅回调（本月免费额度用尽态）
  final VoidCallback onUpgrade;

  const AiDictResultView({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onSignIn,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s case LookupLoaded(result: final AiDictResult r)) {
      if (r.entry.isEmpty) return _empty(context);
      return switch (r.entry) {
        final DictionaryEntry entry => _AiEntryContent(entry: entry),
        final MultiWordDictionaryEntry entry => AiMultiWordResultView(
          entry: entry,
        ),
      };
    }
    // 流式部分结果：首帧尚无字段时显示 shimmer，否则按已到达字段逐块渲染
    // （内容视图各区块已按 isNotEmpty 门控，字段随帧渐显；AnimatedSize 平滑高度）。
    if (s case LookupStreaming(result: final AiDictResult r)) {
      if (r.entry.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.m),
          child: ShimmerPlaceholder(),
        );
      }
      return switch (r.entry) {
        final DictionaryEntry entry => _AiEntryContent(entry: entry),
        final MultiWordDictionaryEntry entry => AiMultiWordResultView(
          entry: entry,
        ),
      };
    }
    if (s is LookupAuthRequired) return _authRequired(context);
    if (s is LookupPhraseTooLong) return _phraseTooLong(context);
    if (s is LookupQuotaExceeded) {
      return _quotaExceeded(context, s.reason);
    }
    if (s is LookupError) return _error(context);
    if (s is LookupNotFound) return _empty(context);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: ShimmerPlaceholder(),
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Text(
        AppLocalizations.of(context)!.aiNoAnalysis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _error(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.aiLoadFailed,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.aiRetry)),
        ],
      ),
    );
  }

  /// 词组过长：静态提示，不显示重试按钮（重试无意义）
  Widget _phraseTooLong(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.dictPhraseTooLong,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 本月免费额度用尽：业界标准内联升级引导卡（说明额度用尽 + 高亮升级按钮）。
  ///
  /// 用户点击「升级」按钮才进入订阅页（不自动跳转）。
  Widget _quotaExceeded(BuildContext context, AiQuotaRejectionReason reason) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.m),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium, size: 20, color: cs.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    aiQuotaTitleFor(
                      l10n,
                      PremiumFeature.aiWordAnalysis,
                      reason,
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              aiQuotaMessageFor(l10n, reason),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onUpgrade,
                child: Text(l10n.aiQuotaExceededCta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authRequired(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aiSignInRequired,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          FilledButton.tonal(
            onPressed: onSignIn,
            child: Text(l10n.authSignInButton),
          ),
        ],
      ),
    );
  }
}

/// AI 词典正文（已加载且非空）
class _AiEntryContent extends StatelessWidget {
  final DictionaryEntry entry;
  const _AiEntryContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final children = <Widget>[];

    // 音标
    if (!entry.pronunciation.isEmpty) {
      children.add(_PronunciationRow(pronunciation: entry.pronunciation));
    }

    // 词义（主内容）：多义项显示序号，义项之间细分隔
    if (entry.meanings.isNotEmpty) {
      final showIndex = entry.meanings.length > 1;
      final meaningWidgets = <Widget>[];
      for (var i = 0; i < entry.meanings.length; i++) {
        if (i > 0) {
          meaningWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          );
        }
        meaningWidgets.add(
          _MeaningBlock(
            meaning: entry.meanings[i],
            index: showIndex ? i + 1 : null,
            l10n: l10n,
          ),
        );
      }
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: meaningWidgets,
        ),
      );
    }

    // 常见搭配
    if (entry.commonExpressions.isNotEmpty) {
      children.add(
        _Section(
          title: l10n.dictAiExpressions,
          icon: const SvgActionIcon(
            assetName: 'assets/icon/link.svg',
            size: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entry.commonExpressions.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.s),
                _ExpressionItem(expression: entry.commonExpressions[i]),
              ],
            ],
          ),
        ),
      );
    }

    // 词形变化（屈折形式）——置于词族之前，与后端 reveal 字段顺序一致
    if (entry.forms.isNotEmpty) {
      children.add(
        _Section(
          title: l10n.dictAiForms,
          icon: const Icon(Icons.text_fields_rounded, size: 14),
          child: _FormsGrid(forms: entry.forms),
        ),
      );
    }

    // 词族
    if (entry.wordFamily.isNotEmpty) {
      children.add(
        _Section(
          title: l10n.dictAiWordFamily,
          icon: const Icon(Icons.account_tree_outlined, size: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entry.wordFamily.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.s),
                _WordFamilyItemView(item: entry.wordFamily[i]),
              ],
            ],
          ),
        ),
      );
    }

    // 学习提示（逐条项目符号）——置于词源之前，与后端 reveal 字段顺序一致
    if (entry.learnerTips.isNotEmpty) {
      children.add(
        _Section(
          title: l10n.dictAiTips,
          icon: const Icon(Icons.lightbulb_outline, size: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entry.learnerTips.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.xs),
                _TipItem(text: entry.learnerTips[i]),
              ],
            ],
          ),
        ),
      );
    }

    // 词源（置于最底部）
    if (entry.etymology.isNotEmpty) {
      children.add(
        _Section(
          title: l10n.dictAiEtymology,
          icon: const Icon(Icons.history_edu_outlined, size: 14),
          child: _bodyText(theme, entry.etymology),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.m),
          children[i],
        ],
      ],
    );
  }
}

Widget _bodyText(ThemeData theme, String text) => Text(
  text,
  style: theme.textTheme.bodyMedium?.copyWith(
    height: 1.5,
    color: theme.colorScheme.onSurface,
  ),
);

/// 音标行（UK/US 音标文本）
///
/// 处理三类情况：
/// - 后端音标可能自带斜杠，统一剥离后由本视图补一对 `/.../`，避免出现 `//...//`。
/// - 英式/美式音标相同时合并为一个 chip（不带 UK/US 前缀）。
/// - 不再显示每条音标的发音按钮（朗读统一在弹窗标题行）。
class _PronunciationRow extends StatelessWidget {
  final Pronunciation pronunciation;
  const _PronunciationRow({required this.pronunciation});

  /// 剥离音标两端的斜杠与空白，避免与本视图补的 `/.../` 重复
  static String _normalize(String ipa) {
    return ipa.trim().replaceAll(RegExp(r'^/+|/+$'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final uk = _normalize(pronunciation.uk);
    final us = _normalize(pronunciation.us);

    // 英美音标一致：合并显示一个
    if (uk.isNotEmpty && uk == us) {
      return _PhoneticChip(ipa: uk);
    }

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        if (uk.isNotEmpty) _PhoneticChip(label: 'UK', ipa: uk),
        if (us.isNotEmpty) _PhoneticChip(label: 'US', ipa: us),
      ],
    );
  }
}

class _PhoneticChip extends StatelessWidget {
  /// 地区前缀（UK/US）；英美一致合并时为空
  final String? label;
  final String ipa;
  const _PhoneticChip({this.label, required this.ipa});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 5),
        ],
        Text(
          '/$ipa/',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// 单条词义块
class _MeaningBlock extends StatelessWidget {
  final WordMeaning meaning;

  /// 义项序号（多义项时显示，单义项为 null）
  final int? index;
  final AppLocalizations l10n;
  const _MeaningBlock({
    required this.meaning,
    required this.index,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 对应词存在时作主标题（中文等目标语先行），英文释义降为辅助行；
    // 对应词缺失（如英文目标语或后端未给）则回退用英文释义作主标题。
    final translation = meaning.translation.join('；');
    final hasTranslation = translation.isNotEmpty;
    final headline = hasTranslation ? translation : meaning.definition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index != null) ...[
              _MeaningIndex(index: index!),
              const SizedBox(width: 8),
            ],
            if (meaning.partOfSpeech.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: PosTag(pos: meaning.partOfSpeech),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                headline,
                style: theme.textTheme.titleMedium?.copyWith(
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        // 英文单语释义（仅当对应词已占主标题时单独成行）
        if (hasTranslation && meaning.definition.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              meaning.definition,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (meaning.usageNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    meaning.usageNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.85,
                      ),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final ex in meaning.examples) _ExampleView(example: ex),
        if (meaning.synonyms.isNotEmpty)
          _WordChips(label: l10n.dictAiSynonyms, words: meaning.synonyms),
        if (meaning.antonyms.isNotEmpty)
          _WordChips(
            label: l10n.dictAiAntonyms,
            words: meaning.antonyms,
            tonal: false,
          ),
      ],
    );
  }
}

/// 义项序号徽章（小号圆形）
class _MeaningIndex extends StatelessWidget {
  final int index;
  const _MeaningIndex({required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$index',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// 例句（引文风格：中性细竖线 + 斜体英文 + 译文次行）
///
/// 刻意压低视觉权重——不用色块填充、不用主色 accent，避免与释义争夺注意力。
/// 英文用斜体小字（符合词典例句惯例），译文更淡，整体作为释义的支撑信息。
class _ExampleView extends ConsumerWidget {
  final ExampleSentence example;
  const _ExampleView({required this.example});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (example.sentence.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // 英文与译文为一组：点击任意处都朗读英文句子。
    // 朗读态（speakingKey == 本句）由协调器维护，保证同时只有一句在播；
    // 平时不显喇叭，仅朗读期间显示，播完 speakingKey 复位即自动消失。
    final isSpeaking = ref.watch(
      ttsControllerProvider.select((s) => s.speakingKey == example.sentence),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: InkWell(
        onTap: () =>
            ref.read(textPlaybackProvider.notifier).speak(example.sentence),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 2,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      example.sentence,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                  // 仅朗读本句时显示喇叭，播完自动消失。
                  if (isSpeaking)
                    Padding(
                      padding: const EdgeInsets.only(left: 6, top: 2),
                      child: Icon(
                        Icons.volume_up,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              if (example.translation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    example.translation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.75,
                      ),
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 近义/反义词 chips
///
/// 标签（近义词/反义词）+ 一组小圆角 chip。
/// [tonal] 为 true 时用主色淡底（近义词），false 时用中性淡底（反义词）。
class _WordChips extends StatelessWidget {
  final String label;
  final List<String> words;
  final bool tonal;
  const _WordChips({
    required this.label,
    required this.words,
    this.tonal = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = tonal
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.onSurface.withValues(alpha: 0.06);
    final fg = tonal
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final w in words)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      w,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 常见搭配条目（表达 + 类型 tag + 含义 + 例句）
class _ExpressionItem extends StatelessWidget {
  final CommonExpression expression;
  const _ExpressionItem({required this.expression});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                expression.expression,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (expression.type.isNotEmpty) ...[
              const SizedBox(width: 8),
              _TypeTag(text: expression.type),
            ],
          ],
        ),
        if (expression.meaning.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              expression.meaning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        _ExampleView(example: expression.example),
      ],
    );
  }
}

/// 搭配类型小标签（搭配/习语/短语动词…，后端按目标语言返回）
class _TypeTag extends StatelessWidget {
  final String text;
  const _TypeTag({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 词族条目（词性 + 词 + 释义 + 例句）
class _WordFamilyItemView extends StatelessWidget {
  final WordFamilyItem item;
  const _WordFamilyItemView({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (item.partOfSpeech.isNotEmpty) ...[
              PosTag(pos: item.partOfSpeech),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                item.word,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (item.meaning.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              item.meaning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        _ExampleView(example: item.example),
      ],
    );
  }
}

/// 词形变化列表（每行：形式名称标签 + 屈折形式）
///
/// 屈折形式数量有限（通常 ≤6），逐行罗列：左侧目标语类型名（淡色小字），
/// 右侧屈折形式（英文，稍重）。空标签或空形式的条目整条跳过。
class _FormsGrid extends StatelessWidget {
  final List<WordForm> forms;
  const _FormsGrid({required this.forms});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = forms.where((f) => f.form.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (items[i].label.isNotEmpty)
                Text(
                  items[i].label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  items[i].form,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 学习提示单条（项目符号 + 文本）
class _TipItem extends StatelessWidget {
  final String text;
  const _TipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: 8),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// 分节：图标徽章 + 主色小标题 + 柔和卡片内容
class _Section extends StatelessWidget {
  final String title;
  final Widget icon;
  final Widget child;
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconTheme(
                data: IconThemeData(size: 14, color: theme.colorScheme.primary),
                child: icon,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}
