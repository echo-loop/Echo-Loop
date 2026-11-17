/// 标签管理集成测试
///
/// 验证标签的创建、关联音频、显示标签 chips、删除标签等管理流程。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/svg_icon_finder.dart';

import '../helpers/test_notifiers.dart';

void _useCompactViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _goToLibraryTab(WidgetTester tester) async {
  final railLibraryIcon = find.descendant(
    of: find.byType(NavigationRail),
    matching: find.byIcon(Icons.library_music_outlined),
  );
  final barLibraryIcon = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.byIcon(Icons.library_music_outlined),
  );
  if (railLibraryIcon.evaluate().isNotEmpty) {
    await tester.tap(railLibraryIcon.first);
  } else {
    await tester.tap(barLibraryIcon.first);
  }
  await tester.pump(const Duration(milliseconds: 500));
}

/// 标签管理相关集成测试
void tagTests() {
  group('流程 9：标签管理', () {
    testWidgets('创建标签并关联音频后显示彩色 chip', (tester) async {
      _useCompactViewport(tester);
      await tester.pumpWidget(createTestAppWithAudio());
      await tester.pump(const Duration(milliseconds: 500));

      // 导航到资源库页
      await _goToLibraryTab(tester);

      // 切换到音频 Tab
      await tester.tap(find.text('Audio'));
      await tester.pump(const Duration(milliseconds: 500));

      // 验证音频项存在
      expect(find.text('Test Audio'), findsOneWidget);

      // 打开弹出菜单
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await safeSettle(tester);

      // 点击"管理标签"（PopupMenuItem）
      await tester.tap(find.text('Manage Tags').last);
      await safeSettle(tester);

      // BottomSheet 应出现 — 显示空状态文本
      expect(find.text('No tags yet'), findsWidgets);

      // 点击"创建标签"
      await tester.tap(find.text('Create Tag'));
      await safeSettle(tester);

      // 输入标签名称
      await tester.enterText(find.byType(TextField), 'Business English');
      await safeSettle(tester);

      // 点击添加按钮
      await tester.tap(find.text('Add'));
      await safeSettle(tester);

      // 即时生效 — 标签自动创建并关联
      // 标签在 Sheet 列表中显示且自动勾选
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isTrue);

      // 关闭 BottomSheet — 点击 Sheet 外部（屏幕顶部 scrim 区域）
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(size.width / 2, 10));
      await safeSettle(tester);

      // 返回音频列表 — 应能看到彩色标签 chip
      expect(find.text('Business English'), findsAtLeast(1));
    });

    testWidgets('删除标签后从列表和音频中移除', (tester) async {
      _useCompactViewport(tester);
      await tester.pumpWidget(createTestAppWithAudio());
      await tester.pump(const Duration(milliseconds: 500));

      // 导航到资源库页 → 音频 Tab
      await _goToLibraryTab(tester);
      await tester.tap(find.text('Audio'));
      await tester.pump(const Duration(milliseconds: 500));

      // 打开管理标签 Sheet
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Manage Tags'));
      await tester.pump(const Duration(milliseconds: 500));

      // 先创建一个标签
      await tester.tap(find.text('Create Tag'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField), 'ToDelete');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Add'));
      await tester.pump(const Duration(milliseconds: 500));

      // 标签已创建且关联
      expect(find.text('ToDelete'), findsAtLeast(1));

      // 点击删除按钮
      await tester.tap(svgIcon('assets/icon/trash-bin.svg'));
      await tester.pump(const Duration(milliseconds: 500));

      // 确认对话框应出现
      expect(find.text('Delete Tag'), findsOneWidget);

      // 确认删除
      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 500));

      // Sheet 内标签消失，回到空状态
      expect(find.text('No tags yet'), findsOneWidget);

      // 关闭 BottomSheet
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(size.width / 2, 10));
      await tester.pump(const Duration(milliseconds: 500));

      // 音频列表上也不再有标签 chip
      expect(find.text('ToDelete'), findsNothing);
    });
  });
}
