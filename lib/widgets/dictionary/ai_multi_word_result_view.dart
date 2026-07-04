/// AI 多词表达结果视图
///
/// 展示后端 `queryType=multi_word` 的结构化分析。视觉语言与单词视图
/// [AiDictResultView] 完全对齐：顶部类别标签 → 核心要点卡片 → 词义区（序号 +
/// 对译 + 例句，主内容，无卡片包裹）→ 补充卡片（自然性 / 发音 / 相似表达 /
/// 背景，图标徽章 + 主色小标题 + 柔和卡片）。空字段整段隐藏。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dictionary/dictionary_entry.dart';
import '../../providers/tts/tts_controller_provider.dart';
import '../../theme/app_theme.dart';

/// AI 多词表达正文（已加载且非空）
class AiMultiWordResultView extends StatelessWidget {
  final MultiWordDictionaryEntry entry;

  const AiMultiWordResultView({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final children = <Widget>[];

    // 类别标签是多词表达的元信息，不参与主要内容区排序。
    if (entry.category.isNotEmpty) {
      children.add(_CategoryTag(text: entry.category));
    }

    // 核心要点（置于词义之前，作主内容不套卡片，逐条项目符号）
    if (entry.keyPoints.isNotEmpty) {
      children.add(
        _Section(
          title: l10n.dictAiMultiKeyPoints,
          icon: Icons.lightbulb_outline,
          boxed: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entry.keyPoints.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.xs),
                _TipItem(text: entry.keyPoints[i]),
              ],
            ],
          ),
        ),
      );
    }

    // 词义（主内容）：多义项显示序号，义项之间细分隔，直接渲染不套卡片
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
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
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
        _Section(
          title: l10n.dictAiMultiMeanings,
          icon: Icons.menu_book_outlined,
          boxed: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: meaningWidgets,
          ),
        ),
      );
    }

    // 自然性提示（纠错；表达自然时后端返回空则整段隐藏）
    if (entry.naturalness.isNotEmpty) {
      children.add(
        _Section(
          title: l10n.dictAiMultiNaturalness,
          icon: Icons.tips_and_updates_outlined,
          child: _bodyText(Theme.of(context), entry.naturalness),
        ),
      );
    }

    // 发音提示（逐条项目符号）
    if (entry.pronunciationTips.isNotEmpty) {
      children.add(
        _Section(
          title: l10n.dictAiMultiPronunciationTips,
          icon: Icons.record_voice_over_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entry.pronunciationTips.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.xs),
                _TipItem(text: entry.pronunciationTips[i]),
              ],
            ],
          ),
        ),
      );
    }

    // 相似表达
    if (entry.similarExpressions.isNotEmpty) {
      children.add(
        _Section(
          title: l10n.dictAiMultiSimilarExpressions,
          icon: Icons.compare_arrows_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entry.similarExpressions.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.s),
                _SimilarExpressionItem(item: entry.similarExpressions[i]),
              ],
            ],
          ),
        ),
      );
    }

    // 背景
    if (entry.background.isNotEmpty) {
      children.add(
        _Section(
          title: l10n.dictAiMultiBackground,
          icon: Icons.history_edu_outlined,
          child: _bodyText(Theme.of(context), entry.background),
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

/// 表达类别标签（短语动词 / 搭配 / 习语…，后端按目标语言返回）
///
/// 复用单词视图搭配类型标签的样式，轻量置顶，与音标行同一视觉层级。
class _CategoryTag extends StatelessWidget {
  final String text;
  const _CategoryTag({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
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
      ),
    );
  }
}

/// 单条词义块（与单词视图 `_MeaningBlock` 对齐，去掉词性与近反义词）
class _MeaningBlock extends StatelessWidget {
  final MultiWordMeaning meaning;

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
    // 对应词作主标题（目标语），多条对译以顿号连接。
    final headline = meaning.translation.join('；');
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
        for (final ex in meaning.examples)
          _ExampleView(sentence: ex.sentence, translation: ex.translation),
      ],
    );
  }
}

/// 义项序号徽章（小号圆形，与单词视图一致）
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

/// 例句（引文风格：中性细竖线 + 斜体英文 + 译文次行，与单词视图一致）
///
/// 点击任意处朗读英文句子；仅朗读本句时显示喇叭，播完自动消失。
class _ExampleView extends ConsumerWidget {
  final String sentence;
  final String translation;
  const _ExampleView({required this.sentence, required this.translation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sentence.isEmpty && translation.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isSpeaking =
        sentence.isNotEmpty &&
        ref.watch(
          ttsControllerProvider.select((s) => s.speakingKey == sentence),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: InkWell(
        onTap: sentence.isEmpty
            ? null
            : () => ref.read(ttsControllerProvider.notifier).speak(sentence),
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
              if (sentence.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        sentence,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
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
              if (translation.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: sentence.isEmpty ? 0 : 2),
                  child: Text(
                    translation,
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

/// 相似表达条目（表达 + 差异说明 + 例句，与单词视图词族条目风格一致）
class _SimilarExpressionItem extends StatelessWidget {
  final SimilarExpression item;
  const _SimilarExpressionItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.expression.isNotEmpty)
          Text(
            item.expression,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        if (item.difference.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              item.difference,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        _ExampleView(sentence: item.sentence, translation: item.translation),
      ],
    );
  }
}

/// 学习提示单条（项目符号 + 文本，与单词视图一致）
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

/// 分节：图标徽章 + 主色小标题 + 柔和卡片内容（与单词视图 `_Section` 一致）
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  /// 是否用柔和卡片（边框+底色）包裹内容。主内容区（如核心要点）传 false，
  /// 直接展示不套卡片，与词义区视觉层级一致。
  final bool boxed;
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.boxed = true,
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
              child: Icon(icon, size: 14, color: theme.colorScheme.primary),
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
        if (boxed)
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
          )
        else
          SizedBox(width: double.infinity, child: child),
      ],
    );
  }
}
