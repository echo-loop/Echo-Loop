// 学习统计头部组件 Widget 测试
//
// 验证今日卡片、本周柱状图、词汇量 badge 的渲染和交互。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:drift/native.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/database/app_database.dart';
import 'package:fluency/database/providers.dart';
import 'package:fluency/widgets/study/study_stats_header.dart';
import 'package:fluency/providers/study_stats_provider.dart';
import 'package:fluency/theme/app_theme.dart';

// ========== 测试用 Mock ==========

/// 测试用 StudyStatsNotifier — 返回预设数据，不访问 StudyTimeService
class _TestStudyStatsNotifier extends StudyStatsNotifier {
  final StudyStats _data;

  _TestStudyStatsNotifier(this._data);

  @override
  Future<StudyStats> build() async => _data;
}

void main() {
  /// 每个测试共享的内存数据库，tearDown 时关闭
  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase(
      NativeDatabase.memory(
        setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  });

  tearDown(() => testDb.close());

  Widget createTestWidget({
    required StudyStats stats,
    Locale locale = const Locale('en'),
    AppDatabase? db,
  }) {
    final effectiveDb = db ?? testDb;
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(effectiveDb),
        studyStatsNotifierProvider.overrideWith(
          () => _TestStudyStatsNotifier(stats),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: const Scaffold(body: StudyStatsHeader()),
      ),
    );
  }

  group('StudyStatsHeader — 今日卡片', () {
    testWidgets('显示今日时长', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 1800, // 30 min
            weekTotalSeconds: 7200,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
    });

    testWidgets('零时长显示 0 min', (tester) async {
      await tester.pumpWidget(createTestWidget(stats: const StudyStats()));
      await tester.pumpAndSettle();

      expect(find.text('0 min'), findsOneWidget);
    });

    testWidgets('大时长格式化为小时分钟', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 5400, // 90 min = 1h 30m
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1h 30m'), findsOneWidget);
    });

    testWidgets('显示听/说/词汇图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(stats: const StudyStats(todaySeconds: 60)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.headphones_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_outlined), findsOneWidget);
      expect(find.byIcon(Icons.spellcheck_rounded), findsOneWidget);
    });

    testWidgets('词汇今日新增显示在今日卡片内', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(todayNewWordForms: 42),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+42'), findsOneWidget);
    });
  });

  group('StudyStatsHeader — 本周柱状图', () {
    testWidgets('标题行显示本周累计时长', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            weekTotalSeconds: 7200, // 2h 0m
            dailySeconds: [0, 0, 0, 0, 0, 0, 600],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Week: 2h 0m'), findsOneWidget);
      expect(find.byIcon(Icons.date_range_outlined), findsOneWidget);
    });

    testWidgets('有学习数据时显示柱状图卡片', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(dailySeconds: [0, 0, 0, 0, 0, 0, 600]),
        ),
      );
      await tester.pumpAndSettle();

      // 两张 Card：今日卡片 + 柱状图卡片
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('全零数据不显示柱状图卡片', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(dailySeconds: [0, 0, 0, 0, 0, 0, 0]),
        ),
      );
      await tester.pumpAndSettle();

      // 仅今日卡片，无柱状图
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('柱状图显示星期标签', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(dailySeconds: [300, 600, 0, 0, 0, 0, 900]),
        ),
      );
      await tester.pumpAndSettle();

      final weekdayLabels = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];
      for (final label in weekdayLabels) {
        expect(find.text(label), findsAtLeast(1));
      }
    });

    testWidgets('非零柱体显示分钟数', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            dailySeconds: [0, 0, 0, 0, 0, 0, 1800], // 30 min
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('30m'), findsOneWidget);
    });
  });

  group('StudyStatsHeader — 词汇量', () {
    testWidgets('点击词汇区域打开底部弹窗', (tester) async {
      await testDb.learnedWordFormDao.insertIfAbsentAll({
        'beta': DateTime(2026, 3, 12, 10),
      });

      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(todayNewWordForms: 1),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();

      expect(find.text('Vocab'), findsWidgets);
      expect(find.text('1 words'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
    });
  });

  group('StudyStatsHeader — 今日卡片 clamp', () {
    testWidgets('input+output > total 时 clamp 显示正确', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 1500, // 25 min
            todayInputSeconds: 1440, // 24 min（超过 total）
            todayOutputSeconds: 1260, // 21 min
            dailySeconds: [0, 0, 0, 0, 0, 0, 1500],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 总时长正常显示 25 min
      expect(find.text('25 min'), findsOneWidget);

      // input: min(1440, 1500) = 1440 → 24分
      // output: min(1260, max(0, 1500-1440)) = min(1260, 60) = 60 → 1分
      expect(find.text('24分'), findsOneWidget);
      expect(find.text('1分'), findsOneWidget);
    });

    testWidgets('input+output <= total 时不 clamp', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 1800, // 30 min
            todayInputSeconds: 900, // 15 min
            todayOutputSeconds: 600, // 10 min
            dailySeconds: [0, 0, 0, 0, 0, 0, 1800],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('15分'), findsOneWidget);
      expect(find.text('10分'), findsOneWidget);
    });
  });

  group('StudyStatsHeader — 柱状图基于 totalSeconds', () {
    testWidgets('柱顶标签显示 total 而非 input+output', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 1500, // 25 min
            weekTotalSeconds: 1500,
            dailySeconds: [0, 0, 0, 0, 0, 0, 1500],
            dailyInputSeconds: [0, 0, 0, 0, 0, 0, 1440],
            dailyOutputSeconds: [0, 0, 0, 0, 0, 0, 1260],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 柱顶应显示 25m（基于 totalSeconds 1500/60=25）
      expect(find.text('25m'), findsOneWidget);
      // 不应显示 45m（input+output 的错误值）
      expect(find.text('45m'), findsNothing);
    });

    testWidgets('input+output > total 时柱状图 clamp 不溢出', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            weekTotalSeconds: 1800,
            dailySeconds: [0, 0, 0, 0, 0, 0, 1800],
            dailyInputSeconds: [0, 0, 0, 0, 0, 0, 1200],
            dailyOutputSeconds: [0, 0, 0, 0, 0, 0, 900],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 柱顶显示 30m（totalSeconds 1800/60=30）
      expect(find.text('30m'), findsOneWidget);
    });
  });

  group('StudyStatsHeader — 听/说弹窗推荐表格', () {
    testWidgets('点击听区域弹窗显示完整推荐表（英文）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 600,
            todayInputSeconds: 300,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.headphones_outlined));
      await tester.pumpAndSettle();

      // 弹窗标题
      expect(find.text('Listening Details'), findsOneWidget);
      // 小节标题 + 表头
      expect(find.text('Daily recommendation'), findsOneWidget);
      expect(find.text('Listening (input)'), findsOneWidget);
      expect(find.text('Speaking (output)'), findsOneWidget);
      // 等级标签
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      // 听力时长
      expect(find.text('12min'), findsAtLeast(1));
      expect(find.text('15min'), findsAtLeast(1));
      expect(find.text('18min'), findsAtLeast(1));
      // 说的时长
      expect(find.text('8min'), findsOneWidget);
      expect(find.text('10min'), findsAtLeast(1));
      // 输入 + 输出词数（~5,000w 出现 2 次：初级输入 + 高级输出）
      expect(find.text('~5,000w'), findsNWidgets(2));
      expect(find.text('~1,700w'), findsOneWidget);
      // 脚注
      expect(
        find.text(
          'Input/output ratio trends from ~3:2 to ~1:1 as level rises',
        ),
        findsOneWidget,
      );
    });

    testWidgets('点击说区域弹窗显示完整推荐表（英文）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 600,
            todayOutputSeconds: 300,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_outlined));
      await tester.pumpAndSettle();

      // 弹窗标题 + 表头
      expect(find.text('Speaking Details'), findsOneWidget);
      expect(find.text('Listening (input)'), findsOneWidget);
      expect(find.text('Speaking (output)'), findsOneWidget);
      // 听 + 说时长都出现
      expect(find.text('12min'), findsAtLeast(1));
      expect(find.text('15min'), findsAtLeast(1));
      expect(find.text('18min'), findsAtLeast(1));
      expect(find.text('8min'), findsOneWidget);
      expect(find.text('10min'), findsAtLeast(1));
      // 输出词数（~5,000w 出现 2 次：初级输入 + 高级输出）
      expect(find.text('~1,700w'), findsOneWidget);
      expect(find.text('~3,500w'), findsOneWidget);
      expect(find.text('~5,000w'), findsNWidgets(2));
    });

    testWidgets('点击听区域弹窗显示完整推荐表（中文）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 600,
            todayInputSeconds: 300,
          ),
          locale: const Locale('zh'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.headphones_outlined));
      await tester.pumpAndSettle();

      // 弹窗标题
      expect(find.text('听力详情'), findsOneWidget);
      // 小节标题
      expect(find.text('每日推荐练习量'), findsOneWidget);
      // 表头
      expect(find.text('听力（输入）'), findsOneWidget);
      expect(find.text('口语（输出）'), findsOneWidget);
      // 中文等级名
      expect(find.text('初级'), findsOneWidget);
      expect(find.text('中级'), findsOneWidget);
      expect(find.text('高级'), findsOneWidget);
      // 听力时长
      expect(find.text('12分钟'), findsAtLeast(1));
      expect(find.text('15分钟'), findsAtLeast(1));
      expect(find.text('18分钟'), findsAtLeast(1));
      // 说的时长
      expect(find.text('8分钟'), findsOneWidget);
      expect(find.text('10分钟'), findsAtLeast(1));
      // 中文脚注
      expect(
        find.text('输入输出比随水平提升从 ~3:2 趋近 ~1:1'),
        findsOneWidget,
      );
    });
  });

  group('StudyStatsHeader — 中文本地化', () {
    testWidgets('中文标签', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 1800,
            weekTotalSeconds: 3600,
            learnedWordFormCount: 1234,
            todayNewWordForms: 12,
            dailySeconds: [0, 0, 0, 0, 0, 0, 1800],
          ),
          locale: const Locale('zh'),
        ),
      );
      await tester.pumpAndSettle();

      // 今日卡片
      expect(find.text('今日'), findsOneWidget);
      expect(find.text('30 分钟'), findsOneWidget);
      // 本周柱状图标题
      expect(find.text('本周: 1小时0分钟'), findsOneWidget);
      // 词汇今日新增（嵌入今日卡片）
      expect(find.text('+12'), findsOneWidget);
    });
  });
}
