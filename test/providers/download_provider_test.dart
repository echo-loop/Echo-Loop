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

  test('不支持的 locale 直接加载时回退英文，不抛异常（fr_CN 回归）', () async {
    final labels = await loadBackgroundFileDownloadNotificationLabels(
      const Locale('fr', 'CN'),
    );

    expect(labels.running, 'Downloading');
    expect(labels.failed, 'Download failed');
  });

  test('跟随系统时按系统语言解析，不支持的系统语言回退英文', () async {
    final labels = await resolveBackgroundDownloadLabels(
      settingLocale: null,
      systemLocale: const Locale('fr', 'CN'),
    );

    expect(labels.running, 'Downloading');
    expect(labels.complete, 'Download complete');
  });

  test('App 显式设置的语言优先于系统语言', () async {
    final labels = await resolveBackgroundDownloadLabels(
      settingLocale: const Locale('zh', 'CN'),
      systemLocale: const Locale('en'),
    );

    expect(labels.running, '正在下载');
    expect(labels.complete, '下载完成');
  });
}
