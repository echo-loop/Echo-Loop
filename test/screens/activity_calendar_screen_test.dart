import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/monthly_study_records_provider.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:echo_loop/screens/activity_calendar_screen.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/study/activity_day_cell.dart';
import 'package:flutter_riverpod/misc.dart';

AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
}

/// 创建包含日历页面的测试 App
Widget _createTestApp({
  required AppDatabase db,
  Map<int, MonthDayRecord>? records,
  StudyStats stats = const StudyStats(),
}) {
  final now = DateTime.now();
  final overrides = <Override>[
    appDatabaseProvider.overrideWithValue(db),
    studyStatsProvider.overrideWith(() => _TestStudyStatsNotifier(stats)),
    // 无 SharedPreferences 时学习设置回退到该初值（每日目标 10 分钟）
    initialLearningSettingsProvider.overrideWithValue(const LearningSettings()),
  ];

  // 如果提供了 records，覆盖 provider
  if (records != null) {
    overrides.add(
      monthlyStudyRecordsProvider(
        now.year,
        now.month,
      ).overrideWith((ref) async => records),
    );
  }

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ActivityCalendarScreen(),
    ),
  );
}

/// 测试用 StudyStatsNotifier
class _TestStudyStatsNotifier extends StudyStatsNotifier {
  final StudyStats _stats;
  _TestStudyStatsNotifier(this._stats);

  @override
  Future<StudyStats> build() async => _stats;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  for (final useTrackpad in [true, false]) {
    testWidgets('指针位于日历日期上时可通过${useTrackpad ? '触控板' : '鼠标滚轮'}滚动页面', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestApp(db: db, records: const {}));
      await tester.pumpAndSettle();

      final calendar = find.byType(TableCalendar<void>);
      final position = tester.getCenter(
        find.descendant(of: calendar, matching: find.byType(PageView)),
      );
      final pageScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(pageScroll.position.maxScrollExtent, greaterThan(0));
      final initialOffset = pageScroll.position.pixels;
      final initialMonth = tester
          .widget<TableCalendar<void>>(calendar)
          .focusedDay;

      if (useTrackpad) {
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.trackpad,
        );
        await gesture.panZoomStart(position);
        await gesture.panZoomUpdate(position, pan: const Offset(0, -40));
        await gesture.panZoomUpdate(position, pan: const Offset(0, -120));
        await gesture.panZoomEnd();
      } else {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            kind: PointerDeviceKind.mouse,
            scrollDelta: const Offset(0, 120),
          ),
        );
      }
      await tester.pumpAndSettle();

      expect(pageScroll.position.pixels, greaterThan(initialOffset));
      expect(
        tester.widget<TableCalendar<void>>(calendar).focusedDay,
        initialMonth,
      );
    });
  }

  testWidgets('日历仍支持横向滑动切换月份', (tester) async {
    await tester.pumpWidget(_createTestApp(db: db, records: const {}));
    await tester.pumpAndSettle();
    final calendar = find.byType(TableCalendar<void>);
    final initial = tester.widget<TableCalendar<void>>(calendar).focusedDay;
    await tester.drag(
      find.descendant(of: calendar, matching: find.byType(PageView)),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    final focused = tester.widget<TableCalendar<void>>(calendar).focusedDay;
    final previous = DateTime(initial.year, initial.month - 1);
    expect(focused.year, previous.year);
    expect(focused.month, previous.month);
  });

  testWidgets('streak>0 时显示橙色 chip', (tester) async {
    await tester.pumpWidget(
      _createTestApp(
        db: db,
        records: const {},
        stats: const StudyStats(streak: 5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5d streak'), findsOneWidget);

    final streakChip = find
        .ancestor(of: find.text('5d streak'), matching: find.byType(Container))
        .first;
    expect(tester.getSize(streakChip).height, 33);

    // 验证火焰图标存在
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
  });

  testWidgets('日历颜色图例显示在日历卡片内部', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _createTestApp(
        db: db,
        records: {
          now.day: const MonthDayRecord(
            studyTimeSeconds: 1800,
            inputTimeSeconds: 0,
            outputTimeSeconds: 0,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('Less study time'),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );
  });

  testWidgets('无学习记录时日历仍显示颜色图例', (tester) async {
    await tester.pumpWidget(_createTestApp(db: db, records: const {}));
    await tester.pumpAndSettle();

    expect(find.text('Less study time'), findsOneWidget);
    expect(find.text('More study time'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Less study time'),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );
  });

  testWidgets('空月份不重复显示日历空态，学习时长图表显示本地化空态', (tester) async {
    // 增加窗口高度以确保日历下方内容可见
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_createTestApp(db: db, records: const {}));
    await tester.pumpAndSettle();

    expect(
      find.text('No learning activity this month', skipOffstage: false),
      findsNothing,
    );
    expect(find.text('No study records', skipOffstage: false), findsOneWidget);
  });

  testWidgets('今日已打卡时顶部显示已打卡状态，并在图例中说明角标含义', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _createTestApp(
        db: db,
        records: {
          now.day: const MonthDayRecord(
            studyTimeSeconds: 600,
            inputTimeSeconds: 0,
            outputTimeSeconds: 0,
            checkedInGoalMinutes: 10,
          ),
        },
        stats: const StudyStats(todaySeconds: 600),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checked in today'), findsOneWidget);
    expect(find.text('Daily goal completed'), findsOneWidget);
    expect(find.byType(DailyGoalCheckInBadge), findsWidgets);
  });

  testWidgets('今日未打卡时顶部显示目标进度', (tester) async {
    await tester.pumpWidget(
      _createTestApp(
        db: db,
        records: const {},
        stats: const StudyStats(todaySeconds: 180),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 min studied'), findsOneWidget);
    expect(find.text('Goal 10 min'), findsOneWidget);
    expect(find.text('Checked in today'), findsNothing);
  });
}
