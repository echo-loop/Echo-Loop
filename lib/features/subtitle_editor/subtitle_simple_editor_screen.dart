import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
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
                  // AppBar 内收紧默认主题的大 padding，保持紧凑
                  style: FilledButton.styleFrom(
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
                        duration: state.totalDuration,
                        sentences: state.sentences,
                        activeSentence: state.selectedSentence,
                        selectedIndex: state.selectedSentenceIndex,
                        selectionEpoch: state.selectionEpoch,
                        playbackPosition: state.playbackPosition,
                        isPlaying:
                            state.isPlaying &&
                            state.playbackMode ==
                                SubtitleEditorPlaybackMode.sentence,
                        zoomScale: state.waveformZoomScale,
                        onZoomChanged: controller.setWaveformZoomScale,
                        onScrub: controller.scrubTo,
                        onScrubEnd: (position) =>
                            unawaited(controller.finishScrub(position)),
                        onAdjustBoundary: controller.adjustSentenceBoundary,
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
                        onPlay: (index) =>
                            unawaited(controller.playSentence(index)),
                        onStop: () => unawaited(controller.stopPlayback()),
                        onSelect: controller.selectSentence,
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
    // 仅调整时间戳（句子数量不变）不会清空学习进度和收藏，无需弹窗确认，直接保存；
    // 仅在句子数量变化（合并/删除）时提示「将清空进度」。
    if (controller.sentenceCountChanged) {
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
  final void Function(int index) onPlay;
  final VoidCallback onStop;
  final void Function(int index) onSelect;
  final void Function(int index) onMergeNext;
  final void Function(int index) onDelete;
  final GuideStep? firstPlayGuideStep;
  final GuideStep? firstMenuGuideStep;

  const _SentenceList({
    required this.sentences,
    required this.selectedIndex,
    required this.playingIndex,
    required this.onPlay,
    required this.onStop,
    required this.onSelect,
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
              child: Center(
                child: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  // 播放中用 primary 实色单点强调，区别于「仅选中定位」的行底高亮
                  color: isPlaying ? theme.colorScheme.primary : null,
                ),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sentence.text),
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
