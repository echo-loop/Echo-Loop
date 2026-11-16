import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../../providers/media_engine/media_engine_provider.dart';
import '../../providers/video_subtitle_mask_provider.dart';
import 'media_presentation_controller.dart';
import 'media_visual_surface.dart';

/// 学习页共享的视频呈现状态。
class PracticeMediaPresentationState {
  const PracticeMediaPresentationState({
    required this.enabled,
    required this.visualTrackVisible,
    required this.expanded,
    required this.subtitleVisible,
    required this.videoAspectRatio,
  });

  /// 当前任务是否使用 MediaEngine，false 时宿主不创建视频呈现资源。
  final bool enabled;

  /// 用户是否选择显示视频轨；隐藏后仍保留音频播放。
  final bool visualTrackVisible;

  /// 视频画面是否处于任务页内的全屏展开状态。
  final bool expanded;

  /// 当前是否已加载并显示字幕轨。
  final bool subtitleVisible;

  /// 已解码视频的宽高比，供讲解页定位字幕遮罩；未知时为 null。
  final double? videoAspectRatio;
}

/// 构建学习页内容，并注入统一媒体状态和视频画面。
typedef PracticeMediaPresentationBuilder = Widget Function(
  BuildContext context,
  PracticeMediaPresentationState state,
  Widget visualSurface,
);

/// 通知父任务当前可借用的视频会话；null 表示宿主已释放。
typedef PracticeMediaPresentationSessionChanged = void Function(
  PracticeMediaPresentationSession? session,
);

/// 视频呈现控制的统一契约：学习任务、随心听与收藏讲解会话都以它向句子讲解页
/// 出借视频画面。
///
/// 会话持有方拥有状态和系统全屏生命周期，讲解页只借用，避免两个路由维护两套
/// 可见性、CC 与全屏状态。
class PracticeMediaPresentationSession {
  const PracticeMediaPresentationSession({
    required this.readState,
    required this.setVisible,
    required this.setSubtitleVisible,
    required this.setFullscreen,
    required this.previewPosition,
    required this.buildVideoView,
  });

  final PracticeMediaPresentationState Function() readState;
  final Future<void> Function(bool visible) setVisible;
  final Future<void> Function(bool visible) setSubtitleVisible;
  final Future<void> Function(bool expanded) setFullscreen;

  /// 暂停中把画面移到讲解句起点，不改变任务页的焦点与高亮。
  final Future<void> Function(Duration position) previewPosition;
  final Widget Function(Size viewportSize) buildVideoView;
}

/// 逐句精听与难句跟读共用的视频画面宿主。
///
/// 统一管理隐藏画面、CC、全屏和 App 生命周期视频轨；播放状态和业务动作仍由
/// 页面对应 controller 提供，组件不会编排学习流程。
class PracticeMediaPresentationHost extends ConsumerStatefulWidget {
  const PracticeMediaPresentationHost({
    super.key,
    required this.enabled,
    required this.audioItemId,
    required this.isPlaying,
    required this.onPlayPause,
    required this.builder,
    this.onSessionChanged,
    this.suppressVisualView = false,
    this.fillVisualSurface = false,
  });

  /// 是否启用媒体呈现；音频任务保持 false，不创建视频资源。
  final bool enabled;

  /// 当前学习材料 ID，用于按需读取其字幕。
  final String audioItemId;

  /// 业务播放状态，用于画面控制按钮图标。
  final bool isPlaying;

  /// 将画面播放按钮转交给任务 Controller。
  final VoidCallback onPlayPause;

  /// 组装页面业务内容与共享视频画面。
  final PracticeMediaPresentationBuilder builder;

  /// 由父任务保存当前会话，并在导航时注入句子讲解页。
  final PracticeMediaPresentationSessionChanged? onSessionChanged;

  /// 子路由借用同一视频纹理期间，父页保留等比例黑色画布而不创建第二个纹理。
  final bool suppressVisualView;

  /// 视频画面铺满父级给定的尺寸；由分栏布局决定尺寸时使用，
  /// 否则画面按宽度自适应并限制最大高度。
  final bool fillVisualSurface;

  @override
  ConsumerState<PracticeMediaPresentationHost> createState() =>
      _PracticeMediaPresentationHostState();
}

class _PracticeMediaPresentationHostState
    extends ConsumerState<PracticeMediaPresentationHost> {
  /// 仅在任务启用媒体呈现时存在；可见性、字幕与全屏状态由控制器统一维护。
  MediaPresentationController? _presentation;

  /// 与 [_presentation] 同生共死；本页画面与借给讲解页的是同一份会话。
  PracticeMediaPresentationSession? _session;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _initializePresentation();
  }

  @override
  void didUpdateWidget(covariant PracticeMediaPresentationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      _initializePresentation();
    } else if (oldWidget.enabled && !widget.enabled) {
      unawaited(_releasePresentation());
    }
    if (oldWidget.audioItemId != widget.audioItemId) {
      _presentation?.switchAudioItem(widget.audioItemId);
    }
  }

  void _initializePresentation() {
    if (_presentation != null) return;
    final presentation = MediaPresentationController(
      engine: ref.read(mediaEngineProvider.notifier),
      readTranscriptSrt: (audioItemId) =>
          ref.read(audioItemDaoProvider).getTranscriptSrt(audioItemId),
      audioItemId: widget.audioItemId,
    );
    presentation.addListener(_handlePresentationChanged);
    presentation.start();
    _presentation = presentation;
    final session = _buildSession(presentation);
    _session = session;
    widget.onSessionChanged?.call(session);
  }

  void _handlePresentationChanged() {
    if (mounted) setState(() {});
  }

  PracticeMediaPresentationSession _buildSession(
    MediaPresentationController presentation,
  ) {
    return PracticeMediaPresentationSession(
      readState: () => PracticeMediaPresentationState(
        enabled: widget.enabled,
        visualTrackVisible: presentation.visualTrackVisible,
        expanded: presentation.expanded,
        subtitleVisible: presentation.subtitleVisible,
        videoAspectRatio: ref
            .read(mediaEngineProvider.notifier)
            .videoAspectRatio,
      ),
      setVisible: presentation.setVisualTrackVisible,
      setSubtitleVisible: presentation.setSubtitleVisible,
      setFullscreen: presentation.setFullscreen,
      previewPosition: (position) =>
          ref.read(mediaEngineProvider.notifier).seekForPreview(position),
      buildVideoView: (size) => ref
          .read(mediaEngineProvider.notifier)
          .buildVideoView(viewportSize: size),
    );
  }

  Future<void> _releasePresentation() async {
    widget.onSessionChanged?.call(null);
    final presentation = _presentation;
    _presentation = null;
    _session = null;
    if (presentation == null) return;
    presentation.removeListener(_handlePresentationChanged);
    await presentation.release();
    presentation.dispose();
  }

  @override
  void dispose() {
    unawaited(_releasePresentation());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 宽高比在媒体 ready 后即确定，随后的播放状态重建会带上最新值；未知时遮罩
    // 退回按整个画面定位。
    final presentation = widget.enabled ? _presentation : null;
    final session = widget.enabled ? _session : null;
    final videoAspectRatio = widget.enabled
        ? ref.read(mediaEngineProvider.notifier).videoAspectRatio
        : null;
    final presentationState = PracticeMediaPresentationState(
      enabled: widget.enabled,
      visualTrackVisible: presentation?.visualTrackVisible ?? false,
      expanded: presentation?.expanded ?? false,
      subtitleVisible: presentation?.subtitleVisible ?? false,
      videoAspectRatio: videoAspectRatio,
    );
    final surface = session != null && !widget.suppressVisualView
        ? PracticeMediaVisualSurface(
            audioItemId: widget.audioItemId,
            session: session,
            isPlaying: widget.isPlaying,
            onPlayPause: widget.onPlayPause,
            fillAvailableHeight: widget.fillVisualSurface,
          )
        : widget.enabled
        ? const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.black),
          )
        : const SizedBox.shrink();
    return widget.builder(context, presentationState, surface);
  }
}

/// 学习任务页、随心听与句子讲解页共用的视频画面。
///
/// 按会话状态组装 [MediaVisualSurface]，画面上的显示 / CC / 全屏操作都回到会话，
/// 并接入该材料的字幕遮罩设置。只在真正显示画面时订阅遮罩，纯音频不读取遮罩数据。
class PracticeMediaVisualSurface extends ConsumerWidget {
  const PracticeMediaVisualSurface({
    super.key,
    required this.audioItemId,
    required this.session,
    required this.isPlaying,
    required this.onPlayPause,
    required this.fillAvailableHeight,
    this.onPresentationChanged,
    this.controls = const MediaVisualControls(),
  });

  final String audioItemId;
  final PracticeMediaPresentationSession session;

  /// 业务播放状态，用于画面播放按钮图标。
  final bool isPlaying;
  final VoidCallback onPlayPause;

  /// 画面铺满父级给定的尺寸（由分栏布局决定尺寸时使用）；全屏时总是铺满。
  final bool fillAvailableHeight;

  /// 会话操作完成后通知持有方重建。会话状态不可监听的借用方（句子讲解页）
  /// 需要传入；宿主与随心听由各自的状态源驱动重建，无需传入。
  final VoidCallback? onPresentationChanged;

  /// 画面上可用的控件，默认全部可用。
  final MediaVisualControls controls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = session.readState();
    final subtitleMaskProvider = videoSubtitleMaskProvider(audioItemId);
    // 加载完成前为 null：不显示遮罩，避免先在默认位置闪现再跳到已保存位置。
    final subtitleMask = ref.watch(subtitleMaskProvider).value;
    final subtitleMaskNotifier = ref.read(subtitleMaskProvider.notifier);
    return MediaVisualSurface(
      state: MediaVisualSurfaceState(
        visible: state.visualTrackVisible,
        expanded: state.expanded,
        isPlaying: isPlaying,
        subtitleVisible: state.subtitleVisible,
        subtitleMask: subtitleMask,
        videoAspectRatio: state.videoAspectRatio,
      ),
      actions: MediaVisualSurfaceActions(
        onShow: () => _runSessionAction(session.setVisible(true)),
        onHide: () => _runSessionAction(session.setVisible(false)),
        onPlayPause: onPlayPause,
        onSubtitleToggle: () => _runSessionAction(
          session.setSubtitleVisible(!state.subtitleVisible),
        ),
        onFullscreenToggle: () =>
            _runSessionAction(session.setFullscreen(!state.expanded)),
        onSubtitleMaskToggle: () =>
            unawaited(subtitleMaskNotifier.toggleEnabled()),
        onSubtitleMaskRectChanged: (rect) =>
            unawaited(subtitleMaskNotifier.setRect(rect)),
      ),
      fillAvailableHeight: state.expanded || fillAvailableHeight,
      buildVideoView: session.buildVideoView,
      controls: controls,
    );
  }

  void _runSessionAction(Future<void> action) {
    unawaited(action.then((_) => onPresentationChanged?.call()));
  }
}
