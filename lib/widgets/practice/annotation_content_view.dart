/// 标注模式内容视图（共享组件）
///
/// 将工具栏固定在顶部不随内容滚动，句子文本和翻译/解析在下方可滚动区域。
/// 内部管理意群全部逻辑：词级时间戳加载、AI 拆分请求、时间范围计算、播放。
///
/// 用于精听、难句补练、难句跟读和收藏复习页面。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/sense_group_result.dart';
import '../../models/speech_practice_models.dart';
import '../../models/word_timestamp.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/learning_settings_provider.dart';
import '../../providers/sentence_ai_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/saved_sense_group_provider.dart';
import '../../services/app_logger.dart';
import '../../services/transcription_api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/sense_group_service.dart';
import '../../utils/sense_group_timing.dart';
import '../../providers/new_user_guide_provider.dart';
import '../guide_flow.dart';
import 'sentence_annotation_card.dart';
import 'sense_group_action_bar.dart';
import 'sense_group_text.dart';

/// 标注模式内容视图
///
/// 工具栏固定在顶部不随内容滚动，句子文本和解析内容在下方可滚动。
/// 内部管理意群数据和播放。
class AnnotationContentView extends ConsumerStatefulWidget {
  /// 句子文本
  final String text;

  /// AI 翻译/解析服务
  final SentenceAiNotifier? aiNotifier;

  /// 来源音频 ID（用于加载词级时间戳 + 词典弹窗）
  final String? audioItemId;

  /// 当前句子索引
  final int? sentenceIndex;

  /// 当前句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 当前句子结束时间（毫秒）
  final int? sentenceEndMs;

  /// 语音评估高亮片段（逐词绿/红标色）
  final List<SpeechTranscriptSegment>? highlightedSegments;

  /// 播放意群前停止主播放回调
  final VoidCallback? onStopMainPlayer;

  /// 意群时间范围变化回调（精听播放按钮需要知道 timings）
  final void Function(List<SenseGroupTiming>? timings)? onTimingsChanged;

  /// 用户点击工具栏按钮（意群/翻译/解析）时触发，通知外部切换到手动模式
  final VoidCallback? onToolbarButtonTapped;

  const AnnotationContentView({
    super.key,
    required this.text,
    this.aiNotifier,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.highlightedSegments,
    this.onStopMainPlayer,
    this.onTimingsChanged,
    this.onToolbarButtonTapped,
  });

  @override
  ConsumerState<AnnotationContentView> createState() =>
      _AnnotationContentViewState();
}

class _AnnotationContentViewState extends ConsumerState<AnnotationContentView> {
  /// 用于访问卡片 State 以构建外部工具栏
  GlobalKey<SentenceAnnotationCardState> _cardKey =
      GlobalKey<SentenceAnnotationCardState>();

  // 新手引导步骤 key —— 解析卡片四步巡览（句子 → 意群 → 翻译 → 解析）
  final GlobalKey _guideSentenceKey = GlobalKey();
  final GlobalKey _guideSenseGroupKey = GlobalKey();
  final GlobalKey _guideTranslationKey = GlobalKey();
  final GlobalKey _guideAnalysisKey = GlobalKey();

  /// 工具栏刷新通知器
  final _toolbarNotifier = RebuildNotifier();

  /// 意群数据服务
  final _sgService = SenseGroupService();

  // --- 意群数据状态 ---
  List<WordTimestamp>? _wordTimestamps;
  SenseGroupResult? _senseGroupResult;
  List<SenseGroupTiming>? _senseGroupTimings;

  /// 当前显示模式对应的 chunks（medium 或 fine）
  List<String>? _activeChunks;

  // --- 意群播放 UI 状态 ---
  int? _playingSenseGroupIndex;
  final Set<int> _playedSenseGroupIndices = {};

  /// 意群播放 session（用于取消）
  int? _sgPlaybackSession;

  // --- 意群快捷菜单 Overlay ---
  OverlayEntry? _actionBarOverlay;
  int? _actionBarGroupIndex;
  Timer? _actionBarTimer;

  /// 缓存预加载 generation counter（防竞态）
  int _preloadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchWordTimestamps();
    _preloadCache();
  }

  @override
  void dispose() {
    _dismissActionBar();
    _toolbarNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnnotationContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切句时重建 GlobalKey + 重置意群数据 + 关闭工具条
    if (widget.text != oldWidget.text) {
      _cardKey = GlobalKey<SentenceAnnotationCardState>();
      _resetSenseGroups();
      _dismissActionBar();
      _preloadCache();
    }
    // 音频切换时重新加载词级时间戳
    if (widget.audioItemId != oldWidget.audioItemId) {
      _resetSenseGroups();
      _wordTimestamps = null;
      _fetchWordTimestamps();
    }
  }

  /// 加载词级时间戳
  Future<void> _fetchWordTimestamps() async {
    final audioItemId = widget.audioItemId;
    if (audioItemId == null) return;

    final words = await _sgService.fetchWordTimestamps(
      audioItemId: audioItemId,
      dao: ref.read(audioItemDaoProvider),
      api: ref.read(transcriptionApiClientProvider),
    );
    if (mounted && widget.audioItemId == audioItemId) {
      setState(() => _wordTimestamps = words);
    }
  }

  /// 从本地缓存预加载翻译/解析/意群数据
  ///
  /// 只查 L2 SQLite 并写入 L1 内存，不调用 L3 API。
  /// 始终执行预加载（开销可忽略），由 [LearningSettings.autoExpandCachedAnnotation]
  /// 在 build() 中控制是否将缓存数据透传给 card。
  Future<void> _preloadCache() async {
    final generation = ++_preloadGeneration;
    final ai = widget.aiNotifier;
    if (ai == null) return;

    final nativeLanguage = ref.read(
      appSettingsProvider.select((s) => s.nativeLanguage),
    );

    // 预加载翻译和解析（结果通过 getCachedTranslation/getCachedAnalysis 透给 card）
    await ai.preloadTranslationFromDb(
      widget.text,
      targetLanguage: nativeLanguage,
    );
    await ai.preloadAnalysisFromDb(widget.text, targetLanguage: nativeLanguage);

    // 预加载意群并计算时间范围
    final sgLoaded = await ai.preloadSenseGroupsFromDb(widget.text);

    if (!mounted || generation != _preloadGeneration) return;

    if (sgLoaded) {
      final autoExpand = ref
          .read(learningSettingsProvider)
          .autoExpandCachedAnnotation;
      if (!autoExpand) return;
      final result = ai.getCachedSenseGroups(widget.text);
      if (result != null && result.medium.isNotEmpty) {
        final timings = _sgService.computeTimings(
          chunks: result.medium,
          wordTimestamps: _wordTimestamps ?? const [],
          sentenceStartMs: widget.sentenceStartMs ?? 0,
          sentenceEndMs: widget.sentenceEndMs ?? 0,
        );
        _senseGroupResult = result;
        _senseGroupTimings = timings;
        _activeChunks = result.medium;
        widget.onTimingsChanged?.call(timings);
      }
    }

    setState(() {});
  }

  /// 请求 AI 拆分意群（作为 onRequestSenseGroups 传给 card）
  Future<void> _requestSenseGroups() async {
    final startMs = widget.sentenceStartMs ?? 0;
    final endMs = widget.sentenceEndMs ?? 0;
    final ai = widget.aiNotifier;
    if (ai == null) return;

    ref.read(analyticsServiceProvider).track(Events.senseGroupRequested);

    try {
      final (result, timings) = await _sgService.requestSenseGroups(
        text: widget.text,
        ai: ai,
        sentenceStartMs: startMs,
        sentenceEndMs: endMs,
        wordTimestamps: _wordTimestamps,
      );

      if (!mounted) return;

      // API 返回空结果（极短句无法拆分）时，提示用户重试，不缓存结果
      if (result.medium.isEmpty) {
        AppLogger.log('SenseGroup', '意群列表为空，提示用户重试');
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.senseGroupLoadFailed ??
                  'Failed to split sense groups, please retry',
            ),
          ),
        );
        return;
      }

      setState(() {
        _senseGroupResult = result;
        _senseGroupTimings = timings;
        _activeChunks = result.medium;
      });
      widget.onTimingsChanged?.call(timings);
    } catch (e) {
      AppLogger.log('SenseGroup', '请求意群失败: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.senseGroupLoadFailed ??
                  'Failed to load sense groups, please retry',
            ),
          ),
        );
      }
    }
  }

  /// 意群粒度切换回调
  void _handleModeChanged(List<String> chunks) {
    // 停止当前意群播放
    _stopSenseGroupPlayback();

    if (chunks.isEmpty) {
      setState(() {
        _senseGroupTimings = null;
        _activeChunks = null;
      });
      widget.onTimingsChanged?.call(null);
    } else {
      _activeChunks = chunks;
      final timings = _sgService.computeTimings(
        chunks: chunks,
        wordTimestamps: _wordTimestamps ?? const [],
        sentenceStartMs: widget.sentenceStartMs ?? 0,
        sentenceEndMs: widget.sentenceEndMs ?? 0,
      );
      setState(() => _senseGroupTimings = timings);
      widget.onTimingsChanged?.call(timings);
    }
  }

  /// 点击意群播放
  Future<void> _handleTapSenseGroup(int index) async {
    final timings = _senseGroupTimings;
    if (timings == null || index >= timings.length) return;

    // 停止主播放
    widget.onStopMainPlayer?.call();

    final timing = timings[index];
    final engine = ref.read(audioEngineProvider.notifier);
    final sessionId = engine.newSession();
    _sgPlaybackSession = sessionId;

    setState(() {
      _playingSenseGroupIndex = index;
      _playedSenseGroupIndices.add(index);
    });

    await engine.playRangeOnce(timing.start, timing.end, sessionId);

    if (mounted && _sgPlaybackSession == sessionId) {
      setState(() => _playingSenseGroupIndex = null);
    }
  }

  /// 停止意群播放
  void _stopSenseGroupPlayback() {
    if (_playingSenseGroupIndex != null) {
      _sgPlaybackSession = null;
      setState(() => _playingSenseGroupIndex = null);
    }
  }

  /// 显示意群快捷菜单
  void _showActionBar(int index, Rect badgeRect) {
    _dismissActionBar();
    _actionBarGroupIndex = index;

    final chunks = _activeChunks ?? _senseGroupResult?.medium ?? [];
    if (index >= chunks.length) return;
    final chunk = chunks[index];
    final normalized = normalizeSenseGroupPhrase(chunk);

    _actionBarOverlay = OverlayEntry(
      builder: (context) {
        // 从 provider 获取收藏状态
        return Consumer(
          builder: (context, ref, _) {
            final savedTextsAsync = ref.watch(savedSenseGroupTextsProvider);
            final savedTexts = savedTextsAsync.valueOrNull ?? {};
            final isSaved = savedTexts.contains(normalized);

            return Positioned(
              left: badgeRect.left + badgeRect.width / 2 - 35,
              top: badgeRect.top - 34,
              child: TapRegion(
                onTapOutside: (_) => _dismissActionBar(),
                child: SenseGroupActionBar(
                  isSaved: isSaved,
                  onToggleSave: () =>
                      _toggleSaveSenseGroup(index, chunk, normalized, isSaved),
                ),
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_actionBarOverlay!);

    // 5 秒自动消失
    _actionBarTimer?.cancel();
    _actionBarTimer = Timer(const Duration(seconds: 5), _dismissActionBar);
  }

  /// 关闭意群快捷菜单
  void _dismissActionBar() {
    _actionBarTimer?.cancel();
    _actionBarTimer = null;
    _actionBarOverlay?.remove();
    _actionBarOverlay = null;
    _actionBarGroupIndex = null;
  }

  /// 收藏/取消收藏意群
  Future<void> _toggleSaveSenseGroup(
    int index,
    String displayText,
    String normalizedText,
    bool currentlySaved,
  ) async {
    final provider = ref.read(savedSenseGroupListProvider.notifier);

    if (currentlySaved) {
      await provider.removeSenseGroup(normalizedText);
    } else {
      // 获取意群时间范围
      int? groupStartMs;
      int? groupEndMs;
      if (_senseGroupTimings != null && index < _senseGroupTimings!.length) {
        final timing = _senseGroupTimings![index];
        groupStartMs = timing.start.inMilliseconds;
        groupEndMs = timing.end.inMilliseconds;
      }

      await provider.saveSenseGroup(
        phraseText: normalizedText,
        displayText: displayText.trim(),
        audioItemId: widget.audioItemId,
        sentenceIndex: widget.sentenceIndex,
        sentenceText: widget.text,
        sentenceStartMs: widget.sentenceStartMs,
        sentenceEndMs: widget.sentenceEndMs,
        groupStartMs: groupStartMs,
        groupEndMs: groupEndMs,
      );
    }

    // 收藏后 500ms 关闭工具条
    _actionBarTimer?.cancel();
    _actionBarTimer = Timer(
      const Duration(milliseconds: 500),
      _dismissActionBar,
    );
  }

  /// 重置意群数据
  void _resetSenseGroups() {
    _senseGroupResult = null;
    _senseGroupTimings = null;
    _activeChunks = null;
    _playingSenseGroupIndex = null;
    _playedSenseGroupIndices.clear();
    _sgPlaybackSession = null;
    widget.onTimingsChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final ai = widget.aiNotifier;
    final nativeLanguage = ref.watch(
      appSettingsProvider.select((s) => s.nativeLanguage),
    );
    final autoExpand = ref
        .watch(learningSettingsProvider)
        .autoExpandCachedAnnotation;
    final cachedTranslation = autoExpand
        ? ai
              ?.getCachedTranslation(
                widget.text,
                targetLanguage: nativeLanguage,
              )
              ?.translation
        : null;
    final cachedAnalysis = autoExpand
        ? ai?.getCachedAnalysis(widget.text, targetLanguage: nativeLanguage)
        : null;
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();

    // 局部 watch 已收藏意群文本集合，避免全局重建
    final savedTextsAsync = ref.watch(savedSenseGroupTextsProvider);
    final savedTexts = savedTextsAsync.valueOrNull ?? {};

    final l10n = AppLocalizations.of(context)!;
    final sentenceStep = GuideStep(
      key: _guideSentenceKey,
      description: l10n.guideSentenceAnnotationSentenceDescription,
    );
    final senseGroupStep = GuideStep(
      key: _guideSenseGroupKey,
      description: l10n.guideSentenceAnnotationSenseGroupDescription,
    );
    final translationStep = GuideStep(
      key: _guideTranslationKey,
      description: l10n.guideSentenceAnnotationTranslationDescription,
    );
    final analysisStep = GuideStep(
      key: _guideAnalysisKey,
      description: l10n.guideSentenceAnnotationAnalysisDescription,
    );
    final guideFlows = <GuideFlow>[
      GuideFlow(
        flowId: GuideFlowIds.sentenceAnnotationTour,
        shouldRun: true,
        // 句子 → 意群 → 翻译 → 解析
        steps: [sentenceStep, senseGroupStep, translationStep, analysisStep],
      ),
    ];

    return GuideFlowSequenceHost(
      flows: guideFlows,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // 滚动时关闭工具条
          if (notification is ScrollStartNotification) {
            _dismissActionBar();
          }
          return false;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 固定工具栏（监听 notifier 刷新）
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.m),
              child: ListenableBuilder(
                listenable: _toolbarNotifier,
                builder: (context, _) {
                  final cardState = _cardKey.currentState;
                  if (cardState == null || !cardState.hasToolbarButtons) {
                    return const SizedBox.shrink();
                  }
                  return cardState.buildToolbar(context);
                },
              ),
            ),
            // 可滚动内容区
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.l),
                child: SentenceAnnotationCard(
                  key: _cardKey,
                  text: widget.text,
                  showToolbar: false,
                  onToolbarStateChanged: _toolbarNotifier.notify,
                  onRequestTranslation: ai != null
                      ? () async {
                          ref
                              .read(analyticsServiceProvider)
                              .track(Events.translationRequested);
                          final result = await ai.getTranslation(
                            widget.text,
                            targetLanguage: nativeLanguage,
                          );
                          return result.translation;
                        }
                      : null,
                  onRequestAnalysis: ai != null
                      ? () async {
                          ref
                              .read(analyticsServiceProvider)
                              .track(Events.analysisRequested);
                          final result = await ai.getAnalysis(
                            widget.text,
                            targetLanguage: nativeLanguage,
                          );
                          return result.toDisplayString();
                        }
                      : null,
                  cachedTranslation: cachedTranslation,
                  cachedAnalysis: cachedAnalysisText,
                  audioItemId: widget.audioItemId,
                  sentenceIndex: widget.sentenceIndex,
                  sentenceStartMs: widget.sentenceStartMs,
                  sentenceEndMs: widget.sentenceEndMs,
                  senseGroupResult: _senseGroupResult,
                  senseGroupTimings: _senseGroupTimings,
                  onSenseGroupModeChanged: _handleModeChanged,
                  playingSenseGroupIndex: _playingSenseGroupIndex,
                  playedSenseGroupIndices: _playedSenseGroupIndices,
                  onTapSenseGroup: _handleTapSenseGroup,
                  onRequestSenseGroups: _requestSenseGroups,
                  hasWordTimestamps: _wordTimestamps != null,
                  highlightedSegments: widget.highlightedSegments,
                  savedGroupTexts: savedTexts,
                  onTapGroupWithRect: _showActionBar,
                  onToolbarButtonTapped: widget.onToolbarButtonTapped,
                  sentenceGuideStep: sentenceStep,
                  senseGroupGuideStep: senseGroupStep,
                  translationGuideStep: translationStep,
                  analysisGuideStep: analysisStep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 简单的重建通知器，用于卡片状态变化时触发工具栏重建
class RebuildNotifier extends ChangeNotifier {
  /// 通知所有监听者重建
  void notify() => notifyListeners();
}
