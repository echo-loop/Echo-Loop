// 睡眠定时器按钮与浮层 widget 测试。
//
// 覆盖：未激活渲染 6 档预设；点选启动并收起浮层、图标转激活态；激活态浮层显示
// 剩余时间 + 关闭项 + 当前档打勾；点关闭恢复未激活。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/sleep_timer.dart';

Widget _buildTestApp() {
  return ProviderScope(
    child: MaterialApp(
      supportedLocales: const [Locale('en'), Locale('zh')],
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Player'),
          actions: const [SleepTimerButton()],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('未激活：点按钮弹出 6 档预设', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    // 初始未激活：timer_outlined 图标。
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.timer), findsNothing);

    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pumpAndSettle();

    // 浮层顶部显示标题。
    expect(find.text('Sleep timer'), findsOneWidget);

    for (final m in [5, 10, 15, 30, 45, 60]) {
      expect(find.text('$m min'), findsOneWidget);
    }
    // 未激活时无「关闭定时」「剩余时间」。
    expect(find.text('Turn off timer'), findsNothing);
    expect(find.text('Time remaining'), findsNothing);
  });

  testWidgets('点选预设启动定时并收起浮层、图标转激活', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();

    // 浮层收起（预设行消失），图标转激活态。
    expect(find.text('5 min'), findsNothing);
    expect(find.byIcon(Icons.timer), findsOneWidget);
  });

  testWidgets('激活态浮层显示剩余时间、关闭项与当前档打勾', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();

    // 再次打开浮层。
    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();

    expect(find.text('Time remaining'), findsOneWidget);
    // 剩余时间 mm:ss（ticker 在 pumpAndSettle 期间可能已走过几秒，故用模式匹配）。
    expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsOneWidget);
    expect(find.text('Turn off timer'), findsOneWidget);
    // 当前档打勾。
    expect(find.byIcon(Icons.check), findsOneWidget);

    // 点关闭：恢复未激活。
    await tester.tap(find.text('Turn off timer'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.timer), findsNothing);
  });
}
