/// 词典查询面板（非 modal 常驻底部面板的内容体）
///
/// 由 [DictionaryPanelHost] 内嵌渲染。右上角下拉切换数据源
/// （本地 / AI / Cambridge），内容区按选中源渲染对应结果，
/// 标题行的单词、发音、收藏、关闭跨源恒定。
/// 本组件是「组装器」：查词逻辑在 [DictionaryLookupController]，
/// 各源渲染在 dictionary/ 视图组件，本文件只负责布局与回调分发。
///
/// 切词：宿主 show() 新查询时经 [didUpdateWidget] 原地切换（重建查词
/// controller 订阅、预热新词 TTS），不重播面板入场动画。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/sign_in_required_dialog.dart';
import '../../features/subscription/widgets/feature_gate.dart';
import '../../models/dictionary/dict_speakable_texts.dart';
import '../../models/pronunciation/pronunciation_clip.dart';
import '../../providers/dictionary/dictionary_registry.dart';
import '../../providers/dictionary/dictionary_settings_provider.dart';
import '../../providers/dictionary/lookup_controller.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/reading_text_prefs_provider.dart';
import '../../providers/pronunciation/pronunciation_providers.dart';
import '../../providers/saved_word_provider.dart';
import '../../providers/saved_sense_group_provider.dart';
import '../../providers/tts/tts_controller_provider.dart';
import '../../services/dictionary/ai_dictionary_source.dart';
import '../../services/dictionary/web_dictionary_source.dart';
import '../../utils/text_normalize.dart';
import '../tts/speak_button.dart';
import '../../theme/app_theme.dart';
import '../animated_bookmark_icon.dart';
import '../common/text_context_menu.dart';
import 'dictionary_panel_host.dart';
import 'dictionary_result_view.dart';
import 'reading_text_scale.dart';
import 'pronunciation_controls.dart';
import 'source_switcher.dart';
import '../common/prewarm_visibility.dart';

/// 词典面板内容
class DictionaryPanel extends ConsumerStatefulWidget {
  /// 当前查询（查询文本 + 收藏来源信息）
  final DictionaryPanelQuery query;

  /// 关闭回调（下拉超阈值 / 关闭按钮触发；由宿主移除面板）
  final VoidCallback onClose;

  /// 面板入场动画（宿主传入）。滑入期间内容区不套过渡动画，
  /// 避免缓存命中结果到达时高度动画与滑入叠加产生闪烁。
  final Animation<double>? entryAnimation;

  const DictionaryPanel({
    super.key,
    required this.query,
    required this.onClose,
    this.entryAnimation,
  });

  @override
  ConsumerState<DictionaryPanel> createState() => _DictionaryPanelState();
}

class _DictionaryPanelState extends ConsumerState<DictionaryPanel> {
  /// 面板滑入动画是否已结束。
  ///
  /// 滑入期间内容区不套 AnimatedSize/AnimatedSwitcher——否则缓存命中（L2）的
  /// 结果在滑入途中到达时，内容区高度增长动画会与滑入叠加，视觉上「闪烁一下」。
  /// 滑入期间内容直接定型（被滑入运动掩盖），滑入结束后才启用切换源的平滑过渡。
  bool _entered = false;

  /// 统一 TTS 控制器（build 时缓存，供 [dispose] 取消词典预热——
  /// `ConsumerState.dispose` 内不可用 `ref`，见 CLAUDE.md §7.14）。
  TtsController? _ttsController;

  /// 本地发音控制器缓存，供 dispose 阶段停止短音频。
  TextPlaybackController? _textPlaybackController;

  /// 当前共享播放器的播放 key；关闭面板时据此避免误停宿主页音频。
  String? _activeTtsKey;
  String? _activeTextPlaybackKey;

  /// 本面板可能发起朗读的单词与例句 key。
  final Set<String> _dictionaryPlaybackKeys = {};

  /// 当前单词及其离线发音命中状态的预热签名，避免 build 重复调度。
  String? _headwordPrewarmSignature;
  bool _isPrewarmVisible = false;
  int _prewarmVisibilityEpoch = 0;
  List<String> _lastDictionaryPrewarmTexts = const [];

  /// 自动发音查询代际，防止切词时旧的 post-frame 回调继续播放。
  int _autoSpeakEpoch = 0;
  String? _lastAutoSpokenWord;
  bool _autoSpeakInFlight = false;

  /// 可拉伸源面板的当前高度（像素）。默认 3/5 屏高（真机反馈：1/2 偏低、
  /// 2/3 偏高），
  /// 用户上拉拖拽指示条可放大、下拉可缩小（夹在 [_minSheetHeight] 与
  /// [_maxSheetHeight] 之间）。文本本地源不用此值（按内容自适应）。
  double? _sheetHeight;

  /// 会话粘滞源 notifier（build 时缓存，供 [dispose] 清除——
  /// `ConsumerState.dispose` 内不可用 `ref`，见 CLAUDE.md §7.14）。
  DictionarySessionSource? _sessionSource;

  /// 当前词典宿主，关闭开始时立即取消本面板发起的播放。
  DictionaryPanelHostState? _panelHost;

  /// 拖拽过程中的「逻辑高度」（仅手势期间有值，可低于 [_minSheetHeight]）。
  ///
  /// 渲染用的 [_sheetHeight] 夹在 [_minSheetHeight] 上，不会真的缩到更小（避免
  /// 内容溢出）；而本字段如实记录手指位置，低于下限的部分即「关闭意图」。
  /// 松手时若低于下限超过 [_kDismissOverdrag] 则关闭面板，实现标准底部面板的
  /// 下滑关闭手感。如此从手指真实位置计算，单步/多步拖拽结果一致。
  double? _dragLogicalHeight;

  /// 触发下滑关闭的 overdrag 阈值（像素）：低于下限再多拉这么多即关闭。
  static const double _kDismissOverdrag = 80;

  /// 面板高度下限：屏高 40%
  double get _minSheetHeight => MediaQuery.sizeOf(context).height * 0.4;

  /// 面板高度上限：屏高 95%（嵌入正文时再受宿主 Stack 约束自然封顶）
  double get _maxSheetHeight => MediaQuery.sizeOf(context).height * 0.95;

  /// 面板默认高度：屏高 3/5（1/2 偏低、2/3 偏高，真机反馈折中）
  double get _defaultSheetHeight => MediaQuery.sizeOf(context).height * 0.6;

  @override
  void initState() {
    super.initState();
    _panelHost = DictionaryPanelHost.maybeOf(context);
    _panelHost?.addOpenStateListener(_handlePanelOpenStateChanged);
    _watchEntryAnimation();
    _scheduleAutoSpeak(widget.query.word);
  }

  /// 面板开始关闭时立即停止发音，并使尚未执行的自动发音回调失效。
  void _handlePanelOpenStateChanged() {
    final host = _panelHost;
    if (host == null || host.isOpen) return;
    _autoSpeakEpoch++;
    _ttsController?.cancelTextsPrewarm();
    _stopDictionaryPlayback();
    if (_autoSpeakInFlight) {
      // 自动发音可能尚未把 speakingKey 同步回面板，不能只依赖播放状态判断。
      unawaited(_ttsController?.stop() ?? Future<void>.value());
    }
  }

  @override
  void didUpdateWidget(DictionaryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldWord = normalizeWord(oldWidget.query.word);
    if (oldWord != _normalizedWord) {
      _scheduleAutoSpeak(widget.query.word);
    }
    if (oldWord != _normalizedWord) {
      // 切词：停掉旧词的在途预热/朗读，立即预热新词。
      _ttsController?.cancelTextsPrewarm();
      _stopDictionaryPlayback();
      _dictionaryPlaybackKeys.clear();
      _headwordPrewarmSignature = null;
      _lastDictionaryPrewarmTexts = const [];
      _prewarmVisibilityEpoch++;
    }
  }

  /// 在面板完成当前帧布局后，按播放按钮的统一链路自动朗读当前查词。
  void _scheduleAutoSpeak(String queryWord) {
    final word = normalizeDictionaryQueryForPrompt(queryWord);
    final normalized = normalizeWord(word);
    if (normalized.isEmpty || _lastAutoSpokenWord == normalized) return;
    if (!ref.read(dictionarySettingsNotifierProvider).autoSpeakOnLookup) return;
    _lastAutoSpokenWord = normalized;
    final epoch = ++_autoSpeakEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_playAutoSpeak(word, epoch));
    });
  }

  /// 播放自动发音并保留请求所有权，关闭面板时可直接取消尚未同步 UI 状态的 TTS。
  Future<void> _playAutoSpeak(String word, int epoch) async {
    if (!mounted || epoch != _autoSpeakEpoch) return;
    if (!ref.read(dictionarySettingsNotifierProvider).autoSpeakOnLookup) {
      return;
    }
    _autoSpeakInFlight = true;
    try {
      await ref.read(textPlaybackProvider.notifier).speak(word, key: word);
    } finally {
      if (epoch == _autoSpeakEpoch) _autoSpeakInFlight = false;
    }
  }

  /// 面板每次重新可见都重新开始当前查询的模型和文本预热。
  void _onPrewarmVisibilityChanged(bool visible) {
    _isPrewarmVisible = visible;
    final epoch = ++_prewarmVisibilityEpoch;
    if (!visible) {
      _ttsController?.cancelTextsPrewarm();
      _headwordPrewarmSignature = null;
      _stopDictionaryPlayback();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isPrewarmVisible || epoch != _prewarmVisibilityEpoch) {
        return;
      }
      _ttsController?.warmUpCurrentEngine();
      _headwordPrewarmSignature = null;
      _scheduleHeadwordPrewarm(
        ref.read(pronunciationClipsProvider(_normalizedWord)).isNotEmpty,
        ref.read(
          ttsControllerProvider.select((state) => state.configurationVersion),
        ),
      );
      _prewarmDictionaryTexts(_lastDictionaryPrewarmTexts);
    });
  }

  /// 监听入场动画：结束时启用内容区过渡。无动画（测试直连）视为已入场。
  void _watchEntryAnimation() {
    final anim = widget.entryAnimation;
    if (anim == null || anim.status == AnimationStatus.completed) {
      _entered = true;
    } else {
      anim.addStatusListener(_onEntryAnimationStatus);
    }
  }

  /// 滑入完成后启用内容区过渡并刷新
  void _onEntryAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_entered && mounted) {
      setState(() => _entered = true);
    }
  }

  @override
  void dispose() {
    widget.entryAnimation?.removeStatusListener(_onEntryAnimationStatus);
    _panelHost?.removeOpenStateListener(_handlePanelOpenStateChanged);
    // 面板关闭即停在途预热，避免离开后继续占用 CPU 合成用不到的例句。
    _ttsController?.cancelTextsPrewarm();
    // 共享播放器也承载复习页来源句，只停止由本面板发起的朗读。
    _stopDictionaryPlayback();
    // 会话结束：清除粘滞源，下次打开面板恢复默认词典。
    // dispose 处于 widget 树 finalize 流程，禁止同步改 provider（Riverpod
    // 断言），推迟到微任务执行。
    final session = _sessionSource;
    Future.microtask(() => session?.clear());
    super.dispose();
  }

  /// 当前选中源是否为网页词典源
  ///
  /// 网页源内容为固定像素的 WebView，需要面板给出明确高度并支持上拉放大；
  /// 文本源（本地/AI）按内容自适应，不走拖拽逻辑。
  bool _isWebSource(String sourceId) =>
      ref.read(dictionarySourcesByIdProvider)[sourceId] is WebDictionarySource;

  /// 只停止 key 属于当前词典内容的播放，避免误停宿主页正在播放的句子。
  void _stopDictionaryPlayback() {
    if (_activeTtsKey case final key?
        when _dictionaryPlaybackKeys.contains(key)) {
      unawaited(_ttsController?.stop() ?? Future<void>.value());
    }
    if (_activeTextPlaybackKey case final key?
        when _dictionaryPlaybackKeys.contains(key)) {
      unawaited(_textPlaybackController?.stop() ?? Future<void>.value());
    }
  }

  /// 拖拽开始：以当前高度初始化逻辑高度。
  void _onHandleDragStart(DragStartDetails details) {
    _dragLogicalHeight = _sheetHeight ?? _defaultSheetHeight;
  }

  /// 拖拽 header 调整面板高度：上拉（delta.dy<0）放大，下拉缩小。
  /// 逻辑高度可低于下限（记录手指真实位置），渲染高度夹在下限上。
  void _onHandleDrag(DragUpdateDetails details) {
    final base = _dragLogicalHeight ?? _sheetHeight ?? _defaultSheetHeight;
    // 逻辑高度允许低于下限（下拉关闭意图），但不超过上限
    final logical = (base - details.delta.dy).clamp(0.0, _maxSheetHeight);
    _dragLogicalHeight = logical;
    setState(() {
      _sheetHeight = logical.clamp(_minSheetHeight, _maxSheetHeight).toDouble();
    });
  }

  /// 拖拽结束：逻辑高度低于下限超过阈值（下拉到底再继续拉）则关闭面板。
  void _onHandleDragEnd(DragEndDetails details) {
    final logical = _dragLogicalHeight ?? _minSheetHeight;
    _dragLogicalHeight = null;
    if (_minSheetHeight - logical > _kDismissOverdrag && mounted) {
      widget.onClose();
    }
  }

  /// 归一化后的表面词形（单词或词组），用于展示、TTS 与收藏。
  ///
  /// 这里一律小写，保持既有正文下划线、收藏 key、本地词典匹配语义不变。
  String get _normalizedWord => normalizeWord(widget.query.word);

  /// 保留大小写的查词 query，用作 controller family key 与 AI 请求输入。
  ///
  /// 展示、TTS、收藏仍使用 [_normalizedWord]，缓存/落库由 AI 源和后端再转小写。
  String get _lookupQuery =>
      normalizeDictionaryQueryForPrompt(widget.query.word);

  Future<void> _toggleSave(String surfaceWord, bool currentlySaved) async {
    // 用户层只有一个收藏状态：取消时清理两类底层记录，避免另一张表的
    // 同名记录让面板在下一次打开时重新显示为已收藏。
    if (currentlySaved) {
      await Future.wait([
        ref.read(savedWordListProvider.notifier).removeWord(surfaceWord),
        ref
            .read(savedSenseGroupListProvider.notifier)
            .removeSenseGroup(surfaceWord),
      ]);
      return;
    }
    if (widget.query.bookmarkKind == DictionaryBookmarkKind.senseGroup) {
      final audioItemId = widget.query.audioItemId;
      if (audioItemId == null) return;
      final notifier = ref.read(savedSenseGroupListProvider.notifier);
      await notifier.saveSenseGroup(
        phraseText: surfaceWord,
        displayText: _lookupQuery,
        audioItemId: audioItemId,
        sentenceIndex: widget.query.sentenceIndex,
        sentenceText: widget.query.sentenceText,
        sentenceStartMs: widget.query.sentenceStartMs,
        sentenceEndMs: widget.query.sentenceEndMs,
      );
      return;
    }
    final notifier = ref.read(savedWordListProvider.notifier);
    await notifier.saveWord(
      word: surfaceWord,
      audioItemId: widget.query.audioItemId,
      sentenceIndex: widget.query.sentenceIndex,
      sentenceText: widget.query.sentenceText,
      sentenceStartMs: widget.query.sentenceStartMs,
      sentenceEndMs: widget.query.sentenceEndMs,
    );
  }

  /// 显式登录按钮直接打开登录页；认证完成后当前查词会自动续跑。
  void _openAiSignInPage() {
    openSignInPage(context);
  }

  /// 本月免费额度用尽 → 打开订阅页；返回后重试（已订阅则放行，否则仍显示额度用尽）。
  Future<void> _handleUpgrade(String word) async {
    await openPaywall(context, ref);
    if (!mounted) return;
    ref.read(_controllerProvider(word).notifier).retry();
  }

  DictionaryLookupControllerProvider _controllerProvider(String word) =>
      dictionaryLookupControllerProvider(
        word,
        preferredSourceId: widget.query.preferredSourceId,
      );

  /// 将共享编排筛选后的词典文本提交到统一 TTS 后台队列。
  void _prewarmDictionaryTexts(List<String> texts) {
    _lastDictionaryPrewarmTexts = List.unmodifiable(texts);
    _dictionaryPlaybackKeys.addAll(texts);
    if (texts.isEmpty || !_isPrewarmVisible) return;
    _ttsController?.prewarmTextsIncremental(texts);
  }

  /// 在订阅离线发音命中结果后再调度标题预热，确保已有本地音频不进入 TTS 队列。
  void _scheduleHeadwordPrewarm(bool hasLocalClip, int configurationVersion) {
    final signature =
        '$_normalizedWord|$hasLocalClip|$configurationVersion|$_prewarmVisibilityEpoch';
    if (_headwordPrewarmSignature == signature) return;
    _headwordPrewarmSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isPrewarmVisible) return;
      if (hasLocalClip) return;
      _ttsController?.prewarmTextsIncremental([_normalizedWord]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = _normalizedWord;
    _dictionaryPlaybackKeys.add(word);
    final lookupQuery = _lookupQuery;
    final pronunciationClips = ref.watch(pronunciationClipsProvider(word));
    _dictionaryPlaybackKeys.addAll(
      pronunciationClips.map((clip) => clip.playbackKey),
    );
    final controllerProvider = _controllerProvider(lookupQuery);
    final state = ref.watch(controllerProvider);
    final ttsConfigurationVersion = ref.watch(
      ttsControllerProvider.select((state) => state.configurationVersion),
    );
    final notifier = ref.read(controllerProvider.notifier);

    // 缓存 TTS 控制器与会话粘滞源供 dispose 使用（dispose 内不可用 ref，§7.14）。
    _ttsController = ref.read(ttsControllerProvider.notifier);
    _textPlaybackController = ref.read(textPlaybackProvider.notifier);
    _activeTtsKey = ref.watch(
      ttsControllerProvider.select((state) => state.speakingKey),
    );
    _activeTextPlaybackKey = ref.watch(
      textPlaybackProvider.select((state) => state.playingKey),
    );
    _sessionSource = ref.read(dictionarySessionSourceProvider.notifier);
    final hasLocalClip = pronunciationClips.isNotEmpty;
    _scheduleHeadwordPrewarm(hasLocalClip, ttsConfigurationVersion);

    // 本地词典下载完成后，若当前选中本地源，自动重新查询
    ref.listen(dictionaryProvider, (prev, next) {
      if (next.status == DictionaryStatus.downloaded &&
          state.selectedSourceId == 'local') {
        notifier.retry();
      }
    });

    // 例句边流边预热：流式帧与完成态都取当前部分结果，增量预热「单词 + 已到达例句」，
    // 用户点击发音时命中缓存秒播。每帧传完整可发音列表，增量入口靠 seen-set 只对
    // 新出现的例句发起合成，已提交的自动跳过（不重发整份、不打断已在推进的批次）。
    ref.listen(controllerProvider, (prev, next) {
      final cur = next.current;
      final result = switch (cur) {
        LookupStreaming(:final result) => result,
        LookupLoaded(:final result) => result,
        _ => null,
      };
      if (result == null) return;
      _prewarmDictionaryTexts(
        dictionaryPrewarmTexts(
          result,
          hasLocalClip: ref
              .read(pronunciationClipsProvider(_normalizedWord))
              .isNotEmpty,
        ),
      );
    });

    final isWeb = _isWebSource(state.selectedSourceId);
    // AI 与网页源内容丰富，默认 3/5 屏高且可上拉放大；本地源内容短，按内容自适应。
    final isResizable =
        isWeb || state.selectedSourceId == AiDictionarySource.sourceId;

    // 非 modal 嵌入渲染：自带表面（顶部圆角 + 阴影），原 modal 容器不复存在。
    return PrewarmVisibility(
      onChanged: _onPrewarmVisibilityChanged,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 12,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SizedBox(
            key: const Key('dict_sheet_sizer'),
            // 可拉伸源用显式高度（默认 3/5，可拖拽指示条调整）；本地源按内容自适应。
            height: isResizable ? (_sheetHeight ?? _defaultSheetHeight) : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isWeb ? AppSpacing.m : AppSpacing.l,
                6,
                isWeb ? AppSpacing.m : AppSpacing.l,
                AppSpacing.s,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header（指示条 + 数据源行 + 标题行）：可拉伸源时整块可上下拖拽调整高度
                  // 标题跨源恒用清洗后的原查询文本（保留大小写，不用各源词形还原/
                  // headword 后的原形）；收藏仍用归一化小写词形，保证正文匹配一致。
                  _buildHeader(
                    theme,
                    state,
                    notifier,
                    word,
                    lookupQuery,
                    isResizable,
                    pronunciationClips,
                  ),
                  const SizedBox(height: AppSpacing.s),

                  // 内容区：按选中源渲染。
                  _buildResultArea(
                    state,
                    word,
                    lookupQuery,
                    notifier,
                    isWeb,
                    isResizable,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 内容区：按源类型决定填充策略。
  /// - 网页源（[isWeb]）：填满面板剩余高度且占满宽度，WebView 跟随上拉一起放大；
  /// - AI 源（[isResizable] 且非网页）：填满剩余高度并内部滚动，跟随上拉显示更多；
  /// - 本地源：按内容自适应、限高 3/5（与可拉伸源默认高度统一）并内部滚动。
  Widget _buildResultArea(
    DictionaryLookupState state,
    String word,
    String lookupQuery,
    DictionaryLookupController notifier,
    bool isWeb,
    bool isResizable,
  ) {
    // 学习内容字号偏好：整块结果区统一缩放主题文字（释义、例句、AI 解析等）
    final resultView = ReadingTextScale(
      child: DictionaryResultView(
        sourceId: state.selectedSourceId,
        state: state.current,
        word: word,
        onRetry: notifier.retry,
        onSignIn: _openAiSignInPage,
        onUpgrade: () => _handleUpgrade(lookupQuery),
      ),
    );
    if (isWeb) {
      // 填满剩余高度且占满宽度，交由 WebView 自身渲染滚动
      return Expanded(
        child: SizedBox(width: double.infinity, child: resultView),
      );
    }
    if (isResizable) {
      // AI 源：填满显式高度并在内部滚动
      return Expanded(
        child: SingleChildScrollView(
          child: _buildContent(state.selectedSourceId, resultView),
        ),
      );
    }
    return Flexible(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SingleChildScrollView(
          child: _buildContent(state.selectedSourceId, resultView),
        ),
      ),
    );
  }

  /// header 整块：指示条 + 数据源选择行 + 标题行。
  ///
  /// [resizable] 为 true（AI/网页源）时，整块 header（含指示条、数据源行、
  /// 标题行及行间留白）都可上下拖拽调整面板高度——竖向拖拽由外层
  /// [GestureDetector] 接管，内部按钮/长按只用 tap/longPress，经手势竞技场天然
  /// 区分（纯点击→按钮赢，有竖向位移→拖拽赢），不破坏现有交互。
  Widget _buildHeader(
    ThemeData theme,
    DictionaryLookupState state,
    DictionaryLookupController notifier,
    String savedWord,
    String displayWord,
    bool resizable,
    List<PronunciationClip> pronunciationClips,
  ) {
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 拖拽指示条（视觉提示；拖拽手势由外层 header 统一接管）
        _buildDragHandle(theme, resizable),
        const SizedBox(height: 6),

        // 数据源选择：整体靠右，AI 快捷按钮紧贴切换器左侧、与其等高
        IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AiSourceButton(
                selectedId: state.selectedSourceId,
                onSelected: notifier.selectSource,
              ),
              const SizedBox(width: 8),
              SourceSwitcher(
                selectedId: state.selectedSourceId,
                onSelected: notifier.selectSource,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 标题行：单词 + 发音 + 收藏 + 关闭（跨源恒定）
        _buildTitleRow(theme, displayWord, savedWord, pronunciationClips),
        if (pronunciationClips.length > 1) ...[
          const SizedBox(height: 8),
          PronunciationBadgeGroup(
            clips: pronunciationClips,
            fallbackText: displayWord,
          ),
        ],
      ],
    );
    if (!resizable) return header;
    return GestureDetector(
      key: const Key('dict_drag_handle'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onHandleDragStart,
      onVerticalDragUpdate: _onHandleDrag,
      onVerticalDragEnd: _onHandleDragEnd,
      child: header,
    );
  }

  /// 拖拽指示条（仅视觉）。[draggable] 时加竖向留白让指示条更易识别为可拖拽。
  Widget _buildDragHandle(ThemeData theme, bool draggable) {
    final bar = Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    if (!draggable) return Center(child: bar);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: bar,
      ),
    );
  }

  /// 内容区包装：滑入结束前直接返回内容（无过渡，被滑入运动掩盖）；
  /// 滑入结束后套 AnimatedSize + AnimatedSwitcher，使切换数据源/切词时平滑过渡。
  Widget _buildContent(String sourceId, Widget content) {
    if (!_entered) return content;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        // 切源与切词都触发过渡
        child: KeyedSubtree(
          key: ValueKey('$_normalizedWord|$sourceId'),
          child: content,
        ),
      ),
    );
  }

  /// 标题行：单词（可长按复制）+ TTS + 收藏 + 关闭
  ///
  /// [displayWord] 为保留大小写的清洗 query，用于标题展示与标题发音；
  /// [savedWord] 为小写归一化词形，用于收藏状态和保存内容。各源的词形还原/
  /// headword 原形仅用于内容展示，不占据标题，也不改变收藏内容。
  Widget _buildTitleRow(
    ThemeData theme,
    String displayWord,
    String savedWord,
    List<PronunciationClip> pronunciationClips,
  ) {
    // 收藏态统一读取两类底层收藏：对用户而言单词与意群没有状态差异，
    // 任一表命中即显示已收藏，避免多词在来源句查词时漏显收藏状态。
    final textPrefs = ref.watch(readingTextPrefsNotifierProvider);
    final savedWords = ref.watch(savedWordTextsProvider).valueOrNull;
    final savedSenseGroups = ref
        .watch(savedSenseGroupTextsProvider)
        .valueOrNull;
    final isSaved =
        (savedWords ?? const <String>{}).contains(savedWord) ||
        (savedSenseGroups ?? const <String>{}).contains(savedWord);
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPressStart: (d) =>
                TextContextMenu.show(context, d.globalPosition, displayWord),
            onSecondaryTapDown: (d) =>
                TextContextMenu.show(context, d.globalPosition, displayWord),
            child: Text(
              displayWord,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: theme.textTheme.titleLarge?.copyWith(
                // 词头基准 17，随学习内容字号同比缩放
                fontSize: 17 * textPrefs.fontScale,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        if (pronunciationClips.length == 1)
          LocalPronunciationIconButton(
            clip: pronunciationClips.single,
            fallbackText: displayWord,
          )
        else if (pronunciationClips.isEmpty)
          SpeakButton(text: displayWord),
        AnimatedBookmarkIcon(
          key: const Key('dict_panel_bookmark'),
          isSaved: isSaved,
          onPressed: () => _toggleSave(savedWord, isSaved),
        ),
        IconButton(
          key: const Key('dict_panel_close'),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          visualDensity: VisualDensity.compact,
          onPressed: widget.onClose,
        ),
      ],
    );
  }
}
