import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/providers/tag_provider.dart';
import 'package:fluency/widgets/edit_tag_membership_sheet.dart';
import 'package:fluency/models/tag.dart';

import '../helpers/test_app.dart';
import '../helpers/mock_providers.dart';

void main() {
  group('EditTagMembershipSheet', () {
    testWidgets('显示空状态文案', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const EditTagMembershipSheet(audioId: 'a1'),
                );
              },
              child: const Text('Open'),
            ),
          ),
          overrides: [
            tagListProvider.overrideWith(() => TestTagList()),
          ],
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Manage Tags'), findsOneWidget);
      expect(find.text('No tags yet'), findsOneWidget);
    });

    testWidgets('显示已有标签并带颜色圆点', (tester) async {
      final tag1 = Tag(
        id: 't1',
        name: 'Business',
        colorValue: 0xFFF44336,
        createdDate: DateTime(2026, 1, 1),
      );
      final tag2 = Tag(
        id: 't2',
        name: 'TED',
        colorValue: 0xFF4CAF50,
        createdDate: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const EditTagMembershipSheet(audioId: 'a1'),
                );
              },
              child: const Text('Open'),
            ),
          ),
          overrides: [
            tagListProvider.overrideWith(
              () => TestTagList(TagState(tags: [tag1, tag2])),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Business'), findsOneWidget);
      expect(find.text('TED'), findsOneWidget);
    });

    testWidgets('点击"创建标签"入口弹出对话框', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const EditTagMembershipSheet(audioId: 'a1'),
                );
              },
              child: const Text('Open'),
            ),
          ),
          overrides: [
            tagListProvider.overrideWith(() => TestTagList()),
          ],
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Tag'));
      await tester.pumpAndSettle();

      expect(find.text('Tag Name'), findsOneWidget);
      expect(find.text('Select Color'), findsOneWidget);
    });

    testWidgets('已关联的标签显示勾选状态', (tester) async {
      final tag1 = Tag(
        id: 't1',
        name: 'Business',
        colorValue: 0xFFF44336,
        createdDate: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const EditTagMembershipSheet(audioId: 'a1'),
                );
              },
              child: const Text('Open'),
            ),
          ),
          overrides: [
            tagListProvider.overrideWith(
              () => TestTagList(TagState(
                tags: [tag1],
                audioIdsMap: {
                  't1': ['a1'],
                },
              )),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // CheckboxListTile 应该是选中状态
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isTrue);
    });

    testWidgets('点击删除按钮弹出确认对话框，确认后标签消失', (tester) async {
      final tag1 = Tag(
        id: 't1',
        name: 'Business',
        colorValue: 0xFFF44336,
        createdDate: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const EditTagMembershipSheet(audioId: 'a1'),
                );
              },
              child: const Text('Open'),
            ),
          ),
          overrides: [
            tagListProvider.overrideWith(
              () => TestTagList(TagState(tags: [tag1])),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 标签应该可见
      expect(find.text('Business'), findsOneWidget);

      // 点击删除按钮
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // 确认对话框应出现
      expect(find.text('Delete Tag'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to delete "Business"? It will be removed from all audio.',
        ),
        findsOneWidget,
      );

      // 点击删除确认按钮
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // 标签应从列表消失
      expect(find.text('Business'), findsNothing);
    });
  });
}
