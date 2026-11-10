/// 快捷速度档位工具函数测试
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/utils/playback_speed.dart';

void main() {
  group('nearestQuickPlaybackSpeedIndex', () {
    test('取最接近当前速度的快捷档位下标', () {
      expect(nearestQuickPlaybackSpeedIndex(0.6), 0);
      expect(nearestQuickPlaybackSpeedIndex(1.0), 2);
      expect(nearestQuickPlaybackSpeedIndex(1.5), 4);
      // 滑块可能设为非快捷档位（如 0.75x 更接近 0.8x）
      expect(nearestQuickPlaybackSpeedIndex(0.75), 1);
      expect(nearestQuickPlaybackSpeedIndex(1.3), 3);
      expect(nearestQuickPlaybackSpeedIndex(2.0), 4);
      expect(nearestQuickPlaybackSpeedIndex(0.4), 0);
    });
  });

  group('nearestPlaybackSpeedIndex', () {
    const options = [0.5, 0.7, 0.8, 0.9, 1.0, 1.2, 1.5, 2.0];

    test('速度不在选项中时取距离最近的选项', () {
      // 1.4 离 1.2 与 1.5 分别为 0.2 与 0.1，应取 1.5
      expect(nearestPlaybackSpeedIndex(options, 1.4), 6);
      // 0.6 离 0.5 与 0.7 同样近，取较小的一项
      expect(nearestPlaybackSpeedIndex(options, 0.6), 0);
      // 速度高于所有选项时取最大项
      expect(nearestPlaybackSpeedIndex(options, 3.0), 7);
    });
  });
}
