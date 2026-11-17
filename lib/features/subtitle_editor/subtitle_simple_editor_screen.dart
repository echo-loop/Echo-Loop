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
import '../../models/practice_media_split.dart';
import '../../providers/media_engine/media_engine_provider.dart';
import '../../providers/new_user_guide_provider.dart';
import '../../services/app_logger.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/practice_media_split_geometry.dart';
import '../../widgets/common/video_toggle_icon.dart';
import '../../widgets/guide_flow.dart';
import 'subtitle_editor_controller.dart';
import 'subtitle_editor_video_preview.dart';
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
  }

  @override
  void dispose() {
    final preview = _videoPreview;
    _videoPreview = null;
    if (preview != null) unawaited(preview.dispose());
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
    );
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

  void _syncVideo(SubtitleEditorState state) {
    if (!_isVideoVisible) return;
    _videoPreview?.follow(
      isPlaying: state.isPlaying,
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
        child: Scaffold(
          appBar: AppBar(
            title: _EditorTitle(
              title: l10n.editSubtitles,
              mediaName: widget.audioItem.name,
            ),
            actions: [
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
        ),
      ),
    );
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
                  wordBoundaries: controller.wordBoundariesForWaveform,
                  onAdjustWord: controller.adjustWord,
                  zoomScale: state.waveformZoomScale,
                  onZoomChanged: controller.setWaveformZoomScale,
                  onScrub: controller.scrubTo,
                  onScrubEnd: (position) =>
                      unawaited(controller.finishScrub(position)),
                  onAdjustEnd: () {},
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
        focusedWordIndex: state.focusedWordIndex,
        onPlay: (index) => unawaited(controller.playSentence(index)),
        onStop: () => unawaited(controller.stopPlayback()),
        onSelect: controller.selectSentence,
        onWordTap: (index) => unawaited(controller.playWord(index)),
        onEditWord: controller.editWord,
        onSplitWord: controller.splitSentenceAtWord,
        onMergeNext: controller.mergeWithNext,
        onDelete: (index) => _deleteSentence(
          context,
          controller,
          AppLocalizations.of(context)!,
          index,
        ),
        firstPlayGuideStep: sentencePlayStep,
        firstMenuGuideStep: sentenceMenuStep,
      ),
    );
    final videoPanel = SubtitleEditorVideoPanel(preview: _videoPreview);

    if (isSideBySide) {
      final panelWidth = (constraints.maxWidth * 0.42).clamp(360.0, 520.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 画面贴顶、工具条与波形紧跟其下，剩余空间留在底部，
                // 视线从画面到波形不被空白隔断。
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _gutter,
                      AppSpacing.m,
                      _gutter,
                      AppSpacing.xs,
                    ),
                    child: videoPanel,
                  ),
                ),
                toolbar,
                waveform,
                const SizedBox(height: AppSpacing.m),
              ],
            ),
          ),
          VerticalDivider(
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          SizedBox(width: panelWidth, child: sentenceList),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.subtitleEditsSaved)));
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
    final isDark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: scheme.outlineVariant) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: .05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        _SubtitleSimpleEditorScreenState._gutter,
        AppSpacing.xs,
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
              icon: const Icon(Icons.add_rounded),
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

  /// 句子行内容的上下留白；左右操作按钮按它对齐首行文字。
  static const double _kRowVerticalPadding = 12;

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
      return _EmptySentences(message: l10n.subtitleFileEmpty);
    }

    const gutter = _SubtitleSimpleEditorScreenState._gutter;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.xs,
        gutter,
        AppSpacing.l,
      ),
      itemCount: widget.sentences.length,
      itemBuilder: (context, index) => KeyedSubtree(
        key: _rowKeys[index],
        child: _buildRow(context, l10n, index),
      ),
    );
  }

  Widget _buildRow(BuildContext context, AppLocalizations l10n, int index) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sentence = widget.sentences[index];
    final isSelected = widget.selectedIndex == index;
    final isPlaying = widget.playingIndex == index;
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
            const SizedBox(height: 3),
            Text(
              key: ValueKey('subtitle-sentence-number-$index'),
              '${index + 1}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                height: 1,
                color: isSelected
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: .7),
                fontWeight: isSelected ? FontWeight.w600 : null,
                fontFeatures: const [FontFeature.tabularFigures()],
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
                  color: scheme.error,
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
                      isSelected
                          ? _SentenceWordLabels(
                              text: sentence.text,
                              words: widget.selectedSentenceWords,
                              focusedWordIndex: widget.focusedWordIndex,
                              onWordTap: widget.onWordTap,
                              onEditWord: widget.onEditWord,
                              onSplitWord: widget.onSplitWord,
                            )
                          : Text(sentence.text, style: textStyle),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTime(sentence.startTime)} - '
                        '${_formatTime(sentence.endTime)} · '
                        '${_formatSeconds(sentence.endTime - sentence.startTime)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: .75),
                          letterSpacing: .1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
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
          ? scheme.primary.withValues(alpha: .12)
          : scheme.surfaceContainerHighest.withValues(alpha: .45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: focused
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
              color: focused ? scheme.primary : scheme.onSurface,
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
