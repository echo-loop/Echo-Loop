/// 手动查词详情：基础词典（词组则为 AI 解析）+ 来源句 + AI 查词折叠卡。
///
/// 由查词页按清洗后的查询词以 ValueKey 构建，切词即重建，状态互不串扰。
/// 单词的基础释义来自本地（在线）词典；词组没有词典条目，直接走 AI 源。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/sign_in_required_dialog.dart';
import '../../features/subscription/widgets/feature_gate.dart';
import '../../models/dictionary/dict_speakable_texts.dart';
import '../../models/dictionary/dictionary_lookup_result.dart';
import '../../providers/dictionary/dictionary_settings_provider.dart';
import '../../providers/dictionary/lookup_controller.dart';
import '../../providers/dictionary/visible_sources_provider.dart';
import '../../providers/pronunciation/pronunciation_providers.dart';
import '../../providers/saved_sense_group_provider.dart';
import '../../providers/saved_word_provider.dart';
import '../../providers/tts/tts_controller_provider.dart';
import '../../services/app_logger.dart';
import '../../services/dictionary/ai_dictionary_source.dart';
import '../../theme/app_theme.dart';
import '../../utils/text_normalize.dart';
import '../animated_bookmark_icon.dart';
import '../favorites/ai_lookup_toggle.dart';
import '../favorites/source_sentence_card.dart';
import '../tts/speak_button.dart';
import 'ai_dict_result_view.dart';
import 'local_dict_result_view.dart';
import 'reading_text_scale.dart';

/// 取查询状态中可用于预热发音的词条：流式部分结果与完成态都可用。
DictionaryLookupResult? resultOfLookupState(SourceLookupState? state) =>
    switch (state) {
      LookupStreaming(:final result) => result,
      LookupLoaded(:final result) => result,
      _ => null,
    };

/// 查词详情。[query] 为清洗后的查询文本（保留大小写，用于展示与 AI 请求）。
class LookupDetailView extends ConsumerStatefulWidget {
  const LookupDetailView({required this.query, super.key});

  final String query;

  @override
  ConsumerState<LookupDetailView> createState() => _LookupDetailViewState();
}

class _LookupDetailViewState extends ConsumerState<LookupDetailView> {
  /// dispose 阶段不能使用 ref，提前缓存 TTS 控制器以便取消未完成的预热
  TtsController? _ttsController;

  /// 同上：缓存文本播放控制器，离开页面时停止本页发起的自动朗读
  TextPlaybackController? _textPlayback;

  /// 本页是否发起过自动朗读；只有发起过才在离开时停止，避免误停其它播放
  bool _autoSpeakStarted = false;

  /// 已为其预热例句的主查询结果，避免同一结果在每次重建时重复调度
  DictionaryLookupResult? _lastPrewarmedResult;

  bool get _isPhrase => widget.query.contains(' ');

  @override
  void initState() {
    super.initState();
    AppLogger.log('Lookup', '打开查词详情 查询词="${widget.query}"');
    _ttsController = ref.read(ttsControllerProvider.notifier);
    _textPlayback = ref.read(textPlaybackProvider.notifier);
    // 确认查词即在后台预热标题发音；点击发音时 CDN 或 TTS 缓存已就绪，无需等待合成。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppLogger.log('Lookup', '预热标题发音 查询词="${widget.query}"');
      unawaited(_textPlayback?.prewarmWord(widget.query));
      _autoSpeakIfEnabled();
    });
  }

  /// 打开详情后自动朗读单词，行为与词典面板的自动发音一致（不提示下载模型）。
  void _autoSpeakIfEnabled() {
    if (!ref.read(dictionarySettingsProvider).autoSpeakOnLookupPage) {
      AppLogger.log('Lookup', '自动发音跳过：设置已关闭 查询词="${widget.query}"');
      return;
    }
    _autoSpeakStarted = true;
    AppLogger.log('Lookup', '自动发音 查询词="${widget.query}"');
    unawaited(
      _textPlayback?.speak(
        widget.query,
        key: widget.query,
        promptIfModelMissing: false,
      ),
    );
  }

  @override
  void dispose() {
    _ttsController?.cancelTextsPrewarm();
    if (_autoSpeakStarted) unawaited(_textPlayback?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAiVisible = ref
        .watch(visibleDictionarySourcesProvider)
        .any((source) => source.id == AiDictionarySource.sourceId);
    final isAiMainSource = _isPhrase && isAiVisible;
    final mainSourceId = isAiMainSource ? AiDictionarySource.sourceId : 'local';
    final mainProvider = dictionaryLookupControllerProvider(
      widget.query,
      preferredSourceId: mainSourceId,
    );
    final mainState = ref.watch(mainProvider);
    final mainNotifier = ref.read(mainProvider.notifier);
    ref.listen<DictionaryLookupState>(mainProvider, (previous, next) {
      _logMainState(next);
    });
    // 按当前状态调度预热，而非只监听变化：结果在订阅前已就绪时同样生效。
    _schedulePrewarmForMainResult(resultOfLookupState(mainState.current));

    final normalizedWord = normalizeWord(widget.query);
    final savedWords =
        ref.watch(savedWordTextsProvider).value ?? const <String>{};
    final savedPhrases =
        ref.watch(savedSenseGroupTextsProvider).value ?? const <String>{};
    final isSaved =
        savedWords.contains(normalizedWord) ||
        savedPhrases.contains(normalizedWord);
    final savedWord = ref.watch(activeSavedWordProvider(normalizedWord)).value;
    final sentenceText = savedWord?.sentenceText?.trim();
    final isSingleWord = !_isPhrase;
    final isAutoShowAi = ref.watch(
      dictionarySettingsProvider.select(
        (settings) => settings.autoShowAiOnLookup,
      ),
    );

    return SingleChildScrollView(
      // 与收藏复习背面一致：左右 16、顶部 16。
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.m,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.query,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SpeakButton(text: widget.query),
              // 词组与单词一样可收藏，与查词面板的默认收藏口径一致。
              AnimatedBookmarkIcon(
                key: const Key('lookup-detail-bookmark'),
                isSaved: isSaved,
                onPressed: () => _toggleSave(normalizedWord, isSaved),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          ReadingTextScale(
            child: isAiMainSource
                ? AiDictResultView(
                    state: mainState.current,
                    onRetry: mainNotifier.retry,
                    onSignIn: () => openSignInPage(context),
                    onUpgrade: () => _upgrade(mainNotifier),
                  )
                : LocalDictResultView(
                    state: mainState.current,
                    word: widget.query,
                    onRetry: mainNotifier.retry,
                  ),
          ),
          if (isSingleWord &&
              savedWord != null &&
              sentenceText != null &&
              sentenceText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            SourceSentenceCard(
              sentenceText: sentenceText,
              audioItemId: savedWord.audioItemId,
              sentenceIndex: savedWord.sentenceIndex,
              sentenceStartMs: savedWord.sentenceStartMs,
              sentenceEndMs: savedWord.sentenceEndMs,
            ),
          ],
          if (isSingleWord && isAiVisible) ...[
            const SizedBox(height: AppSpacing.m),
            _AiLookupCard(query: widget.query, autoExpand: isAutoShowAi),
          ],
        ],
      ),
    );
  }

  /// 主查询结果（单词基础释义或词组 AI 解析）到达后，帧结束时预热例句发音。
  /// 同一结果对象只提交一次；流式部分结果每帧是新对象，由 TTS 增量预热去重。
  void _schedulePrewarmForMainResult(DictionaryLookupResult? result) {
    if (result == null || identical(result, _lastPrewarmedResult)) return;
    _lastPrewarmedResult = result;
    final texts = dictionaryPrewarmTexts(result);
    AppLogger.log(
      'Lookup',
      '预热例句发音 来源=主结果 headword=${result.headword} 数量=${texts.length}',
    );
    if (texts.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ttsController?.prewarmTextsIncremental(texts);
    });
  }

  /// 记录主查询的最终状态与实际展示的词条，用于排查「点的是 A、显示的是 B」。
  void _logMainState(DictionaryLookupState state) {
    final current = state.current;
    final result = resultOfLookupState(current);
    AppLogger.log(
      'Lookup',
      '主查询状态 查询词="${widget.query}" 数据源=${state.selectedSourceId} '
          '状态=${current.runtimeType} 展示词条headword=${result?.headword ?? '-'}',
    );
  }

  /// 收藏/取消收藏单词。取消时同时清理单词与意群两类记录，与查词面板口径一致。
  Future<void> _toggleSave(String normalizedWord, bool currentlySaved) async {
    AppLogger.log(
      'Lookup',
      '${currentlySaved ? '取消收藏' : '收藏'} 词="$normalizedWord"',
    );
    if (currentlySaved) {
      await Future.wait([
        ref.read(savedWordListProvider.notifier).removeWord(normalizedWord),
        ref
            .read(savedSenseGroupListProvider.notifier)
            .removeSenseGroup(normalizedWord),
      ]);
      return;
    }
    await ref
        .read(savedWordListProvider.notifier)
        .saveWord(word: normalizedWord);
  }

  /// 额度用尽后打开订阅页，返回后重试当前查询。
  Future<void> _upgrade(DictionaryLookupController notifier) async {
    await openPaywall(context, ref);
    if (!mounted) return;
    notifier.retry();
  }
}

/// AI 查词折叠卡。
///
/// 默认折叠时不会发起 AI 请求（controller 惰性创建）。由设置自动展开时，若额度
/// 用尽或未登录，则静默收起为普通入口：不弹提示，用户手动点开才看到升级/登录引导。
class _AiLookupCard extends ConsumerStatefulWidget {
  const _AiLookupCard({required this.query, required this.autoExpand});

  final String query;
  final bool autoExpand;

  @override
  ConsumerState<_AiLookupCard> createState() => _AiLookupCardState();
}

class _AiLookupCardState extends ConsumerState<_AiLookupCard> {
  late bool _expanded = widget.autoExpand;

  /// 当前展开是否由设置自动触发；用户手动切换后置为 false，失败不再静默收起
  late bool _expandedAutomatically = widget.autoExpand;

  bool _collapseScheduled = false;

  /// 上一次记录的 AI 卡片状态，避免每次重建都重复写日志
  String? _lastLoggedAiStatus;

  /// 已为其预热发音的 AI 结果，避免同一结果在每次重建时重复提交
  DictionaryLookupResult? _lastPrewarmedAiResult;

  DictionaryLookupControllerProvider get _aiProvider =>
      dictionaryLookupControllerProvider(
        widget.query,
        preferredSourceId: AiDictionarySource.sourceId,
      );

  @override
  Widget build(BuildContext context) {
    final aiState = _expanded ? ref.watch(_aiProvider) : null;
    final current = aiState?.current;
    _schedulePrewarmForAiResult(resultOfLookupState(current));
    final failedSilently =
        _expandedAutomatically &&
        (current is LookupQuotaExceeded || current is LookupAuthRequired);
    if (failedSilently && !_collapseScheduled) {
      _collapseScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _expanded = false;
          _expandedAutomatically = false;
          _collapseScheduled = false;
        });
      });
    }
    _logAiStatus(
      !_expanded
          ? '折叠'
          : failedSilently
          ? '静默收起(${current.runtimeType})'
          : '展开(${current?.runtimeType ?? 'Idle'})',
    );
    final showBody = _expanded && !failedSilently;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiLookupToggle(
          key: const Key('lookup-detail-ai-toggle'),
          expanded: showBody,
          onTap: _handleToggleTapped,
        ),
        if (showBody) ...[
          const SizedBox(height: AppSpacing.s),
          ReadingTextScale(
            child: AiDictResultView(
              state: current,
              onRetry: () => ref.read(_aiProvider.notifier).retry(),
              onSignIn: () => openSignInPage(context),
              onUpgrade: () => _upgrade(ref.read(_aiProvider.notifier)),
            ),
          ),
        ],
      ],
    );
  }

  /// 记录 AI 卡片状态变化（折叠、展开、结果、静默收起），用于判断是否按预期发起请求。
  void _logAiStatus(String status) {
    if (status == _lastLoggedAiStatus) return;
    _lastLoggedAiStatus = status;
    AppLogger.log('Lookup', 'AI 卡片状态 查询词="${widget.query}" 状态=$status');
  }

  /// AI 结果到达后在帧结束时预热例句发音；只对新结果提交一次。
  void _schedulePrewarmForAiResult(DictionaryLookupResult? result) {
    if (result == null || identical(result, _lastPrewarmedAiResult)) return;
    _lastPrewarmedAiResult = result;
    AppLogger.log(
      'Lookup',
      'AI 卡片结果 查询词="${widget.query}" 展示词条headword=${result.headword}',
    );
    final texts = dictionaryPrewarmTexts(result);
    if (texts.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(ttsControllerProvider.notifier).prewarmTextsIncremental(texts);
    });
  }

  void _handleToggleTapped() {
    setState(() {
      _expanded = !_expanded;
      _expandedAutomatically = false;
    });
  }

  Future<void> _upgrade(DictionaryLookupController notifier) async {
    await openPaywall(context, ref);
    if (!mounted) return;
    notifier.retry();
  }
}
