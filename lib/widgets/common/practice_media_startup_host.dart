import 'package:flutter/widgets.dart';

import '../../models/media_learning_startup.dart';
import 'managed_media_visual_surface.dart';

/// 学习任务页与随心听的媒体启动托管入口，统一各页面对 [MediaLearningStartup] 的接入。
///
/// 视频任务的加载占位需要和分栏布局同位置，因此正文以 [buildBody] 接收启动状态，
/// 交给 [PracticeMediaSplitLayout] 画在视频槽内；音频任务与无启动任务时
/// [buildBody] 收到 null，分别使用全页遮罩或直接展示。
class PracticeMediaStartupHost extends StatelessWidget {
  const PracticeMediaStartupHost({
    super.key,
    required this.startup,
    this.onReady,
    required this.buildBody,
  });

  final MediaLearningStartup? startup;
  final VoidCallback? onReady;
  final Widget Function(MediaStartupStatus? status) buildBody;

  @override
  Widget build(BuildContext context) {
    final startup = this.startup;
    if (startup == null) return buildBody(null);
    if (!startup.showVideoLoading) {
      return ManagedMediaVisualSurface(
        loadKey: startup.loadKey,
        load: startup.load,
        cancel: startup.cancel,
        showVideoLoading: false,
        onReady: onReady,
        child: buildBody(null),
      );
    }
    return ManagedMediaVisualSurface.builder(
      loadKey: startup.loadKey,
      load: startup.load,
      cancel: startup.cancel,
      onReady: onReady,
      builder: (context, status) => buildBody(status),
    );
  }
}
