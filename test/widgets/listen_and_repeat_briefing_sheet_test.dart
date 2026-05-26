import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/widgets/listen_and_repeat/listen_and_repeat_briefing_sheet.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('入口面板默认显示 1x 播放速度下拉菜单', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showListenAndRepeatBriefingSheet(
                context: context,
                difficultCount: 5,
                playCount: 3,
                onStartPractice: (_, _) {},
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
    expect(find.text('1x'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButton<double> &&
            widget.value == 1.0 &&
            widget.elevation == 0,
      ),
      findsOneWidget,
    );
  });

  testWidgets('入口面板按 defaultPlaybackSpeed 初始化下拉值', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showListenAndRepeatBriefingSheet(
                context: context,
                difficultCount: 5,
                playCount: 3,
                defaultPlaybackSpeed: 0.85,
                onStartPractice: (_, _) {},
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('0.85x'), findsOneWidget);
  });

  testWidgets('选择速度后随开始练习回调透出', (tester) async {
    double? selectedSpeed;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showListenAndRepeatBriefingSheet(
                context: context,
                difficultCount: 5,
                playCount: 3,
                onStartPractice: (speed, _) {
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

    await tester.tap(find.text('1x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();

    expect(selectedSpeed, 1.5);
  });
}
