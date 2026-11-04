import 'package:echo_loop/services/download_speed_meter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DownloadSpeedMeter', () {
    late DateTime now;
    late DownloadSpeedMeter meter;

    setUp(() {
      now = DateTime(2026, 11, 4, 10);
      meter = DownloadSpeedMeter(now: () => now);
    });

    test('采样不足两次时不返回速度', () {
      expect(meter.record(0), isNull);
    });

    test('按窗口内首末采样计算平均速度', () {
      meter.record(0);
      now = now.add(const Duration(seconds: 2));
      expect(meter.record(4096), closeTo(2048, 1e-6));
    });

    test('超出时间窗口的旧采样不参与计算', () {
      meter.record(0);
      now = now.add(const Duration(seconds: 10));
      meter.record(10000);
      now = now.add(const Duration(seconds: 1));

      expect(meter.record(12000), closeTo(2000, 1e-6));
    });

    test('时间未前进或字节数倒退时不返回速度', () {
      meter.record(1000);
      expect(meter.record(2000), isNull);

      now = now.add(const Duration(seconds: 1));
      expect(meter.record(500), isNull);
    });
  });
}
