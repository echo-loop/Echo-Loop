/// ActivityDayCell 组件测试
///
/// 覆盖：已打卡日显示对勾角标，未打卡与非本月日期不显示，无障碍标签包含打卡信息。
library;

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/monthly_study_records_provider.dart';
import 'package:echo_loop/widgets/study/activity_day_cell.dart';
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

void main() {
  final day = DateTime(2026, 3, 5);

  testWidgets('已打卡日显示对勾角标，语义标签包含打卡信息', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ActivityDayCell(
          day: day,
          record: const MonthDayRecord(
            studyTimeSeconds: 600,
            inputTimeSeconds: 0,
            outputTimeSeconds: 0,
            checkedInGoalMinutes: 5,
          ),
        ),
      ),
    );

    expect(find.byType(DailyGoalCheckInBadge), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('daily goal completed')),
      findsOneWidget,
    );
  });

  testWidgets('未打卡日不显示角标', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ActivityDayCell(
          day: day,
          record: const MonthDayRecord(
            studyTimeSeconds: 600,
            inputTimeSeconds: 0,
            outputTimeSeconds: 0,
          ),
        ),
      ),
    );

    expect(find.byType(DailyGoalCheckInBadge), findsNothing);
  });

  testWidgets('非本月日期不显示角标', (tester) async {
    await tester.pumpWidget(_wrap(ActivityDayCell(day: day, isOutside: true)));

    expect(find.byType(DailyGoalCheckInBadge), findsNothing);
  });
}
