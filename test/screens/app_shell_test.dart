/// App 壳子（底部 Tab / 设置项）测试
///
/// 覆盖原 `integration_test/groups/` 下若干 case（已从 LiveTest 下沉到 flutter_test）：
/// - navigation_tests.dart「App 启动」
/// - settings_tests.dart（主题、语言）
/// - retell_toggle_tests.dart（自动跳过复述开关）
/// - collection_tests.dart（创建合集）
///
/// 预期单文件秒级跑完。
library;

import 'package:echo_loop/main.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  group('流程 1：App 启动与导航', () {
    testWidgets('App 正常启动，显示学习页', (tester) async {
      await pumpFullApp(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('No study tasks yet'), findsOneWidget);

      // 消耗冷启动保护定时器（5 秒）
      await tester.pump(const Duration(seconds: 6));
      // 让 Drift / Riverpod 的零延时清理 timer 执行掉
      await tester.pumpAndSettle();
    });

    // TODO 「点击各导航切换页面」case 暂留在 integration_test：在 flutter_test
    // 下，切换到收藏页会触发 Drift in-memory DB 的 StreamQuery dispose 留下
    // 零延时 timer，导致 invariant 检查失败。需要 mock DAOs（在 test/helpers/
    // 中补 TestSavedWordDao 等）后再下沉。
  });

  group('流程 2：设置修改', () {
    testWidgets('切换主题', (tester) async {
      await pumpFullApp(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 进入我的页
      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 300));

      // 点击主题设置
      await tester.tap(find.text('Theme'));
      await tester.pump(const Duration(milliseconds: 300));

      // 选择 Dark Mode（弹窗里和 tile 副标题都可能匹配，取最后一个 = 弹窗 option）
      await tester.tap(find.text('Dark Mode').last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Dark Mode'), findsWidgets);

      await tester.pump(const Duration(seconds: 6));
      // 让 Drift / Riverpod 的零延时清理 timer 执行掉
      await tester.pumpAndSettle();
    });

    testWidgets('切换语言', (tester) async {
      await pumpFullApp(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 进入我的页
      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 300));

      // 点击语言设置
      await tester.tap(find.text('Interface Language'));
      await tester.pump(const Duration(milliseconds: 300));

      // 选择简体中文
      await tester.tap(find.text('简体中文').last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('简体中文'), findsWidgets);

      await tester.pump(const Duration(seconds: 6));
      // 让 Drift / Riverpod 的零延时清理 timer 执行掉
      await tester.pumpAndSettle();
    });
  });

  group('流程 X：自动跳过复述开关', () {
    testWidgets('设置 → 学习 → 学习设置：开关切换可达且 state 翻转', (tester) async {
      await pumpFullApp(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 500));

      // Study Plan 是 push 进新页面，等路由动画 + 异步加载
      await tester.tap(find.text('Study Plan'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Auto-skip speaking practice'), findsOneWidget);

      // 默认 autoSkipRetell=false
      final context = tester.element(find.byType(EchoLoopApp));
      final container = ProviderScope.containerOf(context);
      expect(container.read(learningSettingsProvider).autoSkipRetell, isFalse);

      // 找到 "Auto-skip speaking practice" 的 SwitchListTile 并切换
      final autoSkipSwitch = find.byWidgetPredicate(
        (w) => w is SwitchListTile && w.title is Text && (w.title as Text).data == 'Auto-skip speaking practice',
      );
      await tester.tap(autoSkipSwitch);
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(learningSettingsProvider).autoSkipRetell, isTrue);

      // 再切回（true → false）
      await tester.tap(autoSkipSwitch);
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(learningSettingsProvider).autoSkipRetell, isFalse);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });

  group('流程 3：合集管理', () {
    testWidgets('创建合集并验证出现在列表中', (tester) async {
      await pumpFullApp(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 切换到资源库页（限定在底部导航/侧边栏内，避免点到页面内容区同名图标）
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
      await tester.pump(const Duration(milliseconds: 500));

      // 点击 AppBar 中的创建按钮
      final appBarAdd = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(appBarAdd.first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // 输入合集名称
      await tester.enterText(find.byType(TextField), 'My Collection');
      await tester.pump(const Duration(milliseconds: 300));

      // 点击添加
      await tester.tap(find.text('Add'));
      await tester.pump(const Duration(milliseconds: 500));

      // 合集应出现在列表中（可能同时出现在弹窗回声和列表中，>=1 即可）
      expect(find.text('My Collection'), findsAtLeast(1));

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });
}
