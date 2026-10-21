import 'media_load_result.dart';

/// 学习任务进入页面后才执行的媒体准备命令。
///
/// 盲听、逐句精听、难句跟读、难句补练与段落复述共用该协议；页面只负责托管 loading、
/// 重试与取消，具体任务状态仍由各自 controller 初始化。
class MediaLearningStartup {
  const MediaLearningStartup({
    required this.loadKey,
    required this.load,
    required this.cancel,
    this.showVideoLoading = true,
  });

  /// 标识本次加载任务；变化时托管组件会取消旧任务并启动新任务。
  final Object loadKey;

  /// 准备媒体与对应学习会话，返回统一的加载结果。
  final Future<MediaLoadResult> Function() load;

  /// 取消尚未完成的进入任务，或退出已经准备完成的媒体会话。
  final Future<void> Function() cancel;

  /// 是否展示视频加载文案；音频练习复用该延迟启动协议时关闭。
  final bool showVideoLoading;
}
