/// 可点词 + 词组选区的句子文本组件（查词业务层）
///
/// 选区能力本身在 [AppSelectableText]（`lib/widgets/selection/`，与「查词」解耦，
/// 后续 AI 回答也复用）。本文件只负责查词业务：
/// - 注入**词典自己的**词边界（[tokenizeSentence]），不用平台 ICU 边界；
/// - 选区确认后打开词典面板（[DictionaryPanelHost]）并登记 owner；
/// - 操作条动作：复制 / 收藏·取消收藏 / 问 AI；
/// - 已收藏的单词/词组/意群渲染橙色点状下划线（收藏集合经 Riverpod 流式监听）；
/// - 跟读评分片段染色。
///
/// 交互模型：点单词即查并选中该词；长按建立选区、拖动扩选（字符级自由边界），
/// 松手后以最终选中文本查询；平台默认手柄与选中背景色。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chatbot/chatbot_flags.dart';
import '../../features/chatbot/sentence_passage.dart';
import '../../features/chatbot/widgets/sentence_chat_button.dart';
import '../../features/remote_config/remote_config.dart';
import '../../features/remote_config/remote_config_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/speech_practice_models.dart';
import '../../providers/saved_word_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/saved_text_index.dart';
import '../../utils/text_normalize.dart';
import '../common/platform_text_selection_style.dart';
import '../dictionary/dictionary_panel_host.dart';
import '../selection/app_selectable_text.dart';
import '../selection/selection_toolbar.dart';
import 'sentence_word_selection.dart';

/// 查词来源上下文（收藏溯源用），聚合原先散落的 5 个参数
class DictionaryLookupOrigin {
  /// 来源音频 ID（可选）
  final String? audioItemId;

  /// 来源句子索引（可选）
  final int? sentenceIndex;

  /// 来源句子文本
  final String? sentenceText;

  /// 来源句子起始时间（毫秒，可选）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒，可选）
  final int? sentenceEndMs;

  const DictionaryLookupOrigin({
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
  });

  /// 组装词典面板查询
  DictionaryPanelQuery queryFor(String word) => DictionaryPanelQuery(
    word: word,
    audioItemId: audioItemId,
    sentenceIndex: sentenceIndex,
    sentenceText: sentenceText,
    sentenceStartMs: sentenceStartMs,
    sentenceEndMs: sentenceEndMs,
  );
}

/// 可点词句子文本
class SelectableSentenceText extends ConsumerStatefulWidget {
  /// 句子文本（无 [highlightedSegments] 时的渲染与分词来源）
  final String text;

  /// 文本样式
  final TextStyle? style;

  /// 高亮片段（跟读评分染色）；非空时渲染文本 = 片段拼接
  final List<SpeechTranscriptSegment>? highlightedSegments;

  /// 当前播放词在句内的序号；null 时不显示播放高亮。
  final int? activeWordIndex;

  /// 查词来源上下文（收藏溯源）
  final DictionaryLookupOrigin origin;

  /// 查词前副作用钩子（盲听进入等待用户态、标注卡切手动模式等）。
  /// 点词与词组松手时、面板 show 之前触发。
  final VoidCallback? onBeforeLookup;

  const SelectableSentenceText({
    super.key,
    required this.text,
    this.style,
    this.highlightedSegments,
    this.activeWordIndex,
    this.origin = const DictionaryLookupOrigin(),
    this.onBeforeLookup,
  });

  @override
  ConsumerState<SelectableSentenceText> createState() =>
      _SelectableSentenceTextState();
}

class _SelectableSentenceTextState
    extends ConsumerState<SelectableSentenceText> {
  final GlobalKey<AppSelectableTextState> _selectableKey =
      GlobalKey<AppSelectableTextState>();

  /// 分词结果（text/segments 变化时重建）
  late List<WordToken> _tokens = tokenizeSentence(_fullText);
  late String _tokenizedText = _fullText;

  /// 已注册豁免区域的宿主（组件卸载时按同一实例注销）
  DictionaryPanelHostState? _host;

  /// 收藏标记掩码缓存（(文本, 索引实例) 不变时复用，避免每帧重算；
  /// 索引是 keepAlive provider 缓存的同一对象，identical 判等即可）
  List<bool> _savedMask = const [];
  String? _savedMaskText;
  SavedTextIndex? _savedMaskIndex;

  /// 当前词汇收藏 key；操作条按它判断选区应显示“收藏”还是“取消收藏”。
  ///
  /// 唯一来源是 `savedWordTextsProvider`（与正文下划线、面板书签同一个流）。
  Set<String> _savedWordTexts = const {};

  /// 渲染文本：有高亮片段时为片段拼接，否则为原句
  String get _fullText {
    final segs = widget.highlightedSegments;
    if (segs == null || segs.isEmpty) return widget.text;
    return segs.map((s) => s.text).join();
  }

  void _ensureTokens() {
    if (_tokenizedText == _fullText) return;
    _tokens = tokenizeSentence(_fullText);
    _tokenizedText = _fullText;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 向宿主注册屏障豁免命中谓词：面板开着时点本组件（词/手柄/操作条）仍放行，
    // 点区域外则由宿主屏障关面板并吸收点击。
    final host = DictionaryPanelHost.maybeOf(context);
    if (!identical(host, _host)) {
      _host?.unregisterTapThroughHitTest(_hitsTapThrough);
      _host = host;
      _host?.registerTapThroughHitTest(_hitsTapThrough);
    }
    // 面板关闭或别的组件发起了查词：结束本组件的选区会话。
    final owner = DictionaryPanelHost.activeOwnerOf(context);
    if (!identical(owner, this)) {
      // didChangeDependencies 处于重建流程，推迟一帧再动 state。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (identical(DictionaryPanelHost.activeOwnerOf(context), this)) return;
        _selectableKey.currentState?.endSession(notify: false);
      });
    }
  }

  @override
  void dispose() {
    _host?.unregisterTapThroughHitTest(_hitsTapThrough);
    super.dispose();
  }

  bool _hitsTapThrough(Offset globalPosition) =>
      _selectableKey.currentState?.hitTest(globalPosition) ?? false;

  // -- 查词 --

  /// 词边界：词典自己的分词规则。
  ///
  /// 不能用平台 ICU 边界——它会把 `co-op` 断成 `co`/`-`/`op`、`e.g.` 断成
  /// `e`/`.`/`g`，导致高亮的词、面板查询的词、两个收藏入口存的词互不一致。
  /// 命中后两端剥掉标点（`dog.` → `dog`，`dogs'` 的所有格撇号保留）。
  TextRange? _wordRangeAt(int charOffset) {
    _ensureTokens();
    final index = wordTokenAtChar(_tokens, charOffset);
    if (index < 0) return null;
    final token = _tokens[index];
    final trimmed = trimSavedRange(_fullText, token.start, token.end);
    if (trimmed == null) return null;
    final (start, end) = trimmed;
    return TextRange(start: start, end: end);
  }

  void _handleSelectionCommitted(String selectedText) {
    if (!hasDictionaryLookupContent(selectedText)) {
      _selectableKey.currentState?.endSession();
      return;
    }
    DictionaryPanelHost.of(
      context,
    ).show(widget.origin.queryFor(selectedText), owner: this);
  }

  void _handleSessionEnded() {
    _host?.closeIfOwnedBy(this);
  }

  // -- 操作条动作 --

  List<SelectionToolbarAction> _buildActions(String selectedText) {
    if (selectedText.isEmpty) return const [];
    final l10n = AppLocalizations.of(context)!;
    final normalized = normalizeWord(selectedText);
    final isSaved = _savedWordTexts.contains(normalized);
    final aiEnabled = shouldShowAiChatAssistantEntry(
      chatbotEnabled: kChatbotEnabled,
      remoteEnabled: ref.read(
        remoteFeatureEnabledProvider(RemoteFeature.aiChatAssistant),
      ),
    );
    return [
      SelectionToolbarAction(
        label: l10n.chatCopy,
        onPressed: () => _handleCopy(selectedText),
      ),
      if (normalized.isNotEmpty)
        SelectionToolbarAction(
          label: isSaved
              ? l10n.favoritesUnsaveVocabulary
              : l10n.favoritesSaveVocabulary,
          onPressed: () =>
              unawaited(_handleToggleSave(normalized, currentlySaved: isSaved)),
        ),
      if (aiEnabled)
        SelectionToolbarAction(
          label: l10n.chatFollowUp,
          onPressed: () => _handleAskAi(selectedText),
        ),
    ];
  }

  void _handleCopy(String selectedText) {
    if (selectedText.isNotEmpty) {
      unawaited(Clipboard.setData(ClipboardData(text: selectedText)));
    }
    // 复制是显式结束查词的动作：清选区并关面板。
    _selectableKey.currentState?.endSession();
  }

  /// 把选区按现有词汇规则收藏或取消收藏，并保留选区与查词面板。
  ///
  /// 收藏状态由 `saved_words` 的流式 Provider 同步到词典面板、正文收藏标记
  /// 和收藏页；来源信息与词典面板收藏入口保持完全一致。选区是本组件自有 state，
  /// 收藏流重建正文 span 不会影响它——不需要任何选区恢复逻辑。
  Future<void> _handleToggleSave(
    String word, {
    required bool currentlySaved,
  }) async {
    final notifier = ref.read(savedWordListProvider.notifier);
    try {
      if (currentlySaved) {
        await notifier.removeWord(word);
      } else {
        await notifier.saveWord(
          word: word,
          audioItemId: widget.origin.audioItemId,
          sentenceIndex: widget.origin.sentenceIndex,
          sentenceText: widget.origin.sentenceText,
          sentenceStartMs: widget.origin.sentenceStartMs,
          sentenceEndMs: widget.origin.sentenceEndMs,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[SelectableSentenceText] 收藏选区失败: $error\n$stackTrace');
    }
  }

  /// 关闭选区与词典后打开同一句子的聊天会话，并把选中文字放入引用待发送区。
  void _handleAskAi(String selectedText) {
    final trimmed = selectedText.trim();
    if (trimmed.isEmpty) return;
    final sourceSentence = widget.origin.sentenceText;
    final sentenceText = sourceSentence == null || sourceSentence.trim().isEmpty
        ? _fullText
        : sourceSentence;
    _selectableKey.currentState?.endSession();
    unawaited(
      showSentenceChatbotSheet(
        context: context,
        ref: ref,
        target: SentenceChatTarget(
          text: sentenceText,
          audioItemId: widget.origin.audioItemId,
          sentenceIndex: widget.origin.sentenceIndex,
        ),
        initialQuote: trimmed,
      ),
    );
  }

  // -- 构建 --

  /// 收藏标记掩码：(文本, 索引) 不变时复用缓存，变化时重算命中区间
  List<bool> _ensureSavedMask(SavedTextIndex index) {
    final text = _fullText;
    if (_savedMaskText == text && identical(_savedMaskIndex, index)) {
      return _savedMask;
    }
    final ranges = savedCharRanges(text, _tokens, index);
    final mask = ranges.isEmpty
        ? const <bool>[]
        : charMaskFromRanges(text.length, ranges);
    _savedMask = mask;
    _savedMaskText = text;
    _savedMaskIndex = index;
    return mask;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _ensureTokens();
    // 单词收藏集合同时供选区操作条判断“收藏 / 取消收藏”。
    _savedWordTexts =
        ref.watch(savedWordTextsProvider).valueOrNull ?? const <String>{};
    // 收藏索引流式监听：加载中/降级（测试环境无 DB）时为空索引 = 无标记
    final savedMask = _ensureSavedMask(ref.watch(savedTextIndexProvider));
    return PlatformTextSelectionStyle(
      child: AppSelectableText(
        key: _selectableKey,
        text: _fullText,
        style: widget.style,
        wordRange: _wordRangeAt,
        spanBuilder: (_) => _buildSpans(theme, savedMask),
        actionsBuilder: _buildActions,
        onBeforeSelectionCommitted: widget.onBeforeLookup,
        onSelectionCommitted: _handleSelectionCommitted,
        onSessionEnded: _handleSessionEnded,
        // 操作条由页面级宿主渲染（层序：正文 → 屏障 → 操作条 → 面板）。
        onShowToolbar: (request) => _host?.showSelectionToolbar(request),
        // owner 由内核给出：组件卸载后（切句、退页）也要能收掉自己的操作条，
        // 不能依赖 currentState。
        onHideToolbar: (owner) => _host?.hideSelectionToolbar(owner),
      ),
    );
  }

  /// 逐 token 构建 span：评分片段染文字色，收藏命中加点状下划线。
  ///
  /// 收藏标记按 [savedMask] 的逐字符边界切分 token（如 "dog." 只给 "dog"
  /// 加下划线、句号不加），下划线颜色沿用「橙色 = 收藏」视觉语言（与意群
  /// 收藏色系一致），必须显式设 decorationColor（默认会跟随文字色）。
  List<InlineSpan> _buildSpans(ThemeData theme, List<bool> savedMask) {
    final savedColor = AppTheme.savedTextMarkColor(theme.brightness);
    final colorAt = _segmentColorLookup();
    final text = _fullText;
    final spans = <InlineSpan>[];
    var wordIndex = 0;
    for (final t in _tokens) {
      // token 颜色按其起点判定（与旧版整 token 染色一致），
      // 收藏掩码只切分下划线子段，不改变染色粒度
      final color = colorAt(t.start);
      final isActiveWord = t.isWord && wordIndex == widget.activeWordIndex;
      if (t.isWord) wordIndex++;
      for (final (subStart, subEnd, saved) in splitByMask(
        t.start,
        t.end,
        savedMask,
      )) {
        spans.add(
          TextSpan(
            text: text.substring(subStart, subEnd),
            style: TextStyle(
              color: color,
              backgroundColor: isActiveWord
                  ? AppTheme.wordHighlightBackgroundColor(theme.colorScheme)
                  : null,
              decoration: saved ? TextDecoration.underline : null,
              decorationStyle: saved ? TextDecorationStyle.dotted : null,
              decorationColor: saved ? savedColor : null,
              decorationThickness: saved ? 2 : null,
            ),
          ),
        );
      }
    }
    return spans;
  }

  /// 评分片段颜色查询：字符偏移 → 文字色（无片段时恒 null）
  Color? Function(int) _segmentColorLookup() {
    final segs = widget.highlightedSegments;
    if (segs == null || segs.isEmpty) return (_) => null;
    // 预计算各片段的字符区间（拼接顺序即偏移顺序）
    final ranges = <(int, int, bool)>[];
    var offset = 0;
    for (final s in segs) {
      ranges.add((offset, offset + s.text.length, s.isMatched));
      offset += s.text.length;
    }
    return (charOffset) {
      for (final (start, end, matched) in ranges) {
        if (charOffset >= start && charOffset < end) {
          // 命中片段沿用既有跟读评分绿色
          return matched ? const Color(0xFF2E9B51) : null;
        }
      }
      return null;
    };
  }
}
