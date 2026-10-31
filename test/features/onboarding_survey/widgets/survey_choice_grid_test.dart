import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/onboarding_survey/widgets/survey_choice_grid.dart';

/// 网格卡片的图标与标签必须在卡片内水平居中，否则同一网格里各卡片的内容会错位。
void main() {
  Widget buildGrid(List<String> labels, {String? selectedLabel}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: SurveyChoiceGrid(
            children: [
              for (final label in labels)
                SurveyChoiceGridTile(
                  label: label,
                  selected: label == selectedLabel,
                  onTap: () {},
                  leading: const SizedBox(
                    width: 40,
                    height: 24,
                    child: ColoredBox(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('卡片内图标与标签水平居中，不受文字宽度影响', (tester) async {
    await tester.pumpWidget(buildGrid(['GitHub', '微信', '其他']));
    await tester.pumpAndSettle();

    for (final label in ['GitHub', '微信', '其他']) {
      final tile = find.ancestor(
        of: find.text(label),
        matching: find.byType(SurveyChoiceGridTile),
      );
      final tileCenterX = tester.getCenter(tile).dx;
      expect(
        tester.getCenter(find.text(label)).dx,
        closeTo(tileCenterX, 0.5),
        reason: '标签 $label 应居中',
      );
      final icon = find.descendant(of: tile, matching: find.byType(ColoredBox));
      expect(
        tester.getCenter(icon).dx,
        closeTo(tileCenterX, 0.5),
        reason: '图标 $label 应居中',
      );
    }
  });

  testWidgets('选中卡片时 ✓ 位于右上角且不改变标签位置', (tester) async {
    await tester.pumpWidget(buildGrid(['GitHub', '微信'], selectedLabel: '微信'));
    await tester.pumpAndSettle();

    final tile = find.ancestor(
      of: find.text('微信'),
      matching: find.byType(SurveyChoiceGridTile),
    );
    final check = find.descendant(
      of: tile,
      matching: find.byIcon(Icons.check_rounded),
    );
    expect(check, findsOneWidget);
    final tileRect = tester.getRect(tile);
    final checkCenter = tester.getCenter(check);
    expect(checkCenter.dx, greaterThan(tileRect.center.dx));
    expect(checkCenter.dy, lessThan(tileRect.center.dy));
  });
}
