/// 学习计划页所需的媒体就绪状态。
///
/// 只有 [MediaReady] 才允许加载学习内容；其它状态由占位页展示。
/// 使用 sealed class，便于 `switch` 穷举。
sealed class MediaReadiness {
  const MediaReadiness();
}

/// 条目已有本地音频路径，正在校验文件是否存在。
final class MediaChecking extends MediaReadiness {
  const MediaChecking();
}

/// 媒体已就绪，可以学习。
final class MediaReady extends MediaReadiness {
  const MediaReady();
}

/// 尚未开始下载（需要 ensure）。
final class MediaNotDownloaded extends MediaReadiness {
  const MediaNotDownloaded();
}

/// 本条目正在下载。[progress] 为 0..1；null 表示总大小未知的不定态。
final class MediaDownloading extends MediaReadiness {
  const MediaDownloading({this.progress});

  final double? progress;
}

/// 同一下载通道正被其它材料占用，本条目会在通道空闲后自动开始。
final class MediaWaiting extends MediaReadiness {
  const MediaWaiting();
}

/// 本条目下载失败，可以重试。
final class MediaFailed extends MediaReadiness {
  const MediaFailed(this.error);

  final Object error;
}

/// 社区文件已下架，无法再下载。
final class MediaUnavailable extends MediaReadiness {
  const MediaUnavailable();
}

/// 条目记录了媒体路径，但文件已不存在；或条目既没有媒体也无法下载。
final class MediaFileMissing extends MediaReadiness {
  const MediaFileMissing();
}

/// 音频库中找不到该条目。
final class MediaItemMissing extends MediaReadiness {
  const MediaItemMissing();
}
