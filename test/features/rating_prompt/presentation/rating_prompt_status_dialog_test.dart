import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/features/rating_prompt/domain/rating_prompt_policy.dart';
import 'package:echo_loop/features/rating_prompt/domain/rating_prompt_status.dart';
import 'package:echo_loop/features/rating_prompt/presentation/rating_prompt_status_dialog.dart';
import 'package:echo_loop/features/rating_prompt/rating_prompt_providers.dart';

RatingPromptStatus _status({
  bool isRemoteEnabled = true,
  bool isStoreInstall = false,
  DateTime? installTime,
  int checkInDays = 1,
  bool withRecentTask = true,
}) {
  return RatingPromptStatus(
    now: DateTime(2026, 10, 22, 12),
    rules: RatingPromptRules.defaults,
    isRemoteEnabled: isRemoteEnabled,
    isStoreInstall: isStoreInstall,
    installerStore: null,
    lastTaskCompletedAt: withRecentTask ? DateTime(2026, 10, 22, 11, 59) : null,
    installTime: installTime ?? DateTime(2026, 10, 20),
    lastAttempt: null,
    countedFrom: DateTime(2026, 10, 20),
    checkInDays: checkInDays,
  );
}

Future<void> _openDialog(WidgetTester tester, RatingPromptStatus status) async {
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
}

void main() {
  testWidgets('展示首要阻断原因、各条件当前值与触发时机', (tester) async {
    await _openDialog(tester, _status());

    expect(find.text('评价提醒状态'), findsOneWidget);
    expect(find.text('仅用于查看，不会触发评价。'), findsOneWidget);
    // 远程开关开启但非商店安装时，结论应指出首要阻断原因。
    expect(find.text('非商店安装，不会请求'), findsOneWidget);
    expect(find.text('远程开关'), findsOneWidget);
    expect(find.text('已开启'), findsOneWidget);
    expect(find.text('商店安装'), findsOneWidget);
    expect(find.text('安装时长'), findsOneWidget);
    expect(find.text('2 天'), findsOneWidget);
    expect(find.text('每日目标打卡天数'), findsOneWidget);
    expect(find.text('1 天'), findsOneWidget);
    expect(find.text('从未请求'), findsOneWidget);
    expect(find.text('回到学习或收藏首页时检查一次；学习过程中不会弹出。'), findsOneWidget);
    expect(find.text('本次启动记录（0）'), findsOneWidget);
  });

  testWidgets('远程开关关闭时结论优先指出远程开关', (tester) async {
    await _openDialog(tester, _status(isRemoteEnabled: false, checkInDays: 5));

    expect(find.text('远程开关未开启，不会请求'), findsOneWidget);
    expect(find.text('已关闭'), findsOneWidget);
  });

  testWidgets('条件全部满足时结论为可请求', (tester) async {
    await _openDialog(
      tester,
      _status(
        isStoreInstall: true,
        installTime: DateTime(2026, 10, 1),
        checkInDays: 3,
      ),
    );

    expect(find.text('条件已满足，回到学习或收藏首页时会请求系统评分'), findsOneWidget);
  });

  testWidgets('没有最近完成的任务时结论指出任务条件', (tester) async {
    await _openDialog(
      tester,
      _status(
        isStoreInstall: true,
        installTime: DateTime(2026, 10, 1),
        checkInDays: 3,
        withRecentTask: false,
      ),
    );

    expect(find.text('最近 10 分钟内没有完成任务，暂不会请求'), findsOneWidget);
    expect(find.text('最近完成任务'), findsOneWidget);
    expect(find.text('无记录'), findsOneWidget);
  });
}
