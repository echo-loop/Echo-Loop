import 'dart:io';

import 'package:echo_loop/services/temp_cleanup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('仅删除过期分享文件，保留近期传输和其它缓存', () async {
    final root = await Directory.systemTemp.createTemp(
      'daily_share_cleanup_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    final old = await File('${root.path}/${dailyShareExportTempPrefix}old.png')
        .writeAsBytes([1, 2, 3]);
    await old.setLastModified(
      DateTime.now().subtract(const Duration(hours: 25)),
    );
    final recent = await File(
      '${root.path}/${dailyShareExportTempPrefix}recent.png',
    ).writeAsBytes([4, 5, 6]);
    final unrelated = await File('${root.path}/system_cache.png')
        .writeAsBytes([7]);
    await unrelated.setLastModified(
      DateTime.now().subtract(const Duration(days: 10)),
    );
    final result = await cleanupStaleDailyShareExportTemp(
      resolveDirectory: () async => root,
    );
    expect(result.freedBytes, 3);
    expect(await old.exists(), isFalse);
    expect(await recent.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
  });

  test('目录按最后分享租约过期，复用文件不会沿用旧的创建时间', () async {
    final root = await Directory.systemTemp.createTemp(
      'daily_share_lease_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    final expired = await Directory(
      '${root.path}/${dailyShareExportTempPrefix}expired',
    ).create();
    final active = await Directory(
      '${root.path}/${dailyShareExportTempPrefix}active',
    ).create();
    final expiredLease = await File(
      '${expired.path}/$dailyShareExportLeaseName',
    ).writeAsString('');
    await expiredLease.setLastModified(
      DateTime.now().subtract(const Duration(hours: 25)),
    );
    await File('${active.path}/$dailyShareExportLeaseName').writeAsString('');
    await cleanupStaleDailyShareExportTemp(resolveDirectory: () async => root);
    expect(await expired.exists(), isFalse);
    expect(await active.exists(), isTrue);
  });
}
