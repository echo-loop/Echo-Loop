/// showDailyGoalCompletedToast 组件测试
///
/// 覆盖：
/// - 弹出后显示文案，约 3 秒后自动消失
/// - 点击可提前关闭
library;

import 'package:echo_loop/widgets/daily_goal_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _message = '今日 5 分钟学习目标已完成！';

void main() {
  /// toast 在下一帧才挂入 overlay，因此点击后先推进一段时间再断言。
  Future<void> showToast(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDailyGoalCompletedToast(
                overlayState: Overlay.of(context),
                message: _message,
                brightness: Brightness.light,
              ),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('trigger'));
    // 挂载与入场动画跨多帧完成，逐帧推进直到文案出现
    for (var i = 0; i < 40 && find.text(_message).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('弹出后显示文案，3 秒后自动消失', (tester) async {
    await showToast(tester);

    expect(find.text(_message), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    // 消耗 toastification 内部的清理定时器，避免测试结束时残留
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(_message), findsNothing);
  });

  testWidgets('点击 toast 可提前关闭', (tester) async {
    await showToast(tester);

    await tester.tap(find.text(_message));
    await tester.pumpAndSettle();
    // 推进到原自动关闭时间之后，确认定时器已被取消且不再报错
    await tester.pump(const Duration(seconds: 4));

    expect(find.text(_message), findsNothing);
  });

  testWidgets('短文案宽度随内容收缩，不占满屏幕', (tester) async {
    await showToast(tester);

    final pill = find.ancestor(
      of: find.byIcon(Icons.check_circle_outline),
      matching: find.byType(Container),
    );
    final width = tester.getSize(pill.first).width;
    expect(width, lessThan(420));
    expect(width, lessThan(tester.view.physicalSize.width));
    // 胶囊水平居中于屏幕
    final screenCenter = tester.getCenter(find.byType(Scaffold)).dx;
    expect(tester.getCenter(pill.first).dx, closeTo(screenCenter, 1));

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('窄屏下 toast 与屏幕左右边缘保持距离', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showToast(tester);

    final pill = find.ancestor(
      of: find.byIcon(Icons.check_circle_outline),
      matching: find.byType(Container),
    );
    final rect = tester.getRect(pill.first);
    expect(rect.left, greaterThanOrEqualTo(24));
    expect(rect.right, lessThanOrEqualTo(360 - 24));

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
  });
}
