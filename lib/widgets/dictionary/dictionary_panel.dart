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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/sign_in_required_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dictionary/dict_speakable_texts.dart';
import '../../models/dictionary/dictionary_lookup_result.dart';
import '../../providers/dictionary/dictionary_registry.dart';
import '../../providers/dictionary/lookup_controller.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/saved_word_provider.dart';
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
import 'source_switcher.dart';

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

  /// 可拉伸源面板的当前高度（像素）。默认 1/2 屏高（避免遮挡正文），
  /// 用户上拉拖拽指示条可放大、下拉可缩小（夹在 [_minSheetHeight] 与
  /// [_maxSheetHeight] 之间）。文本本地源不用此值（按内容自适应）。
  double? _sheetHeight;

  /// 会话粘滞源 notifier（build 时缓存，供 [dispose] 清除——
  /// `ConsumerState.dispose` 内不可用 `ref`，见 CLAUDE.md §7.14）。
  DictionarySessionSource? _sessionSource;

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

  /// 面板默认高度：屏高 1/2（避免遮挡正文）
  double get _defaultSheetHeight => MediaQuery.sizeOf(context).height / 2;

  @override
  void initState() {
    super.initState();
    // 查询文本在面板打开时即已知，立即后台预热，不必等 AI 查询返回。
    // 标题行 SpeakButton 加载前发的就是 _normalizedWord；AI 返回后
    // prewarmTexts 的完整批次会把 headword 排首位，命中缓存/在途去重不重复合成。
    ref.read(ttsControllerProvider.notifier).prewarmTexts([_normalizedWord]);
    _watchEntryAnimation();
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
  void didUpdateWidget(DictionaryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldWord = normalizeWord(oldWidget.query.word);
    if (oldWord != _normalizedWord) {
      // 切词：停掉旧词的在途预热/朗读，立即预热新词。
      // 用户调整过的面板高度保留（连续查词不跳动）。
      _ttsController?.cancelTextsPrewarm();
      _ttsController?.stop();
      ref.read(ttsControllerProvider.notifier).prewarmTexts([_normalizedWord]);
    }
  }

  @override
  void dispose() {
    widget.entryAnimation?.removeStatusListener(_onEntryAnimationStatus);
    // 面板关闭即停在途预热，避免离开后继续占用 CPU 合成用不到的例句。
    _ttsController?.cancelTextsPrewarm();
    // 面板关闭即停止正在朗读的单词/例句，避免离开后声音继续播到尾。
    _ttsController?.stop();
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

  /// 归一化后的词形（单词或词组），用于查询（family key）与展示，
  /// 与各词典源、后端共用同一 [normalizeWord]
  /// （trim + 剥首尾标点[右撇号除外] + 小写 + 内部空白折叠）
  String get _normalizedWord => normalizeWord(widget.query.word);

  /// 标题展示词：优先用当前结果的 headword（本地原形/AI 词头），否则用归一化词形
  String _displayWord(DictionaryLookupState state) {
    final cur = state.current;
    if (cur is LookupLoaded) return cur.result.headword;
    return _normalizedWord;
  }

  /// 收藏用 lemma：优先用本地词典返回的原形，否则用归一化词形
  String _lemmaWord(DictionaryLookupState state) {
    final local = state.bySource['local'];
    if (local case LookupLoaded(result: final LocalDictResult r)) {
      return r.entry.word.toLowerCase();
    }
    return _normalizedWord;
  }

  Future<void> _toggleSave(String lemma, bool currentlySaved) async {
    final notifier = ref.read(savedWordListProvider.notifier);
    if (currentlySaved) {
      await notifier.removeWord(lemma);
    } else {
      await notifier.saveWord(
        word: lemma,
        audioItemId: widget.query.audioItemId,
        sentenceIndex: widget.query.sentenceIndex,
        sentenceText: widget.query.sentenceText,
        sentenceStartMs: widget.query.sentenceStartMs,
        sentenceEndMs: widget.query.sentenceEndMs,
      );
    }
  }

  /// AI 源未登录时引导登录，登录成功后重试
  Future<void> _handleSignIn(String word) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.senseGroupSignInRequiredTitle,
      message: l10n.senseGroupSignInRequiredMessage,
    );
    if (ok) {
      ref.read(dictionaryLookupControllerProvider(word).notifier).retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = _normalizedWord;
    final controllerProvider = dictionaryLookupControllerProvider(word);
    final state = ref.watch(controllerProvider);
    final notifier = ref.read(controllerProvider.notifier);

    // 缓存 TTS 控制器与会话粘滞源供 dispose 使用（dispose 内不可用 ref，§7.14）。
    _ttsController = ref.read(ttsControllerProvider.notifier);
    _sessionSource = ref.read(dictionarySessionSourceProvider.notifier);

    // 本地词典下载完成后，若当前选中本地源，自动重新查询
    ref.listen(dictionaryProvider, (prev, next) {
      if (next.status == DictionaryStatus.downloaded &&
          state.selectedSourceId == 'local') {
        notifier.retry();
      }
    });

    // 查词结果到达（或切换数据源后命中已加载结果）即后台预热「单词 + 例句」，
    // 用户点击发音时命中缓存秒播。仅在选中源的状态变为新的 LookupLoaded 时触发；
    // 重复文本由协调器缓存/在途去重兜底，开销极小。
    ref.listen(controllerProvider, (prev, next) {
      final cur = next.current;
      if (cur is LookupLoaded && !identical(prev?.current, cur)) {
        _ttsController?.prewarmTexts(dictionarySpeakableTexts(cur.result));
      }
    });

    final lemma = _lemmaWord(state);
    final displayWord = _displayWord(state);
    final isWeb = _isWebSource(state.selectedSourceId);
    // AI 与网页源内容丰富，默认 1/2 屏高且可上拉放大；本地源内容短，按内容自适应。
    final isResizable =
        isWeb || state.selectedSourceId == AiDictionarySource.sourceId;

    // 非 modal 嵌入渲染：自带表面（顶部圆角 + 阴影），原 modal 容器不复存在。
    return Material(
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
          // 可拉伸源用显式高度（默认 1/2，可拖拽指示条调整）；本地源按内容自适应。
          height: isResizable ? (_sheetHeight ?? _defaultSheetHeight) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              6,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header（指示条 + 数据源行 + 标题行）：可拉伸源时整块可上下拖拽调整高度
                _buildHeader(
                  theme,
                  state,
                  notifier,
                  displayWord,
                  lemma,
                  isResizable,
                ),
                const SizedBox(height: AppSpacing.s),

                // 内容区：按选中源渲染。
                _buildResultArea(state, word, notifier, isWeb, isResizable),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 内容区：按源类型决定填充策略。
  /// - 网页源（[isWeb]）：填满面板剩余高度且占满宽度，WebView 跟随上拉一起放大；
  /// - AI 源（[isResizable] 且非网页）：填满剩余高度并内部滚动，跟随上拉显示更多；
  /// - 本地源：按内容自适应、限高 1/2 并内部滚动。
  Widget _buildResultArea(
    DictionaryLookupState state,
    String word,
    DictionaryLookupController notifier,
    bool isWeb,
    bool isResizable,
  ) {
    final resultView = DictionaryResultView(
      sourceId: state.selectedSourceId,
      state: state.current,
      word: word,
      onRetry: notifier.retry,
      onSignIn: () => _handleSignIn(word),
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
          maxHeight: MediaQuery.sizeOf(context).height / 2,
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
    String displayWord,
    String lemma,
    bool resizable,
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
        _buildTitleRow(theme, displayWord, lemma),
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
  Widget _buildTitleRow(ThemeData theme, String word, String lemma) {
    final isSaved = ref.watch(isWordSavedProvider(lemma)).valueOrNull ?? false;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPressStart: (d) =>
                TextContextMenu.show(context, d.globalPosition, word),
            onSecondaryTapDown: (d) =>
                TextContextMenu.show(context, d.globalPosition, word),
            child: Text(
              word,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        SpeakButton(text: word),
        AnimatedBookmarkIcon(
          isSaved: isSaved,
          onPressed: () => _toggleSave(lemma, isSaved),
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
