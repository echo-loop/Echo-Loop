/// MonthlySummaryCard 组件测试
///
/// 覆盖：打卡天数只统计已打卡的日期；指标顺序为时长 → 天数 → 最长连续；
/// 列数随宽度自适应。
library;

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/monthly_study_records_provider.dart';
import 'package:echo_loop/widgets/study/monthly_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// 大数字与小字单位分属不同 TextSpan，按拼接后的纯文本查找。
Finder _valueText(String plain) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.textSpan?.toPlainText() ?? widget.data) == plain,
);

MonthDayRecord _record({int? checkedInGoalMinutes}) => MonthDayRecord(
  studyTimeSeconds: 600,
  inputTimeSeconds: 0,
  outputTimeSeconds: 0,
  checkedInGoalMinutes: checkedInGoalMinutes,
);

Widget _app() {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: MonthlySummaryCard(
        year: 2026,
        month: 3,
        monthlyData: {
          1: _record(checkedInGoalMinutes: 10),
          2: _record(checkedInGoalMinutes: 5),
          3: _record(),
        },
      ),
    ),
  );
}

void main() {
  testWidgets('打卡天数只统计已打卡的日期，天数只显示数字', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('Check-in days'), findsOneWidget);
    // 学习天数 3 与最长连续 3 同为「3d」，这里只断言打卡天数
    expect(_valueText('2 d'), findsOneWidget);
  });

  testWidgets('指标顺序为总计、日均、学习天数、打卡天数、最长连续', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());

    final labels = [
      'Total',
      'Avg/day',
      'Active days',
      'Check-in days',
      'Best streak',
    ];
    final tops = [for (final l in labels) tester.getTopLeft(find.text(l)).dy];
    // 宽屏下四列一行，最长连续换到第二行
    expect(tops[0], tops[1]);
    expect(tops[0], tops[2]);
    expect(tops[0], tops[3]);
    expect(tops[4], greaterThan(tops[0]));
  });

  testWidgets('窄屏下两列排布，宽屏下增加列数', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());

    // 窄屏：总计与日均同行，学习天数换到下一行
    final totalTop = tester.getTopLeft(find.text('Total')).dy;
    expect(tester.getTopLeft(find.text('Avg/day')).dy, totalTop);
    expect(
      tester.getTopLeft(find.text('Active days')).dy,
      greaterThan(totalTop),
    );
  });

  testWidgets('时长用大数字加小字单位，超过一小时时单位带剩余分钟', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: MonthlySummaryCard(
            year: 2026,
            month: 3,
            monthlyData: {
              // 总计 90 分钟
              1: const MonthDayRecord(
                studyTimeSeconds: 5400,
                inputTimeSeconds: 0,
                outputTimeSeconds: 0,
              ),
            },
          ),
        ),
      ),
    );

    // 总计与日均（仅一个学习日）都是 1 小时 30 分
    expect(_valueText('1 h 30m'), findsNWidgets(2));
    expect(_valueText('90 min'), findsNothing);
  });
}
