/// 单个条目的下载状态；无记录即表示空闲。sealed class 便于 switch 穷举。
sealed class DownloadProgress {
  const DownloadProgress();
}

/// 下载中：0.0 - 1.0 的比例 + 字节信息（可选）。
class DownloadInProgress extends DownloadProgress {
  /// 当前音频的本地 audioItemId。
  final String audioItemId;

  /// 展示名称（用于 dialog/snackbar）。
  final String displayName;

  /// 0..1，-1 代表不定态
  final double progress;

  /// 已下载字节（可空）。
  final int? receivedBytes;

  /// 总字节（可空）。
  final int? totalBytes;

  /// 最近窗口内的平均下载速度（字节/秒）；采样不足时为 null。
  final double? speedBytesPerSecond;

  const DownloadInProgress({
    required this.audioItemId,
    required this.displayName,
    required this.progress,
    this.receivedBytes,
    this.totalBytes,
    this.speedBytesPerSecond,
  });
}

/// 下载失败。
class DownloadFailed extends DownloadProgress {
  final String audioItemId;
  final String displayName;
  final Object error;

  const DownloadFailed({
    required this.audioItemId,
    required this.displayName,
    required this.error,
  });
}

/// 社区合集文件的下载资源 key，按远端文件 id（不随地区或签名变化）。
String communityResourceKey(String remoteAudioId) => 'community:$remoteAudioId';
