import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'media_startup_status.dart';

/// 视频槽内的启动占位：黑色画布上显示加载或失败态，填满父级分给视频的区域。
///
/// 仅在视频未就绪时叠在视频画面之上，ready 后由调用方移除，视频画面直接接管。
/// 分栏布局由 [PracticeMediaSplitLayout] 决定尺寸，因此占位不自行计算宽高。
class MediaStartupCanvas extends StatelessWidget {
  const MediaStartupCanvas({super.key, required this.status});

  final MediaStartupStatus status;

  @override
  Widget build(BuildContext context) {
    // 不透明的手势层挡住下方未就绪视频的点击；失败态的重试按钮是子节点，仍可点。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        key: const ValueKey('media-startup-canvas'),
        color: Colors.black,
        child: Center(
          child: MediaStartupStatusContent(status: status, videoStyle: true),
        ),
      ),
    );
  }
}

/// 启动加载或失败时的图标、文案与重试按钮。
///
/// [videoStyle] 为 true 时用于黑色视频画布（白色前景、显示视频文案）；
/// 否则跟随页面主题色，用于音频任务的普通页面遮罩。
class MediaStartupStatusContent extends StatelessWidget {
  const MediaStartupStatusContent({
    super.key,
    required this.status,
    required this.videoStyle,
  });

  final MediaStartupStatus status;
  final bool videoStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 文字跟随系统字体缩放，加载与失败态保持一致。
    if (status.phase == ManagedMediaPhase.failure) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: videoStyle ? Colors.white : theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          if (videoStyle)
            Text(
              l10n.videoLoadFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: status.retry, child: Text(l10n.videoRetry)),
        ],
      );
    }

    return Semantics(
      label: videoStyle ? l10n.videoLoading : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: videoStyle ? Colors.white : theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          if (videoStyle)
            Text(
              l10n.videoLoading,
              style: const TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
