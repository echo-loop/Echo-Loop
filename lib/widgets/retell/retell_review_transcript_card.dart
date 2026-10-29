/// 复述评估报告里的「本次转录」折叠卡。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reading_text_prefs_provider.dart';
import '../../theme/app_theme.dart';
import 'retell_review_rating_style.dart';

/// 折叠态露出的转录行数。
const _transcriptCollapsedLines = 1;

/// 转录正文的 widget key，供测试定位（卡内没有标题文字可查）。
@visibleForTesting
const transcriptTextKey = Key('retell-review-transcript-text');

/// 展开箭头预留的宽度。
///
/// 恒定预留而不是按 `canToggle` 增减：宽度参与超行判断，若跟着箭头有无变化，
/// 「是否溢出」和「是否显示箭头」会互为因果，出现宽度抖动。
const _transcriptChevronSlot = 22.0;

/// 卡片内边距与行首图标尺寸。
///
/// 抽成常量而不是就地写字面量：这几个值同时参与「超行预判的可用宽度」和「实际渲染」，
/// 只改一处会让展开箭头的有无与真实溢出对不上（见 [RetellReviewTranscriptCard] 说明）。
const _transcriptPaddingH = 14.0;
const _transcriptPaddingV = 12.0;
const _transcriptIconSize = 18.0;

/// 本次转录：排在结论之后、要点之前，默认只露一行，点击整卡展开或收起。
///
/// 不给标题文字，只用行首图标标识身份：这张卡在报告里位置固定，用户展开一次
/// 就知道是什么，一个「本次转录」标签换来的是折叠态多占一行。
///
/// 不用 [ExpansionTile]：它折叠时完全看不到内容，而转录是后面每条判定的依据，
/// 得先让用户瞥见自己说了什么。用 [TextPainter] 预判是否真的超过折叠行数——没超
/// 就不给箭头也不可点，避免点了没有任何反应。
class RetellReviewTranscriptCard extends ConsumerStatefulWidget {
  final String transcript;

  const RetellReviewTranscriptCard({required this.transcript});

  @override
  ConsumerState<RetellReviewTranscriptCard> createState() =>
      RetellReviewTranscriptCardState();
}

class RetellReviewTranscriptCardState
    extends ConsumerState<RetellReviewTranscriptCard> {
  bool _expanded = false;

  /// 以 [maxWidth] 排版后是否超过折叠行数。
  bool _overflows(InlineSpan span, double maxWidth) {
    final painter = TextPainter(
      text: span,
      maxLines: _transcriptCollapsedLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawBodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.55);
    // 学习内容字号偏好：超行预判与正文渲染共用同一缩放后的样式
    final bodyStyle = rawBodyStyle == null
        ? null
        : ref.watch(readingTextPrefsNotifierProvider).applyTo(rawBodyStyle);
    // 量高与实际渲染必须共用同一段文本和样式，否则超行判断会和渲染结果对不上。
    final span = TextSpan(text: widget.transcript, style: bodyStyle);
    return Container(
      decoration: retellCardDecoration(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 卡片内边距、行首图标和箭头槽位之外的可用宽度，必须和正文 Text 实际
          // 拿到的宽度一致，否则超行判断会和渲染结果对不上。
          final textWidth =
              constraints.maxWidth -
              _transcriptPaddingH * 2 -
              _transcriptIconSize -
              AppSpacing.s -
              _transcriptChevronSlot;
          final canToggle = _overflows(span, textWidth);
          final content = Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _transcriptPaddingH,
              vertical: _transcriptPaddingV,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.subject_rounded,
                  size: _transcriptIconSize,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: .75,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.topLeft,
                    curve: Curves.easeOut,
                    child: Text(
                      widget.transcript,
                      key: transcriptTextKey,
                      style: bodyStyle,
                      maxLines: _expanded ? null : _transcriptCollapsedLines,
                      overflow: _expanded
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  width: _transcriptChevronSlot,
                  child: canToggle
                      ? AnimatedRotation(
                          turns: _expanded ? .5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.expand_more_rounded,
                            size: 22,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          );
          if (!canToggle) return content;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: content,
          );
        },
      ),
    );
  }
}
