/// 标注模式内容视图（共享组件）
///
/// 将工具栏固定在顶部不随内容滚动，句子文本和翻译/解析在下方可滚动区域。
/// 内部管理意群全部逻辑：词级时间戳加载、AI 拆分请求、时间范围计算、播放。
///
/// 用于精听、难句补练、难句跟读和收藏复习页面。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/sign_in_required_dialog.dart';
import '../../features/subscription/widgets/feature_gate.dart';
import '../../features/subscription/providers/ai_quota_limit_provider.dart';
import '../../features/subscription/providers/subscription_identity.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart' as app_model;
import '../../models/sense_group_result.dart';
import '../../models/sentence.dart';
import '../../models/speech_practice_models.dart';
import '../../models/word_timestamp.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/audio_sentences_provider.dart';
import '../../providers/learning_settings_provider.dart';
import '../../providers/sentence_ai_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/saved_sense_group_provider.dart';
import '../../services/app_logger.dart';
import '../../services/dictionary/ai_dictionary_source.dart';
import '../../services/transcription_api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/sense_group_service.dart';
import '../../utils/sense_group_timing_notice_store.dart';
import '../../utils/sense_group_timing.dart';
import '../dictionary/dictionary_panel_host.dart';
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

  /// 是否启用新手引导（句子→意群→翻译→解析 showcase）。
  ///
  /// 默认 true。Free Player 单句模式用 PageView 预建相邻页时，必须仅对**当前页**
  /// 置 true：showcaseview 的 [Showcase] 一挂载即向全局注册，离屏页随 PageView
  /// 回收销毁时其注册回调会落在已 unmount 的 State 上而崩溃。
  final bool enableGuide;

  /// 是否在进入视图时自动加载句子翻译和解析。
  ///
  /// 仅讲解详情页启用；未登录时不会自动触发，避免冷启动直接弹登录。
  final bool autoLoadSentenceAi;

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
    this.enableGuide = true,
    this.autoLoadSentenceAi = false,
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
  Timer? _actionBarTimer;

  /// 缓存预加载 generation counter（防竞态）
  int _preloadGeneration = 0;

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
    _fetchWordTimestamps();
    _preloadCache();
  }

  @override
  void dispose() {
    _sgSub?.cancel();
    _sgCancel?.cancel();
    _detachSenseGroupLookupLock(unlock: false);
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
      accessToken: ref.read(supabaseSessionProvider).valueOrNull?.accessToken,
    );
    if (mounted && widget.audioItemId == audioItemId) {
      setState(() => _wordTimestamps = words);
    }
  }

  /// 从共享字幕投影取当前句的前/后句文本（做翻译上下文）。
  ///
  /// 无来源音频 / 无句索引 / 越界（首、末句）均返回 null。仅取不可变的
  /// [Sentence.text]，前后句上下文进翻译缓存键（见 `getTranslationStream`）。
  (String?, String?) _neighborTexts(List<Sentence>? sentences) {
    final idx = widget.sentenceIndex;
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
    final ai = widget.aiNotifier;
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
      widget.text,
      targetLanguage: nativeLanguage,
      previous: previousText,
      next: nextText,
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

  /// 请求 AI 拆分意群（流式，作为 onRequestSenseGroups 传给 card）
  ///
  /// 返回的 Future 在 **medium 就绪**（medium 流完）时 settle——供拆意群按钮尽早释放、
  /// 让用户可交互 medium；fine 在后台继续流入 `_senseGroupResult`，medium→fine 切换由
  /// [_awaitSenseGroupFine] 协调加载态。逐帧 setState 使 chunk 随 prop 变化自上而下渐显。
  Future<void> _requestSenseGroups() async {
    // 已有活跃流：复用其 medium 就绪信号（去重，避免重复起流）
    final activeReady = _sgMediumReady;
    if (activeReady != null && _sgSub != null) {
      return activeReady.future;
    }

    final startMs = widget.sentenceStartMs ?? 0;
    final endMs = widget.sentenceEndMs ?? 0;
    final ai = widget.aiNotifier;
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
          text: widget.text,
          ai: ai,
          accessToken: accessToken,
          sentenceStartMs: startMs,
          sentenceEndMs: endMs,
          wordTimestamps: _wordTimestamps,
          cancelToken: cancel,
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
              unawaited(_showAiQuotaExceededDialog(e, force: true));
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
    await ensureSignedInForAction(
      context: context,
      ref: ref,
      title:
          l10n?.senseGroupSignInRequiredTitle ??
          'Sign in to use sense group splitting',
      message:
          l10n?.senseGroupSignInRequiredMessage ??
          'AI translation, analysis, and sense group splitting use the cloud AI service. Sign in to generate new results. Cached results remain available.',
    );
  }

  /// 已登录但未解锁 AI 功能时引导订阅升级（登录优先逻辑见 openPaywall）。
  Future<void> _showAiQuotaExceededDialog(
    AiFeatureQuotaExceededException error, {
    bool force = false,
  }) async {
    if (_isShowingAiQuotaDialog || !mounted) return;
    final feature = error.feature;
    final userId = ref.read(subscriptionIdentityProvider).userId;
    final store = ref.read(aiQuotaLimitStoreProvider);
    if (userId != null &&
        feature != null &&
        !force &&
        !store.shouldShowReminder(userId, feature)) {
      return;
    }

    _isShowingAiQuotaDialog = true;
    try {
      final l10n = AppLocalizations.of(context)!;
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.aiQuotaExceededTitle),
          content: Text(l10n.aiQuotaExceededMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('dismiss'),
              child: Text(l10n.aiQuotaExceededDismiss),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('subscribe'),
              child: Text(l10n.aiQuotaExceededSubscribe),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (userId != null && feature != null) {
        await store.markReminderShown(userId, feature);
      }
      if (result == 'subscribe' && mounted) {
        await openPaywall(context, ref);
      }
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

    final shouldContinue = await _ensureSyntheticTimingNoticeAcknowledged();
    if (!mounted || !shouldContinue) return;

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
    if (_playingSenseGroupIndex != null) {
      _sgPlaybackSession = null;
      setState(() => _playingSenseGroupIndex = null);
    }
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

            return Positioned(
              left: badgeRect.left + badgeRect.width / 2 - 35,
              top: badgeRect.top - 46,
              child: TapRegion(
                onTapOutside: (_) => _dismissActionBar(),
                child: SenseGroupActionBar(
                  isSaved: isSaved,
                  onToggleSave: () =>
                      _toggleSaveSenseGroup(index, chunk, normalized, isSaved),
                  onLookup: () => _lookupSenseGroup(chunk),
                  lookupEnabled: !_senseGroupLookupLocked,
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
  /// 这里不关闭快捷条：保留既有 5 秒自然消失，用户查词后仍可继续收藏当前意群。
  void _lookupSenseGroup(String chunk) {
    if (_senseGroupLookupLocked) return;
    final queryText = chunk.trim();
    if (queryText.isEmpty) return;
    widget.onToolbarButtonTapped?.call();
    final host = DictionaryPanelHost.of(context);
    host.show(
      DictionaryPanelQuery(
        word: queryText,
        preferredSourceId: AiDictionarySource.sourceId,
        audioItemId: widget.audioItemId,
        sentenceIndex: widget.sentenceIndex,
        sentenceText: widget.text,
        sentenceStartMs: widget.sentenceStartMs,
        sentenceEndMs: widget.sentenceEndMs,
      ),
      owner: this,
    );
    _lockSenseGroupLookupUntilDictionaryClosed(host);
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
    // watch 共享字幕投影：撑起其 autoDispose 生命周期（视图在屏则常驻）+ 同步取前后句。
    final audioItemId = widget.audioItemId;
    final sentences = (audioItemId != null && audioItemId.isNotEmpty)
        ? ref.watch(audioSentencesProvider(audioItemId)).valueOrNull
        : null;
    final (previousText, nextText) = _neighborTexts(sentences);
    final cachedTranslation = autoExpand
        ? ai
              ?.getCachedTranslation(
                widget.text,
                previous: previousText,
                next: nextText,
                targetLanguage: nativeLanguage,
              )
              ?.translation
        : null;
    final cachedAnalysis = autoExpand
        ? ai?.getCachedAnalysis(widget.text, targetLanguage: nativeLanguage)
        : null;
    final accessToken = ref
        .watch(supabaseSessionProvider)
        .valueOrNull
        ?.accessToken;
    final shouldAutoLoadSentenceAi =
        widget.autoLoadSentenceAi &&
        accessToken != null &&
        accessToken.isNotEmpty;

    // 局部 watch 已收藏意群文本集合，避免全局重建
    final savedTextsAsync = ref.watch(savedSenseGroupTextsProvider);
    final savedTexts = savedTextsAsync.valueOrNull ?? {};

    final l10n = AppLocalizations.of(context)!;
    // 引导关闭时（PageView 离屏页）四个 step 一律为 null：SentenceAnnotationCard 的
    // _wrapGuide 见 null 即不包 Showcase，离屏页不会向 showcaseview 注册，规避回收崩溃。
    final enableGuide = widget.enableGuide;
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
    final translationStep = enableGuide
        ? GuideStep(
            key: _guideTranslationKey,
            description: l10n.guideSentenceAnnotationTranslationDescription,
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
              // 句子 → 意群 → 翻译 → 解析
              steps: [
                sentenceStep!,
                senseGroupStep!,
                translationStep!,
                analysisStep!,
              ],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 固定工具栏（监听 notifier 刷新）。
            // 下方间距缩小：句子已自带 12dp 上留白（给选区手柄圆点让位，
            // 见 SentenceAnnotationCard），二者合计维持原 16dp 视觉间距。
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
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
                      ? (cancelToken, source) async* {
                          var hasContent = false;
                          try {
                            // await for（非 yield*）确保流内 auth/quota 错误在本
                            // try 内重抛，从而弹登录/订阅（与 onRequestAnalysis 语义一致）。
                            await for (final t in ai.getTranslationStream(
                              widget.text,
                              previous: previousText,
                              next: nextText,
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
                              widget.text,
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
                  autoLoadTranslation: shouldAutoLoadSentenceAi,
                  autoLoadAnalysis: shouldAutoLoadSentenceAi,
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
                  onAwaitSenseGroupFine: _awaitSenseGroupFine,
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
