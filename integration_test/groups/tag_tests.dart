/// 标签管理集成测试
///
/// 验证标签的创建、关联音频、显示标签 chips 等管理流程。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_notifiers.dart';

/// 标签管理相关集成测试
void tagTests() {
  group('流程 9：标签管理', () {
    testWidgets('创建标签并关联音频后显示彩色 chip', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await tester.pumpAndSettle();

      // 导航到资源库页
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();

      // 切换到音频 Tab
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      // 验证音频项存在
      expect(find.text('Test Audio'), findsOneWidget);

      // 打开弹出菜单（使用 byType 查找 PopupMenuButton）
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // 点击"管理标签"菜单项（通过文本查找）
      await tester.tap(find.text('Manage Tags'));
      await tester.pumpAndSettle();

      // BottomSheet 应出现 — 显示空状态文本
      expect(find.text('No tags yet'), findsOneWidget);

      // 点击"创建标签"
      await tester.tap(find.text('Create Tag'));
      await tester.pumpAndSettle();

      // 输入标签名称
      await tester.enterText(find.byType(TextField), 'Business English');
      await tester.pumpAndSettle();

      // 点击添加按钮
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // 创建对话框关闭后，标签应出现在列表中且自动勾选
      expect(find.text('Business English'), findsOneWidget);

      // 点击 Done 保存
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // 返回音频列表 — 应能看到彩色标签 chip
      expect(find.text('Business English'), findsOneWidget);
    });
  });
}
