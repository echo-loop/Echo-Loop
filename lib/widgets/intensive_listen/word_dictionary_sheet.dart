/// 词典查询底部弹窗
///
/// 点击单词时弹出，显示音标、释义、柯林斯星级和考试标签。
/// 未查到结果时显示"未收录"提示。
/// 支持收藏/取消收藏单词。
library;

// TODO: AI 解析功能暂时隐藏，后续版本再启用时恢复以下 import。
// import 'dart:convert';
// import '../../models/word_analysis.dart';
// import '../../providers/word_ai_provider.dart';
// import '../common/ai_content_section.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dict_entry.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/saved_word_provider.dart';
import '../../services/dictionary_service.dart';
import '../../services/tts_service.dart';
import '../../theme/app_theme.dart';
import '../animated_bookmark_icon.dart';
import '../common/text_context_menu.dart';

/// 显示词典底部弹窗
///
/// [audioItemId]、[sentenceIndex]、[sentenceText] 为可选来源信息，
/// 用于收藏单词时记录来源。
Future<void> showWordDictionarySheet({
  required BuildContext context,
  required String word,
  String? audioItemId,
  int? sentenceIndex,
  String? sentenceText,
  int? sentenceStartMs,
  int? sentenceEndMs,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => WordDictionarySheet(
      word: word,
      audioItemId: audioItemId,
      sentenceIndex: sentenceIndex,
      sentenceText: sentenceText,
      sentenceStartMs: sentenceStartMs,
      sentenceEndMs: sentenceEndMs,
    ),
  );
}

/// 词典弹窗内容
class WordDictionarySheet extends ConsumerStatefulWidget {
  /// 查询的单词
  final String word;

  /// 来源音频 ID（可选）
  final String? audioItemId;

  /// 来源句子索引（可选）
  final int? sentenceIndex;

  /// 来源句子文本（可选）
  final String? sentenceText;

  /// 来源句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒）
  final int? sentenceEndMs;

  const WordDictionarySheet({
    super.key,
    required this.word,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
  });

  @override
  ConsumerState<WordDictionarySheet> createState() =>
      _WordDictionarySheetState();
}

class _WordDictionarySheetState extends ConsumerState<WordDictionarySheet> {
  DictEntry? _entry;
  bool _loading = true;
  bool _notFound = false;

  /// 词典弹窗统一使用清洗后的词形作为查询和兜底展示文本，
  /// 避免句末标点在“未收录”状态下直接暴露给用户。
  String get _normalizedWord => widget.word.trim().replaceAll(
    RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$'),
    '',
  );

  /// 用于收藏的 lemmatized 单词（优先使用词典返回的原形）
  String get _lemmaWord =>
      _entry?.word.toLowerCase() ?? _normalizedWord.toLowerCase();

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  void _lookup() {
    if (!DictionaryService.instance.isAvailable) {
      // 词典未就绪，不查询，由 build 根据 dictionaryProvider 状态展示
      setState(() => _loading = false);
      return;
    }
    final entry = DictionaryService.instance.lookup(_normalizedWord);
    setState(() {
      _entry = entry;
      _notFound = entry == null;
      _loading = false;
    });
    if (entry != null) {
      ref.read(analyticsServiceProvider).track(Events.wordLookup, {
        EventParams.word: _normalizedWord,
      });
    }
  }

  /// 切换收藏状态
  ///
  /// 弹窗不会关闭，图标动画已提供足够反馈，无需 SnackBar。
  Future<void> _toggleSave(bool currentlySaved) async {
    final notifier = ref.read(savedWordListProvider.notifier);
    if (currentlySaved) {
      await notifier.removeWord(_lemmaWord);
    } else {
      await notifier.saveWord(
        word: _lemmaWord,
        audioItemId: widget.audioItemId,
        sentenceIndex: widget.sentenceIndex,
        sentenceText: widget.sentenceText,
        sentenceStartMs: widget.sentenceStartMs,
        sentenceEndMs: widget.sentenceEndMs,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dictState = ref.watch(dictionaryProvider);

    // 词典下载完成后自动重新查询
    if (dictState.status == DictionaryStatus.downloaded &&
        _entry == null &&
        !_notFound) {
      _lookup();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          12,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator.adaptive(),
                ),
              )
            else if (!DictionaryService.instance.isAvailable)
              _buildDictUnavailable(theme, dictState)
            else ...[
              // 词典内容（支持滚动）
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_notFound)
                        _buildNotFound(theme)
                      else
                        _buildContent(theme, _entry!),

                      // TODO: AI 解析功能暂时隐藏，后续版本再启用。
                      // if (!_loading) ...[
                      //   const SizedBox(height: AppSpacing.m),
                      //   _buildWordAiSection(),
                      // ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 词典不可用时的提示（下载中 / 失败 / 未下载）
  Widget _buildDictUnavailable(ThemeData theme, DictionaryState dictState) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
      child: Column(
        children: [
          if (dictState.status == DictionaryStatus.downloading) ...[
            Text(
              l10n.dictionaryDownloading,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            LinearProgressIndicator(value: dictState.progress),
          ] else ...[
            Text(
              dictState.status == DictionaryStatus.failed
                  ? l10n.dictionaryDownloadFailed
                  : l10n.dictionaryNotDownloaded,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            FilledButton.tonal(
              onPressed: () {
                ref.read(dictionaryProvider.notifier).retryDownload();
              },
              child: Text(
                dictState.status == DictionaryStatus.failed
                    ? l10n.retry
                    : l10n.download,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 未找到结果
  Widget _buildNotFound(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单词（支持长按/右键复制）
          GestureDetector(
            onLongPressStart: (details) => TextContextMenu.show(
              context,
              details.globalPosition,
              _normalizedWord,
            ),
            onSecondaryTapDown: (details) => TextContextMenu.show(
              context,
              details.globalPosition,
              _normalizedWord,
            ),
            child: Text(
              _normalizedWord,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          // 未收录提示
          Text(
            AppLocalizations.of(context)!.intensiveListenWordDictNotFound,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 词典内容
  Widget _buildContent(ThemeData theme, DictEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 单词 + 收藏按钮
        _buildTitleRow(theme, entry),
        const SizedBox(height: 6),

        // 音标 + 星级 + 考试标签（紧凑一行）
        _buildMetaLine(theme, entry),
        const SizedBox(height: AppSpacing.m),

        // 释义
        if (entry.translation != null && entry.translation!.isNotEmpty)
          _buildTranslation(theme, entry.translation!),

        const SizedBox(height: AppSpacing.s),
      ],
    );
  }

  /// 标题行：单词 + 收藏按钮
  Widget _buildTitleRow(ThemeData theme, DictEntry entry) {
    final isSavedAsync = ref.watch(isWordSavedProvider(_lemmaWord));
    final isSaved = isSavedAsync.valueOrNull ?? false;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPressStart: (details) => TextContextMenu.show(
              context,
              details.globalPosition,
              entry.word,
            ),
            onSecondaryTapDown: (details) => TextContextMenu.show(
              context,
              details.globalPosition,
              entry.word,
            ),
            child: Text(
              entry.word,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        // TTS 发音按钮
        IconButton(
          onPressed: () => TtsService.instance.speak(entry.word),
          icon: Icon(
            Icons.volume_up,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        AnimatedBookmarkIcon(
          isSaved: isSaved,
          onPressed: () => _toggleSave(isSaved),
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
        // 音标
        if (entry.phonetic.isNotEmpty)
          Text(
            '/${entry.phonetic}/',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),

        // 柯林斯星级
        if (entry.collins > 0) _buildStars(theme, entry.collins),

        // 考试标签
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
            isFilled ? Icons.star_rounded : Icons.star_rounded,
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

  // TODO: AI 单词解析区块，后续版本再启用。
  // Widget _buildWordAiSection() {
  //   final l10n = AppLocalizations.of(context)!;
  //   final wordAi = ref.read(wordAiNotifierProvider);
  //   final cachedAnalysis = wordAi.getCachedWordAnalysis(_lemmaWord);
  //   final cachedJson = cachedAnalysis != null
  //       ? jsonEncode(cachedAnalysis.toJson())
  //       : null;
  //
  //   return AiContentSection(
  //     icon: Icons.auto_awesome,
  //     title: l10n.wordAiAnalysis,
  //     cachedContent: cachedJson,
  //     onRequest: () async {
  //       final result = await wordAi.getWordAnalysis(
  //         _lemmaWord,
  //         sentence: widget.sentenceText,
  //       );
  //       return jsonEncode(result.toJson());
  //     },
  //     contentBuilder: (content) => _WordAnalysisContent(content: content),
  //   );
  // }

  /// 单条释义行 — 词性标签 + 释义文本
  ///
  /// 识别 "vt." "n." "a." "adv." 等词性前缀，
  /// 以蓝色小标签显示词性，后接释义正文。
  Widget _buildDefinitionLine(ThemeData theme, String line) {
    final posMatch = RegExp(
      r'^([a-z]+\.(?:\s*&\s*[a-z]+\.)*)\s*',
    ).firstMatch(line);

    if (posMatch == null) {
      // 无词性前缀，直接显示
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
        // 词性标签
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              pos,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 释义文本
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

// TODO: AI 单词解析结构化内容，后续版本再启用。
// class _WordAnalysisContent extends StatelessWidget { ... }
