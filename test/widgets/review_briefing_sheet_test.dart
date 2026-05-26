import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/widgets/review/review_briefing_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('入口面板默认显示 1x 播放速度下拉菜单', (tester) async {
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
    expect(find.text('1x'), findsOneWidget);
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
                defaultPlaybackSpeed: 0.75,
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

    expect(find.text('0.75x'), findsOneWidget);
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

    await tester.tap(find.text('1x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.9x').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();

    expect(selectedSpeed, 0.9);
  });
}
