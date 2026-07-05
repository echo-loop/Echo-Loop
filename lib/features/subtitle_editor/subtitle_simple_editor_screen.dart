import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/word_timestamp.dart';
import '../../providers/new_user_guide_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/guide_flow.dart';
import 'subtitle_editor_controller.dart';
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
  final GlobalKey _guideSentencePlayKey = GlobalKey(
    debugLabel: 'subtitleEditorSentencePlay',
  );
  final GlobalKey _guideSentenceMenuKey = GlobalKey(
    debugLabel: 'subtitleEditorSentenceMenu',
  );
  final GlobalKey _guideBoundaryHandleKey = GlobalKey(
    debugLabel: 'subtitleEditorBoundaryHandle',
  );

  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).track(Events.subtitleEditorOpened, {
      EventParams.audioId: widget.audioItem.id,
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(subtitleEditorControllerProvider(widget.audioItem).notifier)
            .load(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(subtitleEditorControllerProvider(widget.audioItem));
    final controller = ref.read(
      subtitleEditorControllerProvider(widget.audioItem).notifier,
    );

    // 时长就绪后，按屏幕物理宽度设置初始缩放（每厘米约 1 秒音频）；幂等，仅生效一次。
    if (state.totalDuration != null) {
      final usableWidth =
          MediaQuery.sizeOf(context).width -
          SubtitleWaveformView.horizontalPadding * 2;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.initZoomForViewport(usableWidth);
      });
    }

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
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.editSubtitles),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s),
                child: FilledButton.tonal(
                  key: const ValueKey('subtitle-editor-save-button'),
                  // AppBar 内收紧默认主题的大 padding，保持紧凑
                  style: FilledButton.styleFrom(
                    backgroundColor: state.isDirty && !state.isSaving
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    foregroundColor: state.isDirty && !state.isSaving
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    ),
                    minimumSize: const Size(0, 36),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: !state.isDirty || state.isSaving
                      ? null
                      : () => unawaited(_save(context, controller, l10n)),
                  child: state.isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
              ),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.errorMessage != null
              ? _EditorError(message: state.errorMessage!)
              : Column(
                  children: [
                    GuideTarget(
                      step: boundaryHandleStep,
                      child: SubtitleWaveformView(
                        waveform: state.waveform,
                        extractionProgress: state.waveformProgress,
                        extractionFailed: state.waveformFailed,
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
                        wordBoundaries: controller.wordBoundariesForWaveform,
                        onAdjustWord: controller.adjustWord,
                        zoomScale: state.waveformZoomScale,
                        onZoomChanged: controller.setWaveformZoomScale,
                        onScrub: controller.scrubTo,
                        onScrubEnd: (position) =>
                            unawaited(controller.finishScrub(position)),
                        onAdjustEnd: () {},
                      ),
                    ),
                    _WaveformControls(
                      zoomScale: state.waveformZoomScale,
                      maxZoomScale: state.maxWaveformZoomScale,
                      playbackSpeed: state.playbackSpeed,
                      onZoomChanged: controller.setWaveformZoomScale,
                      onSpeedChanged: (speed) =>
                          unawaited(controller.setPlaybackSpeed(speed)),
                    ),
                    Expanded(
                      child: _SentenceList(
                        sentences: state.sentences,
                        selectedIndex: state.selectedSentenceIndex,
                        playingIndex: state.playingSentenceIndex,
                        selectedSentenceWords:
                            controller.wordsOfSelectedSentence,
                        focusedWordIndex: state.focusedWordIndex,
                        onPlay: (index) =>
                            unawaited(controller.playSentence(index)),
                        onStop: () => unawaited(controller.stopPlayback()),
                        onSelect: controller.selectSentence,
                        onWordTap: (index) =>
                            unawaited(controller.playWord(index)),
                        onEditWord: controller.editWord,
                        onSplitWord: controller.splitSentenceAtWord,
                        onMergeNext: controller.mergeWithNext,
                        onDelete: (index) =>
                            _deleteSentence(context, controller, l10n, index),
                        firstPlayGuideStep: sentencePlayStep,
                        firstMenuGuideStep: sentenceMenuStep,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    SubtitleEditorController controller,
    AppLocalizations l10n,
  ) async {
    // 仅调整时间戳（句子数量不变）不会清空学习进度和收藏，无需弹窗确认。
    // 句子数量变化但本音频没有学习进度/收藏时，也直接保存，不打断用户。
    final needsConfirmation = await controller.hasResettableLearningData();
    if (!context.mounted) return;
    if (needsConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.saveSubtitleEdits),
          content: Text(l10n.subtitleStructureChangedWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final saved = await controller.save();
    if (saved && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.subtitleEditsSaved)));
    }
  }

  /// 删除句子并提供撤销入口。
  ///
  /// 删除前快照当前列表，删除后用 SnackBar 反馈，点击「撤销」即还原快照。
  void _deleteSentence(
    BuildContext context,
    SubtitleEditorController controller,
    AppLocalizations l10n,
    int index,
  ) {
    final snapshot = List<Sentence>.from(
      ref.read(subtitleEditorControllerProvider(widget.audioItem)).sentences,
    );
    controller.deleteSentence(index);
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.sentenceDeleted),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => controller.restoreSentences(snapshot),
        ),
      ),
    );
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

class _WaveformControls extends StatelessWidget {
  static const _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  final double zoomScale;
  final double maxZoomScale;
  final double playbackSpeed;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<double> onSpeedChanged;

  const _WaveformControls({
    required this.zoomScale,
    required this.maxZoomScale,
    required this.playbackSpeed,
    required this.onZoomChanged,
    required this.onSpeedChanged,
  });

  /// 音频长度允许放大时才启用缩放滑块（短音频整段已铺满屏宽，无需放大）。
  bool get _canZoom => maxZoomScale > 1.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          AppSpacing.xs + 2,
          AppSpacing.m,
          AppSpacing.s,
        ),
        child: Row(
          children: [
            Text(
              l10n.waveformZoom,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              // 缩放语义：最左 1.0 = 不缩放（时间轴铺满屏宽），向右拉长时间轴；
              // 上限按音频长度计算，长音频也能放大到看清一句话。
              // 轨道调细、圆点调小，和紧凑控制条保持一致。
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  key: const ValueKey('subtitle-waveform-zoom-slider'),
                  // 触控目标：横向 padding ≥ overlay 半径，保证圆点在两端也有完整可
                  // 抓取区域（否则外侧被裁，端点最难点中）；纵向留白补回足够高度的
                  // 命中区，避免触摸/鼠标难以抓住小圆点。
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.s,
                  ),
                  min: 1.0,
                  max: _canZoom ? maxZoomScale : 2.0,
                  value: zoomScale.clamp(1.0, _canZoom ? maxZoomScale : 2.0),
                  onChanged: _canZoom ? onZoomChanged : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.l),
            Text(
              l10n.playbackSpeed,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            PopupMenuButton<double>(
              tooltip: l10n.playbackSpeed,
              onSelected: onSpeedChanged,
              itemBuilder: (context) => [
                for (final speed in _speedOptions)
                  PopupMenuItem<double>(
                    value: speed,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${speed}x'),
                        if (speed == playbackSpeed)
                          Icon(
                            Icons.check,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
              ],
              // 速度按钮：带边框紧凑 chip，明确「这是可点的控件」
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${playbackSpeed}x',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
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

  /// 选中句内当前点中词的序号；null 表示无点中词（label 无强调）。
  final int? focusedWordIndex;
  final void Function(int index) onPlay;
  final VoidCallback onStop;
  final void Function(int index) onSelect;

  /// 点击选中句某个单词 label 时回调，传入词在句内的序号。
  final void Function(int wordIndex) onWordTap;

  /// 就地编辑某词提交时回调（铅笔），传入词在句内的序号与新文本。
  final void Function(int wordIndex, String newText) onEditWord;

  /// 从某词处分句时回调（剪刀），传入词在句内的序号。
  final void Function(int wordIndex) onSplitWord;
  final void Function(int index) onMergeNext;
  final void Function(int index) onDelete;
  final GuideStep? firstPlayGuideStep;
  final GuideStep? firstMenuGuideStep;

  const _SentenceList({
    required this.sentences,
    required this.selectedIndex,
    required this.playingIndex,
    required this.selectedSentenceWords,
    required this.focusedWordIndex,
    required this.onPlay,
    required this.onStop,
    required this.onSelect,
    required this.onWordTap,
    required this.onEditWord,
    required this.onSplitWord,
    required this.onMergeNext,
    required this.onDelete,
    this.firstPlayGuideStep,
    this.firstMenuGuideStep,
  });

  @override
  State<_SentenceList> createState() => _SentenceListState();
}

class _SentenceListState extends State<_SentenceList> {
  static const double _kPlayActionWidth = 52;
  static const double _kMenuActionWidth = 44;

  final List<GlobalKey> _rowKeys = [];

  @override
  void didUpdateWidget(covariant _SentenceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRowKeys();
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _scrollSelectedIntoView();
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _rowKeys[index].currentContext;
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
      return Center(child: Text(l10n.subtitleFileEmpty));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.sentences.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final theme = Theme.of(context);
        final sentence = widget.sentences[index];
        final isSelected = widget.selectedIndex == index;
        final isPlaying = widget.playingIndex == index;
        final rowColor = isSelected || isPlaying
            ? theme.colorScheme.primaryContainer.withValues(alpha: .35)
            : Colors.transparent;
        final playAction = SizedBox(
          width: _kPlayActionWidth,
          child: Tooltip(
            message: isPlaying ? l10n.stopPlayback : l10n.playSentence,
            child: InkWell(
              key: ValueKey('subtitle-sentence-play-$index'),
              onTap: isPlaying ? widget.onStop : () => widget.onPlay(index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Icon(
                      isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      // 播放中用 primary 实色单点强调，区别于「仅选中定位」的行底高亮
                      color: isPlaying ? theme.colorScheme.primary : null,
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 0,
                    right: 0,
                    child: Text(
                      key: ValueKey('subtitle-sentence-number-$index'),
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        height: 1,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: .62,
                        ),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final menuAction = SizedBox(
          width: _kMenuActionWidth,
          child: PopupMenuButton<_SentenceAction>(
            padding: EdgeInsets.zero,
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            child: Center(
              child: Icon(
                Icons.more_horiz,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SentenceAction.mergeNext,
                enabled: index < widget.sentences.length - 1,
                child: _MenuRow(
                  icon: Icons.call_merge,
                  label: l10n.mergeWithNextSentence,
                ),
              ),
              PopupMenuItem(
                value: _SentenceAction.delete,
                enabled: widget.sentences.length > 1,
                child: _MenuRow(
                  icon: Icons.delete_outline,
                  label: l10n.deleteSentence,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            onSelected: (action) {
              switch (action) {
                case _SentenceAction.mergeNext:
                  widget.onMergeNext(index);
                case _SentenceAction.delete:
                  widget.onDelete(index);
              }
            },
          ),
        );
        // 新手引导只挂在第一句，用户能立即理解每行左右两侧的操作分区。
        final guidedPlayAction = index == 0 && widget.firstPlayGuideStep != null
            ? GuideTarget(step: widget.firstPlayGuideStep!, child: playAction)
            : playAction;
        final guidedMenuAction = index == 0 && widget.firstMenuGuideStep != null
            ? GuideTarget(step: widget.firstMenuGuideStep!, child: menuAction)
            : menuAction;
        return KeyedSubtree(
          key: _rowKeys[index],
          child: Material(
            color: rowColor,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  guidedPlayAction,
                  Expanded(
                    child: InkWell(
                      onTap: () => widget.onSelect(index),
                      // 行内就地编辑的 TextField 是本 InkWell 的后代，其获焦会让本
                      // InkWell 的 focusNode.hasFocus 为真而绘制 focus 高亮（整列变深
                      // 灰）。选中行不需要 focus 高亮，置空避免编辑时背景变深。
                      focusColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 选中句拆成单词 label（可点词播放并显示词边界）；
                            // 其余句保持纯文本，降低视觉噪音、突出当前编辑句。
                            isSelected
                                ? _SentenceWordLabels(
                                    text: sentence.text,
                                    words: widget.selectedSentenceWords,
                                    focusedWordIndex: widget.focusedWordIndex,
                                    onWordTap: widget.onWordTap,
                                    onEditWord: widget.onEditWord,
                                    onSplitWord: widget.onSplitWord,
                                  )
                                : Text(sentence.text),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatTime(sentence.startTime)} - '
                              '${_formatTime(sentence.endTime)} · '
                              '${_formatSeconds(sentence.endTime - sentence.startTime)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize:
                                    (theme.textTheme.labelSmall?.fontSize ??
                                        11) -
                                    1,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: .68),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  guidedMenuAction,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(Duration duration) {
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

  String _formatSeconds(Duration duration) {
    final clamped = duration.isNegative ? Duration.zero : duration;
    final seconds = clamped.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }
}

/// 选中句的单词 label 流。
///
/// 直接以词级时间戳列表（[words]）逐词渲染成可点 chip：第 i 个 chip 严格对应
/// 第 i 个词，点击播放该词并在波形上显示该词及左右各两词的边界，避免「label 与
/// 词数不一致导致点 A 词却播 B 词」。点中词用 primary 强调。无词时退化为纯文本。
///
/// 点击单词除播放外，还在该词上方弹出带指向三角的悬浮工具栏（编辑 / 前断句，
/// 首词无断句）：
/// - 编辑 → 该 chip 就地变 TextField，回车或点别处提交（[onEditWord]）。
/// - 前断句 → 从该词左边界分句，该词成为下一句首词（[onSplitWord]）。
class _SentenceWordLabels extends StatefulWidget {
  final String text;
  final List<WordTimestamp> words;
  final int? focusedWordIndex;
  final void Function(int wordIndex) onWordTap;
  final void Function(int wordIndex, String newText) onEditWord;
  final void Function(int wordIndex) onSplitWord;

  const _SentenceWordLabels({
    required this.text,
    required this.words,
    required this.focusedWordIndex,
    required this.onWordTap,
    required this.onEditWord,
    required this.onSplitWord,
  });

  @override
  State<_SentenceWordLabels> createState() => _SentenceWordLabelsState();
}

class _SentenceWordLabelsState extends State<_SentenceWordLabels> {
  /// 每个 chip 一个 LayerLink，供悬浮工具栏锚定到对应词上方。
  final List<LayerLink> _links = [];

  /// 单一常驻 Overlay 入口：切换显示哪个词的工具栏只靠 markNeedsBuild，
  /// 避免反复 insert/remove 引发的竞态（旧 entry 误删新 entry）。
  OverlayEntry? _toolbarEntry;

  /// 当前显示工具栏的词序号；null 表示不显示。
  int? _toolbarIndex;

  /// 当前就地编辑的词序号；null 表示无编辑。
  int? _editingIndex;

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
    }
    if (_links.length > widget.words.length) {
      _links.removeRange(widget.words.length, _links.length);
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
    setState(() => _toolbarIndex = index);
    _toolbarEntry?.markNeedsBuild();
  }

  void _hideToolbar() {
    if (_toolbarIndex == null) return;
    setState(() => _toolbarIndex = null);
    _toolbarEntry?.markNeedsBuild();
  }

  void _onWordTap(int index) {
    if (_editingIndex != null) _commitEdit();
    widget.onWordTap(index);
    _showToolbar(index);
  }

  void _startEditing(int index) {
    _hideToolbar();
    setState(() {
      _editingIndex = index;
      _editController.text = widget.words[index].word;
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.length,
      );
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

  void _split(int index) {
    _hideToolbar();
    widget.onSplitWord(index);
  }

  @override
  Widget build(BuildContext context) {
    // label 与词级数据同源：保证「点中的词 = 播放的词 = 波形高亮的词」一致。
    if (widget.words.isEmpty) return Text(widget.text);
    _syncLinks();

    return TapRegion(
      groupId: _tapGroupId,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = 0; i < widget.words.length; i++)
            CompositedTransformTarget(
              link: _links[i],
              child: _editingIndex == i
                  ? _buildEditField(i)
                  : _WordChip(
                      key: ValueKey('subtitle-word-label-$i'),
                      label: widget.words[i].word,
                      focused: widget.focusedWordIndex == i,
                      onTap: () => _onWordTap(i),
                    ),
            ),
        ],
      ),
    );
  }

  /// 就地编辑输入框：仿 chip 紧凑样式，回车 / 点别处提交。
  Widget _buildEditField(int index) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 56),
      child: IntrinsicWidth(
        child: TextField(
          key: ValueKey('subtitle-word-edit-$index'),
          controller: _editController,
          focusNode: _editFocus,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _commitEdit(),
          onTapOutside: (_) => _commitEdit(),
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 6,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
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
    // 深色药丸（inverseSurface）：与浅灰选中行 / chip 形成强对比，浮层边界清晰。
    final surface = scheme.inverseSurface;
    final onSurface = scheme.onInverseSurface;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(10),
                color: surface,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToolbarButton(
                      key: ValueKey('subtitle-word-edit-button-$index'),
                      icon: Icons.edit_outlined,
                      label: l10n.wordEditAction,
                      tooltip: l10n.editWord,
                      color: onSurface,
                      onPressed: () => _startEditing(index),
                    ),
                    // 首词前分句会产生空句，故首词不提供剪刀。
                    if (index > 0) ...[
                      Container(
                        width: 1,
                        height: 20,
                        color: onSurface.withValues(alpha: .24),
                      ),
                      _ToolbarButton(
                        key: ValueKey('subtitle-word-split-button-$index'),
                        icon: Icons.content_cut,
                        label: l10n.wordSplitBeforeAction,
                        tooltip: l10n.splitSentenceHere,
                        color: onSurface,
                        onPressed: () => _split(index),
                      ),
                    ],
                  ],
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

/// 悬浮工具栏内的紧凑按钮：图标 + 短文案，文案点出动作（编辑 / 前断句）。
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个单词 chip。默认极淡描边暗示「可点」，点中态用 primary 填充 + 文字色强调。
class _WordChip extends StatelessWidget {
  final String label;
  final bool focused;
  final VoidCallback onTap;

  const _WordChip({
    super.key,
    required this.label,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: focused
          ? scheme.primary.withValues(alpha: .14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: focused
                  ? scheme.primary.withValues(alpha: .55)
                  : scheme.outlineVariant.withValues(alpha: .6),
            ),
          ),
          // 字重在 focus 态不变（否则加粗变宽会触发 Wrap 重新折行、整体布局跳动），
          // 仅靠颜色 + 底色 + 描边表达选中。
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: focused ? scheme.primary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  /// 可选着色，破坏性操作（删除）传 [colorScheme.error] 以示警示。
  final Color? color;

  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}

enum _SentenceAction { mergeNext, delete }
