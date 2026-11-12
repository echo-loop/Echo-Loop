import 'package:echo_loop/features/daily_goal_check_in/widgets/daily_goal_celebration.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

const _title = '今日目标达成！';

Future<void> _mount(WidgetTester tester, {bool reduceMotion = false}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDailyGoalCelebration(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
}

void main() {
  testWidgets('显示标题，彩带播完后自动关闭', (tester) async {
    await _mount(tester);
    expect(find.text(_title), findsOneWidget);
    // 彩带资源异步加载，等待加载完成后才会挂载 Lottie。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.byType(Lottie), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text(_title), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('点击屏幕可提前跳过', (tester) async {
    await _mount(tester);
    await tester.tap(find.text(_title));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('减少动画时不播放彩带，文字停留后关闭', (tester) async {
    await _mount(tester, reduceMotion: true);
    expect(find.text(_title), findsOneWidget);
    expect(find.byType(Lottie), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsNothing);
  });
}
