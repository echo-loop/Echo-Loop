import 'package:echo_loop/screens/backup_restore_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('备份完成弹窗只能通过右上角关闭', (tester) async {
    final feedback = ValueNotifier<String?>(null);
    addTearDown(feedback.dispose);

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => BackupReadyDialog(
                title: '备份文件已准备好',
                fileNameLabel: '文件名',
                fileName: 'backup.elbak',
                sizeLabel: '总大小',
                size: '1 MB',
                supportsDesktopSave: false,
                downloadLabel: '下载',
                shareLabel: '分享',
                downloadFeedback: feedback,
                shareIcon: const Icon(CupertinoIcons.share),
                onClose: () => Navigator.of(context).pop(),
                onDownload: () {},
                onShare: () {},
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('备份文件已准备好'), findsOneWidget);

    final dialogRect = tester.getRect(find.byType(AlertDialog));
    final closeRect = tester.getRect(find.byTooltip('Close'));
    expect(closeRect.right, lessThan(dialogRect.right - 8));

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('备份文件已准备好'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('备份文件已准备好'), findsNothing);
  });

  testWidgets('下载完成反馈不会自动消失', (tester) async {
    final feedback = ValueNotifier<String?>('下载完成');
    addTearDown(feedback.dispose);

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => BackupReadyDialog(
                title: '备份文件已准备好',
                fileNameLabel: '文件名',
                fileName: 'backup.elbak',
                sizeLabel: '总大小',
                size: '1 MB',
                supportsDesktopSave: false,
                downloadLabel: '下载',
                shareLabel: '分享',
                downloadFeedback: feedback,
                shareIcon: const Icon(CupertinoIcons.share),
                onClose: () => Navigator.of(context).pop(),
                onDownload: () {},
                onShare: () {},
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('下载完成'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('下载完成'), findsOneWidget);
  });
}
