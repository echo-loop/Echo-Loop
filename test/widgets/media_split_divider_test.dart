import 'package:echo_loop/models/practice_media_split.dart';
import 'package:echo_loop/widgets/common/media_split_divider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 回归：拖动中窗口缩放切换布局时分隔条被移出树，手势不会再回调拖动结束，
  // 使用方会一直残留拖动中的尺寸、也不保存。
  testWidgets('拖动中分隔条被移除时补发一次拖动结束', (tester) async {
    final isShown = ValueNotifier(true);
    addTearDown(isShown.dispose);
    var startCount = 0;
    var endCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: isShown,
          builder: (context, shown, _) => Row(
            children: [
              if (shown)
                MediaSplitDivider(
                  axis: PracticeMediaSplitAxis.sideBySide,
                  onDragStart: () => startCount++,
                  onDragUpdate: (_) {},
                  onDragEnd: () => endCount++,
                  onReset: () {},
                ),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('practice-media-split-divider')),
      ),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(startCount, 1);

    isShown.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(endCount, 1);

    await gesture.up();
    // 等双击识别器的计时器结束。
    await tester.pump(const Duration(milliseconds: 500));
    expect(endCount, 1, reason: '松手不再重复回调');
  });

  testWidgets('未拖动时移除分隔条不回调拖动结束', (tester) async {
    final isShown = ValueNotifier(true);
    addTearDown(isShown.dispose);
    var endCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: isShown,
          builder: (context, shown, _) => Row(
            children: [
              if (shown)
                MediaSplitDivider(
                  axis: PracticeMediaSplitAxis.sideBySide,
                  onDragStart: () {},
                  onDragUpdate: (_) {},
                  onDragEnd: () => endCount++,
                  onReset: () {},
                ),
            ],
          ),
        ),
      ),
    );
    isShown.value = false;
    await tester.pump();
    expect(endCount, 0);
  });
}
