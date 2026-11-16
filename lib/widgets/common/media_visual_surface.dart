import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/video_subtitle_mask.dart';
import 'svg_action_icon.dart';
import 'video_subtitle_mask_overlay.dart';

/// 视频画面的纯展示状态，供随心听与学习任务共享同一套视觉组件。
class MediaVisualSurfaceState {
  const MediaVisualSurfaceState({
    required this.visible,
    required this.expanded,
    required this.isPlaying,
    required this.subtitleVisible,
    required this.subtitleMask,
    required this.videoAspectRatio,
  });

  final bool visible;
  final bool expanded;
  final bool isPlaying;
  final bool subtitleVisible;

  /// 当前视频的字幕遮罩设置；尚未从数据库读出时为 null，此时不显示遮罩。
  final VideoSubtitleMask? subtitleMask;

  /// 视频实际宽高比，用于把遮罩定位到去掉黑边后的画面；未知时为 null。
  final double? videoAspectRatio;
}

/// 视频画面产生的业务动作；组件本身不直接依赖任何 Provider。
class MediaVisualSurfaceActions {
  const MediaVisualSurfaceActions({
    required this.onShow,
    required this.onHide,
    required this.onPlayPause,
    required this.onSubtitleToggle,
    required this.onFullscreenToggle,
    required this.onSubtitleMaskToggle,
    required this.onSubtitleMaskRectChanged,
  });

  final VoidCallback onShow;
  final VoidCallback onHide;
  final VoidCallback onPlayPause;
  final VoidCallback onSubtitleToggle;
  final VoidCallback onFullscreenToggle;
  final VoidCallback onSubtitleMaskToggle;

  /// 遮罩拖动 / 缩放结束后提交的归一化位置。
  final ValueChanged<Rect> onSubtitleMaskRectChanged;
}

/// 画面右上角可用的控件；默认全部可用，个别页面按需收起。
class MediaVisualControls {
  const MediaVisualControls({
    this.showSubtitleTrackButton = true,
    this.showFullscreenButton = true,
  });

  final bool showSubtitleTrackButton;
  final bool showFullscreenButton;
}

/// media_kit 视频画面的共享外壳。
///
/// 隐藏、CC、全屏和悬浮控制行为只有这一份实现；播放器实例通过
/// [buildVideoView] 注入，组件不会越过 controller 直接改变播放状态。
class MediaVisualSurface extends StatefulWidget {
  const MediaVisualSurface({
    super.key,
    required this.state,
    required this.actions,
    required this.buildVideoView,
    this.fillAvailableHeight = false,
    this.controls = const MediaVisualControls(),
  });

  final MediaVisualSurfaceState state;
  final MediaVisualSurfaceActions actions;
  final Widget Function(Size viewportSize) buildVideoView;
  final bool fillAvailableHeight;
  final MediaVisualControls controls;

  @override
  State<MediaVisualSurface> createState() => _MediaVisualSurfaceState();
}

class _MediaVisualSurfaceState extends State<MediaVisualSurface> {
  static const _buttonVisibleDuration = Duration(seconds: 3);
  bool _controlsVisible = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _hideControls() {
    _hideTimer?.cancel();
    if (_controlsVisible) setState(() => _controlsVisible = false);
  }

  /// 开启遮罩时收起控件，让遮罩手柄提示不被播放按钮遮挡。
  void _toggleSubtitleMask() {
    final subtitleMask = widget.state.subtitleMask;
    if (subtitleMask == null) return;
    if (!subtitleMask.enabled) _hideControls();
    widget.actions.onSubtitleMaskToggle();
  }

  void _showControlsTemporarily() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _hideTimer = Timer(_buttonVisibleDuration, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    if (!state.visible) {
      return InkWell(
        key: const ValueKey('media-visual-collapsed-bar'),
        onTap: widget.actions.onShow,
        child: Container(
          height: 44,
          width: double.infinity,
          alignment: Alignment.center,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.smart_display_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.mediaShowVisualTrack,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final controlsVisible = state.expanded || _controlsVisible;
        final subtitleMask = state.subtitleMask;
        final isSubtitleMaskEnabled = subtitleMask?.enabled ?? false;
        final controls = widget.controls;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;
        final preferredHeight = width / (16 / 9);
        final height = state.expanded
            ? maxHeight
            : widget.fillAvailableHeight
            ? maxHeight
            : math.min(preferredHeight, math.min(260.0, maxHeight));
        return MouseRegion(
          onEnter: (_) => _showControlsTemporarily(),
          onHover: (_) => _showControlsTemporarily(),
          child: GestureDetector(
            key: const ValueKey('media-visual-surface'),
            onTap: _showControlsTemporarily,
            child: Center(
              child: SizedBox(
                width: double.infinity,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      key: const ValueKey('media-video-canvas'),
                      color: Colors.black,
                      child: widget.buildVideoView(Size(width, height)),
                    ),
                    // 数据加载后即挂载，开关只改变 isEnabled：开启才会激发手柄，
                    // 挂载本身（打开视频、布局切换）不会。
                    if (subtitleMask != null)
                      Positioned.fill(
                        child: VideoSubtitleMaskOverlay(
                          normalizedRect: subtitleMask.rect,
                          isEnabled: subtitleMask.enabled,
                          contentRect: videoContentRect(
                            Size(width, height),
                            state.videoAspectRatio,
                          ),
                          onRectChanged:
                              widget.actions.onSubtitleMaskRectChanged,
                          onInteractionStart: _hideControls,
                        ),
                      ),
                    Center(
                      child: AnimatedOpacity(
                        opacity: controlsVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: !controlsVisible,
                          child: Tooltip(
                            message: state.isPlaying
                                ? AppLocalizations.of(context)!.pause
                                : AppLocalizations.of(context)!.play,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.58),
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: IconButton(
                                key: const ValueKey(
                                  'media-visual-play-pause-button',
                                ),
                                icon: Icon(
                                  state.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                                color: Colors.white,
                                iconSize: 42,
                                padding: const EdgeInsets.all(14),
                                tooltip: null,
                                onPressed: widget.actions.onPlayPause,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: AnimatedOpacity(
                        opacity: controlsVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: !controlsVisible,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: _spaced([
                              _VisualControlButton(
                                key: const ValueKey(
                                  'media-subtitle-mask-button',
                                ),
                                icon: _SubtitleMaskIcon(
                                  enabled: isSubtitleMaskEnabled,
                                ),
                                active: isSubtitleMaskEnabled,
                                tooltip: isSubtitleMaskEnabled
                                    ? AppLocalizations.of(context)!
                                          .mediaHideSubtitleMask
                                    : AppLocalizations.of(context)!
                                          .mediaShowSubtitleMask,
                                onPressed: _toggleSubtitleMask,
                              ),
                              if (controls.showSubtitleTrackButton)
                                _VisualControlButton(
                                  key: const ValueKey(
                                    'media-subtitle-track-button',
                                  ),
                                  icon: _CcTrackIcon(
                                    enabled: state.subtitleVisible,
                                  ),
                                  active: state.subtitleVisible,
                                  tooltip: state.subtitleVisible
                                      ? AppLocalizations.of(context)!
                                            .mediaHideVideoSubtitles
                                      : AppLocalizations.of(context)!
                                            .mediaShowVideoSubtitles,
                                  onPressed: widget.actions.onSubtitleToggle,
                                ),
                              if (controls.showFullscreenButton)
                                _VisualControlButton(
                                  key: const ValueKey(
                                    'media-fullscreen-button',
                                  ),
                                  icon: Icon(
                                    state.expanded
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen,
                                  ),
                                  active: true,
                                  tooltip: state.expanded
                                      ? AppLocalizations.of(context)!
                                            .mediaExitFullscreen
                                      : AppLocalizations.of(context)!
                                            .mediaEnterFullscreen,
                                  onPressed: widget.actions.onFullscreenToggle,
                                ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: AnimatedOpacity(
                        opacity: controlsVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: !controlsVisible || state.expanded,
                          child: Offstage(
                            offstage: state.expanded,
                            child: _VisualControlButton(
                              key: const ValueKey('media-hide-visual-button'),
                              icon: const Icon(Icons.visibility_off),
                              active: true,
                              tooltip: AppLocalizations.of(context)!
                                  .videoHideTrack,
                              onPressed: widget.actions.onHide,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 在按钮之间插入固定间距，个别按钮被收起时不残留多余空隙。
List<Widget> _spaced(List<Widget> buttons) => [
  for (var i = 0; i < buttons.length; i++) ...[
    if (i > 0) const SizedBox(width: 8),
    buttons[i],
  ],
];

class _VisualControlButton extends StatelessWidget {
  const _VisualControlButton({
    super.key,
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget icon;
  final bool active;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.52),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          icon: IconTheme.merge(
            data: IconThemeData(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.58),
            ),
            child: icon,
          ),
          iconSize: 22,
          splashRadius: 22,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _CcTrackIcon extends StatelessWidget {
  const _CcTrackIcon({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _TrackToggleIcon(
      enabled: enabled,
      glyphBuilder: (color) => Container(
        width: 20,
        height: 15,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.8),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          'CC',
          style: TextStyle(
            color: color,
            fontSize: 9,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// 字幕遮罩开关图标：外框底部横条表示遮住字幕区。
class _SubtitleMaskIcon extends StatelessWidget {
  const _SubtitleMaskIcon({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _TrackToggleIcon(
      enabled: enabled,
      glyphBuilder: (color) => SvgActionIcon(
        assetName: 'assets/icon/subtitle_mask.svg',
        color: color,
      ),
    );
  }
}

/// 画面开关类图标的共用外观：关闭时图形变暗、叠加纯白斜线。
///
/// 斜线保持纯白，保证在视频画面上依然清晰可辨；CC 与字幕遮罩共用这一份，
/// 避免两个按钮的关闭态风格不一致。
class _TrackToggleIcon extends StatelessWidget {
  const _TrackToggleIcon({required this.enabled, required this.glyphBuilder});

  final bool enabled;
  final Widget Function(Color color) glyphBuilder;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.white : Colors.white.withValues(alpha: 0.68);
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          glyphBuilder(color),
          if (!enabled)
            Transform.rotate(
              angle: -0.72,
              child: Container(
                width: 25,
                height: 2.2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
