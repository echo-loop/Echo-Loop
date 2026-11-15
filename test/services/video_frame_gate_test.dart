import 'dart:ui';

import 'package:echo_loop/services/video_frame_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const portrait = Size(720, 1280);
  const landscape = Size(1280, 720);

  test('尺寸不同：VO 已配置但纹理未重建前仍是上一媒体画面', () {
    final gate = VideoFrameGate()
      ..updateTextureSize(portrait)
      ..resetForNewMedia();

    expect(gate.updateVideoSize(landscape), isFalse);
    expect(gate.updateVoConfigured(true), isFalse);
    expect(gate.isCurrentMediaVisible, isFalse);

    expect(gate.updateTextureSize(landscape), isTrue);
    expect(gate.isCurrentMediaVisible, isTrue);
  });

  test('尺寸相同：纹理不会重建，以 VO 配置完成为准', () {
    final gate = VideoFrameGate()
      ..updateTextureSize(portrait)
      ..resetForNewMedia();

    expect(gate.updateVideoSize(portrait), isFalse);
    expect(gate.updateVoConfigured(true), isTrue);
  });

  test('打开新媒体时撤销上一媒体的 VO 状态与尺寸', () {
    final gate = VideoFrameGate()
      ..updateTextureSize(portrait)
      ..updateVideoSize(portrait)
      ..updateVoConfigured(true);
    expect(gate.isCurrentMediaVisible, isTrue);

    gate.resetForNewMedia();
    expect(gate.isCurrentMediaVisible, isFalse);
    // 新媒体尺寸未知时，旧 VO 状态残留也不能放行。
    expect(gate.updateVoConfigured(true), isFalse);
    expect(gate.updateVideoSize(portrait), isTrue);
  });

  test('无视频轨（无有效尺寸）时始终不绘制纹理', () {
    final gate = VideoFrameGate()
      ..updateTextureSize(portrait)
      ..resetForNewMedia();

    expect(gate.updateVideoSize(Size.zero), isFalse);
    expect(gate.updateVoConfigured(true), isFalse);
  });
}
