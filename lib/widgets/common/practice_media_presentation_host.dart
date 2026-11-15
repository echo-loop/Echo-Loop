import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../../providers/media_engine/media_engine_provider.dart';
import '../../providers/video_subtitle_mask_provider.dart';
import '../../services/media_fullscreen_service.dart';
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
typedef PracticeMediaPresentationBuilder =
    Widget Function(
      BuildContext context,
      PracticeMediaPresentationState state,
      Widget visualSurface,
    );

/// 通知父任务当前可借用的视频会话；null 表示宿主已释放。
typedef PracticeMediaPresentationSessionChanged =
    void Function(PracticeMediaPresentationSession? session);

/// 任务页面与句子讲解页共享的视频呈现控制。
///
/// 宿主拥有状态和系统全屏生命周期，详情页只借用，避免两个路由维护两套
/// 可见性、CC 与全屏状态。
class PracticeMediaPresentationSession {
  const PracticeMediaPresentationSession({
    required this.readState,
    required this.setVisible,
    required this.setSubtitleVisible,
    required this.setFullscreen,
    required this.buildVideoView,
  });

  final PracticeMediaPresentationState Function() readState;
  final Future<void> Function(bool visible) setVisible;
  final Future<void> Function(bool visible) setSubtitleVisible;
  final Future<void> Function(bool expanded) setFullscreen;
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

  @override
  ConsumerState<PracticeMediaPresentationHost> createState() =>
      _PracticeMediaPresentationHostState();
}

class _PracticeMediaPresentationHostState
    extends ConsumerState<PracticeMediaPresentationHost> {
  MediaFullscreenService? _fullscreenService;
  StreamSubscription<bool>? _fullscreenSubscription;
  AppLifecycleListener? _lifecycle;
  bool _visible = true;
  bool _expanded = false;
  bool _subtitleVisible = false;

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
      _subtitleVisible = false;
    }
  }

  void _initializePresentation() {
    if (_fullscreenService != null) return;
    final service = MediaFullscreenService();
    _fullscreenService = service;
    _fullscreenSubscription = service.changes.listen((expanded) {
      if (mounted) setState(() => _expanded = expanded);
    });
    _lifecycle = AppLifecycleListener(onStateChange: _handleLifecycle);
    widget.onSessionChanged?.call(_session);
  }

  PracticeMediaPresentationSession get _session =>
      PracticeMediaPresentationSession(
        readState: () => PracticeMediaPresentationState(
          enabled: widget.enabled,
          visualTrackVisible: _visible,
          expanded: _expanded,
          subtitleVisible: _subtitleVisible,
          videoAspectRatio: ref
              .read(mediaEngineProvider.notifier)
              .videoAspectRatio,
        ),
        setVisible: _setVisible,
        setSubtitleVisible: _setSubtitleVisible,
        setFullscreen: _setFullscreen,
        buildVideoView: (size) => ref
            .read(mediaEngineProvider.notifier)
            .buildVideoView(viewportSize: size),
      );

  void _handleLifecycle(AppLifecycleState state) {
    final engine = ref.read(mediaEngineProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(engine.setVideoTrackEnabled(false));
      case AppLifecycleState.resumed:
        if (_visible) unawaited(engine.setVideoTrackEnabled(true));
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _setVisible(bool visible) async {
    await ref.read(mediaEngineProvider.notifier).setVideoTrackEnabled(visible);
    if (mounted) setState(() => _visible = visible);
  }

  Future<void> _toggleSubtitle() async {
    await _setSubtitleVisible(!_subtitleVisible);
  }

  Future<void> _setSubtitleVisible(bool visible) async {
    final engine = ref.read(mediaEngineProvider.notifier);
    if (visible) {
      final srt = await ref
          .read(audioItemDaoProvider)
          .getTranscriptSrt(widget.audioItemId);
      await engine.setSubtitleTrackData(srt);
    } else {
      await engine.setSubtitleTrackData(null);
    }
    if (mounted) setState(() => _subtitleVisible = visible);
  }

  Future<void> _toggleFullscreen() async {
    await _setFullscreen(!_expanded);
  }

  Future<void> _setFullscreen(bool expanded) async {
    final service = _fullscreenService;
    if (service == null) return;
    if (expanded) {
      await service.enter(
        isLandscapeVideo:
            ref.read(mediaEngineProvider.notifier).isLandscapeVideo ?? false,
      );
      return;
    }
    await service.exit();
  }

  Future<void> _releasePresentation() async {
    widget.onSessionChanged?.call(null);
    _lifecycle?.dispose();
    _lifecycle = null;
    await _fullscreenSubscription?.cancel();
    _fullscreenSubscription = null;
    final service = _fullscreenService;
    _fullscreenService = null;
    if (service != null) {
      await service.exit();
      await service.dispose();
    }
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
    final videoAspectRatio = widget.enabled
        ? ref.read(mediaEngineProvider.notifier).videoAspectRatio
        : null;
    final presentation = PracticeMediaPresentationState(
      enabled: widget.enabled,
      visualTrackVisible: widget.enabled && _visible,
      expanded: widget.enabled && _expanded,
      subtitleVisible: widget.enabled && _subtitleVisible,
      videoAspectRatio: videoAspectRatio,
    );
    final surface = widget.enabled && !widget.suppressVisualView
        ? _buildVisualSurface(videoAspectRatio)
        : widget.enabled
        ? const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.black),
          )
        : const SizedBox.shrink();
    return widget.builder(context, presentation, surface);
  }

  /// 只在真正显示视频画面时订阅遮罩设置，纯音频任务不读取遮罩数据。
  Widget _buildVisualSurface(double? videoAspectRatio) {
    final subtitleMaskProvider = videoSubtitleMaskProvider(widget.audioItemId);
    // 加载完成前为 null：不显示遮罩，避免先在默认位置闪现再跳到已保存位置。
    final subtitleMask = ref.watch(subtitleMaskProvider).value;
    final subtitleMaskNotifier = ref.read(subtitleMaskProvider.notifier);
    return MediaVisualSurface(
      state: MediaVisualSurfaceState(
        visible: _visible,
        expanded: _expanded,
        isPlaying: widget.isPlaying,
        subtitleVisible: _subtitleVisible,
        subtitleMask: subtitleMask,
        videoAspectRatio: videoAspectRatio,
      ),
      actions: MediaVisualSurfaceActions(
        onShow: () => unawaited(_setVisible(true)),
        onHide: () => unawaited(_setVisible(false)),
        onPlayPause: widget.onPlayPause,
        onSubtitleToggle: () => unawaited(_toggleSubtitle()),
        onFullscreenToggle: () => unawaited(_toggleFullscreen()),
        onSubtitleMaskToggle: () =>
            unawaited(subtitleMaskNotifier.toggleEnabled()),
        onSubtitleMaskRectChanged: (rect) =>
            unawaited(subtitleMaskNotifier.setRect(rect)),
      ),
      fillAvailableHeight: _expanded,
      buildVideoView: (size) => ref
          .read(mediaEngineProvider.notifier)
          .buildVideoView(viewportSize: size),
    );
  }
}
