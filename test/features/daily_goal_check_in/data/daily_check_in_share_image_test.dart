import 'dart:io';
import 'dart:ui' as ui;

import 'package:echo_loop/features/daily_goal_check_in/data/daily_check_in_share_image.dart';
import 'package:echo_loop/features/daily_goal_check_in/domain/share_card_template.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../share_card_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('二维码按地区选择，与界面语言无关', () {
    expect(dailyShareQrAsset(true), 'assets/qr/www.echo-loop.cn.png');
    expect(dailyShareQrAsset(false), 'assets/qr/www.echo-loop.top.png');
  });

  for (final word in [false, true]) {
    test('完整渲染${word ? '单词' : '句子'}卡片并编码，预览克隆可独立释放', () async {
      await DailyShareFontLoader().load();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 1080, 1440),
        ui.Paint()..color = const ui.Color(0xffe4c59a),
      );
      final picture = recorder.endRecording();
      final backgroundImage = await picture.toImage(1080, 1440);
      final background = await backgroundImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      picture.dispose();
      backgroundImage.dispose();
      final logo = await rootBundle.load('assets/icon/app-icon-1024-alpha.png');
      final qr = await rootBundle.load(dailyShareQrAsset(true));
      final image = await generateDailyCheckInShareImage(
        template: ShareCardTemplate.fromJson(cardJson(word: word)),
        data: DailyCheckInShareData(
          date: DateTime(2026, 11, 8),
          totalSeconds: 1920,
          inputSeconds: 1200,
          outputSeconds: 720,
          streak: 128,
          nickname: 'Bluebird',
          isChinese: !word,
          nativeLanguage: 'zh-CN',
        ),
        assets: DailyCheckInShareAssets(
          background: background!.buffer.asUint8List(),
          logo: logo.buffer.asUint8List(),
          qrCode: qr.buffer.asUint8List(),
        ),
      );
      expect(image.preview.width, 1080);
      expect(image.preview.height, 1440);
      final codec = await ui.instantiateImageCodec(image.pngBytes);
      final decoded = (await codec.getNextFrame()).image;
      expect(decoded.width, 1080);
      expect(decoded.height, 1440);
      decoded.dispose();
      codec.dispose();
      final clone = image.clone();
      image.dispose();
      expect(clone.preview.debugDisposed, isFalse);
      // 保留可视化检查产物，避免只用尺寸断言掩盖排版错误。
      final directory = await Directory('build/test_artifacts')
          .create(recursive: true);
      await File(
        '${directory.path}/daily_share_${word ? 'word' : 'sentence'}.png',
      ).writeAsBytes(clone.pngBytes);
      clone.dispose();
    });
  }
}
