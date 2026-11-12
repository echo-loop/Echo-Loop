/// 手动查词页（全屏）。
///
/// 顶部搜索框自动聚焦；输入时用本地词表做前缀建议，空输入显示最近查询。
/// 查询一律走词典 API：词表只负责建议，不限制用户只能查词表内的词。
/// 词表在页面存活期间加载，退出即释放（见 [wordlistProvider]）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/providers.dart';
import '../features/chatbot/sentence_passage.dart';
import '../features/chatbot/widgets/sentence_chat_button.dart';
import '../l10n/app_localizations.dart';
import '../providers/dictionary/lookup_history_provider.dart';
import '../providers/dictionary/wordlist_provider.dart';
import '../services/app_logger.dart';
import '../providers/saved_word_provider.dart';
import '../services/dictionary/wordlist_index.dart';
import '../theme/app_theme.dart';
import '../utils/text_normalize.dart';
import '../widgets/common/search_app_bar.dart';
import '../widgets/common/svg_action_icon.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/dictionary/lookup_detail_view.dart';
import '../widgets/dictionary/lookup_settings_sheet.dart';

class DictionaryLookupScreen extends ConsumerStatefulWidget {
  const DictionaryLookupScreen({super.key});

  @override
  ConsumerState<DictionaryLookupScreen> createState() =>
      _DictionaryLookupScreenState();
}

class _DictionaryLookupScreenState
    extends ConsumerState<DictionaryLookupScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// 当前展示详情的查询词（清洗后，保留大小写）；null 表示尚未查询或已改写输入。
  String? _lookedUpQuery;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    // 详情只由 _openLookup 显式打开。开始编辑时立即回到列表并丢弃旧详情：
    // 否则失焦时（例如点击列表项）若输入框文本恰好等于上一次的查询词，
    // 旧详情会替换掉正在点击的列表，导致点击的词被忽略。
    if (_focusNode.hasFocus) {
      if (_lookedUpQuery != null) {
        AppLogger.log('Lookup', '开始编辑 收起当前详情 查询词="$_lookedUpQuery"');
      }
      _lookedUpQuery = null;
      // 全选输入内容，便于直接键入新词连续查询。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusNode.hasFocus) return;
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
    }
    setState(() {});
  }

  /// 统一查询入口：建议、历史与键盘搜索都经过这里。
  void _openLookup(String raw, {required String source}) {
    final query = normalizeDictionaryQueryForPrompt(raw);
    AppLogger.log('Lookup', '提交查询 来源=$source 输入框原文="$raw" 查询词="$query"');
    if (query.isEmpty) return;
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() => _lookedUpQuery = query);
    _focusNode.unfocus();
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const LookupSettingsSheet(),
    );
  }

  void _clearInput() {
    _controller.clear();
    setState(() => _lookedUpQuery = null);
    _focusNode.requestFocus();
  }

  Future<void> _confirmClearHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.lookupClearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.lookupClearHistory),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(lookupHistoryDaoProvider).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 进入页面即开始加载词表；页面退出后无监听者，autoDispose 释放引用。
    ref.watch(wordlistProvider);
    final isShowingDetail = _lookedUpQuery != null && !_focusNode.hasFocus;
    final lookedUpQuery = _lookedUpQuery;

    return Scaffold(
      appBar: SearchAppBar(
        controller: _controller,
        focusNode: _focusNode,
        hintText: l10n.lookupSearchHint,
        query: _controller.text,
        onChanged: (_) => setState(() {}),
        onSubmitted: (raw) => _openLookup(raw, source: '键盘搜索'),
        onClear: _clearInput,
        onCancel: () => context.pop(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.pop(),
        ),
        // 与合集、资源库搜索的「取消」按钮一致，末尾留 8 的右边距。
        actions: [
          if (isShowingDetail && lookedUpQuery != null)
            _buildChatAction(lookedUpQuery),
          IconButton(
            key: const Key('dictionary-lookup-settings'),
            tooltip: l10n.lookupSettingsTooltip,
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DictionaryPanelHost(
        handleBackButton: true,
        child: isShowingDetail && lookedUpQuery != null
            ? LookupDetailView(
                key: ValueKey(lookedUpQuery),
                query: lookedUpQuery,
              )
            : _buildSuggestionsOrHistory(theme, l10n),
      ),
    );
  }

  /// 详情态右上角的 AI 助手入口：与收藏来源句关联，便于在语境中继续提问。
  Widget _buildChatAction(String query) {
    final savedWord = ref
        .watch(activeSavedWordProvider(normalizeWord(query)))
        .value;
    return SentenceChatButton(
      target: SentenceChatTarget(
        text: query,
        audioItemId: savedWord?.audioItemId,
        sentenceIndex: savedWord?.sentenceIndex,
      ),
    );
  }

  Widget _buildSuggestionsOrHistory(ThemeData theme, AppLocalizations l10n) {
    if (_controller.text.trim().isEmpty) {
      return _buildHistory(theme, l10n);
    }
    return _buildSuggestions(theme, l10n);
  }

  Widget _buildSuggestions(ThemeData theme, AppLocalizations l10n) {
    final wordlist = ref.watch(wordlistProvider);
    final WordlistIndex? index = wordlist.value;
    final suggestions = index?.suggest(_controller.text) ?? const <String>[];
    if (suggestions.isEmpty) {
      // 无建议不阻止回车查询；仅在词表加载失败时提示用户建议不可用。
      if (!wordlist.hasError) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Text(
          l10n.lookupWordlistUnavailable,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      key: const Key('dictionary-lookup-suggestions'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final word = suggestions[index];
        return ListTile(
          leading: SvgActionIcon(
            assetName: 'assets/icon/search.svg',
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(word),
          onTap: () => _openLookup(word, source: '建议点击'),
        );
      },
    );
  }

  Widget _buildHistory(ThemeData theme, AppLocalizations l10n) {
    final history = ref.watch(lookupHistoryProvider).value ?? const [];
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Text(
            l10n.lookupHistoryEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView(
      key: const Key('dictionary-lookup-history'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.s,
            AppSpacing.s,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.lookupRecentTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const Key('dictionary-lookup-clear-history'),
                onPressed: _confirmClearHistory,
                child: Text(l10n.lookupClearHistory),
              ),
            ],
          ),
        ),
        for (final entry in history)
          ListTile(
            leading: Icon(
              Icons.history,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(entry.word),
            onTap: () => _openLookup(entry.word, source: '历史点击'),
          ),
      ],
    );
  }
}
