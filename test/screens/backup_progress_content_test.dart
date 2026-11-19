import 'package:echo_loop/screens/backup_restore_screen.dart';
import 'package:echo_loop/services/backup/backup_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('不确定进度弹窗的图标与文案垂直居中，内容上下留白对称', (tester) async {
    final progress = ValueNotifier<BackupProgress>(
      const BackupProgress(stage: 'importingExtracting'),
    );
    addTearDown(progress.dispose);

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => BackupProgressDialog(progress: progress),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // 不确定进度圈持续动画，不能用 pumpAndSettle 等待静止。
    await tester.pump(const Duration(milliseconds: 300));

    // AlertDialog 的 Dialog 外框占满屏幕，视觉卡片是其内部的 Material。
    final cardRect = tester.getRect(
      find.descendant(of: find.byType(Dialog), matching: find.byType(Material)),
    );
    final contentRect = tester.getRect(
      find.descendant(of: find.byType(Dialog), matching: find.byType(Row)),
    );
    final spinnerCenterY = tester
        .getCenter(find.byType(CircularProgressIndicator))
        .dy;
    final textCenterY = tester.getCenter(find.text('Extracting backup...')).dy;

    expect(textCenterY, closeTo(spinnerCenterY, 1));
    final topGap = contentRect.top - cardRect.top;
    final bottomGap = cardRect.bottom - contentRect.bottom;
    expect(topGap, closeTo(bottomGap, 1));
  });
}
