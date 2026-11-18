import 'dart:ui';

/// 判断复用的原生视频纹理是否已画出当前媒体的画面。
///
/// media_kit 跨 open 复用同一块纹理，新媒体出帧前纹理仍是上一个媒体的最后一帧。
/// 只有同时满足以下条件才认为纹理属于当前媒体：
/// - mpv `vo-configured` 在本次 open 之后变为 yes：VO 已为新媒体完成配置并开始出图；
/// - 纹理尺寸等于新媒体尺寸：尺寸不同时原生会先重建纹理再绘制，重建前纹理仍是旧画面。
///
/// `video-params` 只表示解码器输出参数，实测比原生出帧早 100~400ms，不能作为信号。
class VideoFrameGate {
  bool _isVoConfigured = false;
  Size? _videoSize;
  Size? _textureSize;
  bool _isCurrentMediaVisible = false;

  /// 纹理是否已画出当前媒体。
  bool get isCurrentMediaVisible => _isCurrentMediaVisible;

  /// VO 已为当前媒体配置、尺寸已知，但纹理尚未追上：需要主动让 mpv 重绘一帧。
  ///
  /// 暂停时 mpv 不会主动出帧，纹理会一直停在上一媒体的尺寸，画面不放行。
  bool get needsFrameRedraw {
    final videoSize = _videoSize;
    return !_isCurrentMediaVisible &&
        _isVoConfigured &&
        videoSize != null &&
        _textureSize != videoSize;
  }

  // 以下仅供诊断日志使用。
  bool get isVoConfigured => _isVoConfigured;
  Size? get videoSize => _videoSize;
  Size? get textureSize => _textureSize;

  /// 开始打开新媒体：此后纹理内容一律视为上一个媒体，直到新媒体满足出帧条件。
  void resetForNewMedia() {
    _isVoConfigured = false;
    _videoSize = null;
    _isCurrentMediaVisible = false;
  }

  /// 返回本次输入是否让当前媒体变为可见。
  bool updateVoConfigured(bool isConfigured) {
    _isVoConfigured = isConfigured;
    return _evaluate();
  }

  bool updateVideoSize(Size? size) {
    _videoSize = _validSize(size);
    return _evaluate();
  }

  bool updateTextureSize(Size? size) {
    _textureSize = _validSize(size);
    return _evaluate();
  }

  bool _evaluate() {
    if (_isCurrentMediaVisible) return false;
    final videoSize = _videoSize;
    if (!_isVoConfigured || videoSize == null) return false;
    if (_textureSize != videoSize) return false;
    _isCurrentMediaVisible = true;
    return true;
  }

  static Size? _validSize(Size? size) {
    if (size == null || size.width <= 0 || size.height <= 0) return null;
    return size;
  }
}
