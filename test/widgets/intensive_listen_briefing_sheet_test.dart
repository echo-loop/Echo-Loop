import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/stage_settings_overrides.dart'
    show BriefingPauseChoice;
import 'package:echo_loop/widgets/intensive_listen/intensive_listen_briefing_sheet.dart';
import 'package:echo_loop/widgets/common/briefing_action_row.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('底部开始按钮避让 Android/iOS 底部安全区', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showIntensiveListenBriefingSheet(
              context: context,
              sentenceCount: 10,
              onStartPractice: (_, _) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final actionRow = tester.getRect(find.byType(BriefingActionRow));
    expect(actionRow.bottom, lessThanOrEqualTo(844 - 34));
  });

  testWidgets('入口面板默认显示 1.0x 播放速度下拉菜单', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
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

  testWidgets('入口面板按 defaultPlaybackSpeed 初始化下拉值', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                defaultPlaybackSpeed: 0.9,
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

    expect(find.text('0.9x'), findsOneWidget);
  });

  testWidgets('选择速度后随开始练习回调透出', (tester) async {
    double? selectedSpeed;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
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

    await tester.tap(find.byType(DropdownButton<double>).last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();
    final startButton = find.descendant(
      of: find.byType(BriefingActionRow),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(selectedSpeed, 1.5);
  });

  testWidgets('句间停顿默认为「自动」，点击开始练习时回传', (tester) async {
    BriefingPauseChoice? selectedPause;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                onStartPractice: (_, pause) {
                  selectedPause = pause;
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

    expect(find.text('Pause between sentences'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);

    await tester.tap(find.text('Start Practicing'));
    await tester.pumpAndSettle();

    expect(selectedPause, const BriefingPauseChoice.smart());
  });

  testWidgets('不传 onSkip 时不显示跳过按钮', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
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

    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('传 onSkip 时显示跳过按钮，点击触发回调', (tester) async {
    var skipped = false;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                onStartPractice: (_, _) {},
                onSkip: () => skipped = true,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(skipped, isTrue);
  });

  testWidgets('选择 3x 后回传 multiplier(3.0)', (tester) async {
    BriefingPauseChoice? selectedPause;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                onStartPractice: (_, pause) {
                  selectedPause = pause;
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

    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    // 分组下拉项较多(固定间隔 15 档 + 句长倍数 7 档),倍数在底部,需滚动到可见。
    await tester.scrollUntilVisible(
      find.text('3x'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('3x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practicing'));
    await tester.pumpAndSettle();

    expect(selectedPause, const BriefingPauseChoice.multiplier(3.0));
  });

  testWidgets('改动停顿即时回调 onSelectionChanged(改完即记,不必开始练习)', (tester) async {
    BriefingPauseChoice? changedPause;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                onStartPractice: (_, _) {},
                onSelectionChanged: (_, pause) {
                  changedPause = pause;
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

    // 打开停顿下拉,选「固定间隔 2s」——未点「开始练习」也应即时回调。
    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2s'),
      80,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('2s'));
    await tester.pumpAndSettle();

    expect(changedPause, const BriefingPauseChoice.fixed(2));
  });
}
