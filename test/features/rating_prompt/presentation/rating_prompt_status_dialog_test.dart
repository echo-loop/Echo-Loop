import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/features/rating_prompt/domain/rating_prompt_policy.dart';
import 'package:echo_loop/features/rating_prompt/domain/rating_prompt_status.dart';
import 'package:echo_loop/features/rating_prompt/presentation/rating_prompt_status_dialog.dart';
import 'package:echo_loop/features/rating_prompt/rating_prompt_providers.dart';

void main() {
  testWidgets('展示各条件的满足情况，并标明不会触发评价', (tester) async {
    final status = RatingPromptStatus(
      now: DateTime(2026, 10, 22, 12),
      isRemoteEnabled: true,
      isStoreInstall: false,
      installerStore: null,
      installTime: DateTime(2026, 10, 20),
      lastAttempt: null,
      cooldownRemaining: null,
      countedFrom: DateTime(2026, 10, 20),
      effectiveStudyDays: 1,
      policy: RatingPromptPolicy.defaultPolicy,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ratingPromptStatusProvider.overrideWith((ref) async => status),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const RatingPromptStatusDialog(),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('评价提醒状态'), findsOneWidget);
    expect(find.text('仅用于查看，不会触发评价。'), findsOneWidget);
    expect(find.text('✅ 远程开关：已开启'), findsOneWidget);
    expect(find.textContaining('❌ 商店安装：否'), findsOneWidget);
    expect(find.text('❌ 安装时长：2 天 / 要求 7 天'), findsOneWidget);
    expect(find.textContaining('❌ 有效学习天数：1 / 要求 3'), findsOneWidget);
    expect(find.text('✅ 冷却：从未请求过系统评分'), findsOneWidget);
    expect(find.text('❌ 跟读完成：不会请求'), findsOneWidget);
    expect(find.text('❌ 复述完成：不会请求'), findsOneWidget);
    expect(find.text('本次启动尚无评估记录'), findsOneWidget);
  });
}
