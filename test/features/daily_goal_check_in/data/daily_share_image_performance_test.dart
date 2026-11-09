import 'dart:ui' as ui;

import 'package:echo_loop/features/daily_goal_check_in/data/daily_check_in_share_image.dart';
import 'package:echo_loop/features/daily_goal_check_in/data/daily_share_decoded_image_cache.dart';
import 'package:echo_loop/features/daily_goal_check_in/domain/share_card_template.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../share_card_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('真实固定资源下冷暖缓存合成采样，不对机器耗时作断言', () async {
    await DailyShareFontLoader().load();
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
        .drawPaint(ui.Paint()..color = const ui.Color(0xffe4c59a));
    final picture = recorder.endRecording();
    final background = await picture.toImage(1080, 1440);
    final backgroundBytes = (await background.toByteData(
      format: ui.ImageByteFormat.png,
    ))!;
    picture.dispose();
    background.dispose();
    final logo = await rootBundle.load('assets/icon/app-icon-1024-alpha.png');
    final qr = await rootBundle.load(dailyShareQrAsset(true));
    final assets = DailyCheckInShareAssets(
      background: backgroundBytes.buffer.asUint8List(
        backgroundBytes.offsetInBytes,
        backgroundBytes.lengthInBytes,
      ),
      logo: logo.buffer.asUint8List(logo.offsetInBytes, logo.lengthInBytes),
      qrCode: qr.buffer.asUint8List(qr.offsetInBytes, qr.lengthInBytes),
    );
    final cache = DailyShareDecodedImageCache();
    final template = ShareCardTemplate.fromJson(cardJson());
    final cold = <int>[];
    final warm = <int>[];
    try {
      for (var sample = 0; sample < 3; sample++) {
        cache.clear();
        for (final isWarm in [false, true]) {
          final watch = Stopwatch()..start();
          // 每次改变可见分钟，代表缓存资源齐全时实际需要更新的统计。
          final image = await generateDailyCheckInShareImage(
            template: template,
            data: DailyCheckInShareData(
              date: DateTime(2026, 11, 9),
              totalSeconds: (sample * 2 + (isWarm ? 2 : 1)) * 60,
              inputSeconds: 60,
              outputSeconds: 0,
              streak: 128,
              isChinese: true,
              nativeLanguage: 'zh-CN',
              nickname: 'Bluebird',
            ),
            assets: assets,
            decodedImageCache: cache,
          );
          watch.stop();
          expect(image.preview.width, 1080);
          expect(image.pngBytes, isNotEmpty);
          image.dispose();
          (isWarm ? warm : cold).add(watch.elapsedMilliseconds);
          // 测试日志标记和生成器分阶段日志一一对应，便于人工诊断。
          debugPrint(
            '分享性能采样 模式=${isWarm ? "暖" : "冷"} 序号=${sample + 1} 总耗时=${watch.elapsedMilliseconds}ms',
          );
        }
      }
      final sortedCold = [...cold]..sort();
      final sortedWarm = [...warm]..sort();
      debugPrint(
        '分享性能汇总 Debug测试引擎 冷样本=$cold 中位数=${sortedCold[1]}ms 暖样本=$warm 中位数=${sortedWarm[1]}ms',
      );
    } finally {
      cache.dispose();
    }
  });
}
