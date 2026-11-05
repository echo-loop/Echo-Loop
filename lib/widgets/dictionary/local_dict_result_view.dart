/// 本地（在线）词典结果视图
///
/// 渲染词典词条（音标/柯林斯星级/考试标签/释义）。加载、未收录、失败三种状态
/// 与 AI 词典视图保持一致；单词标题/TTS/收藏在弹窗标题行，不在此渲染。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dict_entry.dart';
import '../../models/dictionary/dictionary_lookup_result.dart';
import '../../providers/dictionary/lookup_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/text_normalize.dart';
import 'pos_tag.dart';

/// 本地（在线）词典结果视图
class LocalDictResultView extends StatelessWidget {
  /// 当前源的查询态
  final SourceLookupState? state;

  /// 归一化后的查询词（表面词形），用于在线词典的精确结果展示。
  final String word;

  /// 失败后的重试回调；为空时不显示重试按钮（如收藏复习页只展示已加载结果）
  final VoidCallback? onRetry;

  const LocalDictResultView({
    super.key,
    required this.state,
    required this.word,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = state;
    if (s case LookupLoaded(result: final LocalDictResult r)) {
      return _buildContent(context, theme, r.entry);
    }
    if (s is LookupNotFound) {
      return _buildNotFound(context, theme);
    }
    if (s is LookupError) {
      return _buildError(context, theme);
    }
    // Loading / Idle / 其它
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(child: CircularProgressIndicator.adaptive()),
    );
  }

  /// 查询失败提示 + 重试
  Widget _buildError(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.dictionaryLookupFailed,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          if (onRetry case final retry?)
            TextButton(
              onPressed: retry,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
        ],
      ),
    );
  }

  /// 未收录提示
  Widget _buildNotFound(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          AppLocalizations.of(context)!.intensiveListenWordDictNotFound,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 词典内容：（原形回退提示）+ 音标/星级/标签 + 释义
  Widget _buildContent(BuildContext context, ThemeData theme, DictEntry entry) {
    // 表面词形未直接收录、经词形还原命中原形时（entry.word 与查询词不同），
    // 顶部加一条弱化提示，说明展示的是原形释义。收藏保存的仍是表面词形。
    // 两侧同经 normalizeWord 归一，消除大小写/边缘标点等差异导致的误提示。
    final isBaseFormFallback = normalizeWord(entry.word) != word;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBaseFormFallback) ...[
          _buildBaseFormHint(context, theme, entry.word),
          const SizedBox(height: AppSpacing.s),
        ],
        _buildMetaLine(theme, entry),
        const SizedBox(height: AppSpacing.m),
        if (entry.translation != null && entry.translation!.isNotEmpty)
          _buildTranslation(theme, entry.translation!),
        const SizedBox(height: AppSpacing.s),
      ],
    );
  }

  /// 原形回退提示（弱化样式）：告知用户展示的是原形 [lemma] 的查词结果
  Widget _buildBaseFormHint(
    BuildContext context,
    ThemeData theme,
    String lemma,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            AppLocalizations.of(context)!.dictionaryBaseFormHint(lemma),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  /// 音标、星级、考试标签合并为一行
  Widget _buildMetaLine(ThemeData theme, DictEntry entry) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (entry.phonetic.isNotEmpty)
          Text(
            '/${entry.phonetic}/',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        if (entry.collins > 0) _buildStars(theme, entry.collins),
        if (entry.examTags.isNotEmpty) _buildExamTags(theme, entry.examTags),
      ],
    );
  }

  /// 柯林斯五星评级
  Widget _buildStars(ThemeData theme, int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final isFilled = i < rating;
        return Padding(
          padding: const EdgeInsets.only(right: 1),
          child: Icon(
            Icons.star_rounded,
            size: 14,
            color: isFilled
                ? Colors.amber.shade600
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        );
      }),
    );
  }

  /// 考试标签组
  Widget _buildExamTags(ThemeData theme, List<String> tags) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tags.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '·',
                style: TextStyle(
                  color: theme.colorScheme.outlineVariant,
                  fontSize: 10,
                ),
              ),
            ),
          Text(
            tags[i],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }

  /// 释义内容 — 解析词性前缀，区分显示
  Widget _buildTranslation(ThemeData theme, String translation) {
    final lines = translation.split('\n').where((l) => l.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildDefinitionLine(theme, line.trim()),
          ),
      ],
    );
  }

  /// 单条释义行 — 词性标签 + 释义文本
  Widget _buildDefinitionLine(ThemeData theme, String line) {
    final posMatch = RegExp(
      r'^([a-z]+\.(?:\s*&\s*[a-z]+\.)*)\s*',
    ).firstMatch(line);

    if (posMatch == null) {
      return Text(
        line,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.6,
          color: theme.colorScheme.onSurface,
        ),
      );
    }

    final pos = posMatch.group(1)!;
    final definition = line.substring(posMatch.end);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: PosTag(pos: pos),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            definition,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
