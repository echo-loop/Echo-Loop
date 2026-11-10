/// 统一的播放速度档位与格式化工具。
library;

/// 全局统一的离散播放速度档位。
///
/// 规则：
/// - `0.4x-1.5x` 按 `0.1x` 递增；
/// - 额外保留 `2.0x` 档位；
/// - 不再提供 `0.75x / 0.85x / 0.95x / 1.25x / 1.75x` 等旧档位。
const List<double> kUnifiedPlaybackSpeeds = [
  0.4,
  0.5,
  0.6,
  0.7,
  0.8,
  0.9,
  1.0,
  1.1,
  1.2,
  1.3,
  1.4,
  1.5,
  2.0,
];

/// 统一显示播放速度文案，始终保留一位小数。
String formatPlaybackSpeedLabel(double speed) {
  return '${speed.toStringAsFixed(1)}x';
}

/// 将任意速度归一化到支持档位。
///
/// - 超出支持范围时回退到 [fallback]；
/// - 范围内但不在档位表中时，先按 `0.1` 四舍五入，再吸附到支持档位；
/// - 便于旧 `0.75/0.85/0.95` 稳定升到 `0.8/0.9/1.0`。
double normalizePlaybackSpeed(double speed, {double fallback = 1.0}) {
  if (speed < kUnifiedPlaybackSpeeds.first ||
      speed > kUnifiedPlaybackSpeeds.last) {
    return fallback;
  }
  if (kUnifiedPlaybackSpeeds.contains(speed)) return speed;

  final roundedToTenth = (speed * 10).round() / 10;
  if (kUnifiedPlaybackSpeeds.contains(roundedToTenth)) {
    return roundedToTenth;
  }

  var best = kUnifiedPlaybackSpeeds.first;
  var bestDistance = (roundedToTenth - best).abs();
  for (final candidate in kUnifiedPlaybackSpeeds.skip(1)) {
    final distance = (roundedToTenth - candidate).abs();
    if (distance < bestDistance) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best;
}

/// 将当前播放速度转换成离散滑块索引。
double playbackSpeedSliderValue(double speed) {
  return kUnifiedPlaybackSpeeds
      .indexOf(normalizePlaybackSpeed(speed))
      .toDouble();
}

/// 将离散滑块值映射回统一播放速度档位。
double playbackSpeedFromSliderValue(double sliderValue) {
  final index = sliderValue.round().clamp(0, kUnifiedPlaybackSpeeds.length - 1);
  return kUnifiedPlaybackSpeeds[index];
}

/// 播放控制栏速度按钮的可选档位，升序排列。
///
/// 只做粗调，不复用完整的 [kUnifiedPlaybackSpeeds]，以免选择列表过长。
const List<double> kQuickPlaybackSpeeds = [0.6, 0.8, 1.0, 1.2, 1.5];

/// 与 [speed] 最接近的快捷档位下标，用于速度选择器的初始高亮。
int nearestQuickPlaybackSpeedIndex(double speed) =>
    nearestPlaybackSpeedIndex(kQuickPlaybackSpeeds, speed);

/// [options]（升序）中与 [speed] 最接近的下标。
///
/// 速度可能来自完整档位表（如媒体页），不一定在选项里，因此按距离取最近项。
int nearestPlaybackSpeedIndex(List<double> options, double speed) {
  var best = 0;
  var bestDistance = double.infinity;
  for (var i = 0; i < options.length; i++) {
    final distance = (options[i] - speed).abs();
    if (distance < bestDistance) {
      best = i;
      bestDistance = distance;
    }
  }
  return best;
}
