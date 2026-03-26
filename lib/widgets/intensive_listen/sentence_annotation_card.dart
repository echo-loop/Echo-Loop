/// 标注模式内容卡片
///
/// 显示句子文本（单词可点击弹出词典弹窗）、
/// 难句标记切换、AI 翻译和 AI 解析区域。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/sentence_ai_result.dart';
import '../../models/speech_practice_models.dart';
import '../../theme/app_theme.dart';
import '../common/tappable_wrapper.dart';
import '../common/ai_content_section.dart';
import '../common/text_context_menu.dart';
import 'word_dictionary_sheet.dart';

/// 标注模式句子卡片
///
/// 使用 StatefulWidget 管理 TapGestureRecognizer 生命周期，
/// 防止内存泄漏。
class SentenceAnnotationCard extends StatefulWidget {
  /// 句子文本
  final String text;

  /// 当前句子是否标记为难句
  final bool isDifficult;

  /// 是否展示“自动标记”文案
  ///
  /// 仅在“看不懂”触发自动标记的当次传 true；
  /// 其它场景（包括已存在的难句）保持 false。
  final bool showAutoMarkedLabel;

  /// 切换难句标记回调（为 null 时不显示标记行）
  final VoidCallback? onToggle;

  /// 请求翻译回调（返回翻译文本）
  final Future<String> Function()? onRequestTranslation;

  /// 请求解析回调（返回解析 JSON 文本）
  final Future<String> Function()? onRequestAnalysis;

  /// 已缓存的翻译文本
  final String? cachedTranslation;

  /// 已缓存的解析文本（grammar\nvocabulary\nusage 格式）
  final String? cachedAnalysis;

  /// 来源音频 ID（用于词典弹窗收藏单词时记录来源）
  final String? audioItemId;

  /// 来源句子索引
  final int? sentenceIndex;

  /// 来源句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒）
  final int? sentenceEndMs;

  /// 句子正文下方的附加反馈区域。
  final Widget? inlineFeedback;

  /// 句子正文的高亮片段；为空时按原始句子构建。
  final List<SpeechTranscriptSegment>? highlightedSegments;

  const SentenceAnnotationCard({
    super.key,
    required this.text,
    required this.isDifficult,
    this.showAutoMarkedLabel = false,
    this.onToggle,
    this.onRequestTranslation,
    this.onRequestAnalysis,
    this.cachedTranslation,
    this.cachedAnalysis,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.inlineFeedback,
    this.highlightedSegments,
  });

  @override
  State<SentenceAnnotationCard> createState() => _SentenceAnnotationCardState();
}

class _SentenceAnnotationCardState extends State<SentenceAnnotationCard> {
  final List<TapGestureRecognizer> _recognizers = [];
  static final RegExp _textPartPattern = RegExp(r'\s+|[^\s]+');

  /// 当前被按压高亮的词索引（-1 表示无）
  int _highlightedWordIndex = -1;

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  /// 短暂高亮被点击的词（150ms 后自动清除）
  void _flashWord(int index) {
    setState(() => _highlightedWordIndex = index);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _highlightedWordIndex = -1);
    });
  }

  /// 每次 build 前清理旧 recognizer，创建新的
  List<InlineSpan> _buildWordSpans(ThemeData theme) {
    // 清理旧 recognizer
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final parts = _textPartPattern
        .allMatches(widget.text)
        .map((match) => match.group(0) ?? '')
        .toList();
    final highlightColor = theme.colorScheme.primary.withValues(alpha: 0.1);
    final result = <InlineSpan>[];
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final cleanWord =
          part.replaceAll(RegExp(r'[.,!?;:\-—…、，。！？；：]'), '');
      if (part.trim().isEmpty) {
        result.add(TextSpan(text: part));
        continue;
      }
      final wordIndex = i;
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (cleanWord.isNotEmpty) {
            _flashWord(wordIndex);
            showWordDictionarySheet(
              context: context,
              word: cleanWord,
              audioItemId: widget.audioItemId,
              sentenceIndex: widget.sentenceIndex,
              sentenceText: widget.text,
              sentenceStartMs: widget.sentenceStartMs,
              sentenceEndMs: widget.sentenceEndMs,
            );
          }
        };
      _recognizers.add(recognizer);
      result.add(TextSpan(
        text: part,
        recognizer: recognizer,
        style: _highlightedWordIndex == wordIndex
            ? TextStyle(
                backgroundColor: highlightColor,
              )
            : null,
      ));
    }
    return result;
  }

  /// 基于高亮片段生成可点击的富文本 span。
  List<InlineSpan> _buildHighlightedWordSpans(ThemeData theme) {
    final segments = widget.highlightedSegments;
    if (segments == null || segments.isEmpty) {
      return _buildWordSpans(theme);
    }

    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final highlightColor = theme.colorScheme.primary.withValues(alpha: 0.1);
    final spans = <InlineSpan>[];
    int wordIndex = 0;
    for (final segment in segments) {
      final parts = _textPartPattern
          .allMatches(segment.text)
          .map((match) => match.group(0) ?? '')
          .toList();
      for (final part in parts) {
        if (part.isEmpty) {
          continue;
        }
        if (part.trim().isEmpty) {
          spans.add(TextSpan(text: part));
          continue;
        }
        final cleanWord = part.replaceAll(RegExp(r'[.,!?;:\-—…、，。！？；：]'), '');
        final currentIndex = wordIndex++;
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (cleanWord.isNotEmpty) {
              _flashWord(currentIndex);
              showWordDictionarySheet(
                context: context,
                word: cleanWord,
                audioItemId: widget.audioItemId,
                sentenceIndex: widget.sentenceIndex,
                sentenceText: widget.text,
                sentenceStartMs: widget.sentenceStartMs,
                sentenceEndMs: widget.sentenceEndMs,
              );
            }
          };
        _recognizers.add(recognizer);
        final isHighlighted = _highlightedWordIndex == currentIndex;
        spans.add(
          TextSpan(
            text: part,
            recognizer: recognizer,
            style: TextStyle(
              color: segment.isMatched ? const Color(0xFF2E9B51) : null,
              backgroundColor: isHighlighted ? highlightColor : null,
            ),
          ),
        );
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 难句标记（可点击切换；onToggle 为 null 时不显示）
        if (widget.onToggle != null) ...[
          TappableWrapper(
            onTap: widget.onToggle,
            feedbackType: TapFeedback.opacity,
            pressedOpacity: 0.4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    widget.isDifficult
                        ? (widget.showAutoMarkedLabel
                              ? l10n.intensiveListenAutoMarkedDifficult
                              : l10n.intensiveListenMarkedDifficult)
                        : l10n.intensiveListenNotDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  widget.isDifficult ? Icons.bookmark : Icons.bookmark_border,
                  color: widget.isDifficult ? Colors.amber : Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
        ],

        // 句子文本（单词可点击查词典，长按/右键复制整句）
        GestureDetector(
          onLongPressStart: (details) => TextContextMenu.show(
            context,
            details.globalPosition,
            widget.text,
          ),
          onSecondaryTapDown: (details) => TextContextMenu.show(
            context,
            details.globalPosition,
            widget.text,
          ),
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurface,
              ),
              children: _buildHighlightedWordSpans(theme),
            ),
          ),
        ),
        if (widget.inlineFeedback case final inlineFeedback?) ...[
          const SizedBox(height: AppSpacing.l),
          Align(alignment: Alignment.centerRight, child: inlineFeedback),
        ],
        // AI 翻译区域（仅在有回调或缓存时显示）
        if (widget.onRequestTranslation != null ||
            widget.cachedTranslation != null) ...[
          const SizedBox(height: AppSpacing.l),
          AiContentSection(
            icon: Icons.translate,
            title: l10n.aiTranslation,
            onRequest: widget.onRequestTranslation,
            cachedContent: widget.cachedTranslation,
          ),
        ],

        // AI 解析区域（仅在有回调或缓存时显示）
        if (widget.onRequestAnalysis != null ||
            widget.cachedAnalysis != null) ...[
          const SizedBox(height: AppSpacing.s),
          AiContentSection(
            icon: Icons.auto_awesome,
            title: l10n.aiAnalysis,
            onRequest: widget.onRequestAnalysis,
            cachedContent: widget.cachedAnalysis,
            contentBuilder: (content) => _AnalysisContent(content: content),
          ),
        ],
      ],
    );
  }
}

/// 解析内容结构化展示
///
/// 使用 [SentenceAnalysis.parseDisplayString] 将内容按字段分隔符拆分为
/// grammar / vocabulary / listening 三段，每段带标签标题。
/// vocabulary 和 listening 字段内按 `\n` 拆分为多条，每条前加 bullet。
class _AnalysisContent extends StatelessWidget {
  final String content;

  const _AnalysisContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final fields = SentenceAnalysis.parseDisplayString(content);
    final labels = [l10n.aiGrammar, l10n.aiVocabulary, l10n.aiListening];

    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length && i < labels.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s),
          // 标签标题（primary 色 + w600）
          Text(
            labels[i],
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          // grammar（单行）直接展示；vocabulary / listening（多行）加 bullet
          if (i == 0)
            Text(fields[i], style: bodyStyle)
          else
            ..._buildBulletItems(fields[i], bodyStyle),
        ],
      ],
    );
  }

  /// 将 `\n` 分隔的多条内容渲染为带 bullet 的列表
  List<Widget> _buildBulletItems(String field, TextStyle? style) {
    final items = field.split('\n').where((s) => s.trim().isNotEmpty).toList();
    if (items.length <= 1) {
      return [Text(field, style: style)];
    }
    return [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('· $item', style: style),
        ),
    ];
  }
}
