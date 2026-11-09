/// DailyGoalProgressCard 组件测试
///
/// 覆盖：未打卡时显示进度与分钟数，已打卡时显示打卡状态并满格，进度封顶。
library;

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/features/daily_goal_check_in/widgets/daily_check_in_share_icon.dart';
import 'package:echo_loop/widgets/study/daily_goal_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

double _progressValue(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value!;

void main() {
  testWidgets('未打卡时显示已学分钟数、目标与进度', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DailyGoalProgressCard(
          studiedSeconds: 180,
          goalMinutes: 10,
          isCheckedIn: false,
        ),
      ),
    );

    expect(find.text("Today's goal"), findsOneWidget);
    expect(find.text('3 min studied'), findsOneWidget);
    expect(find.text('Goal 10 min'), findsOneWidget);
    expect(_progressValue(tester), closeTo(0.3, 0.0001));
  });

  testWidgets('已打卡时显示打卡状态且进度满格', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DailyGoalProgressCard(
          studiedSeconds: 180,
          goalMinutes: 10,
          isCheckedIn: true,
        ),
      ),
    );

    expect(find.text('Checked in today'), findsOneWidget);
    expect(find.byType(DailyCheckInShareIcon), findsNothing);
    // 已打卡后仍展示实际已学时长与目标
    expect(find.text('3 min studied'), findsOneWidget);
    expect(find.text('Goal 10 min'), findsOneWidget);
    expect(_progressValue(tester), 1);
  });

  testWidgets('点击已打卡目标卡片其他区域也会触发分享回调', (tester) async {
    var shareTapped = false;
    await tester.pumpWidget(
      _wrap(
        DailyGoalProgressCard(
          studiedSeconds: 180,
          goalMinutes: 10,
          isCheckedIn: true,
          onShareTap: () => shareTapped = true,
        ),
      ),
    );

    expect(find.byType(DailyCheckInShareIcon), findsOneWidget);

    await tester.tap(find.byType(LinearProgressIndicator));

    expect(shareTapped, isTrue);
  });

  testWidgets('未打卡时点击目标卡片不触发分享回调', (tester) async {
    var shareTapped = false;
    await tester.pumpWidget(
      _wrap(
        DailyGoalProgressCard(
          studiedSeconds: 180,
          goalMinutes: 10,
          isCheckedIn: false,
          onShareTap: () => shareTapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(LinearProgressIndicator));

    expect(shareTapped, isFalse);
  });

  testWidgets('学习时长超过目标时进度封顶为 1', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DailyGoalProgressCard(
          studiedSeconds: 1200,
          goalMinutes: 10,
          isCheckedIn: false,
        ),
      ),
    );

    expect(_progressValue(tester), 1);
  });
}
