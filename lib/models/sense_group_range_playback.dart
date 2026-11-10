/// 意群时间区间播放的最小契约。
///
/// 讲解 UI 只表达用户要播放或取消某材料中的一个意群，不依赖具体媒体引擎；不同学习
/// 会话可各自注入实现，避免跨材料复用全局播放器。
abstract interface class SenseGroupRangePlayback {
  /// 播放 [audioItemId] 的 [start] 至 [end]；新的调用会使旧播放失效。
  Future<void> play(String audioItemId, Duration start, Duration end);

  /// 取消当前意群播放，并使迟到的异步回调失效。
  Future<void> cancel();
}

/// 支持句子讲解页暂停续播的区间播放能力。
///
/// 意群试听仍使用 [SenseGroupRangePlayback.play] 从区间起点播放；只有句子讲解页
/// 显式调用 [playFromPosition] 时才从已有暂停位置继续。
abstract interface class ResumableSentenceRangePlayback {
  /// 当前媒体绝对位置。
  Duration get currentPosition;

  /// 从 [position] 继续播放到 [end]。
  Future<void> playFromPosition(
    String audioItemId,
    Duration start,
    Duration end,
    Duration position,
  );
}

/// 支持在区间播放进行中改变播放速度的能力。
///
/// 句子讲解页的速度按钮用它让正在播放的句子即时变速；未实现该接口的播放器只能在下一次
/// 播放时应用新速度。
abstract interface class LiveSpeedRangePlayback {
  /// 立即把 [speed] 应用到正在进行的区间播放；未在播放时仅影响之后的播放。
  Future<void> setPlaybackSpeed(double speed);
}
