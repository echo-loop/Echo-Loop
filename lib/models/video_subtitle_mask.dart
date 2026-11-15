import 'dart:ui';

/// 视频字幕遮罩设置：用于遮住视频画面里烧录的原字幕，按视频分别记住。
///
/// [rect] 是相对“视频实际画面区域”（去掉黑边后）的归一化坐标，取值 0~1。
/// 这样窗口缩放或全屏切换后，遮罩仍落在画面同一位置。
class VideoSubtitleMask {
  const VideoSubtitleMask({this.enabled = false, this.rect = defaultRect});

  /// 默认位置：画面底部、水平居中。
  static const defaultRect = Rect.fromLTWH(0.08, 0.76, 0.84, 0.18);

  /// 归一化尺寸下限，避免遮罩被缩到无法再拖动。
  static const minNormalizedSize = 0.06;

  final bool enabled;
  final Rect rect;

  VideoSubtitleMask copyWith({bool? enabled, Rect? rect}) {
    return VideoSubtitleMask(
      enabled: enabled ?? this.enabled,
      rect: rect ?? this.rect,
    );
  }

  /// 把任意矩形约束到画面内且不小于最小尺寸。
  static Rect clampRect(Rect rect) {
    final width = rect.width.clamp(minNormalizedSize, 1.0);
    final height = rect.height.clamp(minNormalizedSize, 1.0);
    final left = rect.left.clamp(0.0, 1.0 - width);
    final top = rect.top.clamp(0.0, 1.0 - height);
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  bool operator ==(Object other) =>
      other is VideoSubtitleMask &&
      other.enabled == enabled &&
      other.rect == rect;

  @override
  int get hashCode => Object.hash(enabled, rect);
}
