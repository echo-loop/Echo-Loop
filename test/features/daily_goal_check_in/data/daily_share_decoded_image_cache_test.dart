import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echo_loop/features/daily_goal_check_in/data/daily_share_decoded_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> png(int width, int height) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
        .drawPaint(ui.Paint()..color = const ui.Color(0xffabcdef));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  test('小资源按绘制尺寸解码，命中复用底层图像且返回独立句柄', () async {
    final cache = DailyShareDecodedImageCache();
    final bytes = await png(512, 512);
    final avatar = await cache.acquire(DailyShareImageRole.avatar, bytes);
    final again = await cache.acquire(DailyShareImageRole.avatar, bytes);
    expect(avatar.width, 54);
    expect(avatar.height, 54);
    expect(avatar.isCloneOf(again), isTrue);
    final logo = await cache.acquire(DailyShareImageRole.logo, bytes);
    final qr = await cache.acquire(DailyShareImageRole.qrCode, bytes);
    expect(logo.width, 80);
    expect(qr.width, 106);
    cache.dispose();
    expect(avatar.debugDisposed, isFalse);
    expect(again.debugDisposed, isFalse);
    avatar.dispose();
    again.dispose();
    logo.dispose();
    qr.dispose();
  });

  test('替换或解码中清空缓存不提前释放借用句柄', () async {
    final cache = DailyShareDecodedImageCache();
    final first = await png(512, 512);
    final second = await png(200, 100);
    final pending = cache.acquire(DailyShareImageRole.background, first);
    cache.clear();
    final previous = await pending;
    final replacement = await cache.acquire(
      DailyShareImageRole.background,
      second,
    );
    expect(previous.debugDisposed, isFalse);
    expect(replacement.width, 200);
    expect(replacement.height, 100);
    cache.dispose();
    previous.dispose();
    replacement.dispose();
  });

  test('失败解码不污染缓存，随后可重试', () async {
    final cache = DailyShareDecodedImageCache();
    await expectLater(
      cache.acquire(DailyShareImageRole.avatar, Uint8List(0)),
      throwsA(anything),
    );
    final avatar = await cache.acquire(
      DailyShareImageRole.avatar,
      await png(24, 24),
    );
    expect(avatar.width, 24);
    avatar.dispose();
    cache.dispose();
  });
}
