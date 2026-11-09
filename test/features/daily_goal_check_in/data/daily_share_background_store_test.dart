import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echo_loop/features/daily_goal_check_in/data/daily_share_background_store.dart';
import 'package:echo_loop/features/daily_goal_check_in/domain/share_card_template.dart';
import 'package:flutter_test/flutter_test.dart';

import '../share_card_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Uint8List bytes;
  final today = DateTime(2026, 11, 9);
  final template = ShareCardTemplate.fromJson(cardJson());

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'daily_share_store_test_',
    );
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
        .drawPaint(ui.Paint()..color = const ui.Color(0xffaabbcc));
    final picture = recorder.endRecording();
    final image = await picture.toImage(20, 30);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    image.dispose();
    picture.dispose();
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  DailyShareBackgroundStore store() =>
      DailyShareBackgroundStore(resolveDirectory: () async => directory);

  test('真实文件跨实例恢复模板与背景，换卡只保留一个选中模板', () async {
    final original = store();
    await original.write(today, template, bytes);
    final restored = await store().read(today);
    expect(restored!.template.toJson(), template.toJson());
    expect(restored.bytes, bytes);
    final next = ShareCardTemplate.fromJson({
      ...cardJson(word: true),
      'id': 'next',
    });
    await original.write(today, next, bytes);
    final selected = await store().read(today);
    expect(selected!.template.id, 'next');
    expect(selected.template.toJson(), next.toJson());
    final files = await Directory(
      '${directory.path}/${DailyShareBackgroundStore.directoryName}',
    ).list().toList();
    expect(files.length, 2);
  });

  test('过期背景与清单清除', () async {
    final cache = store();
    await cache.write(today, template, bytes);
    await cache.removeExpired(DateTime(2026, 11, 10));
    expect(await cache.read(today), isNull);
    expect(
      await Directory(
        '${directory.path}/${DailyShareBackgroundStore.directoryName}',
      ).exists(),
      isFalse,
    );
  });

  test('损坏图片或清单返回miss并清理，随后可重新写入', () async {
    final cache = store();
    await cache.write(today, template, bytes);
    final folder = Directory(
      '${directory.path}/${DailyShareBackgroundStore.directoryName}',
    );
    final image = await folder
        .list()
        .where((file) => file.path.endsWith('.bin'))
        .first;
    // 保留合法图片头，仅篡改末尾内容，验证校验和而非仅依赖格式头。
    final altered = Uint8List.fromList(bytes);
    altered[altered.length - 1] ^= 1;
    await File(image.path).writeAsBytes(altered);
    expect(await cache.read(today), isNull);
    await cache.write(today, template, bytes);
    await File('${folder.path}/manifest.json').writeAsString('{invalid');
    expect(await cache.read(today), isNull);
    await cache.write(today, template, bytes);
    expect((await cache.read(today))!.bytes, bytes);
  });

  test('无效写入保留旧缓存，超大图片拒绝', () async {
    final cache = store();
    await cache.write(today, template, bytes);
    await expectLater(
      cache.write(today, template, Uint8List.fromList([1, 2])),
      throwsFormatException,
    );
    await expectLater(
      cache.write(
        today,
        template,
        Uint8List(DailyShareBackgroundStore.maxImageBytes + 1),
      ),
      throwsFormatException,
    );
    expect((await cache.read(today))!.template.id, template.id);
  });

  test('写入与清除按调用顺序串行，清除后不会被旧写入复活', () async {
    final cache = store();
    final writing = cache.write(today, template, bytes);
    final clearing = cache.clear();
    await Future.wait([writing, clearing]);
    expect(await cache.read(today), isNull);
  });
}
