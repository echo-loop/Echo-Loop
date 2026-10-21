/// 标注模式内容视图（共享组件）
///
/// 将工具栏、句子文本和翻译/解析放入同一个滚动容器。
/// 内部管理意群全部逻辑：词级时间戳加载、AI 拆分请求、时间范围计算、播放。
///
/// 用于精听、难句补练、难句跟读和收藏复习页面。
library;

import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/sign_in_required_dialog.dart';
import '../../features/chatbot/chatbot_flags.dart';
import '../../features/chatbot/widgets/sentence_chat_button.dart';
import '../../features/remote_config/remote_config.dart';
import '../../features/remote_config/remote_config_providers.dart';
import '../../features/subscription/widgets/ai_quota_exceeded_dialog.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart' as app_model;
import '../../models/sense_group_result.dart';
import '../../models/sense_group_range_playback.dart';
import '../../models/sentence.dart';
import '../../models/speech_practice_models.dart';
import '../../models/word_timestamp.dart';
import '../../models/word_highlight_binding.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/audio_sentences_provider.dart';
import '../../providers/learning_settings_provider.dart';
import '../../providers/sentence_ai_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/word_highlight_provider.dart';
import '../../providers/saved_sense_group_provider.dart';
import '../../services/app_logger.dart';
import '../../services/dictionary/ai_dictionary_source.dart';
import '../../theme/app_theme.dart';
import '../../utils/sense_group_service.dart';
import '../../utils/sense_group_timing_notice_store.dart';
import '../../utils/sense_group_timing.dart';
import '../dictionary/dictionary_panel_host.dart';
import '../../providers/new_user_guide_provider.dart';
import '../guide_flow.dart';
import 'sentence_annotation_card.dart';
import 'sense_group_action_bar.dart';
import '../selection/selection_toolbar.dart';
import 'sense_group_text.dart';

/// 用于 AI 自动预加载诊断的页面上下文。
class SentenceExplanationContext {
  const SentenceExplanationContext({required this.source, this.flowPhase});

  final String source;
  final String? flowPhase;
}

/// 完整的单句讲解视图。
///
/// 管理讲解正文、AI 翻译/解析、意群、缓存、认证与词典交互；不管理任务流程、
/// 播放会话、录音、句子进度或元信息行。
class SentenceExplanationView extends ConsumerStatefulWidget {
  /// 句子文本
  final String? text;

  /// AI 翻译/解析服务
  final SentenceAiNotifier? aiNotifier;

  /// 来源音频 ID（用于加载词级时间戳 + 词典弹窗）
  final String? audioItemId;

  /// 当前任务使用的原音播放位置来源；为空时只显示普通句子文本。
  final WordHighlightSource? wordHighlightSource;

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

  /// 当前会话注入的意群区间播放器；为空时保持原音频播放链路。
  final SenseGroupRangePlayback? senseGroupRangePlayback;

  /// 意群时间范围变化回调（精听播放按钮需要知道 timings）
  final void Function(List<SenseGroupTiming>? timings)? onTimingsChanged;

  /// 用户点击工具栏按钮（意群/翻译/解析）时触发，通知外部切换到手动模式
  final VoidCallback? onToolbarButtonTapped;

  /// 是否启用新手引导（句子→意群→翻译→解析 showcase）。
  ///
  /// 默认 true。Free Player 单句模式用 PageView 预建相邻页时，必须仅对**当前页**
  /// 置 true：showcaseview 的 [Showcase] 一挂载即向全局注册，离屏页随 PageView
  /// 回收销毁时其注册回调会落在已 unmount 的 State 上而崩溃。
  final bool enableGuide;

  /// 工具栏与句子正文的横向内边距；解析内容面板仍保持满宽，由自身处理内边距。
  final double contentHorizontalPadding;

  /// 自动预加载的页面来源，仅用于诊断日志。
  final String? diagnosticSource;

  /// 调用方流程阶段，仅用于诊断日志，不参与调度。
  final String? diagnosticFlowPhase;

  final SentenceExplanationContext? explanationContext;
  final bool showTranscript;

  /// 当前页面是否是用户正在查看的句子。
  ///
  /// 分页器会保活相邻页面；从离屏页重新进入时，讲解滚动区必须回到顶部，
  /// 不能让上一轮阅读位置裁切工具栏。
  final bool isActiveSentence;

  /// AI 自动展示总开关覆盖；未传入时沿用全局学习任务设置。
  final bool? autoShowAiExplanation;

  /// AI 句子解析自动展示覆盖；未传入时沿用全局学习任务设置。
  final bool? autoShowAiAnalysis;

  /// AI 句子翻译自动展示覆盖；未传入时沿用全局学习任务设置。
  final bool? autoShowAiTranslation;

  /// AI 意群自动展示覆盖；未传入时沿用全局学习任务设置。
  final bool? autoShowAiSenseGroups;

  const SentenceExplanationView({
    super.key,
    this.text,
    this.aiNotifier,
    this.audioItemId,
    this.wordHighlightSource,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.highlightedSegments,
    this.onStopMainPlayer,
    this.senseGroupRangePlayback,
    this.onTimingsChanged,
    this.onToolbarButtonTapped,
    this.enableGuide = true,
    this.contentHorizontalPadding = 0,
    this.diagnosticSource,
    this.diagnosticFlowPhase,
    this.explanationContext,
    this.showTranscript = true,
    this.isActiveSentence = true,
    this.autoShowAiExplanation,
    this.autoShowAiAnalysis,
    this.autoShowAiTranslation,
    this.autoShowAiSenseGroups,
  });

  @override
  ConsumerState<SentenceExplanationView> createState() =>
      _SentenceExplanationViewState();
}

class _SentenceExplanationViewState
    extends ConsumerState<SentenceExplanationView> {
  String get _text => widget.text ?? '';
  int? get _sentenceIndex => widget.sentenceIndex;
  int? get _sentenceStartMs => widget.sentenceStartMs;
  int? get _sentenceEndMs => widget.sentenceEndMs;
  String? get _diagnosticSource =>
      widget.explanationContext?.source ?? widget.diagnosticSource;
  String? get _diagnosticFlowPhase =>
      widget.explanationContext?.flowPhase ?? widget.diagnosticFlowPhase;

  WordHighlightBinding? get _wordHighlightBinding {
    final source = widget.wordHighlightSource;
    final startMs = _sentenceStartMs;
    final endMs = _sentenceEndMs;
    if (source == null || startMs == null || endMs == null) return null;
    final playingGroupIndex = _playingSenseGroupIndex;
    final timings = _senseGroupTimings;
    final activeRangeStartMs =
        playingGroupIndex != null &&
            timings != null &&
            playingGroupIndex < timings.length
        ? timings[playingGroupIndex].start.inMilliseconds
        : null;
    return WordHighlightBinding(
      source: source,
      sentenceStartMs: startMs,
      sentenceEndMs: endMs,
      activeRangeStartMs: activeRangeStartMs,
    );
  }

  /// 用于访问卡片 State 以构建外部工具栏
  GlobalKey<SentenceAnnotationCardState> _cardKey =
      GlobalKey<SentenceAnnotationCardState>();

  // 新手引导步骤 key —— 解析卡片三步巡览（句子 → 意群 → 解析）
  final GlobalKey _guideSentenceKey = GlobalKey();
  final GlobalKey _guideSenseGroupKey = GlobalKey();
  final GlobalKey _guideAnalysisKey = GlobalKey();

  /// 工具栏刷新通知器
  final _toolbarNotifier = RebuildNotifier();

  /// 讲解滚动位置由视图自身拥有，避免受 PageView / PageStorage 隐式恢复影响。
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  int _scrollResetGeneration = 0;

  /// 意群数据服务
  final _sgService = SenseGroupService();

  // --- 意群数据状态 ---
  /// 与正文高亮组件共用同一份词级时间戳加载结果。
  List<WordTimestamp>? get _wordTimestamps {
    final audioItemId = widget.audioItemId;
    if (audioItemId == null) return null;
    return ref.read(wordTimestampsProvider(audioItemId)).valueOrNull;
  }

  SenseGroupResult? _senseGroupResult;
  List<SenseGroupTiming>? _senseGroupTimings;

  /// 当前显示模式对应的 chunks（medium 或 fine）
  List<String>? _activeChunks;

  // --- 意群播放 UI 状态 ---
  int? _playingSenseGroupIndex;
  final Set<int> _playedSenseGroupIndices = {};

  /// 意群播放 generation（用于丢弃取消或重复点击后的迟到完成）。
  int _sgPlaybackGeneration = 0;

  /// 词典面板打开期间锁定意群快捷 lookup，避免同一快捷条重复触发查词。
  bool _senseGroupLookupLocked = false;
  DictionaryPanelHostState? _lookupLockHost;
  VoidCallback? _lookupLockListener;

  /// 上传字幕推测时间提示是否正在展示，防止快速连点弹出多个对话框。
  bool _isShowingSyntheticTimingNotice = false;

  /// quota 提醒弹窗是否正在展示，防止翻译/解析并发失败时叠多个弹窗。
  bool _isShowingAiQuotaDialog = false;

  // --- 意群快捷菜单 Overlay ---
  OverlayEntry? _actionBarOverlay;

  /// 缓存预加载 generation counter（防竞态）
  int _preloadGeneration = 0;

  /// 自动预加载诊断去重键，避免 rebuild 重复记录同一判定。
  String? _autoLoadDiagnosticKey;

  // --- 意群流式状态 ---
  /// 当前意群流订阅（逐帧渐显 medium）
  StreamSubscription<(SenseGroupResult, List<SenseGroupTiming>)>? _sgSub;

  /// 意群流 Dio 取消令牌（切句/dispose 时中断底层请求）
  CancelToken? _sgCancel;

  /// medium 就绪信号：medium 流完（fine 开始或流结束）即完成 → 早释放拆意群按钮
  Completer<void>? _sgMediumReady;

  /// 全部就绪信号：流结束（含 final）或出错完成 → fine 已完整，供 medium→fine 切换 await
  Completer<void>? _sgAllDone;

  @override
  void initState() {
    super.initState();
    _preloadCache();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _deferSenseGroupPlaybackCancellation();
    _sgSub?.cancel();
    _sgCancel?.cancel();
    _detachSenseGroupLookupLock(unlock: false);
    _dismissActionBar();
    _toolbarNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SentenceExplanationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 自动展示设置变化时重建内部卡片，收起旧结果并取消旧卡片的 AI 流。
    if (widget.autoShowAiExplanation != oldWidget.autoShowAiExplanation ||
        widget.autoShowAiAnalysis != oldWidget.autoShowAiAnalysis ||
        widget.autoShowAiTranslation != oldWidget.autoShowAiTranslation ||
        widget.autoShowAiSenseGroups != oldWidget.autoShowAiSenseGroups) {
      _cardKey = GlobalKey<SentenceAnnotationCardState>();
      _resetSenseGroups();
      _dismissActionBar();
    }
    // 切句时重建 GlobalKey + 重置意群数据 + 关闭工具条
    if (_text != (oldWidget.text ?? '')) {
      _cardKey = GlobalKey<SentenceAnnotationCardState>();
      _resetSenseGroups();
      _dismissActionBar();
      _preloadCache();
    }
    // 音频切换时重新加载词级时间戳
    if (widget.audioItemId != oldWidget.audioItemId) {
      _resetSenseGroups();
    }
    if (_shouldResetScrollPosition(oldWidget)) {
      _resetScrollPosition();
    }
  }

  /// 判断是否进入了新的讲解阅读会话。
  ///
  /// 仅切句或离屏页重新激活时归零；翻译、解析和意群的流式 rebuild 不应打断
  /// 用户正在阅读同一句时的滚动位置。
  bool _shouldResetScrollPosition(SentenceExplanationView oldWidget) {
    final sentenceChanged =
        widget.audioItemId != oldWidget.audioItemId ||
        _sentenceIndex != oldWidget.sentenceIndex ||
        _text != (oldWidget.text ?? '');
    final becameActive = widget.isActiveSentence && !oldWidget.isActiveSentence;
    return widget.isActiveSentence && (sentenceChanged || becameActive);
  }

  /// 将新激活句的工具栏和正文同步带回滚动区顶部。
  ///
  /// PageView 的子页可能尚未挂载 [ScrollPosition]。因此同步归零后保留一次
  /// 帧后兜底，并用 generation 与当前激活态隔离已过期的切句回调。
  void _resetScrollPosition() {
    final generation = ++_scrollResetGeneration;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _scrollResetGeneration ||
          !widget.isActiveSentence ||
          !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(0);
    });
  }

  /// 从共享字幕投影取当前句的前/后句文本（做翻译上下文）。
  ///
  /// 无来源音频 / 无句索引 / 越界（首、末句）均返回 null。仅取不可变的
  /// [Sentence.text]，前后句上下文进翻译缓存键（见 `getTranslationStream`）。
  (String?, String?) _neighborTexts(List<Sentence>? sentences) {
    final idx = _sentenceIndex;
    if (sentences == null || idx == null) return (null, null);
    String? at(int i) =>
        (i >= 0 && i < sentences.length) ? sentences[i].text : null;
    return (at(idx - 1), at(idx + 1));
  }

  /// 从本地缓存预加载翻译/解析/意群数据
  ///
  /// 只查 L2 SQLite 并写入 L1 内存，不调用 L3 API。
  /// 始终执行预加载（开销可忽略），由 [LearningSettings.autoExpandCachedAnnotation]
  /// 在 build() 中控制是否将缓存数据透传给 card。
  Future<void> _preloadCache() async {
    final generation = ++_preloadGeneration;
    final ai = widget.aiNotifier ?? ref.read(sentenceAiNotifierProvider);
    if (ai == null) return;

    final nativeLanguage = ref.read(
      appSettingsProvider.select((s) => s.nativeLanguage),
    );

    // 取前后句上下文（翻译缓存键含上下文，须与 build/请求处一致）
    final audioItemId = widget.audioItemId;
    final sentences = (audioItemId != null && audioItemId.isNotEmpty)
        ? await ref.read(audioSentencesProvider(audioItemId).future)
        : null;
    if (!mounted || generation != _preloadGeneration) return;
    final (previousText, nextText) = _neighborTexts(sentences);

    // 预加载翻译和解析（结果通过 getCachedTranslation/getCachedAnalysis 透给 card）
    await ai.preloadTranslationFromDb(
      _text,
      targetLanguage: nativeLanguage,
      previous: previousText,
      next: nextText,
    );
    await ai.preloadAnalysisFromDb(_text, targetLanguage: nativeLanguage);

    // 预加载意群并计算时间范围
    final sgLoaded = await ai.preloadSenseGroupsFromDb(_text);

    if (!mounted || generation != _preloadGeneration) return;

    if (sgLoaded) {
      final settings = ref.read(learningSettingsProvider);
      final autoShowAiExplanation =
          widget.autoShowAiExplanation ?? settings.autoShowAiExplanation;
      final autoShowAiSenseGroups =
          widget.autoShowAiSenseGroups ?? settings.autoShowAiSenseGroups;
      final autoExpand = autoShowAiExplanation && autoShowAiSenseGroups;
      if (!autoExpand) return;
      final result = ai.getCachedSenseGroups(_text);
      if (result != null && result.medium.isNotEmpty) {
        final timings = _sgService.computeTimings(
          chunks: result.medium,
          wordTimestamps: _wordTimestamps ?? const [],
          sentenceStartMs: _sentenceStartMs ?? 0,
          sentenceEndMs: _sentenceEndMs ?? 0,
        );
        _senseGroupResult = result;
        _senseGroupTimings = timings;
        _activeChunks = result.medium;
        widget.onTimingsChanged?.call(timings);
      }
    }

    setState(() {});
  }

  /// 请求 AI 拆分意群（流式，作为 onRequestSenseGroups 传给 card）
  ///
  /// 返回的 Future 在 **medium 就绪**（medium 流完）时 settle——供拆意群按钮尽早释放、
  /// 让用户可交互 medium；fine 在后台继续流入 `_senseGroupResult`，medium→fine 切换由
  /// [_awaitSenseGroupFine] 协调加载态。逐帧 setState 使 chunk 随 prop 变化自上而下渐显。
  Future<void> _requestSenseGroups(SentenceAiRequestSource source) async {
    // 已有活跃流：复用其 medium 就绪信号（去重，避免重复起流）
    final activeReady = _sgMediumReady;
    if (activeReady != null && _sgSub != null) {
      return activeReady.future;
    }

    final startMs = _sentenceStartMs ?? 0;
    final endMs = _sentenceEndMs ?? 0;
    // 调用方可以显式注入测试或会话级 notifier；统一页面入口未注入时，
    // 必须回退到 Provider，避免工具栏请求回调为空而整组 AI 按钮被禁用。
    final ai = widget.aiNotifier ?? ref.read(sentenceAiNotifierProvider);
    if (ai == null) return;
    final accessToken = ref
        .read(supabaseSessionProvider)
        .valueOrNull
        ?.accessToken;

    ref.read(usageTrackerProvider).record(UsageEvent.senseGroupTapped);

    final mediumReady = Completer<void>();
    final allDone = Completer<void>();
    final cancel = CancelToken();
    _sgMediumReady = mediumReady;
    _sgAllDone = allDone;
    _sgCancel = cancel;

    void completeAll() {
      if (!mediumReady.isCompleted) mediumReady.complete();
      if (!allDone.isCompleted) allDone.complete();
    }

    _sgSub = _sgService
        .streamSenseGroups(
          text: _text,
          ai: ai,
          accessToken: accessToken,
          sentenceStartMs: startMs,
          sentenceEndMs: endMs,
          wordTimestamps: _wordTimestamps,
          cancelToken: cancel,
          respectLocalQuotaReset: source == SentenceAiRequestSource.automatic,
        )
        .listen(
          (frame) {
            final (result, timings) = frame;
            // 空快照跳过，留 shimmer（仿流式解析）
            if (result.medium.isEmpty || !mounted) return;
            setState(() {
              _senseGroupResult = result;
              _senseGroupTimings = timings;
              _activeChunks = result.medium;
            });
            // fine 已开始 ⇒ medium 已流完（后端 medium→fine 顺序）→ 早释放按钮
            if (!mediumReady.isCompleted && result.fine.isNotEmpty) {
              mediumReady.complete();
            }
          },
          onError: (Object e, StackTrace st) {
            completeAll();
            _sgSub = null;
            if (!mounted) return;
            if (e is AiFeatureAuthRequiredException) {
              _showAiFeatureSignInDialog();
            } else if (e is AiFeatureQuotaExceededException) {
              unawaited(
                _showAiQuotaExceededDialog(
                  e,
                  force: source == SentenceAiRequestSource.userTap,
                ),
              );
            } else {
              AppLogger.log('SenseGroup', '请求意群失败: $e');
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
          },
          onDone: () {
            // 流正常结束：medium/fine 均完整（缓存/校验/计费由 provider 负责）
            final result = _senseGroupResult;
            if (result != null && result.medium.isNotEmpty) {
              ref
                  .read(usageTrackerProvider)
                  .record(UsageEvent.senseGroupSucceeded);
              widget.onTimingsChanged?.call(_senseGroupTimings);
            }
            completeAll();
            _sgSub = null;
          },
          cancelOnError: true,
        );

    return mediumReady.future;
  }

  /// 等待 fine 意群就绪（供 card 在 medium→fine 且 fine 未就绪时 await，按钮自动显示加载）。
  ///
  /// fine 完整 = 意群流结束（后端 fine 在 medium 之后、done 之前全部流出）。流已结束或无活跃流
  /// （如缓存命中已含完整 fine）则立即返回。
  Future<void> _awaitSenseGroupFine() async {
    final done = _sgAllDone;
    if (done == null || done.isCompleted) return;
    await done.future;
  }

  /// 展示云端 AI 能力的登录引导弹窗。
  ///
  /// 只在确实需要请求 L3 API 且当前无 Supabase session 时出现；
  /// 已缓存的 L1/L2 结果不会触发登录门槛。
  Future<void> _showAiFeatureSignInDialog() async {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.senseGroupSignInRequiredTitle,
      message: l10n.senseGroupSignInRequiredMessage,
    );
  }

  /// 已登录但未解锁 AI 功能时展示统一额度提示。
  Future<void> _showAiQuotaExceededDialog(
    AiFeatureQuotaExceededException error, {
    bool force = false,
  }) async {
    if (_isShowingAiQuotaDialog || !mounted) return;
    _isShowingAiQuotaDialog = true;
    try {
      await showAiQuotaExceededDialog(
        context: context,
        ref: ref,
        feature: error.feature,
        reason: error.reason,
        respectReminderCooldown: !force,
      );
    } finally {
      _isShowingAiQuotaDialog = false;
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
        sentenceStartMs: _sentenceStartMs ?? 0,
        sentenceEndMs: _sentenceEndMs ?? 0,
      );
      setState(() => _senseGroupTimings = timings);
      widget.onTimingsChanged?.call(timings);
    }
  }

  /// 点击意群播放
  Future<void> _handleTapSenseGroup(int index) async {
    final timings = _senseGroupTimings;
    if (timings == null || index >= timings.length) return;

    final shouldContinue = await _ensureSyntheticTimingNoticeAcknowledged();
    if (!mounted || !shouldContinue) return;

    // 停止主播放
    widget.onStopMainPlayer?.call();

    final timing = timings[index];
    final generation = ++_sgPlaybackGeneration;
    final rangePlayback = widget.senseGroupRangePlayback;
    final audioItemId = widget.audioItemId;

    setState(() {
      _playingSenseGroupIndex = index;
      _playedSenseGroupIndices.add(index);
    });

    if (rangePlayback != null && audioItemId != null) {
      await rangePlayback.play(audioItemId, timing.start, timing.end);
    } else {
      final engine = ref.read(audioEngineProvider.notifier);
      final sessionId = engine.newSession();
      await engine.playRangeOnce(timing.start, timing.end, sessionId);
    }

    if (mounted && _sgPlaybackGeneration == generation) {
      setState(() => _playingSenseGroupIndex = null);
    }
  }

  /// 确保用户已知晓上传字幕生成的意群时间只是推测值。
  ///
  /// AI 转录字幕自带词级时间戳；本地上传字幕的词级时间戳由字幕片段按词长
  /// 推算，意群播放边界可能不准，因此首次播放前展示一次阻塞提示。
  Future<bool> _ensureSyntheticTimingNoticeAcknowledged() async {
    final audioItemId = widget.audioItemId;
    if (audioItemId == null) return true;
    if (_isShowingSyntheticTimingNotice) return false;

    final noticeStore = SenseGroupTimingNoticeStore(
      ref.read(sharedPreferencesProvider),
    );
    if (noticeStore.hasSeenSyntheticTimingNotice) return true;

    final audioItem = await ref.read(audioItemDaoProvider).getById(audioItemId);
    if (!mounted || widget.audioItemId != audioItemId) return false;
    // 本地上传与设备离线转录的词级时间戳都是合成近似值，均需提示；AI 转录自带
    // 真实词级时间戳，无需提示。
    final source = audioItem?.transcriptSource;
    if (source != app_model.TranscriptSource.local.index &&
        source != app_model.TranscriptSource.device.index) {
      return true;
    }

    try {
      _isShowingSyntheticTimingNotice = true;
      final l10n = AppLocalizations.of(context);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            l10n?.senseGroupSyntheticTimingNoticeTitle ??
                'Timing may be inaccurate',
          ),
          content: Text(
            l10n?.senseGroupSyntheticTimingNoticeMessage ??
                'This sense group playback timing is estimated from your uploaded subtitles and may be inaccurate.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n?.guideDone ?? 'Got it'),
            ),
          ],
        ),
      );
    } finally {
      _isShowingSyntheticTimingNotice = false;
    }
    if (!mounted) return false;
    await noticeStore.markSyntheticTimingNoticeSeen();
    return true;
  }

  /// 停止意群播放
  void _stopSenseGroupPlayback() {
    _sgPlaybackGeneration++;
    unawaited(widget.senseGroupRangePlayback?.cancel());
    if (_playingSenseGroupIndex != null) {
      setState(() => _playingSenseGroupIndex = null);
    }
  }

  /// 将区间播放取消安排到当前 widget 生命周期之后。
  ///
  /// 媒体实现取消时会暂停 [MediaEngine] 并更新其 Riverpod 状态；在
  /// `dispose` / `didUpdateWidget` 同步调用会违反构建期状态变更约束。
  /// generation 已先失效，因此延后一轮事件循环不会让旧意群重新生效。
  void _deferSenseGroupPlaybackCancellation() {
    final rangePlayback = widget.senseGroupRangePlayback;
    if (rangePlayback == null) return;
    scheduleMicrotask(() {
      unawaited(rangePlayback.cancel());
    });
  }

  /// 显示意群快捷菜单
  void _showActionBar(int index, Rect badgeRect) {
    _dismissActionBar();

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
            final l10n = AppLocalizations.of(context)!;
            final askAiEnabled = shouldShowAiChatAssistantEntry(
              chatbotEnabled: kChatbotEnabled,
              remoteEnabled: ref.read(
                remoteFeatureEnabledProvider(RemoteFeature.aiChatAssistant),
              ),
            );
            final actions = <SelectionToolbarAction>[
              SelectionToolbarAction(
                label: l10n.chatCopy,
                onPressed: () {
                  unawaited(
                    Clipboard.setData(ClipboardData(text: chunk.trim())),
                  );
                  _dismissActionBar();
                },
              ),
              SelectionToolbarAction(
                label: isSaved
                    ? l10n.favoritesUnsaveVocabulary
                    : l10n.favoritesSaveVocabulary,
                onPressed: () {
                  unawaited(
                    _toggleSaveSenseGroup(index, chunk, normalized, isSaved),
                  );
                },
              ),
              SelectionToolbarAction(
                label: l10n.annotationBtnAnalysis,
                onPressed: () => _lookupSenseGroup(chunk),
              ),
              if (askAiEnabled)
                SelectionToolbarAction(
                  label: l10n.chatFollowUp,
                  onPressed: () => _askAiAboutSenseGroup(chunk),
                ),
            ];

            return Positioned.fill(
              child: Builder(
                builder: (barContext) {
                  final renderObject = barContext.findRenderObject();
                  final topCenter = badgeRect.topCenter;
                  final bottomCenter = badgeRect.bottomCenter;
                  final anchors = renderObject is RenderBox
                      ? TextSelectionToolbarAnchors(
                          primaryAnchor: renderObject.globalToLocal(topCenter),
                          secondaryAnchor: renderObject.globalToLocal(
                            bottomCenter,
                          ),
                        )
                      : TextSelectionToolbarAnchors(
                          primaryAnchor: topCenter,
                          secondaryAnchor: bottomCenter,
                        );
                  return SenseGroupActionBar(
                    anchors: anchors,
                    actions: actions,
                  );
                },
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_actionBarOverlay!);
  }

  /// 关闭意群快捷菜单
  void _dismissActionBar() {
    _actionBarOverlay?.remove();
    _actionBarOverlay = null;
  }

  void _setSenseGroupLookupLocked(bool locked) {
    if (_senseGroupLookupLocked == locked) return;
    _senseGroupLookupLocked = locked;
    _actionBarOverlay?.markNeedsBuild();
  }

  void _detachSenseGroupLookupLock({required bool unlock}) {
    final host = _lookupLockHost;
    final listener = _lookupLockListener;
    if (host != null && listener != null) {
      host.removeOpenStateListener(listener);
    }
    _lookupLockHost = null;
    _lookupLockListener = null;
    if (unlock) _setSenseGroupLookupLocked(false);
  }

  void _lockSenseGroupLookupUntilDictionaryClosed(
    DictionaryPanelHostState host,
  ) {
    _detachSenseGroupLookupLock(unlock: false);
    _setSenseGroupLookupLocked(true);

    void listener() {
      if (!host.isOpen) {
        _detachSenseGroupLookupLock(unlock: true);
      }
    }

    _lookupLockHost = host;
    _lookupLockListener = listener;
    host.addOpenStateListener(listener);
  }

  /// 用当前意群文本打开 AI 查词面板。
  ///
  /// 查词面板打开后，意群快捷条立即关闭，避免两个浮层同时遮挡内容。
  void _lookupSenseGroup(String chunk) {
    if (_senseGroupLookupLocked) return;
    final queryText = chunk.trim();
    if (queryText.isEmpty) return;
    _dismissActionBar();
    widget.onToolbarButtonTapped?.call();
    final host = DictionaryPanelHost.of(context);
    host.show(
      DictionaryPanelQuery(
        word: queryText,
        preferredSourceId: AiDictionarySource.sourceId,
        bookmarkKind: DictionaryBookmarkKind.senseGroup,
        audioItemId: widget.audioItemId,
        sentenceIndex: _sentenceIndex,
        sentenceText: _text,
        sentenceStartMs: _sentenceStartMs,
        sentenceEndMs: _sentenceEndMs,
      ),
      owner: this,
    );
    _lockSenseGroupLookupUntilDictionaryClosed(host);
  }

  /// 关闭操作条后打开句子级 AI 助教，并引用当前意群。
  void _askAiAboutSenseGroup(String chunk) {
    final quote = chunk.trim();
    if (quote.isEmpty) return;
    _dismissActionBar();
    unawaited(
      showSentenceChatbotSheet(
        context: context,
        sentenceText: _text,
        initialQuote: quote,
      ),
    );
  }

  /// 收藏或取消收藏当前意群。
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
      // 收藏意群必须绑定父音频；没有来源时保持未收藏，避免向必填参数传入 null。
      final audioItemId = widget.audioItemId;
      if (audioItemId == null) return;
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
        audioItemId: audioItemId,
        sentenceIndex: _sentenceIndex,
        sentenceText: _text,
        sentenceStartMs: _sentenceStartMs,
        sentenceEndMs: _sentenceEndMs,
        groupStartMs: groupStartMs,
        groupEndMs: groupEndMs,
      );
    }
    // 意群收藏状态回流后原地更新操作栏，并与解析面板共享同一真值。
  }

  /// 重置意群数据
  void _resetSenseGroups() {
    // 中断进行中的意群流并完成挂起的就绪信号（避免旧 card 的 await 悬挂）
    _sgSub?.cancel();
    _sgSub = null;
    _sgCancel?.cancel();
    _sgCancel = null;
    if (_sgMediumReady?.isCompleted == false) _sgMediumReady!.complete();
    if (_sgAllDone?.isCompleted == false) _sgAllDone!.complete();
    _sgMediumReady = null;
    _sgAllDone = null;
    _senseGroupResult = null;
    _senseGroupTimings = null;
    _activeChunks = null;
    _playingSenseGroupIndex = null;
    _playedSenseGroupIndices.clear();
    _sgPlaybackGeneration++;
    _deferSenseGroupPlaybackCancellation();
    widget.onTimingsChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final timestampAudioItemId = widget.audioItemId;
    // 讲解页无论高亮开关状态都需要意群计时；正文高亮组件监听同一 provider，
    // 因此两处共享一次时间戳加载。
    final wordTimestamps = timestampAudioItemId == null
        ? null
        : ref.watch(wordTimestampsProvider(timestampAudioItemId)).valueOrNull;

    // 调用方可以显式注入测试或会话级 notifier；统一页面入口未注入时，
    // 必须回退到 Provider，避免工具栏请求回调为空而整组 AI 按钮被禁用。
    final ai = widget.aiNotifier ?? ref.read(sentenceAiNotifierProvider);
    final nativeLanguage = ref.watch(
      appSettingsProvider.select((s) => s.nativeLanguage),
    );
    final learningSettings = ref.watch(learningSettingsProvider);
    final autoShowAiExplanation =
        widget.autoShowAiExplanation ?? learningSettings.autoShowAiExplanation;
    final autoShowAiAnalysis =
        autoShowAiExplanation &&
        (widget.autoShowAiAnalysis ?? learningSettings.autoShowAiAnalysis);
    final autoShowAiTranslation =
        autoShowAiExplanation &&
        (widget.autoShowAiTranslation ??
            learningSettings.autoShowAiTranslation);
    final autoShowAiSenseGroups =
        autoShowAiExplanation &&
        (widget.autoShowAiSenseGroups ??
            learningSettings.autoShowAiSenseGroups);
    // watch 共享字幕投影：撑起其 autoDispose 生命周期（视图在屏则常驻）+ 同步取前后句。
    // 翻译缓存 key 包含前后句，必须等字幕投影就绪后才允许自动翻译；
    // 否则首帧会用 null/null 写入无上下文 key，返回页面时再用带上下文 key 读取就会 miss。
    final audioItemId = widget.audioItemId;
    final hasSentenceContextSource =
        audioItemId != null && audioItemId.isNotEmpty && _sentenceIndex != null;
    final sentencesAsync = (audioItemId != null && audioItemId.isNotEmpty)
        ? ref.watch(audioSentencesProvider(audioItemId))
        : null;
    final translationContextReady =
        !hasSentenceContextSource || (sentencesAsync?.hasValue ?? false);
    final sentences = translationContextReady
        ? sentencesAsync?.valueOrNull
        : null;
    final (previousText, nextText) = translationContextReady
        ? _neighborTexts(sentences)
        : (null, null);

    Future<(String?, String?)> resolveTranslationContext() async {
      if (!hasSentenceContextSource) return (null, null);
      final loadedSentences =
          sentencesAsync?.valueOrNull ??
          await ref.read(audioSentencesProvider(audioItemId).future);
      return _neighborTexts(loadedSentences);
    }

    final cachedTranslation = autoShowAiTranslation
        ? ai
              ?.getCachedTranslation(
                _text,
                previous: previousText,
                next: nextText,
                targetLanguage: nativeLanguage,
              )
              ?.translation
        : null;
    final cachedAnalysis = autoShowAiAnalysis
        ? ai?.getCachedAnalysis(_text, targetLanguage: nativeLanguage)
        : null;
    final accessToken = ref
        .watch(supabaseSessionProvider)
        .valueOrNull
        ?.accessToken;
    // 讲解视图自包含：是否自动请求只由认证状态和用户 AI 设置决定，
    // 宿主无需额外传入“启用自动加载”的开关。
    final shouldAutoLoadSentenceAi =
        accessToken != null && accessToken.isNotEmpty;
    final willStartAutoLoad =
        shouldAutoLoadSentenceAi &&
        (autoShowAiAnalysis ||
            autoShowAiSenseGroups ||
            (autoShowAiTranslation && translationContextReady));
    _logAutoLoadDecision(
      hasAccessToken: accessToken != null && accessToken.isNotEmpty,
      autoShowAiTranslation: autoShowAiTranslation,
      autoShowAiAnalysis: autoShowAiAnalysis,
      autoShowAiSenseGroups: autoShowAiSenseGroups,
      translationContextReady: translationContextReady,
      willLoad: willStartAutoLoad,
    );

    // 局部 watch 已收藏意群文本集合，避免全局重建
    final savedTextsAsync = ref.watch(savedSenseGroupTextsProvider);
    final savedTexts = savedTextsAsync.valueOrNull ?? {};

    final l10n = AppLocalizations.of(context)!;
    // 引导关闭时（PageView 离屏页）四个 step 一律为 null：SentenceAnnotationCard 的
    // _wrapGuide 见 null 即不包 Showcase，离屏页不会向 showcaseview 注册，规避回收崩溃。
    // 总开关关闭时不创建 Showcase 目标，避免分页回收后第三方注册回调访问已卸载状态。
    final enableGuide = widget.enableGuide && ref.watch(guideEnabledProvider);
    final sentenceStep = enableGuide
        ? GuideStep(
            key: _guideSentenceKey,
            description: l10n.guideSentenceAnnotationSentenceDescription,
          )
        : null;
    final senseGroupStep = enableGuide
        ? GuideStep(
            key: _guideSenseGroupKey,
            description: l10n.guideSentenceAnnotationSenseGroupDescription,
          )
        : null;
    final analysisStep = enableGuide
        ? GuideStep(
            key: _guideAnalysisKey,
            description: l10n.guideSentenceAnnotationAnalysisDescription,
          )
        : null;
    final guideFlows = enableGuide
        ? <GuideFlow>[
            GuideFlow(
              flowId: GuideFlowIds.sentenceAnnotationTour,
              shouldRun: true,
              // 句子 → 意群 → 解析
              steps: [sentenceStep!, senseGroupStep!, analysisStep!],
            ),
          ]
        : const <GuideFlow>[];

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
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _dismissActionBar(),
          child: _TranscriptVisibilityMask(
            showTranscript: widget.showTranscript,
            child: _AnnotationContentLayout(
              scrollController: _scrollController,
              toolbar: Padding(
                // 紧凑工具栏与相邻信息/正文统一保留 6dp，正文自己的顶部留白
                // 继续负责维持首行文本的可读起点。
                padding: EdgeInsets.only(
                  left: widget.contentHorizontalPadding,
                  top: 6,
                  right: widget.contentHorizontalPadding,
                  bottom: 6,
                ),
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
              content: SentenceAnnotationCard(
                key: _cardKey,
                text: _text,
                wordHighlightBinding: _wordHighlightBinding,
                contentHorizontalPadding: widget.contentHorizontalPadding,
                showToolbar: false,
                onToolbarStateChanged: _toolbarNotifier.notify,
                onRequestTranslation: ai != null
                    ? (cancelToken, source) async* {
                        var hasContent = false;
                        try {
                          final (requestPreviousText, requestNextText) =
                              await resolveTranslationContext();
                          // await for（非 yield*）确保流内 auth/quota 错误在本
                          // try 内重抛，从而弹登录/订阅（与 onRequestAnalysis 语义一致）。
                          await for (final t in ai.getTranslationStream(
                            _text,
                            previous: requestPreviousText,
                            next: requestNextText,
                            targetLanguage: nativeLanguage,
                            accessToken: accessToken,
                            cancelToken: cancelToken,
                            respectLocalQuotaReset:
                                source == SentenceAiRequestSource.automatic,
                          )) {
                            if (t.translation.isNotEmpty) {
                              hasContent = true;
                            }
                            yield t.translation;
                          }
                          if (hasContent) {
                            ref
                                .read(usageTrackerProvider)
                                .record(UsageEvent.translationSucceeded);
                          }
                        } on AiFeatureAuthRequiredException {
                          if (mounted) {
                            unawaited(_showAiFeatureSignInDialog());
                          }
                          rethrow;
                        } on AiFeatureQuotaExceededException catch (e) {
                          if (mounted) {
                            unawaited(
                              _showAiQuotaExceededDialog(
                                e,
                                force:
                                    source == SentenceAiRequestSource.userTap,
                              ),
                            );
                          }
                          rethrow;
                        }
                      }
                    : null,
                onRequestAnalysis: ai != null
                    ? (cancelToken, source) async* {
                        var hasContent = false;
                        try {
                          // await for 确保流内 auth/quota 错误进入本层 catch，
                          // 从而触发登录或订阅导航，并由卡片恢复按钮状态。
                          await for (final analysis in ai.getAnalysisStream(
                            _text,
                            targetLanguage: nativeLanguage,
                            accessToken: accessToken,
                            cancelToken: cancelToken,
                            respectLocalQuotaReset:
                                source == SentenceAiRequestSource.automatic,
                          )) {
                            if (analysis.isNotEmpty) {
                              hasContent = true;
                            }
                            yield analysis;
                          }
                          if (hasContent) {
                            ref
                                .read(usageTrackerProvider)
                                .record(UsageEvent.analysisSucceeded);
                          }
                        } on AiFeatureAuthRequiredException {
                          if (mounted) {
                            unawaited(_showAiFeatureSignInDialog());
                          }
                          rethrow;
                        } on AiFeatureQuotaExceededException catch (e) {
                          if (mounted) {
                            unawaited(
                              _showAiQuotaExceededDialog(
                                e,
                                force:
                                    source == SentenceAiRequestSource.userTap,
                              ),
                            );
                          }
                          rethrow;
                        }
                      }
                    : null,
                cachedTranslation: cachedTranslation,
                cachedAnalysis: cachedAnalysis,
                autoLoadTranslation:
                    shouldAutoLoadSentenceAi &&
                    autoShowAiTranslation &&
                    translationContextReady,
                autoLoadAnalysis:
                    shouldAutoLoadSentenceAi && autoShowAiAnalysis,
                onTranslationUserIntent: () {
                  ref
                      .read(usageTrackerProvider)
                      .record(UsageEvent.translationTapped);
                },
                onAnalysisUserIntent: () {
                  ref
                      .read(usageTrackerProvider)
                      .record(UsageEvent.analysisTapped);
                },
                audioItemId: widget.audioItemId,
                sentenceIndex: _sentenceIndex,
                sentenceStartMs: _sentenceStartMs,
                sentenceEndMs: _sentenceEndMs,
                senseGroupResult: _senseGroupResult,
                senseGroupTimings: _senseGroupTimings,
                onSenseGroupModeChanged: _handleModeChanged,
                playingSenseGroupIndex: _playingSenseGroupIndex,
                playedSenseGroupIndices: _playedSenseGroupIndices,
                onTapSenseGroup: _handleTapSenseGroup,
                onRequestSenseGroups: _requestSenseGroups,
                autoLoadSenseGroups:
                    shouldAutoLoadSentenceAi && autoShowAiSenseGroups,
                onAwaitSenseGroupFine: _awaitSenseGroupFine,
                hasWordTimestamps: wordTimestamps != null,
                highlightedSegments: widget.highlightedSegments,
                savedGroupTexts: savedTexts,
                onTapGroupWithRect: _showActionBar,
                onToolbarButtonTapped: widget.onToolbarButtonTapped,
                sentenceGuideStep: sentenceStep,
                senseGroupGuideStep: senseGroupStep,
                analysisGuideStep: analysisStep,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 记录当前可见讲解句的自动加载判定，便于区分认证、设置与上下文阻断。
  void _logAutoLoadDecision({
    required bool hasAccessToken,
    required bool autoShowAiTranslation,
    required bool autoShowAiAnalysis,
    required bool autoShowAiSenseGroups,
    required bool translationContextReady,
    required bool willLoad,
  }) {
    final reason = !hasAccessToken
        ? 'missingAuth'
        : !autoShowAiTranslation &&
              !autoShowAiAnalysis &&
              !autoShowAiSenseGroups
        ? 'allSettingsDisabled'
        : !translationContextReady
        ? 'translationContextPending'
        : 'triggered';
    final key = [
      widget.audioItemId,
      _sentenceIndex,
      _diagnosticSource,
      _diagnosticFlowPhase,
      hasAccessToken,
      autoShowAiTranslation,
      autoShowAiAnalysis,
      autoShowAiSenseGroups,
      translationContextReady,
    ].join('|');
    if (_autoLoadDiagnosticKey == key) return;
    _autoLoadDiagnosticKey = key;
    AppLogger.log(
      'SentenceAnnotation',
      '自动预加载判定: source=${_diagnosticSource ?? 'unknown'} '
          'sentence=${_sentenceIndex ?? -1} '
          'phase=${_diagnosticFlowPhase ?? 'none'} '
          'auth=$hasAccessToken translation=$autoShowAiTranslation '
          'analysis=$autoShowAiAnalysis senseGroups=$autoShowAiSenseGroups '
          'contextReady=$translationContextReady load=$willLoad reason=$reason',
    );
  }
}

/// 讲解工具栏与正文属于同一个滚动容器，保证所有讲解内容同步滚动。
class _AnnotationContentLayout extends StatelessWidget {
  const _AnnotationContentLayout({
    required this.scrollController,
    required this.toolbar,
    required this.content,
  });

  final ScrollController scrollController;
  final Widget toolbar;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [toolbar, content],
      ),
    );
  }
}

class _TranscriptVisibilityMask extends StatelessWidget {
  const _TranscriptVisibilityMask({
    required this.showTranscript,
    required this.child,
  });

  final bool showTranscript;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (showTranscript) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 简单的重建通知器，用于卡片状态变化时触发工具栏重建
class RebuildNotifier extends ChangeNotifier {
  /// 通知所有监听者重建
  void notify() => notifyListeners();
}
