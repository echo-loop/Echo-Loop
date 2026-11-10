/// CapsuleSelector 通用组件测试
///
/// 覆盖：轻点选择、长按滑动松手应用、长按未滑动不改速度、滑出范围取消、点浮层外关闭。
library;

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/utils/playback_speed.dart';
import 'package:echo_loop/widgets/common/capsule_selector.dart';

/// 组件测试自带的固定选项，与产品速度档位解耦。
const List<double> _kTestSpeedOptions = [0.7, 0.9, 1.0, 1.1, 1.3];

void main() {
  double? changedSpeed;

  Future<void> pumpSelector(WidgetTester tester, {double speed = 1.0}) async {
    changedSpeed = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CapsuleSelector<double>(
              value: speed,
              options: _kTestSpeedOptions,
              labelOf: formatPlaybackSpeedLabel,
              onChanged: (value) => changedSpeed = value,
              title: '播放速度',
              dragHint: '左右滑动 · 松手应用',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('按下时显示按压背景，浮层打开时为激活背景，关闭后恢复', (
    tester,
  ) async {
    await pumpSelector(tester);
    final colorScheme = Theme.of(
      tester.element(find.byType(CapsuleSelector<double>)),
    ).colorScheme;

    Color? surfaceColor() {
      final decoration = tester
          .widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(CapsuleSelector<double>),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration as BoxDecoration;
      return decoration.color;
    }

    // 默认无底色
    expect(surfaceColor(), isNull);

    // 按下未松手：按压态
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('1.0x')),
    );
    await tester.pump();
    expect(surfaceColor(), colorScheme.surfaceContainerHighest);

    // 松手后浮层打开：激活态（主题主色）
    await gesture.up();
    await tester.pumpAndSettle();
    expect(surfaceColor(), colorScheme.primary);

    // 点击浮层外关闭：恢复无底色
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(surfaceColor(), isNull);
  });

  testWidgets('浮层选项提供悬浮与按压高亮，选中项同样有反馈', (tester) async {
    await pumpSelector(tester);
    await tester.tap(find.text('1.0x'));
    await tester.pump();

    // 标题右侧也会显示当前速度，因此只在选项（InkWell）内部查找
    for (final label in ['0.9x', '1.0x', '1.1x']) {
      final inkWell = tester.widget<InkWell>(
        find.widgetWithText(InkWell, label),
      );
      expect(inkWell.hoverColor, isNotNull, reason: label);
      expect(inkWell.highlightColor, isNotNull, reason: label);
    }
  });

  testWidgets('长按滑动时经过主播放按钮再松手，不会触发播放', (tester) async {
    var centerTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CapsuleSelector<double>(
                  value: 1.0,
              options: _kTestSpeedOptions,
              labelOf: formatPlaybackSpeedLabel,
                  onChanged: (_) {},
                  title: '播放速度',
                  dragHint: '左右滑动 · 松手应用',
                ),
                IconButton(
                  key: const ValueKey('center-play'),
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => centerTaps++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('1.0x')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    // 滑动经过主播放按钮后，在它上面松手
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('center-play'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(centerTaps, 0);
  });

  testWidgets('当前为 1.3x 时长按后轻微左移不会跳到最慢档', (tester) async {
    // 按钮贴着屏幕左边缘，浮层会被夹紧到屏幕内，选项行的位置与手指不再对应
    double? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: CapsuleSelector<double>(
              value: 1.3,
              options: _kTestSpeedOptions,
              labelOf: formatPlaybackSpeedLabel,
              onChanged: (value) => changed = value,
              title: '播放速度',
              dragHint: '左右滑动 · 松手应用',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('1.3x')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(-10, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(changed, isNull);
  });

  testWidgets('可用于任意类型的选项（字符串），选中后返回对应值', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CapsuleSelector<String>(
              value: 'A',
              options: const ['A', 'B', 'C'],
              labelOf: (value) => '选项$value',
              onChanged: (value) => picked = value,
              title: '选择',
              dragHint: '左右滑动',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('选项A'));
    await tester.pump();
    await tester.tap(find.text('选项B'));
    await tester.pumpAndSettle();

    expect(picked, 'B');
  });

  testWidgets('多指触摸时第二根手指的抬起不会结束第一根手指的拖动', (tester) async {
    await pumpSelector(tester);

    final first = await tester.startGesture(
      tester.getCenter(find.text('1.0x')),
    );
    final second = await tester.startGesture(
      tester.getCenter(find.text('1.0x')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('1.3x'), findsOneWidget);

    await first.moveTo(tester.getCenter(find.text('1.3x')));
    await tester.pump();
    // 第二根手指先抬起，不应结束拖动：浮层仍然打开
    await second.up();
    await tester.pump();
    expect(find.text('0.9x'), findsOneWidget);

    await first.up();
    await tester.pumpAndSettle();
    expect(changedSpeed, 1.3);
  });

  testWidgets('轻点按钮打开浮层，点选项后应用并关闭', (tester) async {
    await pumpSelector(tester);

    await tester.tap(find.text('1.0x'));
    await tester.pump();
    expect(find.text('1.1x'), findsOneWidget);

    await tester.tap(find.text('1.1x'));
    await tester.pumpAndSettle();

    expect(changedSpeed, 1.1);
    expect(find.text('1.1x'), findsNothing);
  });

  testWidgets('长按后滑动到目标档位松手即应用', (tester) async {
    await pumpSelector(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('1.0x')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('1.3x'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('1.3x')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(changedSpeed, 1.3);
    expect(find.text('1.3x'), findsNothing);
  });

  testWidgets('长按后未滑动直接松手，速度保持不变', (tester) async {
    await pumpSelector(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('1.0x')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(changedSpeed, isNull);
    expect(find.text('1.1x'), findsNothing);
  });

  testWidgets('长按滑动后纵向滑出范围松手视为取消，速度保持不变', (tester) async {
    await pumpSelector(tester);

    final buttonCenter = tester.getCenter(find.text('1.0x'));
    final gesture = await tester.startGesture(buttonCenter);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.text('1.3x')));
    await tester.pump();
    // 向下滑出按钮纵向范围
    await gesture.moveTo(buttonCenter + const Offset(0, 300));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(changedSpeed, isNull);
    expect(find.text('1.3x'), findsNothing);
  });

  testWidgets('轻点打开浮层后点击浮层外部关闭，速度保持不变', (tester) async {
    await pumpSelector(tester);

    await tester.tap(find.text('1.0x'));
    await tester.pump();
    expect(find.text('1.1x'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(changedSpeed, isNull);
    expect(find.text('1.1x'), findsNothing);
  });
}
