import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/media_load_result.dart';
import '../../services/app_logger.dart';
import 'media_startup_canvas.dart';
import 'media_startup_status.dart';

export 'media_startup_status.dart';

/// 按启动状态构建内容，用于由使用方自行决定加载占位的位置（如分栏视频槽）。
typedef MediaStartupBuilder = Widget Function(
  BuildContext context,
  MediaStartupStatus status,
);

/// 自动管理媒体准备、失败重试与迟到结果隔离的可复用画面托管层。
///
/// 两种用法二选一：
/// - 默认构造：[child] 之上叠加全页加载 / 失败遮罩。
/// - [ManagedMediaVisualSurface.builder]：不绘制遮罩，由 [builder] 按
///   [MediaStartupStatus] 自行放置占位，加载态与最终布局占同一位置。
///
/// [load] 与 [cancel] 由 feature controller 注入，组件不直接依赖 Provider 或
/// MediaEngine。每次加载都会分配 generation；切换 [loadKey] 或销毁组件后，旧
/// Future 即使完成也不会覆盖当前 UI。
class ManagedMediaVisualSurface extends StatefulWidget {
  const ManagedMediaVisualSurface({
    super.key,
    required this.loadKey,
    required this.load,
    required this.cancel,
    required Widget this.child,
    this.onReady,
    this.showVideoLoading = true,
  }) : builder = null;

  const ManagedMediaVisualSurface.builder({
    super.key,
    required this.loadKey,
    required this.load,
    required this.cancel,
    required MediaStartupBuilder this.builder,
    this.onReady,
  }) : child = null,
       showVideoLoading = true;

  /// 标识当前媒体准备任务；变化时取消旧任务并加载新媒体。
  final Object loadKey;

  /// 启动一次全新的媒体准备任务。
  final Future<MediaLoadResult> Function() load;

  /// 使当前业务加载 generation 失效；实现必须幂等。
  final Future<void> Function() cancel;

  /// 媒体 ready 后展示的业务内容；与 [builder] 互斥。
  final Widget? child;

  /// 按启动状态构建内容；与 [child] 互斥。
  final MediaStartupBuilder? builder;

  /// 当前 generation 首次 ready 后调用一次。
  final VoidCallback? onReady;

  /// 是否使用视频加载样式；音频任务使用普通页面加载遮罩。仅对 [child] 用法生效。
  final bool showVideoLoading;

  @override
  State<ManagedMediaVisualSurface> createState() =>
      _ManagedMediaVisualSurfaceState();
}

class _ManagedMediaVisualSurfaceState extends State<ManagedMediaVisualSurface> {
  var _phase = ManagedMediaPhase.loading;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant ManagedMediaVisualSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadKey != widget.loadKey) {
      unawaited(oldWidget.cancel());
      _startLoad();
    }
  }

  @override
  void dispose() {
    _generation += 1;
    if (_phase != ManagedMediaPhase.ready) {
      unawaited(widget.cancel());
    }
    super.dispose();
  }

  /// 启动并守卫一次加载；只有最新 generation 可以提交终态。
  void _startLoad() {
    final generation = ++_generation;
    if (mounted) {
      setState(() => _phase = ManagedMediaPhase.loading);
    }
    // 首次加载可能同步写入 Provider，必须等当前 widget tree 完成本帧构建。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      unawaited(_runLoad(generation));
    });
  }

  Future<void> _runLoad(int generation) async {
    MediaLoadResult result;
    AppLogger.log(
      'ManagedMedia',
      'event=startup_started generation=$generation loadKey=${widget.loadKey}',
    );
    try {
      result = await widget.load();
    } catch (error, stackTrace) {
      AppLogger.log(
        'ManagedMedia',
        '✗ load command failed: $error\n$stackTrace',
      );
      result = MediaLoadResult.failure;
    }
    if (!mounted || generation != _generation) return;

    switch (result) {
      case MediaLoadResult.ready:
        AppLogger.log(
          'ManagedMedia',
          'event=startup_ready generation=$generation loadKey=${widget.loadKey}',
        );
        setState(() => _phase = ManagedMediaPhase.ready);
        widget.onReady?.call();
      case MediaLoadResult.failure:
        AppLogger.log(
          'ManagedMedia',
          'event=startup_failed generation=$generation loadKey=${widget.loadKey}',
        );
        setState(() => _phase = ManagedMediaPhase.failure);
      case MediaLoadResult.cancelled:
        AppLogger.log(
          'ManagedMedia',
          'event=startup_cancelled generation=$generation loadKey=${widget.loadKey}',
        );
        setState(() => _phase = ManagedMediaPhase.cancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = MediaStartupStatus(phase: _phase, retry: _startLoad);
    final builder = widget.builder;
    if (builder != null) return builder(context, status);

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final overlay = switch (_phase) {
      ManagedMediaPhase.ready => const SizedBox.shrink(
        key: ValueKey('managed-media-ready'),
      ),
      _ => _MediaOverlayFrame(
        key: ValueKey('managed-media-${_phase.name}'),
        showVideoCanvas: widget.showVideoLoading,
        child: MediaStartupStatusContent(
          status: status,
          videoStyle: widget.showVideoLoading,
        ),
      ),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child!,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _phase == ManagedMediaPhase.ready,
            child: AnimatedSwitcher(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: overlay,
            ),
          ),
        ),
      ],
    );
  }
}

/// 根据媒体类型绘制视频画布或普通页面遮罩。
class _MediaOverlayFrame extends StatelessWidget {
  const _MediaOverlayFrame({
    super.key,
    required this.child,
    required this.showVideoCanvas,
  });

  final Widget child;
  final bool showVideoCanvas;

  @override
  Widget build(BuildContext context) {
    if (!showVideoCanvas) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(child: child),
      );
    }

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final maxHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 260.0;
          final height = math.min(width / (16 / 9), math.min(260.0, maxHeight));
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              key: const ValueKey('managed-media-overlay-canvas'),
              width: double.infinity,
              height: height,
              child: ColoredBox(
                color: Colors.black,
                child: Center(child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}
