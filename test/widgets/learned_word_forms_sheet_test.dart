import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/study/learned_word_forms_sheet.dart';

import '../helpers/mock_providers.dart';

AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
}

Widget _buildTestApp(AppDatabase db) {
  return ProviderScope(
    overrides: [analyticsOverride(), appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: const Scaffold(body: LearnedWordFormsSheet()),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('默认按最近学习倒序显示', (tester) async {
    await db.learnedWordFormDao.insertIfAbsentAll({
      'alpha': DateTime(2026, 3, 12, 8),
      'beta': DateTime(2026, 3, 12, 10),
      'gamma': DateTime(2026, 3, 12, 9),
    });

    await tester.pumpWidget(_buildTestApp(db));
    await tester.pumpAndSettle();

    expect(find.text('3 words'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('gamma'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);

    final betaTopLeft = tester.getTopLeft(find.text('beta'));
    final gammaTopLeft = tester.getTopLeft(find.text('gamma'));
    expect(betaTopLeft.dy, lessThan(gammaTopLeft.dy));
  });

  testWidgets('单词和日期在同一行展示', (tester) async {
    await db.learnedWordFormDao.insertIfAbsentAll({
      'thing': DateTime(2026, 3, 12, 14, 19),
    });

    await tester.pumpWidget(_buildTestApp(db));
    await tester.pumpAndSettle();

    // 验证单词显示
    expect(find.text('thing'), findsOneWidget);
    // 验证相对时间格式显示（日期不是 "2026-03-12 14:19" 而是 "x days ago" 等格式）
    // 检查行内布局：单词右侧应有日期文本
    final rowFinder = find.ancestor(
      of: find.text('thing'),
      matching: find.byType(Row),
    );
    expect(rowFinder, findsOneWidget);
    // Row 内应包含日期 Text
    final rowWidget = tester.widget<Row>(rowFinder);
    final hasDateText = rowWidget.children.any(
      (child) => child is Text && child.data != 'thing',
    );
    expect(hasDateText, isTrue);
  });

  testWidgets('切换到 A → Z 后按字母正序显示', (tester) async {
    await db.learnedWordFormDao.insertIfAbsentAll({
      'alpha': DateTime(2026, 3, 12, 8),
      'beta': DateTime(2026, 3, 12, 10),
      'gamma': DateTime(2026, 3, 12, 9),
    });

    await tester.pumpWidget(_buildTestApp(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A → Z').last);
    await tester.pumpAndSettle();

    final alphaTopLeft = tester.getTopLeft(find.text('alpha'));
    final betaTopLeft = tester.getTopLeft(find.text('beta'));
    expect(alphaTopLeft.dy, lessThan(betaTopLeft.dy));
  });

  testWidgets('滚动到底部自动加载下一页', (tester) async {
    final data = <String, DateTime>{};
    for (var i = 0; i < 55; i++) {
      data['word_${i.toString().padLeft(2, '0')}'] = DateTime(
        2026,
        3,
        12,
        10,
        i,
      );
    }
    await db.learnedWordFormDao.insertIfAbsentAll(data);

    await tester.pumpWidget(_buildTestApp(db));
    await tester.pumpAndSettle();

    expect(find.text('55 words'), findsOneWidget);
    expect(find.text('word_54'), findsOneWidget);
    expect(find.text('word_00'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('word_00'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('word_00'), findsOneWidget);
  });

  testWidgets('空列表显示空状态', (tester) async {
    await tester.pumpWidget(_buildTestApp(db));
    await tester.pumpAndSettle();

    expect(find.text('0 words'), findsOneWidget);
    expect(
      find.text('No words learned yet. Complete a listening session first.'),
      findsOneWidget,
    );
  });
}
