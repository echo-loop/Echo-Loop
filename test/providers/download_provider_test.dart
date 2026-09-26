import 'dart:ui' show Locale;

import 'package:echo_loop/providers/download_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads English background download notification labels', () async {
    final labels = await loadBackgroundFileDownloadNotificationLabels(
      const Locale('en'),
    );

    expect(labels.running, 'Downloading');
    expect(labels.complete, 'Download complete');
    expect(labels.failed, 'Download failed');
  });

  test(
    'loads Simplified Chinese background download notification labels',
    () async {
      final labels = await loadBackgroundFileDownloadNotificationLabels(
        const Locale('zh', 'CN'),
      );

      expect(labels.running, '正在下载');
      expect(labels.complete, '下载完成');
      expect(labels.failed, '下载失败');
    },
  );
}
