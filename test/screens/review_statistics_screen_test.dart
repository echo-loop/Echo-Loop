import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/review_statistics/review_statistics_repository.dart';
import 'package:echo_loop/screens/review_statistics_screen.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/common/app_segmented_button.dart';

void main() {
  testWidgets('统计页按时间口径展示范围筛选、分区和说明', (tester) async {
    final db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('zh')],
          home: ReviewStatisticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(AppSegmentedButton<ReviewStatisticsScope>),
      findsOneWidget,
    );
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('收藏句子'), findsAtLeastNWidgets(1));
    expect(find.text('收藏词汇'), findsAtLeastNWidgets(1));
    expect(find.text('今日概览'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_rounded), findsAtLeastNWidgets(1));
    expect(find.text('学习节奏'), findsOneWidget);
    expect(find.byIcon(Icons.insights_rounded), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(find.text('复习安排'), 300);
    expect(find.text('复习安排'), findsOneWidget);
    expect(find.byIcon(Icons.event_available_rounded), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(find.text('近期表现'), 300);
    expect(find.text('近期表现'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(find.text('历史足迹'), 300);
    expect(find.text('历史足迹'), findsOneWidget);
    expect(find.byIcon(Icons.timeline_rounded), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(find.text('近 30 天记忆保持率'), 300);
    expect(find.text('近 30 天记忆保持率'), findsOneWidget);
    expect(
      find.text('每项内容仅统计首次复习结果。\n保持率 = (听懂了 + 轻松听懂) / 总数'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('未来 7 天复习安排（含今天）'), 300);
    expect(find.text('未来 7 天复习安排（含今天）'), findsOneWidget);
    expect(find.text('ALL TIME'), findsNothing);
  });

  testWidgets('统计页可在深色主题中渲染', (tester) async {
    final db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh')],
          home: const ReviewStatisticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('今日概览'), findsOneWidget);
  });

  test('评级图例复用评分按钮文案', () {
    final l10n = AppLocalizations.delegate.load(const Locale('zh'));

    return l10n.then((localizations) {
      expect(localizations.bookmarkReviewRatingAgain, '听不懂');
      expect(localizations.bookmarkReviewRatingGood, '听懂了');
      expect(localizations.bookmarkReviewRatingEasy, '轻松听懂');
    });
  });

  test('英文复习保持率文案使用明确的首次复习口径', () async {
    final localizations = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    expect(localizations.reviewStatisticsSentences, 'Sentences');
    expect(localizations.reviewStatisticsVocabulary, 'Vocabulary');
    expect(localizations.reviewStatisticsRatings, '30-day retention rate');
    expect(
      localizations.reviewStatisticsRetentionExplanation,
      "Based on each item's first review in the last 30 days.\n"
      'Retention rate = (Got it + Easy) / Total',
    );
  });
}
