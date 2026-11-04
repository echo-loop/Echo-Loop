/// 下载速度计算：用最近一段时间内的进度采样求平均速度（字节/秒）。
///
/// 底层下载回调按网络分块触发，相邻两次的瞬时值跳动明显，所以用滑动窗口平均。
/// 每次下载应使用独立的实例；时间来源由调用方注入，便于测试。
class DownloadSpeedMeter {
  DownloadSpeedMeter({
    required DateTime Function() now,
    this.window = const Duration(seconds: 5),
  }) : _now = now;

  final DateTime Function() _now;

  /// 计算平均速度所用的时间窗口。
  final Duration window;

  final List<_ProgressSample> _samples = <_ProgressSample>[];

  /// 记录一次进度（已下载字节数），返回窗口内的平均速度。
  ///
  /// 采样不足或时间未前进时返回 null，表示暂不显示速度。
  double? record(int receivedBytes) {
    final now = _now();
    _samples.add(_ProgressSample(at: now, receivedBytes: receivedBytes));
    _samples.removeWhere((sample) => now.difference(sample.at) > window);
    if (_samples.length < 2) return null;
    final first = _samples.first;
    final elapsed = now.difference(first.at);
    final deltaBytes = receivedBytes - first.receivedBytes;
    if (elapsed <= Duration.zero || deltaBytes < 0) return null;
    return deltaBytes /
        (elapsed.inMicroseconds / Duration.microsecondsPerSecond);
  }
}

class _ProgressSample {
  const _ProgressSample({required this.at, required this.receivedBytes});

  final DateTime at;
  final int receivedBytes;
}
