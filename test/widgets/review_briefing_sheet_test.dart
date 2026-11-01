import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/widgets/review/review_briefing_sheet.dart';
import 'package:echo_loop/widgets/common/briefing_action_row.dart';
import 'package:echo_loop/widgets/study/study_stage_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('难句补练顶部任务图标和颜色与学习任务列表一致', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showReviewBriefingSheet(
              context: context,
              stage: LearningStage.review2,
              subStage: SubStageType.reviewDifficultPractice,
              onStartPractice: (_, _) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final heroIconFinder = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.size == 56,
    );
    final sheetContext = tester.element(heroIconFinder);
    final expected = studyStageVisual(
      StudyStage.reviewDifficultPractice,
      AppLocalizations.of(sheetContext)!,
    );
    final heroIcon = tester.widget<Icon>(heroIconFinder);

    expect(heroIcon.icon, expected.icon);
    expect(heroIcon.color, expected.iconColor);
  });

  testWidgets('全文复述顶部任务图标和颜色与学习任务列表一致', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showReviewBriefingSheet(
              context: context,
              stage: LearningStage.review28,
              subStage: SubStageType.reviewRetellSummary,
              onStartPractice: (_, _) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final heroIconFinder = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.size == 56,
    );
    final sheetContext = tester.element(heroIconFinder);
    final expected = studyRetellSummaryVisual(
      AppLocalizations.of(sheetContext)!,
    );
    final heroIcon = tester.widget<Icon>(heroIconFinder);

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
            onPressed: () => showReviewBriefingSheet(
              context: context,
              stage: LearningStage.review2,
              subStage: SubStageType.reviewDifficultPractice,
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
              showReviewBriefingSheet(
                context: context,
                stage: LearningStage.review2,
                subStage: SubStageType.reviewDifficultPractice,
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
  });

  testWidgets('入口面板按 defaultPlaybackSpeed 初始化下拉值', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showReviewBriefingSheet(
                context: context,
                stage: LearningStage.firstLearn,
                subStage: SubStageType.reviewDifficultPractice,
                defaultPlaybackSpeed: 0.8,
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

    expect(find.text('0.8x'), findsOneWidget);
  });

  testWidgets('选择速度后随开始练习回调透出', (tester) async {
    double? selectedSpeed;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showReviewBriefingSheet(
                context: context,
                stage: LearningStage.review2,
                subStage: SubStageType.reviewDifficultPractice,
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

    await tester.tap(find.text('1.0x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.9x').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practicing'));
    await tester.pumpAndSettle();

    expect(selectedSpeed, 0.9);
  });

  testWidgets('传入不支持的子步骤（如全文盲听）会抛出异常而非静默显示错误文案', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showReviewBriefingSheet(
                context: context,
                stage: LearningStage.review2,
                subStage: SubStageType.blindListen,
                onStartPractice: (_, _) {},
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(tester.takeException(), isA<ArgumentError>());
  });
}
