import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:echo_loop/widgets/common/svg_action_icon.dart';

import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/word_timestamp.dart';
import '../../models/practice_media_split.dart';
import '../../providers/media_engine/media_engine_provider.dart';
import '../../providers/new_user_guide_provider.dart';
import '../../services/app_logger.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/media_split_divider.dart';
import '../../widgets/common/practice_media_split_geometry.dart';
import '../../widgets/common/video_toggle_icon.dart';
import '../../widgets/guide_flow.dart';
import 'subtitle_edit_engine.dart';
import 'subtitle_editor_controller.dart';
import 'subtitle_editor_split_geometry.dart';
import 'subtitle_editor_split_provider.dart';
import 'subtitle_editor_video_preview.dart';
import 'subtitle_sentence_colors.dart';
import 'subtitle_waveform_view.dart';

class SubtitleSimpleEditorScreen extends ConsumerStatefulWidget {
  final AudioItem audioItem;

  const SubtitleSimpleEditorScreen({super.key, required this.audioItem});

  @override
  ConsumerState<SubtitleSimpleEditorScreen> createState() =>
      _SubtitleSimpleEditorScreenState();
}

class _SubtitleSimpleEditorScreenState
    extends ConsumerState<SubtitleSimpleEditorScreen> {
  /// 页面左右边距，波形卡片、工具条与句子列表对齐到同一条竖线。
  static const double _gutter = 12;

  /// 单栏布局的最大内容宽度：宽窗口里波形、工具条与句子列表一起居中，
  /// 左右边缘对齐，句子也不会横向拉得过长。
  static const double _maxSingleColumnWidth = 960;

  /// 上下布局时视频画面最多占用的高度比例，其余留给波形与句子列表。
  static const double _stackedVideoMaxFraction = 0.3;

  /// 左右分栏时左栏画面上下的留白。
  static const double _sideVideoTopGap = AppSpacing.m;
  static const double _sideVideoBottomGap = AppSpacing.xs;
  static const double _sideBottomGap = AppSpacing.m;

  /// 左右分栏时左栏中画面以外的固定高度：画面上下留白 + 工具条 + 波形 + 底部留白。
  static const double _sideChromeHeight =
      _sideVideoTopGap +
      _sideVideoBottomGap +
      _EditorToolbar.height +
      SubtitleWaveformView.height +
      _sideBottomGap;

  final GlobalKey _guideSentencePlayKey = GlobalKey(
    debugLabel: 'subtitleEditorSentencePlay',
  );
  final GlobalKey _guideSentenceMenuKey = GlobalKey(
    debugLabel: 'subtitleEditorSentenceMenu',
  );
  final GlobalKey _guideBoundaryHandleKey = GlobalKey(
    debugLabel: 'subtitleEditorBoundaryHandle',
  );

  /// 波形与句子列表在上下 / 左右布局间换位置；GlobalKey 让它们搬家而不重建，
  /// 保住波形的平移位置和列表的滚动位置。
  final GlobalKey _waveformKey = GlobalKey(
    debugLabel: 'subtitleEditorWaveform',
  );
  final GlobalKey _sentenceListKey = GlobalKey(
    debugLabel: 'subtitleEditorSentenceList',
  );

  /// 编辑字幕以波形和文字为主，画面默认收起；只影响本页。
  bool _isVideoVisible = false;

  /// 首次显示画面时才创建，离开页面时释放。
  SubtitleEditorVideoPreview? _videoPreview;

  /// 拖动分隔条过程中的左栏宽度，只存在于拖动期间；松手后写入偏好并清空。
  double? _dragMediaColumnWidth;

  /// 正在整句改文字的句子序号；null 表示没有。
  int? _editingSentenceIndex;

  /// 正在输入的新句所占的时间区间；null 表示没有待输入的新句。
  /// 新句只在确认文字后才写入字幕，取消或留空不会留下空句。
  SentenceSlot? _draftSlot;

  SubtitleEditorController get _controller =>
      ref.read(subtitleEditorControllerProvider(widget.audioItem).notifier);

  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).track(Events.subtitleEditorOpened, {
      EventParams.audioId: widget.audioItem.id,
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.load());
    });
    FocusManager.instance.addEarlyKeyEventHandler(_handleShortcut);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleShortcut);
    final preview = _videoPreview;
    _videoPreview = null;
    if (preview != null) {
      preview.aspectRatio.removeListener(_onVideoAspectRatioChanged);
      unawaited(preview.dispose());
    }
    super.dispose();
  }

  Future<void> _toggleVideo() async {
    final isVisible = !_isVideoVisible;
    setState(() => _isVideoVisible = isVisible);
    AppLogger.log(
      'SubtitleEditorVideo',
      '${isVisible ? '显示' : '隐藏'}画面 audio=${widget.audioItem.id}',
    );
    if (!isVisible) {
      _videoPreview?.suspend();
      return;
    }
    if (_videoPreview != null) {
      _syncVideo(ref.read(subtitleEditorControllerProvider(widget.audioItem)));
      return;
    }
    final preview = SubtitleEditorVideoPreview(
      ref.read(mediaBackendFactoryProvider)(),
    )..aspectRatio.addListener(_onVideoAspectRatioChanged);
    setState(() => _videoPreview = preview);
    final path = await widget.audioItem.getFullAudioPath();
    if (!mounted || _videoPreview != preview) return;
    await preview.open(
      path,
      initialPosition: ref
          .read(subtitleEditorControllerProvider(widget.audioItem))
          .playbackPosition,
    );
    if (mounted && _isVideoVisible) {
      _syncVideo(ref.read(subtitleEditorControllerProvider(widget.audioItem)));
    }
  }

  /// 解码出视频比例后重新计算分栏宽度（竖屏视频会把宽度让给句子列表）。
  void _onVideoAspectRatioChanged() {
    if (mounted) setState(() {});
  }

  void _syncVideo(SubtitleEditorState state) {
    if (!_isVideoVisible) return;
    _videoPreview?.follow(
      // 试听单词时播放头不动，画面也停在播放头所在帧。
      isPlaying:
          state.isPlaying &&
          state.playbackMode != SubtitleEditorPlaybackMode.wordAudition,
      position: state.playbackPosition,
      speed: state.playbackSpeed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = subtitleEditorControllerProvider(widget.audioItem);
    ref.listen(provider, (_, next) => _syncVideo(next));
    final state = ref.watch(provider);
    final controller = _controller;

    final sentencePlayStep = GuideStep(
      key: _guideSentencePlayKey,
      description: l10n.guideSubtitleEditorSentencePlayDescription,
    );
    final sentenceMenuStep = GuideStep(
      key: _guideSentenceMenuKey,
      description: l10n.guideSubtitleEditorSentenceMenuDescription,
    );
    final boundaryHandleStep = GuideStep(
      key: _guideBoundaryHandleKey,
      description: l10n.guideSubtitleEditorBoundaryHandleDescription,
    );
    final guideFlows = [
      GuideFlow(
        flowId: GuideFlowIds.subtitleEditorSentenceActions,
        shouldRun: state.sentences.isNotEmpty,
        steps: [sentencePlayStep, sentenceMenuStep, boundaryHandleStep],
      ),
    ];

    return GuideFlowSequenceHost(
      flows: guideFlows,
      child: PopScope(
        canPop: !state.isDirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final discard = await _confirmDiscard(context, l10n);
          if (discard == true && context.mounted) {
            context.pop();
          }
        },
        child: _buildScaffold(
          context,
          l10n: l10n,
          state: state,
          controller: controller,
          sentencePlayStep: sentencePlayStep,
          sentenceMenuStep: sentenceMenuStep,
          boundaryHandleStep: boundaryHandleStep,
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required AppLocalizations l10n,
    required SubtitleEditorState state,
    required SubtitleEditorController controller,
    required GuideStep sentencePlayStep,
    required GuideStep sentenceMenuStep,
    required GuideStep boundaryHandleStep,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: _EditorTitle(
          title: l10n.editSubtitles,
          mediaName: widget.audioItem.name,
        ),
        actions: [
          IconButton(
            key: const ValueKey('subtitle-editor-undo'),
            tooltip: _withShortcutHint(l10n.undo, 'Z'),
            onPressed: state.canUndo ? _undo : null,
            icon: const SvgActionIcon(assetName: 'assets/icon/undo.svg'),
          ),
          IconButton(
            key: const ValueKey('subtitle-editor-redo'),
            tooltip: _withShortcutHint(l10n.redo, '⇧Z'),
            onPressed: state.canRedo ? _redo : null,
            icon: const SvgActionIcon(assetName: 'assets/icon/redo.svg'),
          ),
          const SizedBox(width: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.m - 4),
            child: _SaveButton(
              isDirty: state.isDirty,
              isSaving: state.isSaving,
              onPressed: () => unawaited(_save(context, controller, l10n)),
            ),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
          ? _EditorError(message: state.errorMessage!)
          : SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) => _buildEditor(
                  context,
                  constraints: constraints,
                  state: state,
                  controller: controller,
                  sentencePlayStep: sentencePlayStep,
                  sentenceMenuStep: sentenceMenuStep,
                  boundaryHandleStep: boundaryHandleStep,
                ),
              ),
            ),
    );
  }

  /// 桌面端按钮提示附带快捷键（如「撤销 ⌘Z」），触屏设备不显示。
  String _withShortcutHint(String label, String key) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => '$label  ⌘$key',
      TargetPlatform.windows ||
      TargetPlatform.linux => '$label  Ctrl+${key.replaceAll('⇧', 'Shift+')}',
      _ => label,
    };
  }

  /// 分发桌面快捷键（注册为 [FocusManager] 的前置按键处理，先于焦点树执行）。
  ///
  /// 不挂在焦点树上：那样需要页面一直持有一个焦点锚点，输入框收起后还得把焦点
  /// 抢回来，和刚打开的输入框争焦点会让输入框偶尔拿不到焦点。也不能注册到
  /// `HardwareKeyboard`：那里返回已处理并不会拦住焦点树，方向键仍会移动焦点、
  /// 回车仍会激活获焦的按钮（如倍速按钮弹出菜单）。返回 handled 后焦点树不再收到
  /// 该按键；输入文字时放行，否则 macOS 上已处理的按键不会再交给输入框。
  ///
  /// 只在本页是当前页面（没有弹窗、菜单盖在上面）且焦点不在输入框时处理。
  KeyEventResult _handleShortcut(KeyEvent event) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
      return KeyEventResult.ignored;
    }
    if (_isTypingText) return KeyEventResult.ignored;
    final bindings = _shortcutBindings(
      context,
      ref.read(subtitleEditorControllerProvider(widget.audioItem)),
      _controller,
      AppLocalizations.of(context)!,
    );
    for (final MapEntry(key: activator, value: action) in bindings.entries) {
      if (activator.accepts(event, HardwareKeyboard.instance)) {
        action();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// 桌面快捷键（输入文字时不响应，见 [_handleShortcut]）。
  Map<ShortcutActivator, VoidCallback> _shortcutBindings(
    BuildContext context,
    SubtitleEditorState state,
    SubtitleEditorController controller,
    AppLocalizations l10n,
  ) {
    final undo = _undo;
    final redo = _redo;
    void save() {
      if (state.isDirty && !state.isSaving) {
        unawaited(_save(context, controller, l10n));
      }
    }

    final selected = state.selectedSentenceIndex;
    return {
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): undo,
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): undo,
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
          redo,
      const SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      ): redo,
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): redo,
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true): save,
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): save,
      const SingleActivator(LogicalKeyboardKey.arrowUp): () {
        if (selected != null) controller.selectSentence(selected - 1);
      },
      const SingleActivator(LogicalKeyboardKey.arrowDown): () {
        if (selected != null) controller.selectSentence(selected + 1);
      },
      const SingleActivator(LogicalKeyboardKey.enter): () {
        if (selected != null) _startEditingText(selected);
      },
    };
  }

  /// 焦点是否在输入框内。
  bool get _isTypingText {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// 撤销 / 重做会改变句子结构，进行中的输入一并收起，避免序号错位。
  void _undo() {
    _closeTextEditors();
    _controller.undo();
  }

  void _redo() {
    _closeTextEditors();
    _controller.redo();
  }

  void _closeTextEditors() {
    if (_editingSentenceIndex == null && _draftSlot == null) return;
    setState(() {
      _editingSentenceIndex = null;
      _draftSlot = null;
    });
  }

  void _startEditingText(int index) {
    setState(() {
      _draftSlot = null;
      _editingSentenceIndex = index;
    });
  }

  void _commitSentenceText(int index, String text) {
    setState(() => _editingSentenceIndex = null);
    _controller.editSentenceText(index, text);
  }

  /// 打开新句输入：新句占 [slot]，确认文字后才真正插入。
  void _startDraft(SentenceSlot slot) {
    AppLogger.log(
      'SubtitleEditor',
      '开始输入新句 range=${slot.start.inMilliseconds}-${slot.end.inMilliseconds}ms',
    );
    setState(() {
      _editingSentenceIndex = null;
      _draftSlot = slot;
    });
  }

  void _commitDraft(String text) {
    final slot = _draftSlot;
    setState(() => _draftSlot = null);
    if (slot != null) _controller.insertSentence(slot, text);
  }

  /// 组装编辑区：画面收起或空间不足时上下排布；宽窗口显示画面时左右分栏，
  /// 左侧「画面 + 工具条 + 波形」都是时间维度的视图，右侧是逐句编辑的文字。
  Widget _buildEditor(
    BuildContext context, {
    required BoxConstraints constraints,
    required SubtitleEditorState state,
    required SubtitleEditorController controller,
    required GuideStep sentencePlayStep,
    required GuideStep sentenceMenuStep,
    required GuideStep boundaryHandleStep,
  }) {
    final isVideoShown = widget.audioItem.isVideo && _isVideoVisible;
    final isSideBySide =
        isVideoShown &&
        PracticeMediaSplitGeometry.resolveAxis(constraints.biggest) ==
            PracticeMediaSplitAxis.sideBySide;
    final size = constraints.biggest;
    final splitRange = SubtitleEditorSplitGeometry.mediaColumnRange(size.width);
    final videoAspectRatio = _videoPreview?.aspectRatio.value;
    // 拖动中的宽度也按当前范围限制：拖动期间窗口变化不会让右栏被挤出最小宽度。
    final mediaColumnWidth = isSideBySide
        ? splitRange.clamp(
            _dragMediaColumnWidth ??
                SubtitleEditorSplitGeometry.resolveMediaColumnWidth(
                  size: size,
                  chromeHeight: _sideChromeHeight,
                  horizontalPadding: _gutter * 2,
                  videoAspectRatio: videoAspectRatio,
                  fraction: ref.watch(subtitleEditorSplitProvider),
                ),
          )
        : null;
    final toolbar = _EditorToolbar(
      isVideoVisible: widget.audioItem.isVideo ? _isVideoVisible : null,
      onToggleVideo: () => unawaited(_toggleVideo()),
      zoomScale: state.waveformZoomScale,
      maxZoomScale: state.maxWaveformZoomScale,
      playbackSpeed: state.playbackSpeed,
      onZoomChanged: controller.setWaveformZoomScale,
      onSpeedChanged: (speed) => unawaited(controller.setPlaybackSpeed(speed)),
    );
    final waveform = KeyedSubtree(
      key: _waveformKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gutter),
        child: _WaveformCard(
          child: LayoutBuilder(
            builder: (context, box) {
              // 时长就绪后按波形实际宽度设置初始缩放（每厘米约 1 秒音频）；
              // controller 侧幂等，仅首次生效。
              if (state.totalDuration != null) {
                final usableWidth =
                    box.maxWidth - SubtitleWaveformView.horizontalPadding * 2;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) controller.initZoomForViewport(usableWidth);
                });
              }
              return GuideTarget(
                step: boundaryHandleStep,
                child: SubtitleWaveformView(
                  waveform: state.waveform,
                  extractionProgress: state.waveformProgress,
                  extractionFailed: state.waveformFailed,
                  audioMissing: state.waveformAudioMissing,
                  onRetryExtraction: () =>
                      unawaited(controller.retryWaveform()),
                  duration: state.totalDuration,
                  sentences: state.sentences,
                  activeSentence: state.selectedSentence,
                  selectionEpoch: state.selectionEpoch,
                  playbackPosition: state.playbackPosition,
                  isPlaying:
                      state.isPlaying &&
                      (state.playbackMode ==
                              SubtitleEditorPlaybackMode.sentence ||
                          state.playbackMode ==
                              SubtitleEditorPlaybackMode.word),
                  // 试听单词时不跟随，避免在波形上点词后视图滚走。
                  followsPlayhead:
                      state.playbackMode == SubtitleEditorPlaybackMode.sentence,
                  wordBoundaries: controller.wordBoundariesForWaveform,
                  // 波形上点词只试听，播放头不动；字幕列表点词才移动播放头帮助定位。
                  onWordTap: (index) => unawaited(
                    controller.playWord(index, movesPlayhead: false),
                  ),
                  highlightedWord: switch (controller.highlightedWordIndex) {
                    final index? => controller.wordsOfSelectedSentence[index],
                    null => null,
                  },
                  onAdjustWord: controller.adjustWord,
                  onMoveWord: controller.moveWord,
                  zoomScale: state.waveformZoomScale,
                  onZoomChanged: controller.setWaveformZoomScale,
                  onScrub: controller.scrubTo,
                  onScrubEnd: (position) =>
                      unawaited(controller.finishScrub(position)),
                  onAdjustEnd: controller.endWordAdjust,
                  // 已在输入新句时不再提示，避免重复入口。
                  insertSlot: _draftSlot == null
                      ? controller.insertSlotAtPlayhead
                      : null,
                  onInsertSentence: () {
                    final slot = controller.insertSlotAtPlayhead;
                    if (slot != null) _startDraft(slot);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    final sentenceList = KeyedSubtree(
      key: _sentenceListKey,
      child: _SentenceList(
        sentences: state.sentences,
        selectedIndex: state.selectedSentenceIndex,
        playingIndex: state.playingSentenceIndex,
        selectedSentenceWords: controller.wordsOfSelectedSentence,
        highlightedWordIndex: controller.highlightedWordIndex,
        onPlay: (index) => unawaited(controller.playSentence(index)),
        onStop: () => unawaited(controller.stopPlayback()),
        onSelect: controller.selectSentence,
        onWordTap: (index) => unawaited(controller.playWord(index)),
        onEditWord: controller.editWord,
        onInsertWords: controller.insertWords,
        onDeleteWord: controller.deleteWord,
        onSplitWord: controller.splitSentenceAtWord,
        onMergeNext: controller.mergeWithNext,
        editingIndex: _editingSentenceIndex,
        onStartEditText: _startEditingText,
        onCommitText: _commitSentenceText,
        onCancelText: () => setState(() => _editingSentenceIndex = null),
        insertSlotNear: (index, {required after}) =>
            controller.insertSlotNear(index, after: after),
        onInsertNear: (index, {required after}) {
          final slot = controller.insertSlotNear(index, after: after);
          if (slot != null) _startDraft(slot);
        },
        draftSlot: _draftSlot,
        onCommitDraft: _commitDraft,
        onCancelDraft: () {
          AppLogger.log('SubtitleEditor', '放弃新句');
          setState(() => _draftSlot = null);
        },
        onDelete: (index) => controller.deleteSentence(index),
        firstPlayGuideStep: sentencePlayStep,
        firstMenuGuideStep: sentenceMenuStep,
      ),
    );
    final videoPanel = SubtitleEditorVideoPanel(preview: _videoPreview);

    if (mediaColumnWidth != null) {
      return Row(
        key: const ValueKey('subtitle-editor-side-by-side'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: mediaColumnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 画面贴顶、工具条与波形紧跟其下；默认宽度让画面恰好填满剩余
                // 高度，用户拖宽后多出的高度留在底部。
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _gutter,
                      _sideVideoTopGap,
                      _gutter,
                      _sideVideoBottomGap,
                    ),
                    child: videoPanel,
                  ),
                ),
                toolbar,
                waveform,
                const SizedBox(height: _sideBottomGap),
              ],
            ),
          ),
          MediaSplitDivider(
            axis: PracticeMediaSplitAxis.sideBySide,
            onDragStart: () =>
                setState(() => _dragMediaColumnWidth = mediaColumnWidth),
            onDragUpdate: (delta) => setState(
              () => _dragMediaColumnWidth = splitRange.clamp(
                (_dragMediaColumnWidth ?? mediaColumnWidth) + delta,
              ),
            ),
            onDragEnd: () => _commitMediaColumnDrag(splitRange),
            onReset: () => unawaited(
              ref.read(subtitleEditorSplitProvider.notifier).setFraction(null),
            ),
          ),
          Expanded(child: sentenceList),
        ],
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxSingleColumnWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isVideoShown)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _gutter,
                  AppSpacing.s,
                  _gutter,
                  0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * _stackedVideoMaxFraction,
                  ),
                  child: videoPanel,
                ),
              ),
            toolbar,
            waveform,
            const SizedBox(height: AppSpacing.xs),
            Expanded(child: sentenceList),
          ],
        ),
      ),
    );
  }

  /// 松手后按可用宽度记住左栏比例，窗口缩放后仍保持相近的分配。
  void _commitMediaColumnDrag(PracticeMediaExtentRange range) {
    // 分隔条在拖动中被移除时会在帧结束后补发，此时页面可能已关闭。
    if (!mounted) return;
    final width = _dragMediaColumnWidth;
    setState(() => _dragMediaColumnWidth = null);
    if (width == null) return;
    final fraction = range.fractionOf(range.clamp(width));
    if (fraction == null) return;
    unawaited(
      ref.read(subtitleEditorSplitProvider.notifier).setFraction(fraction),
    );
  }

  Future<void> _save(
    BuildContext context,
    SubtitleEditorController controller,
    AppLocalizations l10n,
  ) async {
    final saved = await controller.save();
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.subtitleEditsSaved)));
    }
  }

  Future<bool?> _confirmDiscard(BuildContext context, AppLocalizations l10n) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardSubtitleEditsTitle),
        content: Text(l10n.discardSubtitleEditsMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
  }
}

/// 标题栏：功能名 + 当前材料名，告诉用户正在编辑哪份字幕。
class _EditorTitle extends StatelessWidget {
  const _EditorTitle({required this.title, required this.mediaName});

  final String title;
  final String mediaName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(
          mediaName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 保存按钮：无改动时置灰，有改动时主色实心，保存中显示进度。
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isDirty,
    required this.isSaving,
    required this.onPressed,
  });

  final bool isDirty;
  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      key: const ValueKey('subtitle-editor-save-button'),
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        minimumSize: const Size(64, 36),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: !isDirty || isSaving ? null : onPressed,
      child: isSaving
          ? SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onSurfaceVariant,
              ),
            )
          : Text(l10n.save),
    );
  }
}

/// 波形卡片：圆角承载波形，与页面背景分层，作为「时间」视图的主体。
class _WaveformCard extends StatelessWidget {
  const _WaveformCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        // 与剪辑页时间线一致的浅灰底：白色播放头在上面清晰可见。
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}

/// 波形上方的工具条：画面开关、缩放、播放速度。
///
/// 只放与「看波形 / 听」有关的全局控件；逐句操作留在句子行内，避免工具条膨胀。
class _EditorToolbar extends StatelessWidget {
  static const _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  /// 缩放按钮每次放大 / 缩小的倍数。
  static const double _zoomStep = 1.5;

  /// 工具条固定高度（容纳 48px 图标按钮），左右分栏据此计算画面可用高度。
  static const double height = 52;

  /// 为 null 表示音频材料，不显示画面开关。
  final bool? isVideoVisible;
  final VoidCallback onToggleVideo;
  final double zoomScale;
  final double maxZoomScale;
  final double playbackSpeed;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<double> onSpeedChanged;

  const _EditorToolbar({
    required this.isVideoVisible,
    required this.onToggleVideo,
    required this.zoomScale,
    required this.maxZoomScale,
    required this.playbackSpeed,
    required this.onZoomChanged,
    required this.onSpeedChanged,
  });

  /// 音频长度允许放大时才启用缩放（短音频整段已铺满屏宽，无需放大）。
  bool get _canZoom => maxZoomScale > 1.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sliderMax = _canZoom ? maxZoomScale : 2.0;
    final value = zoomScale.clamp(1.0, sliderMax);
    final iconColor = scheme.onSurfaceVariant;
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        _SubtitleSimpleEditorScreenState._gutter,
        0,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: iconColor, size: 20),
        child: Row(
          children: [
            if (isVideoVisible case final isVisible?) ...[
              IconButton(
                key: const ValueKey('subtitle-editor-toggle-video'),
                tooltip: isVisible
                    ? l10n.videoHideTrack
                    : l10n.mediaShowVisualTrack,
                isSelected: isVisible,
                onPressed: onToggleVideo,
                icon: VideoToggleIcon(isVisible: isVisible, size: 20),
              ),
              Container(
                width: 1,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                color: scheme.outlineVariant,
              ),
            ],
            IconButton(
              key: const ValueKey('subtitle-waveform-zoom-out'),
              tooltip: l10n.waveformZoomOut,
              onPressed: _canZoom && value > 1.0
                  ? () =>
                        onZoomChanged((value / _zoomStep).clamp(1.0, sliderMax))
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              // 缩放语义：最左 1.0 = 不缩放（时间轴铺满波形宽度），向右拉长时间轴；
              // 上限按音频长度计算，长音频也能放大到看清一句话。
              // 轨道和圆点保持紧凑，overlay 使用 48px 标准触摸范围。
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                ),
                child: Slider(
                  key: const ValueKey('subtitle-waveform-zoom-slider'),
                  // 不设显式 padding：Flutter 的 Slider padding 只负责布局，
                  // 留白本身不参与命中测试，会让两端圆点外侧形成死区。
                  min: 1.0,
                  max: sliderMax,
                  value: value,
                  semanticFormatterCallback: (_) => l10n.waveformZoom,
                  onChanged: _canZoom ? onZoomChanged : null,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('subtitle-waveform-zoom-in'),
              tooltip: l10n.waveformZoomIn,
              onPressed: _canZoom && value < sliderMax
                  ? () =>
                        onZoomChanged((value * _zoomStep).clamp(1.0, sliderMax))
                  : null,
              icon: const SvgActionIcon(assetName: 'assets/icon/plus.svg'),
            ),
            const SizedBox(width: AppSpacing.s),
            _SpeedChip(
              speed: playbackSpeed,
              options: _speedOptions,
              onSelected: onSpeedChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// 播放速度胶囊：显示当前倍速，点开选择。
class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.options,
    required this.onSelected,
  });

  final double speed;
  final List<double> options;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDefault = speed == 1.0;
    return PopupMenuButton<double>(
      tooltip: l10n.playbackSpeed,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<double>(
            value: option,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${option}x'),
                if (option == speed)
                  Icon(Icons.check, size: 18, color: scheme.primary),
              ],
            ),
          ),
      ],
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s + 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // 非 1x 时用主色提示「当前不是原速」，避免用户忘了调过速度。
          color: isDefault
              ? scheme.surfaceContainerHighest.withValues(alpha: .6)
              : scheme.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speed_rounded,
              size: 16,
              color: isDefault ? scheme.onSurfaceVariant : scheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '${speed}x',
              style: theme.textTheme.labelMedium?.copyWith(
                color: isDefault ? scheme.onSurface : scheme.primary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorError extends StatelessWidget {
  final String message;

  const _EditorError({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.m - 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentenceList extends StatefulWidget {
  final List<Sentence> sentences;
  final int? selectedIndex;
  final int? playingIndex;

  /// 选中句包含的词列表（按时间升序），用于把选中句拆成单词 label。
  final List<WordTimestamp> selectedSentenceWords;

  /// 选中句内与播放头对应的单词序号（见 controller.highlightedWordIndex）；
  /// null 表示播放头不在任何词上。
  final int? highlightedWordIndex;
  final void Function(int index) onPlay;
  final VoidCallback onStop;
  final void Function(int index) onSelect;

  /// 点击选中句某个单词 label 时回调，传入词在句内的序号。
  final void Function(int wordIndex) onWordTap;

  /// 就地编辑某词提交时回调（铅笔），传入词在句内的序号与新文本。
  final void Function(int wordIndex, String newText) onEditWord;

  /// 在某词前 / 后插入新词时回调。
  final void Function(int wordIndex, String text, {required bool after})
  onInsertWords;
  final void Function(int wordIndex) onDeleteWord;

  /// 从某词处分句时回调（剪刀），传入词在句内的序号。
  final void Function(int wordIndex) onSplitWord;
  final void Function(int index) onMergeNext;
  final void Function(int index) onDelete;

  /// 正在整句改文字的句子序号；null 表示没有。
  final int? editingIndex;
  final void Function(int index) onStartEditText;
  final void Function(int index, String text) onCommitText;
  final VoidCallback onCancelText;

  /// 某句前 / 后可插入新句的区间；null 表示空隙不足（菜单项置灰）。
  final SentenceSlot? Function(int index, {required bool after}) insertSlotNear;
  final void Function(int index, {required bool after}) onInsertNear;

  /// 正在输入的新句区间；非 null 时在对应位置显示新句输入行。
  final SentenceSlot? draftSlot;
  final ValueChanged<String> onCommitDraft;
  final VoidCallback onCancelDraft;
  final GuideStep? firstPlayGuideStep;
  final GuideStep? firstMenuGuideStep;

  const _SentenceList({
    required this.sentences,
    required this.selectedIndex,
    required this.playingIndex,
    required this.selectedSentenceWords,
    required this.highlightedWordIndex,
    required this.onPlay,
    required this.onStop,
    required this.onSelect,
    required this.onWordTap,
    required this.onEditWord,
    required this.onInsertWords,
    required this.onDeleteWord,
    required this.onSplitWord,
    required this.onMergeNext,
    required this.onDelete,
    required this.editingIndex,
    required this.onStartEditText,
    required this.onCommitText,
    required this.onCancelText,
    required this.insertSlotNear,
    required this.onInsertNear,
    required this.draftSlot,
    required this.onCommitDraft,
    required this.onCancelDraft,
    this.firstPlayGuideStep,
    this.firstMenuGuideStep,
  });

  @override
  State<_SentenceList> createState() => _SentenceListState();
}

class _SentenceListState extends State<_SentenceList> {
  static const double _kPlayActionWidth = 52;
  static const double _kMenuActionWidth = 44;

  /// 句子行内容的上下留白；左右操作按钮按它对齐首行文字。
  static const double _kRowVerticalPadding = 12;

  final List<GlobalKey> _rowKeys = [];
  final GlobalKey _draftRowKey = GlobalKey(debugLabel: 'subtitleDraftRow');

  @override
  void didUpdateWidget(covariant _SentenceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRowKeys();
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _scrollSelectedIntoView();
    }
    if (widget.draftSlot != null && widget.draftSlot != oldWidget.draftSlot) {
      _scrollIntoView(_draftRowKey);
    }
  }

  /// 新句输入行在列表中的位置：排在开始时间晚于它的第一句之前。
  int? get _draftPosition {
    final slot = widget.draftSlot;
    if (slot == null) return null;
    final index = widget.sentences.indexWhere((s) => s.startTime >= slot.end);
    return index < 0 ? widget.sentences.length : index;
  }

  @override
  void initState() {
    super.initState();
    _syncRowKeys();
  }

  void _syncRowKeys() {
    while (_rowKeys.length < widget.sentences.length) {
      _rowKeys.add(GlobalKey());
    }
    if (_rowKeys.length > widget.sentences.length) {
      _rowKeys.removeRange(widget.sentences.length, _rowKeys.length);
    }
  }

  void _scrollSelectedIntoView() {
    final index = widget.selectedIndex;
    if (index == null || index < 0 || index >= _rowKeys.length) return;
    _scrollIntoView(_rowKeys[index]);
  }

  void _scrollIntoView(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = key.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: .35,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _syncRowKeys();
    if (widget.sentences.isEmpty) {
      return _EmptySentences(message: l10n.subtitleFileEmpty);
    }

    const gutter = _SubtitleSimpleEditorScreenState._gutter;
    final draftPosition = _draftPosition;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.xs,
        gutter,
        AppSpacing.l,
      ),
      itemCount: widget.sentences.length + (draftPosition == null ? 0 : 1),
      itemBuilder: (context, position) {
        if (position == draftPosition) {
          return KeyedSubtree(
            key: _draftRowKey,
            child: _buildDraftRow(context, l10n, widget.draftSlot!),
          );
        }
        final index = draftPosition != null && position > draftPosition
            ? position - 1
            : position;
        // 行内主色换成该句主题色，选中卡片与单词高亮和波形上的句子同色。
        final theme = Theme.of(context);
        return KeyedSubtree(
          key: _rowKeys[index],
          child: Theme(
            data: theme.copyWith(
              colorScheme: SubtitleSentenceColors.schemeFor(
                index,
                theme.colorScheme,
              ),
            ),
            child: Builder(
              builder: (context) => _buildRow(context, l10n, index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, AppLocalizations l10n, int index) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sentence = widget.sentences[index];
    final isSelected = widget.selectedIndex == index;
    final isPlaying = widget.playingIndex == index;
    // 外层已把主色换成该句主题色（见 build）。
    final sentenceColor = scheme.primary;
    final playAction = SizedBox(
      width: _kPlayActionWidth,
      child: Padding(
        padding: const EdgeInsets.only(top: _kRowVerticalPadding - 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: isPlaying ? l10n.stopPlayback : l10n.playSentence,
              child: _PlayButton(
                key: ValueKey('subtitle-sentence-play-$index'),
                isPlaying: isPlaying,
                isSelected: isSelected,
                onTap: isPlaying ? widget.onStop : () => widget.onPlay(index),
              ),
            ),
            const SizedBox(height: 2),
            // 编号胶囊用该句的主题色，与波形上的句子区间颜色对应。
            DecoratedBox(
              decoration: BoxDecoration(
                color: sentenceColor.withValues(alpha: isSelected ? .18 : .1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Text(
                  key: ValueKey('subtitle-sentence-number-$index'),
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    height: 1,
                    color: sentenceColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final menuAction = SizedBox(
      width: _kMenuActionWidth,
      child: Padding(
        padding: const EdgeInsets.only(top: _kRowVerticalPadding - 6),
        child: Align(
          alignment: Alignment.topCenter,
          child: PopupMenuButton<_SentenceAction>(
            padding: EdgeInsets.zero,
            iconSize: 20,
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            position: PopupMenuPosition.under,
            icon: Icon(
              Icons.more_horiz_rounded,
              color: scheme.onSurfaceVariant.withValues(alpha: .8),
            ),
            itemBuilder: (context) {
              final canInsertAbove =
                  widget.insertSlotNear(index, after: false) != null;
              final canInsertBelow =
                  widget.insertSlotNear(index, after: true) != null;
              return [
                PopupMenuItem(
                  value: _SentenceAction.editText,
                  child: _MenuRow(
                    icon: Icons.edit_note_rounded,
                    label: l10n.subtitleEditSentenceText,
                  ),
                ),
                const PopupMenuDivider(),
                _insertMenuItem(
                  l10n,
                  action: _SentenceAction.insertAbove,
                  label: l10n.subtitleInsertSentenceAbove,
                  icon: Icons.vertical_align_top_rounded,
                  enabled: canInsertAbove,
                ),
                _insertMenuItem(
                  l10n,
                  action: _SentenceAction.insertBelow,
                  label: l10n.subtitleInsertSentenceBelow,
                  icon: Icons.vertical_align_bottom_rounded,
                  enabled: canInsertBelow,
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _SentenceAction.mergePrevious,
                  enabled: index > 0,
                  child: _MenuRow(
                    icon: Icons.merge_rounded,
                    label: l10n.mergeWithPreviousSentence,
                  ),
                ),
                PopupMenuItem(
                  value: _SentenceAction.mergeNext,
                  enabled: index < widget.sentences.length - 1,
                  child: _MenuRow(
                    icon: Icons.call_merge,
                    label: l10n.mergeWithNextSentence,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _SentenceAction.delete,
                  enabled: widget.sentences.length > 1,
                  child: _MenuRow(
                    iconWidget: SvgActionIcon(
                      assetName: 'assets/icon/trash-bin.svg',
                      size: 20,
                      color: scheme.error,
                    ),
                    label: l10n.deleteSentence,
                    color: scheme.error,
                  ),
                ),
              ];
            },
            onSelected: (action) {
              switch (action) {
                case _SentenceAction.editText:
                  widget.onStartEditText(index);
                case _SentenceAction.insertAbove:
                  widget.onInsertNear(index, after: false);
                case _SentenceAction.insertBelow:
                  widget.onInsertNear(index, after: true);
                case _SentenceAction.mergePrevious:
                  widget.onMergeNext(index - 1);
                case _SentenceAction.mergeNext:
                  widget.onMergeNext(index);
                case _SentenceAction.delete:
                  widget.onDelete(index);
              }
            },
          ),
        ),
      ),
    );
    // 新手引导只挂在第一句，用户能立即理解每行左右两侧的操作分区。
    final guidedPlayAction = index == 0 && widget.firstPlayGuideStep != null
        ? GuideTarget(step: widget.firstPlayGuideStep!, child: playAction)
        : playAction;
    final guidedMenuAction = index == 0 && widget.firstMenuGuideStep != null
        ? GuideTarget(step: widget.firstMenuGuideStep!, child: menuAction)
        : menuAction;
    // 选中句是正在编辑的句子：抬升为带主色描边的卡片；播放中的非选中句只淡淡铺底。
    final Color rowColor;
    if (isSelected) {
      rowColor = scheme.surface;
    } else if (isPlaying) {
      rowColor = scheme.primary.withValues(alpha: .06);
    } else {
      rowColor = Colors.transparent;
    }
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.45,
      color: scheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: rowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isSelected
              ? BorderSide(color: scheme.primary.withValues(alpha: .55))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onSelect(index),
          // 行内就地编辑的 TextField 是本 InkWell 的后代，其获焦会让本
          // InkWell 的 focusNode.hasFocus 为真而绘制 focus 高亮（整列变深
          // 灰）。选中行不需要 focus 高亮，置空避免编辑时背景变深。
          focusColor: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              guidedPlayAction,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: _kRowVerticalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 选中句拆成单词 label（可点词播放并显示词边界）；
                      // 其余句保持纯文本，降低视觉噪音、突出当前编辑句。
                      if (widget.editingIndex == index)
                        _SentenceTextField(
                          key: ValueKey('subtitle-sentence-text-field-$index'),
                          initialText: sentence.text,
                          hintText: null,
                          onCommit: (text) => widget.onCommitText(index, text),
                          onCancel: widget.onCancelText,
                        )
                      else if (isSelected)
                        _SentenceWordLabels(
                          text: sentence.text,
                          words: widget.selectedSentenceWords,
                          highlightedWordIndex: widget.highlightedWordIndex,
                          onWordTap: widget.onWordTap,
                          onEditWord: widget.onEditWord,
                          onInsertWords: widget.onInsertWords,
                          onDeleteWord: widget.onDeleteWord,
                          onSplitWord: widget.onSplitWord,
                        )
                      else
                        Text(sentence.text, style: textStyle),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeRangeText(
                              start: sentence.startTime,
                              end: sentence.endTime,
                            ),
                          ),
                          if (isSelected && widget.editingIndex != index)
                            _EditTextButton(
                              key: ValueKey(
                                'subtitle-sentence-edit-text-$index',
                              ),
                              onPressed: () => widget.onStartEditText(index),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              guidedMenuAction,
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_SentenceAction> _insertMenuItem(
    AppLocalizations l10n, {
    required _SentenceAction action,
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    final item = PopupMenuItem(
      value: action,
      enabled: enabled,
      child: _MenuRow(icon: icon, label: label),
    );
    if (enabled) return item;
    // 置灰时说明原因，用户知道该先拖边界腾出位置。
    return PopupMenuItem(
      value: action,
      enabled: false,
      child: Tooltip(
        message: l10n.subtitleInsertSentenceNoGap,
        child: _MenuRow(icon: icon, label: label),
      ),
    );
  }

  /// 新句输入行：位置与时间按空隙确定，确认文字后才插入字幕。
  Widget _buildDraftRow(
    BuildContext context,
    AppLocalizations l10n,
    SentenceSlot slot,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.primary.withValues(alpha: .55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _kPlayActionWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: _kRowVerticalPadding + 2),
                child: SvgActionIcon(
                  assetName: 'assets/icon/plus.svg',
                  size: 22,
                  color: scheme.primary,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _kRowVerticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SentenceTextField(
                      key: const ValueKey('subtitle-new-sentence-field'),
                      initialText: '',
                      hintText: l10n.subtitleNewSentenceHint,
                      onCommit: widget.onCommitDraft,
                      onCancel: widget.onCancelDraft,
                    ),
                    const SizedBox(height: 4),
                    _TimeRangeText(start: slot.start, end: slot.end),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: _kMenuActionWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: _kRowVerticalPadding - 6),
                child: IconButton(
                  key: const ValueKey('subtitle-new-sentence-cancel'),
                  iconSize: 20,
                  tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
                  onPressed: widget.onCancelDraft,
                  icon: Icon(
                    Icons.close_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 句子时间区间与时长，如「00:04.000 - 00:08.000 · 4.0s」。
class _TimeRangeText extends StatelessWidget {
  const _TimeRangeText({required this.start, required this.end});

  final Duration start;
  final Duration end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '${_formatTime(start)} - ${_formatTime(end)} · '
      '${_formatSeconds(end - start)}',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .75),
        letterSpacing: .1,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  static String _formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = duration.inMilliseconds
        .remainder(1000)
        .toString()
        .padLeft(3, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds.$milliseconds';
    }
    return '$minutes:$seconds.$milliseconds';
  }

  static String _formatSeconds(Duration duration) {
    final clamped = duration.isNegative ? Duration.zero : duration;
    final seconds = clamped.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }
}

/// 选中句右下角的「编辑文字」入口：整句改文字，比逐词点开改更直接。
class _EditTextButton extends StatelessWidget {
  const _EditTextButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note_rounded, size: 16, color: color),
            const SizedBox(width: 3),
            Text(
              AppLocalizations.of(context)!.subtitleEditSentenceText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 整句文字 / 新句输入框：回车或点别处保存，Esc 取消。
///
/// 只提交一次：回车保存后输入框随即移除，此后的「点别处」不会重复提交。
class _SentenceTextField extends StatefulWidget {
  const _SentenceTextField({
    super.key,
    required this.initialText,
    required this.hintText,
    required this.onCommit,
    required this.onCancel,
  });

  final String initialText;
  final String? hintText;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;

  @override
  State<_SentenceTextField> createState() => _SentenceTextFieldState();
}

class _SentenceTextFieldState extends State<_SentenceTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  final FocusNode _focusNode = FocusNode();
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  /// 键盘操作提示只在桌面端显示（触屏用键盘上的「完成」）。
  static bool get _showsKeyboardHint => switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    if (_isDone) return;
    _isDone = true;
    final text = _controller.text.trim();
    // 新句留空等于放弃；已有句子清空交给上层按「删除该句」处理。
    if (text.isEmpty && widget.initialText.isEmpty) {
      widget.onCancel();
      return;
    }
    widget.onCommit(text);
  }

  void _cancel() {
    if (_isDone) return;
    _isDone = true;
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            minLines: 1,
            maxLines: null,
            // 字幕按空格分词，换行没有意义：回车直接保存。
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _commit(),
            onTapOutside: (_) => _commit(),
            // 获焦时滚动露出输入框下方的操作提示与时间行，避免被屏幕底边或键盘挡住。
            scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hintText,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: .35),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: scheme.primary, width: 1.5),
              ),
            ),
          ),
        ),
        if (_showsKeyboardHint)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              AppLocalizations.of(context)!.subtitleTextEditHint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: .7),
              ),
            ),
          ),
      ],
    );
  }
}

/// 选中句的单词 label 流。
///
/// 直接以词级时间戳列表（[words]）逐词渲染成可点 chip：第 i 个 chip 严格对应
/// 第 i 个词，点击播放该词并在波形上显示该词及左右各两词的边界，避免「label 与
/// 词数不一致导致点 A 词却播 B 词」。点中词用 primary 强调。无词时退化为纯文本。
///
/// 点击单词除播放外，还在该词上方弹出带指向三角的悬浮工具栏：
/// - 编辑 → 该 chip 就地变输入框，回车或点别处提交、Esc 取消（[onEditWord]）。
/// - 前插 / 后插 → 在该词旁出现空输入框，输入的词插到该词前 / 后（[onInsertWords]）。
/// - 断句 → 从该词左边界分句，该词成为下一句首词（[onSplitWord]，首词没有）。
/// - 删除 → 删掉该词（[onDeleteWord]）。
class _SentenceWordLabels extends StatefulWidget {
  final String text;
  final List<WordTimestamp> words;

  /// 与播放头对应的单词序号，高亮显示。
  final int? highlightedWordIndex;
  final void Function(int wordIndex) onWordTap;
  final void Function(int wordIndex, String newText) onEditWord;
  final void Function(int wordIndex, String text, {required bool after})
  onInsertWords;
  final void Function(int wordIndex) onDeleteWord;
  final void Function(int wordIndex) onSplitWord;

  const _SentenceWordLabels({
    required this.text,
    required this.words,
    required this.highlightedWordIndex,
    required this.onWordTap,
    required this.onEditWord,
    required this.onInsertWords,
    required this.onDeleteWord,
    required this.onSplitWord,
  });

  @override
  State<_SentenceWordLabels> createState() => _SentenceWordLabelsState();
}

class _SentenceWordLabelsState extends State<_SentenceWordLabels> {
  /// 每个 chip 一个 LayerLink，供悬浮工具栏锚定到对应词上方。
  final List<LayerLink> _links = [];

  /// 每个 chip 的 key：计算工具栏贴边平移时读 chip 在屏幕上的位置。
  final List<GlobalKey> _chipKeys = [];

  /// 单一常驻 Overlay 入口：切换显示哪个词的工具栏只靠 markNeedsBuild，
  /// 避免反复 insert/remove 引发的竞态（旧 entry 误删新 entry）。
  OverlayEntry? _toolbarEntry;

  /// 当前显示工具栏的词序号；null 表示不显示。
  int? _toolbarIndex;

  /// 工具栏药丸的横向平移：居中于词时若超出屏幕边缘，平移回屏内（指向三角仍对准
  /// 词）。null 表示尚未测量，这一帧先透明绘制、测量后再显示，避免跳动可见。
  double? _toolbarShift;
  final GlobalKey _toolbarPillKey = GlobalKey(debugLabel: 'wordToolbarPill');

  /// 工具栏与屏幕左右边缘的最小间距。
  static const double _toolbarEdgeMargin = 8;

  /// 测量失败（药丸这一帧还没布局完）时的已重试次数；超过上限就按居中显示，
  /// 保证工具栏不会一直透明。
  int _toolbarMeasureAttempts = 0;
  static const int _maxToolbarMeasureAttempts = 5;

  /// 当前就地编辑的词序号；null 表示无编辑。
  int? _editingIndex;

  /// 正在插入新词的参照词序号与方向；null 表示没有在插入。
  int? _insertAnchor;
  bool _insertAfter = false;

  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocus = FocusNode();

  /// chip 与工具栏同组：点组内（任意 chip / 工具栏）不触发工具栏外部关闭，
  /// 点组外（其他句、波形、空白）才关闭，从而点别的词能直接重锚而不发生竞态。
  final Object _tapGroupId = Object();

  @override
  void initState() {
    super.initState();
    _syncLinks();
  }

  void _syncLinks() {
    while (_links.length < widget.words.length) {
      _links.add(LayerLink());
      _chipKeys.add(GlobalKey());
    }
    if (_links.length > widget.words.length) {
      _links.removeRange(widget.words.length, _links.length);
      _chipKeys.removeRange(widget.words.length, _chipKeys.length);
    }
  }

  @override
  void didUpdateWidget(covariant _SentenceWordLabels oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLinks();
    // 词数变化（编辑/分句导致）→ 关闭悬浮态，避免索引错位。
    if (widget.words.length != oldWidget.words.length) {
      if (_editingIndex != null && _editingIndex! >= widget.words.length) {
        _editingIndex = null;
      }
      _insertAnchor = null;
      _hideToolbar();
    }
  }

  @override
  void dispose() {
    _toolbarEntry?.remove();
    _toolbarEntry = null;
    _editController.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  void _ensureToolbarEntry() {
    if (_toolbarEntry != null) return;
    _toolbarEntry = OverlayEntry(builder: _buildToolbarLayer);
    Overlay.of(context).insert(_toolbarEntry!);
  }

  void _showToolbar(int index) {
    _ensureToolbarEntry();
    setState(() {
      _toolbarIndex = index;
      _toolbarShift = null;
      _toolbarMeasureAttempts = 0;
    });
    _toolbarEntry?.markNeedsBuild();
  }

  /// 按词 chip 的屏幕位置与药丸宽度，算出把药丸收回屏内所需的平移。
  ///
  /// 不直接读药丸的位置：它跟随词 chip 的位置在合成阶段才更新，帧后读到的可能还是
  /// 跟随前的旧位置。chip 在普通布局树里，位置可靠；药丸宽度与位置无关。
  void _measureToolbar() {
    final index = _toolbarIndex;
    if (!mounted || index == null || index >= _chipKeys.length) return;
    final pill = _toolbarPillKey.currentContext?.findRenderObject();
    final chip = _chipKeys[index].currentContext?.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (pill is! RenderBox ||
        chip is! RenderBox ||
        overlay is! RenderBox ||
        !pill.hasSize ||
        !chip.hasSize) {
      // 这一帧还没布局完：下一帧重建并再测；多次失败则不平移直接显示。
      _toolbarMeasureAttempts++;
      if (_toolbarMeasureAttempts >= _maxToolbarMeasureAttempts) {
        _toolbarShift = 0;
      }
      _toolbarEntry?.markNeedsBuild();
      return;
    }
    final chipCenter = chip
        .localToGlobal(chip.size.center(Offset.zero), ancestor: overlay)
        .dx;
    final left = chipCenter - pill.size.width / 2;
    final right = left + pill.size.width;
    final maxRight = overlay.size.width - _toolbarEdgeMargin;
    var shift = 0.0;
    if (left < _toolbarEdgeMargin) {
      shift = _toolbarEdgeMargin - left;
    } else if (right > maxRight) {
      shift = maxRight - right;
    }
    // 已在正确位置就不再重建，避免每帧循环。
    final applied = _toolbarShift;
    if (applied != null && (shift - applied).abs() < .5) return;
    _toolbarShift = shift;
    _toolbarEntry?.markNeedsBuild();
  }

  void _hideToolbar() {
    if (_toolbarIndex == null) return;
    setState(() => _toolbarIndex = null);
    _toolbarEntry?.markNeedsBuild();
  }

  void _onWordTap(int index) {
    if (_editingIndex != null) _commitEdit();
    if (_insertAnchor != null) _commitInsert();
    widget.onWordTap(index);
    _showToolbar(index);
  }

  void _startEditing(int index) {
    _hideToolbar();
    setState(() {
      _insertAnchor = null;
      _editingIndex = index;
      _editController.text = widget.words[index].word;
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.length,
      );
    });
    _focusEditField();
  }

  /// 输入框出现后的下一帧请求焦点（输入框此时才挂到树上）。
  void _focusEditField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editFocus.requestFocus();
    });
  }

  /// 提交就地编辑：文本无实质变化则只退出编辑态，否则上报 [onEditWord]。
  void _commitEdit() {
    final index = _editingIndex;
    if (index == null) return;
    final text = _editController.text;
    final original = index < widget.words.length
        ? widget.words[index].word
        : '';
    setState(() => _editingIndex = null);
    if (text.trim() == original.trim()) return;
    widget.onEditWord(index, text);
  }

  void _cancelEdit() => setState(() => _editingIndex = null);

  void _startInserting(int index, {required bool after}) {
    _hideToolbar();
    setState(() {
      _editingIndex = null;
      _insertAnchor = index;
      _insertAfter = after;
      _editController.clear();
    });
    _focusEditField();
  }

  /// 提交插入：留空等于放弃。
  void _commitInsert() {
    final anchor = _insertAnchor;
    if (anchor == null) return;
    final text = _editController.text.trim();
    setState(() => _insertAnchor = null);
    if (text.isEmpty) return;
    widget.onInsertWords(anchor, text, after: _insertAfter);
  }

  void _cancelInsert() => setState(() => _insertAnchor = null);

  void _delete(int index) {
    _hideToolbar();
    widget.onDeleteWord(index);
  }

  void _split(int index) {
    _hideToolbar();
    widget.onSplitWord(index);
  }

  @override
  Widget build(BuildContext context) {
    // label 与词级数据同源：保证「点中的词 = 播放的词 = 波形高亮的词」一致。
    if (widget.words.isEmpty) return Text(widget.text);
    _syncLinks();

    final insertAnchor = _insertAnchor;
    final insertPosition = insertAnchor == null
        ? null
        : (_insertAfter ? insertAnchor + 1 : insertAnchor);
    final insertField = _buildEditField(
      key: const ValueKey('subtitle-word-insert-field'),
      hintText: AppLocalizations.of(context)!.subtitleNewWordHint,
      onCommit: _commitInsert,
      onCancel: _cancelInsert,
    );
    return TapRegion(
      groupId: _tapGroupId,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = 0; i < widget.words.length; i++) ...[
            if (insertPosition == i) insertField,
            CompositedTransformTarget(
              key: _chipKeys[i],
              link: _links[i],
              child: _editingIndex == i
                  ? _buildEditField(
                      key: ValueKey('subtitle-word-edit-$i'),
                      onCommit: _commitEdit,
                      onCancel: _cancelEdit,
                    )
                  : _WordChip(
                      key: ValueKey('subtitle-word-label-$i'),
                      label: widget.words[i].word,
                      isHighlighted: widget.highlightedWordIndex == i,
                      onTap: () => _onWordTap(i),
                    ),
            ),
          ],
          if (insertPosition == widget.words.length) insertField,
        ],
      ),
    );
  }

  /// 就地输入框（改词 / 插词）：仿 chip 紧凑样式，回车或点别处提交，Esc 取消。
  Widget _buildEditField({
    required Key key,
    String? hintText,
    required VoidCallback onCommit,
    required VoidCallback onCancel,
  }) {
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onCancel},
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 56),
        child: IntrinsicWidth(
          child: TextField(
            key: key,
            controller: _editController,
            focusNode: _editFocus,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onCommit(),
            onTapOutside: (_) => onCommit(),
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Overlay 层：按 [_toolbarIndex] 把工具栏锚定到对应词上方；无则空。
  ///
  /// 浮层由「药丸 + 指向三角」组成：三角尖端朝下指向所属词，明确浮层归属哪个词。
  /// 剪刀=「在该词左边界断句」，故按钮文案为「前断句」，配合三角让断句落点可辨。
  Widget _buildToolbarLayer(BuildContext ctx) {
    final index = _toolbarIndex;
    if (index == null || index >= _links.length) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(ctx)!;
    final theme = Theme.of(ctx);
    final scheme = theme.colorScheme;
    final shift = _toolbarShift;
    // 每次重建后复核一次位置：词换行、窗口缩放或某一帧测到过时的位置时自动纠正。
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureToolbar());
    // 深色药丸（inverseSurface）：与浅灰选中行 / chip 形成强对比，浮层边界清晰。
    final surface = scheme.inverseSurface;
    final onSurface = scheme.onInverseSurface;
    final divider = Container(
      width: 1,
      height: 20,
      color: onSurface.withValues(alpha: .24),
    );
    // Align 给 follower 松约束，使工具栏按内容尺寸收缩（否则在 Overlay 紧约束下会
    // 撑满全屏宽，bottomCenter 锚点把它推到屏外）。follower 的图层变换再锚到对应词。
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _links[index],
        showWhenUnlinked: false,
        targetAnchor: Alignment.topCenter,
        followerAnchor: Alignment.bottomCenter,
        offset: const Offset(0, -4),
        child: TapRegion(
          groupId: _tapGroupId,
          onTapOutside: (_) => _hideToolbar(),
          // 药丸在上、三角在下：三角随 follower 的 bottomCenter 锚到词正上方，
          // 形成「气泡指向该词」的视觉，断句落点与所属词不再含糊。
          child: Opacity(
            opacity: shift == null ? 0 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(shift ?? 0, 0),
                  child: Material(
                    key: _toolbarPillKey,
                    elevation: 4,
                    shadowColor: Colors.black.withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(10),
                    color: surface,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ToolbarButton(
                          key: ValueKey('subtitle-word-edit-button-$index'),
                          iconWidget: SvgActionIcon(
                            assetName: 'assets/icon/edit.svg',
                            size: 16,
                            color: onSurface,
                          ),
                          label: l10n.wordEditAction,
                          tooltip: l10n.editWord,
                          color: onSurface,
                          onPressed: () => _startEditing(index),
                        ),
                        divider,
                        _ToolbarButton(
                          key: ValueKey('subtitle-word-insert-before-$index'),
                          iconWidget: _InsertWordIcon(
                            after: false,
                            color: onSurface,
                          ),
                          tooltip: l10n.insertWordBefore,
                          color: onSurface,
                          onPressed: () => _startInserting(index, after: false),
                        ),
                        _ToolbarButton(
                          key: ValueKey('subtitle-word-insert-after-$index'),
                          iconWidget: _InsertWordIcon(
                            after: true,
                            color: onSurface,
                          ),
                          tooltip: l10n.insertWordAfter,
                          color: onSurface,
                          onPressed: () => _startInserting(index, after: true),
                        ),
                        divider,
                        // 首词前分句会产生空句，故首词不提供剪刀。
                        if (index > 0)
                          _ToolbarButton(
                            key: ValueKey('subtitle-word-split-button-$index'),
                            icon: Icons.content_cut,
                            tooltip: l10n.splitSentenceHere,
                            color: onSurface,
                            onPressed: () => _split(index),
                          ),
                        _ToolbarButton(
                          key: ValueKey('subtitle-word-delete-button-$index'),
                          icon: Icons.delete_outline_rounded,
                          tooltip: l10n.deleteWord,
                          color: onSurface,
                          onPressed: () => _delete(index),
                        ),
                      ],
                    ),
                  ),
                ),
                CustomPaint(
                  size: const Size(14, 7),
                  painter: _CaretPainter(color: surface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 浮层底部朝下的小三角指示器，尖端指向所属词。
class _CaretPainter extends CustomPainter {
  final Color color;

  const _CaretPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) => oldDelegate.color != color;
}

/// 悬浮工具栏内的紧凑按钮。最常用的「编辑」带文案，其余只用图标 + 提示，
/// 保证五个动作在手机宽度下也能排成一行。
class _ToolbarButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String? label;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _ToolbarButton({
    super.key,
    this.icon,
    this.iconWidget,
    this.label,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        // 深色药丸上默认 overlay 几乎不可见，显式用前景色做 hover / 按压高亮。
        hoverColor: color.withValues(alpha: .12),
        highlightColor: color.withValues(alpha: .12),
        splashColor: color.withValues(alpha: .18),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label == null ? 10 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget ?? Icon(icon, size: 16, color: color),
              if (label case final text?) ...[
                const SizedBox(width: 5),
                Text(
                  text,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 「插词」图标：小方块代表当前词，加号在哪一侧就插到哪一侧。
class _InsertWordIcon extends StatelessWidget {
  const _InsertWordIcon({required this.after, required this.color});

  final bool after;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final word = Container(
      width: 9,
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: .7), width: 1.4),
      ),
    );
    final plus = SvgActionIcon(
      assetName: 'assets/icon/plus.svg',
      size: 14,
      color: color,
    );
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: after ? [word, plus] : [plus, word],
      ),
    );
  }
}

/// 单个单词 chip。默认淡底暗示「可点」；播放头所在的词用 primary 底色 + 描边 +
/// 文字色强调，与波形上标出的单词区间、视频画面同步。
class _WordChip extends StatelessWidget {
  final String label;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _WordChip({
    super.key,
    required this.label,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: isHighlighted
          ? scheme.primary.withValues(alpha: .12)
          : scheme.surfaceContainerHighest.withValues(alpha: .45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isHighlighted
              ? scheme.primary.withValues(alpha: .6)
              : Colors.transparent,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          // 字重在 focus 态不变（否则加粗变宽会触发 Wrap 重新折行、整体布局跳动），
          // 仅靠颜色 + 底色 + 描边表达选中。
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: isHighlighted ? scheme.primary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// 句子行左侧的圆形播放按钮：选中句淡主色底，播放中主色实心显示停止。
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    super.key,
    required this.isPlaying,
    required this.isSelected,
    required this.onTap,
  });

  static const double _size = 34;

  final bool isPlaying;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;
    if (isPlaying) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else if (isSelected) {
      background = scheme.primary.withValues(alpha: .12);
      foreground = scheme.primary;
    } else {
      background = Colors.transparent;
      foreground = scheme.onSurfaceVariant;
    }
    return Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: _size,
          child: Icon(
            isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 22,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// 没有任何句子时的空状态。
class _EmptySentences extends StatelessWidget {
  const _EmptySentences({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.subtitles_off_outlined,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.m - 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;

  /// 可选着色，破坏性操作（删除）传 [colorScheme.error] 以示警示。
  final Color? color;

  const _MenuRow({this.icon, this.iconWidget, required this.label, this.color})
    : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        iconWidget ?? Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}

enum _SentenceAction {
  editText,
  insertAbove,
  insertBelow,
  mergePrevious,
  mergeNext,
  delete,
}
