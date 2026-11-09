import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/widgets/common/async_toggle_button.dart';

import '../helpers/test_app.dart';

void main() {
  group('AsyncToggleButton', () {
    testWidgets('显示图标和文字', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          AsyncToggleButton(
            label: 'Test',
            icon: Icons.star,
            onPressed: () async {},
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('图标与文字作为一组水平居中，且垂直对齐', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(
              width: 200,
              child: AsyncToggleButton(
                label: 'Centered',
                icon: Icons.star,
                onPressed: () async {},
              ),
            ),
          ),
        ),
      );

      final buttonCenter = tester.getCenter(find.byType(AsyncToggleButton));
      final iconRect = tester.getRect(find.byIcon(Icons.star));
      final labelRect = tester.getRect(find.text('Centered'));
      final groupCenterX = (iconRect.left + labelRect.right) / 2;
      expect(groupCenterX, closeTo(buttonCenter.dx, 0.5));
      expect(iconRect.center.dy, closeTo(labelRect.center.dy, 1.0));
    });

    testWidgets('使用紧凑的 32dp 按钮高度', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          AsyncToggleButton(
            label: 'Compact',
            icon: Icons.star,
            onPressed: () async {},
          ),
        ),
      );

      expect(tester.getSize(find.byType(AsyncToggleButton)).height, 32);
    });

    testWidgets('点击触发 onPressed', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        createTestApp(
          AsyncToggleButton(
            label: 'Click',
            icon: Icons.star,
            onPressed: () async {
              pressed = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Click'));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });

    testWidgets('异步请求期间显示 loading spinner', (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        createTestApp(
          AsyncToggleButton(
            label: 'Load',
            icon: Icons.star,
            onPressed: () => completer.future,
          ),
        ),
      );

      // 点击触发异步请求
      await tester.tap(find.text('Load'));
      await tester.pump();

      // 应显示 spinner，不显示图标
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);

      // 完成请求
      completer.complete();
      await tester.pumpAndSettle();

      // spinner 消失，图标恢复
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('loading 期间禁止重复点击', (tester) async {
      var callCount = 0;
      final completer = Completer<void>();
      await tester.pumpWidget(
        createTestApp(
          AsyncToggleButton(
            label: 'NoDouble',
            icon: Icons.star,
            onPressed: () {
              callCount++;
              return completer.future;
            },
          ),
        ),
      );

      // 第一次点击
      await tester.tap(find.text('NoDouble'));
      await tester.pump();
      expect(callCount, 1);

      // loading 期间再次点击 — 不应触发
      await tester.tap(find.text('NoDouble'));
      await tester.pump();
      expect(callCount, 1);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('请求失败后 loading 停止', (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        createTestApp(
          AsyncToggleButton(
            label: 'Fail',
            icon: Icons.star,
            onPressed: () => completer.future,
          ),
        ),
      );

      await tester.tap(find.text('Fail'));
      await tester.pump();

      // loading 中
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 失败
      completer.completeError('error');
      await tester.pumpAndSettle();

      // 失败后 spinner 消失，图标恢复
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('isDisabled 时点击无效', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        createTestApp(
          AsyncToggleButton(
            label: 'Disabled',
            icon: Icons.star,
            isDisabled: true,
            onPressed: () async {
              pressed = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();
      expect(pressed, isFalse);
    });

    testWidgets('isActive 时显示选中态样式', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          AsyncToggleButton(
            label: 'Active',
            icon: Icons.star,
            isActive: true,
            onPressed: () async {},
          ),
        ),
      );

      // 选中态应有 primary 色边框
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AsyncToggleButton),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, isNotNull);
    });

    testWidgets('同步完成的 onPressed 不闪烁 loading', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          AsyncToggleButton(
            label: 'Sync',
            icon: Icons.star,
            onPressed: () async {
              // 同步完成
            },
          ),
        ),
      );

      await tester.tap(find.text('Sync'));
      await tester.pump();

      // 同步完成后不应有 spinner 残留
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
