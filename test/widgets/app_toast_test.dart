/// showAppToast 统一接口测试
///
/// 覆盖：位置参数生效、自定义时长后消失、dismissOnTap 关闭时点击不消失。
library;

import 'package:echo_loop/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _message = '统一接口测试';

void main() {
  /// toast 在下一帧才挂入 overlay，因此点击后逐帧推进直到文案出现。
  Future<void> showToast(
    WidgetTester tester, {
    required AppToastPosition position,
    Duration duration = const Duration(seconds: 3),
    bool dismissOnTap = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppToast(
                overlayState: Overlay.of(context, rootOverlay: true),
                message: _message,
                position: position,
                duration: duration,
                dismissOnTap: dismissOnTap,
              ),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('trigger'));
    for (var i = 0; i < 40 && find.text(_message).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// 清理 toastification 内部定时器，避免测试结束时残留。
  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('底部位置的 toast 出现在屏幕下半部分，并按自定义时长消失', (tester) async {
    await showToast(
      tester,
      position: AppToastPosition.bottom,
      duration: const Duration(seconds: 1),
    );

    final screenHeight = tester.view.physicalSize.height /
        tester.view.devicePixelRatio;
    expect(find.text(_message), findsOneWidget);
    expect(tester.getCenter(find.text(_message)).dy, greaterThan(screenHeight / 2));

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(_message), findsNothing);
  });

  testWidgets('dismissOnTap 为 false 时点击 toast 不会提前关闭', (tester) async {
    await showToast(tester, position: AppToastPosition.top, dismissOnTap: false);

    await tester.tap(find.text(_message));
    await tester.pumpAndSettle();

    expect(find.text(_message), findsOneWidget);
    await drainTimers(tester);
  });
}
