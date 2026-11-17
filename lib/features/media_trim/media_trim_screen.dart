import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart';
import '../../models/practice_media_split.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/collection_provider.dart';
import '../../router/app_router.dart';
import '../../services/app_logger.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/common/media_split_divider.dart';
import '../../widgets/common/practice_media_split_geometry.dart';
import '../../widgets/common/video_toggle_icon.dart';
import 'media_trim_clip.dart';
import 'media_trim_editor_controller.dart';
import 'media_trim_exporter.dart';
import 'media_trim_repository.dart';
import 'media_trim_split_geometry.dart';
import 'media_trim_split_provider.dart';
import 'widgets/media_trim_clip_panel.dart';
import 'widgets/media_trim_dialogs.dart';
import 'widgets/media_trim_format.dart';
import 'widgets/media_trim_timeline.dart';
import 'widgets/media_trim_transcript_list.dart';

/// 已下载媒体的剪辑页：把一段材料切成多个独立的新材料，原材料保持不变。
class MediaTrimScreen extends ConsumerStatefulWidget {
  const MediaTrimScreen({super.key, required this.source, this.collectionId});

  final AudioItem source;

  /// 入口所在合集；是本地合集时作为默认保存目标。
  final String? collectionId;

  @override
  ConsumerState<MediaTrimScreen> createState() => _MediaTrimScreenState();
}

class _MediaTrimScreenState extends ConsumerState<MediaTrimScreen>
    with WidgetsBindingObserver {
  /// 宽屏双栏的最小可用尺寸。
  static const double _wideMinWidth = 960;
  static const double _wideMinHeight = 520;

  /// 窄屏下固定时间轴、列表单独滚动所需的最小高度；更矮时整页滚动。
  static const double _pinnedMinHeight = 600;

  /// 页面左右边距固定，不随窗口宽度分档：拖动窗口跨过分档宽度时边距跳变很突兀，
  /// 也与右侧片段面板的 16 保持一致。
  static const double _gutter = 16;

  AudioItem get _source => widget.source;

  /// 剪辑主要看波形和片段，画面默认收起，把高度留给时间轴和列表；只影响本页。
  bool _isVideoVisible = false;

  /// 拖动分隔条过程中的左栏宽度，只存在于拖动期间；松手后写入偏好并清空。
  double? _dragTimelineWidth;

  /// 时间轴在宽 / 窄 / 矮布局间、以及展开收起画面时会换位置；用 GlobalKey 让它
  /// 搬家而不重建，保住缩放倍数和平移位置。
  final _timelineKey = GlobalKey(debugLabel: 'media-trim-timeline');

  MediaTrimEditorController get _controller =>
      ref.read(mediaTrimEditorProvider(_source).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        ref.read(mediaTrimEditorProvider(_source)).isPlaying) {
      unawaited(_controller.pause());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 在空白处新建片段；没有足够长的空白时顶部 toast 提示，不打断操作。
  void _addClip() {
    if (_controller.addClipInGap()) return;
    showAppToast(
      overlayState: Overlay.of(context, rootOverlay: true),
      message: AppLocalizations.of(context)!.mediaTrimNoGapForClip,
    );
  }

  Future<void> _handlePop() async {
    final state = ref.read(mediaTrimEditorProvider(_source));
    if (state.isSaving) {
      await _controller.cancelSave();
      return;
    }
    if (state.isDirty && state.clips.isNotEmpty) {
      if (!await showMediaTrimDiscardDialog(context)) return;
      AppLogger.log('MediaTrim', '放弃未保存的剪辑 clips=${state.clips.length}');
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openAutoSplit() async {
    final state = ref.read(mediaTrimEditorProvider(_source));
    final boundaries = state.boundaries;
    if (boundaries == null) return;
    final target = await showMediaTrimAutoSplitDialog(
      context,
      boundaries: boundaries,
      existingClipCount: state.clips.length,
    );
    if (target != null && mounted) _controller.autoSplit(target);
  }

  Future<void> _rename(MediaTrimClip clip) async {
    final name = await showMediaTrimRenameDialog(
      context,
      currentName: ref.read(mediaTrimEditorProvider(_source)).clipName(clip),
    );
    if (name != null && mounted) _controller.renameClip(clip.id, name);
  }

  Future<void> _editTime(MediaTrimEdge edge) async {
    final state = ref.read(mediaTrimEditorProvider(_source));
    final clip = state.selectedClip;
    if (clip == null) return;
    final time = await showMediaTrimTimeDialog(
      context,
      edge: edge,
      current: edge == MediaTrimEdge.start ? clip.start : clip.end,
      snapsToSentences: state.boundaries?.hasSentences ?? false,
    );
    if (time == null || !mounted) return;
    final failure = _controller.setEdgeTime(edge, time);
    if (failure != null) {
      _showMessage(
        mediaTrimFailureMessage(AppLocalizations.of(context)!, failure),
      );
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(mediaTrimEditorProvider(_source));
    if (state.clips.isEmpty || state.isSaving) return;
    final collections = await ref
        .read(mediaTrimRepositoryProvider)
        .localCollections();
    if (!mounted) return;
    final destination = await showMediaTrimSaveDialog(
      context,
      clipCount: state.clips.length,
      collections: collections,
      preferredCollectionId: widget.collectionId,
      defaultCollectionName: l10n.mediaTrimDefaultCollectionName(_source.name),
      // 入口合集不在本地合集里（播客 / 共享合集），或材料本身来自播客、社区。
      isFromManagedCollection:
          _source.isCommunity ||
          _source.podcastEpisodeGuid != null ||
          (widget.collectionId != null &&
              collections.every((c) => c.id != widget.collectionId)),
    );
    if (destination == null || !mounted) return;
    final MediaTrimExportResult result;
    try {
      result = await _controller.save(destination);
    } on MediaTrimException catch (error) {
      if (mounted) _showMessage(mediaTrimFailureMessage(l10n, error.failure));
      return;
    }
    await Future.wait([
      ref.read(audioLibraryProvider.notifier).loadLibrary(),
      ref.read(collectionListProvider.notifier).loadCollections(),
    ]);
    if (!mounted) return;
    _showMessage(
      result.reusedCount == 0
          ? l10n.mediaTrimSaved(result.createdCount)
          : l10n.mediaTrimSavedWithReused(
              result.createdCount,
              result.reusedCount,
            ),
    );
    if (result.collectionId == widget.collectionId) {
      context.pop();
    } else {
      context.go(AppRoutes.collectionDetail(result.collectionId));
    }
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    final controller = _controller;
    return {
      const SingleActivator(LogicalKeyboardKey.space): () =>
          unawaited(controller.togglePlayback()),
      const SingleActivator(LogicalKeyboardKey.keyI): () =>
          controller.setEdgeAtPlayhead(MediaTrimEdge.start),
      const SingleActivator(LogicalKeyboardKey.keyO): () =>
          controller.setEdgeAtPlayhead(MediaTrimEdge.end),
      const SingleActivator(LogicalKeyboardKey.keyN): _addClip,
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          unawaited(controller.seekBy(const Duration(seconds: -1))),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          unawaited(controller.seekBy(const Duration(seconds: 1))),
      const SingleActivator(LogicalKeyboardKey.escape):
          controller.clearSelection,
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = mediaTrimEditorProvider(_source);
    ref.listen(provider.select((s) => s.noticeSerial), (previous, next) {
      final notice = ref.read(provider).notice;
      if (notice != null) {
        _showMessage(
          mediaTrimFailureMessage(AppLocalizations.of(context)!, notice),
        );
      }
    });
    final (status, failure, isDirty, isSaving, clipCount) = ref.watch(
      provider.select(
        (s) => (s.status, s.loadFailure, s.isDirty, s.isSaving, s.clips.length),
      ),
    );
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !isSaving && !(isDirty && clipCount > 0),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handlePop());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.mediaTrimTitle),
              Text(
                _source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const ValueKey('trim-save'),
                onPressed:
                    status == MediaTrimLoadStatus.ready &&
                        clipCount > 0 &&
                        !isSaving
                    ? _save
                    : null,
                child: Text(
                  clipCount == 0
                      ? l10n.save
                      : l10n.mediaTrimSaveCount(clipCount),
                ),
              ),
            ),
          ],
        ),
        body: switch (status) {
          MediaTrimLoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          MediaTrimLoadStatus.failed => _LoadFailure(
            message: mediaTrimFailureMessage(
              l10n,
              failure ?? MediaTrimFailure.unexpected,
            ),
          ),
          MediaTrimLoadStatus.ready => Stack(
            children: [
              CallbackShortcuts(
                bindings: _shortcuts(),
                child: Focus(autofocus: true, child: _buildEditor(context)),
              ),
              if (isSaving) _SaveProgressOverlay(source: _source),
            ],
          ),
        },
      ),
    );
  }

  /// 松手后按可用宽度记住左栏比例；算不出有效比例时保留原偏好，不当作恢复默认。
  void _commitTimelineDrag(PracticeMediaExtentRange range) {
    // 分隔条在拖动中被移除时会在帧结束后补发，此时页面可能已关闭。
    if (!mounted) return;
    final width = _dragTimelineWidth;
    setState(() => _dragTimelineWidth = null);
    if (width == null) return;
    final fraction = range.fractionOf(range.clamp(width));
    if (fraction == null) return;
    unawaited(ref.read(mediaTrimSplitProvider.notifier).setFraction(fraction));
  }

  Widget _buildEditor(BuildContext context) {
    final savedFraction = ref.watch(mediaTrimSplitProvider);
    final hasSentences = ref.watch(
      mediaTrimEditorProvider(_source)
          .select((s) => s.boundaries?.hasSentences ?? false),
    );
    MediaTrimClipSlivers buildClipSlivers({bool showTitle = true}) =>
        MediaTrimClipSlivers(
          source: _source,
          showTitle: showTitle,
          onAutoSplit: _openAutoSplit,
          onAddClip: _addClip,
          onRename: _rename,
          onEditTime: _editTime,
        );
    final clipSlivers = buildClipSlivers();
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth >= _wideMinWidth &&
              constraints.maxHeight >= _wideMinHeight;
          final header = [
            if (_source.isVideo && _isVideoVisible)
              _VideoPreview(
                source: _source,
                maxHeight: constraints.maxHeight * (isWide ? 0.42 : 0.28),
              ),
            _TransportBar(
              source: _source,
              isVideoVisible: _source.isVideo ? _isVideoVisible : null,
              onToggleVideo: () =>
                  setState(() => _isVideoVisible = !_isVideoVisible),
            ),
            _TimelineSection(key: _timelineKey, source: _source),
          ];
          if (isWide) {
            final splitRange = MediaTrimSplitGeometry.range(
              constraints.maxWidth,
            );
            // 拖动中的宽度也按当前范围限制：拖动期间窗口变化不会让右栏被挤出最小宽度。
            final timelineWidth = splitRange.clamp(
              _dragTimelineWidth ??
                  MediaTrimSplitGeometry.resolveTimelineWidth(
                    width: constraints.maxWidth,
                    fraction: savedFraction,
                  ),
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const ValueKey('trim-timeline-column'),
                  width: timelineWidth,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...header,
                        Expanded(
                          child: hasSentences
                              ? CustomScrollView(
                                  key: const ValueKey('trim-transcript-scroll'),
                                  slivers: [
                                    MediaTrimTranscriptSlivers(source: _source),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                MediaSplitDivider(
                  axis: PracticeMediaSplitAxis.sideBySide,
                  onDragStart: () =>
                      setState(() => _dragTimelineWidth = timelineWidth),
                  onDragUpdate: (delta) => setState(
                    () => _dragTimelineWidth = splitRange.clamp(
                      (_dragTimelineWidth ?? timelineWidth) + delta,
                    ),
                  ),
                  onDragEnd: () => _commitTimelineDrag(splitRange),
                  onReset: () => unawaited(
                    ref.read(mediaTrimSplitProvider.notifier).setFraction(null),
                  ),
                ),
                Expanded(
                  key: const ValueKey('trim-clip-column'),
                  child: CustomScrollView(
                    key: const ValueKey('trim-editor'),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: clipSlivers,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          if (constraints.maxHeight >= _pinnedMinHeight) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...header,
                  Expanded(
                    child: hasSentences
                        ? _NarrowTabs(
                            source: _source,
                            clipSlivers: buildClipSlivers(showTitle: false),
                          )
                        : CustomScrollView(
                            key: const ValueKey('trim-editor'),
                            slivers: [clipSlivers],
                          ),
                  ),
                ],
              ),
            );
          }
          // 矮窗口（横屏手机、小桌面窗口）整页滚动，保证所有控件可达。
          return CustomScrollView(
            key: const ValueKey('trim-editor'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 0),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(child: Column(children: header)),
                    clipSlivers,
                    if (hasSentences)
                      MediaTrimTranscriptSlivers(source: _source),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NarrowTabs extends ConsumerWidget {
  const _NarrowTabs({required this.source, required this.clipSlivers});

  final AudioItem source;
  final Widget clipSlivers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final count = ref.watch(
      mediaTrimEditorProvider(source).select((s) => s.clips.length),
    );
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(
                key: const ValueKey('trim-tab-clips'),
                text: count == 0
                    ? l10n.mediaTrimClips
                    : '${l10n.mediaTrimClips} · $count',
              ),
              Tab(
                key: const ValueKey('trim-tab-transcript'),
                text: l10n.mediaTrimTranscript,
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                CustomScrollView(
                  key: const ValueKey('trim-editor'),
                  slivers: [clipSlivers],
                ),
                CustomScrollView(
                  key: const ValueKey('trim-transcript-scroll'),
                  slivers: [
                    MediaTrimTranscriptSlivers(
                      source: source,
                      showHeader: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends ConsumerWidget {
  const _VideoPreview({required this.source, required this.maxHeight});

  final AudioItem source;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaTrimEditorProvider(source);
    final aspectRatio =
        ref.watch(provider.select((s) => s.videoAspectRatio)) ?? 16 / 9;
    final controller = ref.read(provider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: LayoutBuilder(
                  builder: (context, box) =>
                      controller.buildVideoView(box.biggest),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportBar extends ConsumerWidget {
  const _TransportBar({
    required this.source,
    required this.isVideoVisible,
    required this.onToggleVideo,
  });

  final AudioItem source;

  /// 为 null 表示音频材料，不显示画面开关。
  final bool? isVideoVisible;
  final VoidCallback onToggleVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaTrimEditorProvider(source);
    final (position, isPlaying, total) = ref.watch(
      provider.select(
        (s) => (s.position, s.isPlaying, s.boundaries?.total ?? Duration.zero),
      ),
    );
    final controller = ref.read(provider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton.filled(
            key: const ValueKey('trim-play'),
            tooltip: isPlaying ? l10n.mediaTrimPause : l10n.mediaTrimPlay,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: () =>
                isPlaying ? controller.pause() : controller.togglePlayback(),
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatTrimTime(position),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: ' / ${formatTrimClock(total)}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          if (isVideoVisible case final isVisible?)
            IconButton(
              key: const ValueKey('trim-toggle-video'),
              tooltip: isVisible
                  ? l10n.mediaTrimHideVideo
                  : l10n.mediaTrimShowVideo,
              onPressed: onToggleVideo,
              icon: VideoToggleIcon(isVisible: isVisible),
            ),
        ],
      ),
    );
  }
}

class _TimelineSection extends ConsumerWidget {
  const _TimelineSection({super.key, required this.source});

  final AudioItem source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaTrimEditorProvider(source);
    final state = ref.watch(
      provider.select(
        (s) => (
          waveform: s.waveform,
          progress: s.waveformProgress,
          failed: s.isWaveformFailed,
          boundaries: s.boundaries,
          clips: s.clips,
          selected: s.selectedClipId,
          revealSerial: s.revealSerial,
          position: s.position,
          isPlaying: s.isPlaying,
        ),
      ),
    );
    final controller = ref.read(provider.notifier);
    final boundaries = state.boundaries;
    if (boundaries == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaTrimTimeline(
            key: const ValueKey('trim-timeline'),
            waveform: state.waveform,
            waveformProgress: state.progress,
            isWaveformFailed: state.failed,
            onRetryWaveform: controller.loadWaveform,
            total: boundaries.total,
            spans: boundaries.spans,
            clips: state.clips,
            selectedClipId: state.selected,
            revealSerial: state.revealSerial,
            position: state.position,
            isPlaying: state.isPlaying,
            onSeek: controller.seek,
            onScrub: controller.scrub,
            onScrubEnd: controller.endScrub,
            onSelectClip: (id, at) => controller.selectClip(id, at: at),
            onClearSelection: controller.clearSelection,
            onEdgeDrag: controller.dragEdge,
            onEdgeDragEnd: controller.endEdgeDrag,
          ),
        ],
      ),
    );
  }
}

class _SaveProgressOverlay extends ConsumerWidget {
  const _SaveProgressOverlay({required this.source});

  final AudioItem source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaTrimEditorProvider(source);
    final (progress, isCancelling) = ref.watch(
      provider.select((s) => (s.saveProgress, s.isCancellingSave)),
    );
    if (progress == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final current = (progress.completedClips + 1).clamp(1, progress.totalClips);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isCancelling
                          ? l10n.mediaTrimCancelling
                          : l10n.mediaTrimSaving(current, progress.totalClips),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: isCancelling ? null : progress.fraction,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress.fraction * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const ValueKey('trim-cancel-save'),
                        onPressed: isCancelling
                            ? null
                            : ref.read(provider.notifier).cancelSave,
                        child: Text(l10n.cancel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(l10n.mediaTrimLoadFailed, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.back),
            ),
          ],
        ),
      ),
    );
  }
}
