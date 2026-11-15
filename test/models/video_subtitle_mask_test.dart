import 'dart:ui';

import 'package:echo_loop/models/video_subtitle_mask.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoSubtitleMask', () {
    test('clampRect 把越界矩形收回画面内并保留最小尺寸', () {
      final rect = VideoSubtitleMask.clampRect(
        const Rect.fromLTWH(0.9, -0.2, 0.01, 1.4),
      );

      expect(rect.width, closeTo(VideoSubtitleMask.minNormalizedSize, 1e-9));
      expect(rect.height, 1.0);
      expect(rect.right, lessThanOrEqualTo(1.0));
      expect(rect.top, 0.0);
    });
  });
}
