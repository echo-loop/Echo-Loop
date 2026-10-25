import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/widgets/listen_and_repeat/listen_and_repeat_briefing_sheet.dart';
import 'package:echo_loop/widgets/common/briefing_action_row.dart';
import 'package:echo_loop/models/intensive_listen_prefs.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/widgets/study/study_stage_visuals.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('顶部任务图标和颜色与学习任务列表一致', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showListenAndRepeatBriefingSheet(
              context: context,
              difficultCount: 5,
              fullTextCount: 12,
              playCount: 3,
              difficultEstimatedDuration: const Duration(minutes: 2),
              fullTextEstimatedDuration: const Duration(minutes: 5),
              onStartPractice: (_, _, _) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheetContext = tester.element(
      find.byType(ListenAndRepeatBriefingSheet),
    );
    final expected = studyStageVisual(
      StudyStage.listenAndRepeat,
      AppLocalizations.of(sheetContext)!,
    );
    final heroIcon = tester.widget<Icon>(
      find.byWidgetPredicate((widget) => widget is Icon && widget.size == 56),
    );

    expect(heroIcon.icon, expected.icon);
    expect(heroIcon.color, expected.iconColor);
  });

  testWidgets('底部开始按钮避让系统安全区', (tester) async {
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
            onPressed: () => showListenAndRepeatBriefingSheet(
              context: context,
              difficultCount: 5,
              fullTextCount: 12,
              playCount: 3,
              difficultEstimatedDuration: const Duration(minutes: 2),
              fullTextEstimatedDuration: const Duration(minutes: 5),
              onStartPractice: (_, _, _) {},
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

  testWidgets('无限遍数显示无限状态且不显示预计时长', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showListenAndRepeatBriefingSheet(
              context: context,
              difficultCount: 5,
              fullTextCount: 12,
              playCount: 0,
              difficultEstimatedDuration: null,
              fullTextEstimatedDuration: null,
              onStartPractice: (_, _, _) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Infinite ∞'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
  });

  testWidgets('入口面板默认显示 1.0x 播放速度下拉菜单', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showListenAndRepeatBriefingSheet(
                context: context,
                difficultCount: 5,
                fullTextCount: 12,
                playCount: 3,
                difficultEstimatedDuration: const Duration(minutes: 2),
                fullTextEstimatedDuration: const Duration(minutes: 5),
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

  testWidgets('跟读范围位于提示与句间停顿之间，并复用设置下拉样式', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showListenAndRepeatBriefingSheet(
              context: context,
              difficultCount: 5,
              fullTextCount: 12,
              playCount: 3,
              difficultEstimatedDuration: const Duration(minutes: 2),
              fullTextEstimatedDuration: const Duration(minutes: 5),
              onStartPractice: (_, _, _) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final tip = find.text(
      'Listen first, then repeat during the pause. By default, each saved sentence will be played three times.',
    );
    final scopeLabel = find.text('Repeat Scope');
    final pauseLabel = find.text('Pause between sentences');
    expect(
      tester.getTopLeft(tip).dy,
      lessThan(tester.getTopLeft(scopeLabel).dy),
    );
    expect(
      tester.getTopLeft(scopeLabel).dy,
      lessThan(tester.getTopLeft(pauseLabel).dy),
    );

    final scopeDropdown = tester.widget<DropdownButton<ListenAndRepeatScope>>(
      find.byType(DropdownButton<ListenAndRepeatScope>),
    );
    final speedDropdown = tester.widget<DropdownButton<double>>(
      find.byType(DropdownButton<double>),
    );
    expect(scopeDropdown.padding, speedDropdown.padding);
    expect(scopeDropdown.borderRadius, speedDropdown.borderRadius);
    expect(scopeDropdown.elevation, speedDropdown.elevation);
    expect(scopeDropdown.isDense, speedDropdown.isDense);
    expect(scopeDropdown.alignment, AlignmentDirectional.center);
    expect(scopeDropdown.isExpanded, isFalse);
    expect(
      tester.getSize(find.byType(DropdownButton<ListenAndRepeatScope>)).width,
      isNot(144),
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
                fullTextCount: 12,
                playCount: 3,
                difficultEstimatedDuration: const Duration(minutes: 2),
                fullTextEstimatedDuration: const Duration(minutes: 5),
                defaultPlaybackSpeed: 0.9,
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

    expect(find.text('0.9x'), findsOneWidget);
  });

  testWidgets('选择速度后随开始练习回调透出', (tester) async {
    double? selectedSpeed;
    ListenAndRepeatScope? selectedScope;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showListenAndRepeatBriefingSheet(
                context: context,
                difficultCount: 5,
                fullTextCount: 12,
                playCount: 3,
                difficultEstimatedDuration: const Duration(minutes: 2),
                fullTextEstimatedDuration: const Duration(minutes: 5),
                onStartPractice: (speed, _, scope) {
                  selectedSpeed = speed;
                  selectedScope = scope;
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
    expect(selectedScope, ListenAndRepeatScope.difficultOnly);
  });

  testWidgets('切换范围立即更新统计并回调范围', (tester) async {
    ListenAndRepeatScope? changedScope;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showListenAndRepeatBriefingSheet(
              context: context,
              difficultCount: 5,
              fullTextCount: 12,
              playCount: 3,
              difficultEstimatedDuration: const Duration(minutes: 2),
              fullTextEstimatedDuration: const Duration(minutes: 5),
              onScopeChanged: (scope) => changedScope = scope,
              onStartPractice: (_, _, _) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Only'), findsOneWidget);
    expect(find.text('5 saved sentences'), findsOneWidget);
    expect(find.text('Est. 2 min'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<ListenAndRepeatScope>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full Text').last);
    await tester.pumpAndSettle();

    expect(changedScope, ListenAndRepeatScope.fullText);
    expect(find.text('12 sentences'), findsOneWidget);
    expect(find.text('Est. 5 min'), findsOneWidget);
  });

  testWidgets('仅收藏且无收藏句时禁用开始按钮，切换全文后恢复', (tester) async {
    var startCount = 0;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showListenAndRepeatBriefingSheet(
              context: context,
              difficultCount: 0,
              fullTextCount: 12,
              playCount: 3,
              difficultEstimatedDuration: Duration.zero,
              fullTextEstimatedDuration: const Duration(minutes: 5),
              onStartPractice: (_, _, _) => startCount++,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final disabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'No saved sentences'),
    );
    expect(disabledButton.onPressed, isNull);
    await tester.tap(find.text('No saved sentences'));
    await tester.pumpAndSettle();
    expect(startCount, 0);

    await tester.tap(find.byType(DropdownButton<ListenAndRepeatScope>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full Text').last);
    await tester.pumpAndSettle();

    final enabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start Practicing'),
    );
    expect(enabledButton.onPressed, isNotNull);
    await tester.tap(find.text('Start Practicing'));
    await tester.pumpAndSettle();
    expect(startCount, 1);
  });
}
