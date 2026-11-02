// 环形学习进度图标测试
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/widgets/learning_progress_icon.dart';
import 'package:echo_loop/models/learning_plan.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import '../helpers/mock_providers.dart';

void main() {
  Widget createTestWidget(LearningProgress? progress, {bool isVideo = false}) {
    return ProviderScope(
      overrides: dedupeOverrides([
        initialLearningSettingsProvider.overrideWithValue(
          const LearningSettings(),
        ),
      ]),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: LearningProgressIcon(progress: progress, isVideo: isVideo),
          ),
        ),
      ),
    );
  }

  group('LearningProgressIcon', () {
    testWidgets('未学习 → 显示 audio icon + 灰色圆形背景', (tester) async {
      await tester.pumpWidget(createTestWidget(null));

      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
      // Container with circle shape
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      // 没有 CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('进行中 → 显示 CircularProgressIndicator + 进度值', (tester) async {
      // v2：精听是入口（未开始）；跟读才算进行中
      final progress = LearningProgress(
        audioItemId: 'test-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(createTestWidget(progress));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      // plan 是静态的全量
      final defaultPlan = LearningPlan.standard();
      expect(
        indicator.value,
        progress.progressPercent(defaultPlan, const <String>{}),
      );
      // 应显示 graphic_eq 图标
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    });

    testWidgets('已完成音频 → 显示波形图标 + 绿色满环', (tester) async {
      final progress = LearningProgress(
        audioItemId: 'test-1',
        currentStage: LearningStage.completed,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(createTestWidget(progress));

      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      final mediaIcon = tester.widget<Icon>(find.byIcon(Icons.graphic_eq));
      expect(mediaIcon.color, isNot(LearningProgressIcon.completedColor));
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 1.0);
      expect(indicator.color, LearningProgressIcon.completedColor);
    });

    testWidgets('已完成视频 → 显示视频 SVG + 绿色满环', (tester) async {
      final progress = LearningProgress(
        audioItemId: 'test-1',
        currentStage: LearningStage.completed,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(createTestWidget(progress, isVideo: true));

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 1.0);
      expect(indicator.color, LearningProgressIcon.completedColor);
    });

    testWidgets('暂停态 → 显示 pause icon + 灰色环（保留进度比例）', (tester) async {
      final progress = LearningProgress(
        audioItemId: 'test-1',
        currentStage: LearningStage.review2,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 5, 1),
        isPaused: true,
      );

      await tester.pumpWidget(createTestWidget(progress));

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, isNot(LearningProgressIcon.completedColor));
      expect(indicator.value, isNotNull);
    });

    testWidgets('视频条目未学习 → 中心图标用视频 SVG，而非 graphic_eq', (tester) async {
      await tester.pumpWidget(createTestWidget(null, isVideo: true));

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsNothing);
    });

    testWidgets('视频条目进行中 → 环形进度 + 中心视频 SVG', (tester) async {
      final progress = LearningProgress(
        audioItemId: 'test-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(createTestWidget(progress, isVideo: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsNothing);
    });
  });
}
