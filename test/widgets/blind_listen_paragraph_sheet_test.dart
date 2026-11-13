import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/widgets/blind_listen_paragraph_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  final sentences = [
    Sentence(
      index: 0,
      text: 'First sentence.',
      startTime: Duration.zero,
      endTime: const Duration(seconds: 3),
    ),
    Sentence(
      index: 1,
      text: 'Second sentence.',
      startTime: const Duration(seconds: 3),
      endTime: const Duration(seconds: 6),
    ),
  ];

  testWidgets('入口面板显示默认 1.0x 播放速度下拉菜单', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showBlindListenParagraphSheet(
                context: context,
                sentences: sentences,
                onStartPractice: (_, _, _) {},
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Playback Speed'), findsOneWidget);
    expect(find.text('1.0x'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButton<double> &&
            widget.value == 1.0 &&
            widget.elevation == 8,
      ),
      findsOneWidget,
    );
  });

  testWidgets('入口面板选择速度后随开始练习传入设置', (tester) async {
    double? selectedSpeed;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showBlindListenParagraphSheet(
                context: context,
                sentences: sentences,
                onStartPractice: (_, _, speed) {
                  selectedSpeed = speed;
                },
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1.0x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practicing'));
    await tester.pumpAndSettle();

    expect(selectedSpeed, 1.5);
  });
}
