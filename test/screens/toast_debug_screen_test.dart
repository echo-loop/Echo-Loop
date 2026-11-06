/// ToastDebugScreen 测试
///
/// 覆盖：点击预设后弹出打卡 toast，并在自动关闭后消失。
library;

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/screens/toast_debug_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('点击预设弹出 toast，自动关闭后消失', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ToastDebugScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('短文案（5 分钟，跟随当前语言）'));
    // toast 跨多帧挂载，逐帧推进直到图标出现
    for (
      var i = 0;
      i < 40 && find.byIcon(Icons.check_circle_outline).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });
}
