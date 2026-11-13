import 'package:echo_loop/features/account_usage/domain/account_usage.dart';
import 'package:echo_loop/features/account_usage/providers/account_usage_provider.dart';
import 'package:echo_loop/features/account_usage/screens/account_usage_screen.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

AccountUsage _usage() => AccountUsage(
  plan: 'free',
  periodStart: DateTime(2026, 11),
  resetAt: DateTime(2026, 12),
  features: const {
    UsageFeature.dictionary: FeatureUsage(limit: 15, used: 0),
    UsageFeature.translate: FeatureUsage(limit: 15, used: 2),
    UsageFeature.transcription: FeatureUsage(limit: 1, used: 125),
    UsageFeature.chat: FeatureUsage(limit: null, used: 2),
  },
);

Future<void> _pumpScreen(WidgetTester tester, Override override) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [override],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: const AccountUsageScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('展示套餐、重置时间与各功能百分比，已满额显示100%且不露出原始计量', (tester) async {
    await _pumpScreen(
      tester,
      accountUsageProvider.overrideWith((ref) => Future.value(_usage())),
    );

    expect(find.text('Free plan'), findsOneWidget);
    expect(find.text('November 2026 quota'), findsOneWidget);
    expect(find.text('Resets Dec 1'), findsOneWidget);
    expect(find.text('AI Lookup'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('13%'), findsOneWidget);
    expect(find.text('100%'), findsNWidgets(1));
    expect(find.textContaining('125'), findsNothing);
    // 不限量只显示文字，不画进度条：有额度的 3 项各一条。
    expect(find.text('Unlimited'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
  });

  testWidgets('付费套餐显示会员名称', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final paidUsage = AccountUsage(
      plan: 'paid',
      periodStart: DateTime(2026, 11),
      resetAt: DateTime(2026, 12),
      features: const {},
    );

    await _pumpScreen(
      tester,
      accountUsageProvider.overrideWith((ref) => Future.value(paidUsage)),
    );

    expect(find.text(l10n.premiumTitle), findsOneWidget);
    expect(find.text('paid'), findsNothing);
  });

  testWidgets('加载失败后点击重试会重新请求并展示数据', (tester) async {
    var requestCount = 0;
    await _pumpScreen(
      tester,
      accountUsageProvider.overrideWith((ref) {
        requestCount++;
        if (requestCount == 1) {
          return Future<AccountUsage?>.error(StateError('offline'));
        }
        return Future.value(_usage());
      }),
    );

    expect(find.text("Couldn't load usage. Tap to retry."), findsOneWidget);
    expect(find.text('AI Lookup'), findsNothing);

    await tester.tap(find.text("Couldn't load usage. Tap to retry."));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(find.text('AI Lookup'), findsOneWidget);
  });
}
