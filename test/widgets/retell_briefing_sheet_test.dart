import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/widgets/retell/retell_briefing_sheet.dart';
import 'package:echo_loop/widgets/study/study_stage_visuals.dart';
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

  testWidgets('入口任务图标和颜色与学习任务列表一致', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showRetellBriefingSheet(
              context: context,
              sentences: sentences,
              onStartPractice: (_, _, _, _) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    final heroIconFinder = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.size == 56,
    );
    final sheetContext = tester.element(heroIconFinder);
    final expected = studyStageVisual(
      StudyStage.retell,
      AppLocalizations.of(sheetContext)!,
    );
    final heroIcon = tester.widget<Icon>(heroIconFinder);

    expect(heroIcon.icon, expected.icon);
    expect(heroIcon.color, expected.iconColor);
  });

  testWidgets('入口面板显示默认 1.0x 播放速度下拉菜单', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showRetellBriefingSheet(
                context: context,
                sentences: sentences,
                onStartPractice: (_, _, _, _) {},
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
              showRetellBriefingSheet(
                context: context,
                sentences: sentences,
                onStartPractice: (_, _, _, speed) {
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
    expect(RetellSettings.briefingPlaybackSpeedOptions, contains(1.5));
  });

  testWidgets('入口预计时长按已生效的重复遍数计算', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showRetellBriefingSheet(
              context: context,
              sentences: sentences,
              defaultSeconds: -1,
              repeatCount: 5,
              onStartPractice: (_, _, _, _) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheetContext = tester.element(
      find.byWidgetPredicate((widget) => widget is Icon && widget.size == 56),
    );
    expect(
      find.text(AppLocalizations.of(sheetContext)!.estimatedMinutes(2)),
      findsOneWidget,
    );
  });

  testWidgets('无限重复时入口不显示有限预计时长', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showRetellBriefingSheet(
              context: context,
              sentences: sentences,
              defaultSeconds: -1,
              repeatCount: 0,
              onStartPractice: (_, _, _, _) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheetContext = tester.element(
      find.byWidgetPredicate((widget) => widget is Icon && widget.size == 56),
    );
    final l10n = AppLocalizations.of(sheetContext)!;
    expect(find.text(l10n.estimatedLessThanOneMinute), findsNothing);
    expect(find.text(l10n.estimatedMinutes(1)), findsNothing);
  });
}
