import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/media_load_result.dart';
import '../../services/app_logger.dart';

/// 自动管理媒体准备、失败重试与迟到结果隔离的可复用画面托管层。
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
    required this.child,
    this.onReady,
    this.showVideoLoading = true,
  });

  /// 标识当前媒体准备任务；变化时取消旧任务并加载新媒体。
  final Object loadKey;

  /// 启动一次全新的媒体准备任务。
  final Future<MediaLoadResult> Function() load;

  /// 使当前业务加载 generation 失效；实现必须幂等。
  final Future<void> Function() cancel;

  /// 媒体 ready 后展示的业务内容。
  final Widget child;

  /// 当前 generation 首次 ready 后调用一次。
  final VoidCallback? onReady;

  /// 是否使用视频加载样式；音频任务使用普通页面加载遮罩。
  final bool showVideoLoading;

  @override
  State<ManagedMediaVisualSurface> createState() =>
      _ManagedMediaVisualSurfaceState();
}

enum _ManagedMediaPhase { loading, ready, failure, cancelled }

class _ManagedMediaVisualSurfaceState extends State<ManagedMediaVisualSurface> {
  var _phase = _ManagedMediaPhase.loading;
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
    if (_phase != _ManagedMediaPhase.ready) {
      unawaited(widget.cancel());
    }
    super.dispose();
  }

  /// 启动并守卫一次加载；只有最新 generation 可以提交终态。
  void _startLoad() {
    final generation = ++_generation;
    if (mounted) {
      setState(() => _phase = _ManagedMediaPhase.loading);
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
        setState(() => _phase = _ManagedMediaPhase.ready);
        widget.onReady?.call();
      case MediaLoadResult.failure:
        AppLogger.log(
          'ManagedMedia',
          'event=startup_failed generation=$generation loadKey=${widget.loadKey}',
        );
        setState(() => _phase = _ManagedMediaPhase.failure);
      case MediaLoadResult.cancelled:
        AppLogger.log(
          'ManagedMedia',
          'event=startup_cancelled generation=$generation loadKey=${widget.loadKey}',
        );
        setState(() => _phase = _ManagedMediaPhase.cancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final overlay = switch (_phase) {
      _ManagedMediaPhase.loading => _MediaLoadingOverlay(
        key: ValueKey('managed-media-loading'),
        showVideoLoading: widget.showVideoLoading,
      ),
      _ManagedMediaPhase.failure => _MediaFailureOverlay(
        key: const ValueKey('managed-media-failure'),
        onRetry: _startLoad,
        showVideoLoading: widget.showVideoLoading,
      ),
      _ManagedMediaPhase.cancelled => _MediaLoadingOverlay(
        key: ValueKey('managed-media-cancelled'),
        showVideoLoading: widget.showVideoLoading,
      ),
      _ManagedMediaPhase.ready => const SizedBox.shrink(
        key: ValueKey('managed-media-ready'),
      ),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _phase == _ManagedMediaPhase.ready,
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

class _MediaLoadingOverlay extends StatelessWidget {
  const _MediaLoadingOverlay({super.key, required this.showVideoLoading});

  final bool showVideoLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 音频任务使用主题色提示，避免在普通页面背景上显示视频样式的黑色画布。
    // 文字跟随系统字体缩放，与失败态保持一致。
    return _MediaOverlayFrame(
      showVideoCanvas: showVideoLoading,
      child: Semantics(
        label: showVideoLoading ? l10n.videoLoading : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: showVideoLoading
                  ? Colors.white
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            if (showVideoLoading)
              Text(
                l10n.videoLoading,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaFailureOverlay extends StatelessWidget {
  const _MediaFailureOverlay({
    super.key,
    required this.onRetry,
    required this.showVideoLoading,
  });

  final VoidCallback onRetry;
  final bool showVideoLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return _MediaOverlayFrame(
      showVideoCanvas: showVideoLoading,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: showVideoLoading ? Colors.white : theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          if (showVideoLoading)
            Text(
              l10n.videoLoadFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(l10n.videoRetry)),
        ],
      ),
    );
  }
}

/// 根据媒体类型绘制视频画布或普通页面遮罩。
class _MediaOverlayFrame extends StatelessWidget {
  const _MediaOverlayFrame({
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
