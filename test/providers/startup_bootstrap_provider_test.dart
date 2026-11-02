import 'dart:async';

import 'package:echo_loop/providers/startup_bootstrap_provider.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/user_region/user_region_bootstrapper.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_providers.dart';

void main() {
  testWidgets('首帧提交后执行本地启动，并将成功结果发布为唯一 gate', (tester) async {
    final bootstrapper = _FakeBootstrapper();

    await tester.pumpWidget(_host(bootstrapper: bootstrapper));
    expect(bootstrapper.localCalls, 1);
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('本地失败显示 error，重试后不会保留失败 gate', (tester) async {
    final bootstrapper = _FakeBootstrapper(failLocalAttempts: 1);

    await tester.pumpWidget(_host(bootstrapper: bootstrapper));
    await tester.pump();
    expect(find.text('error'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(bootstrapper.localCalls, 2);
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('第三方启动严格等待本地 gate 成功', (tester) async {
    final localGate = Completer<StartupReport>();
    final bootstrapper = _FakeBootstrapper(localGate: localGate);

    await tester.pumpWidget(
      _host(bootstrapper: bootstrapper, watchThirdParty: true),
    );
    await tester.pump();
    expect(bootstrapper.localCalls, 1);
    expect(bootstrapper.thirdPartyCalls, 0);

    localGate.complete(const StartupReport([]));
    await tester.pump();
    await tester.pump();

    expect(bootstrapper.thirdPartyCalls, 1);
    expect(find.text('third-ready'), findsOneWidget);
  });

  testWidgets('本地重试成功后会重新释放第三方初始化', (tester) async {
    final bootstrapper = _FakeBootstrapper(failLocalAttempts: 1);

    await tester.pumpWidget(
      _host(bootstrapper: bootstrapper, watchThirdParty: true),
    );
    await tester.pump();
    expect(find.byType(FilledButton), findsOneWidget);
    expect(bootstrapper.thirdPartyCalls, 0);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump();

    expect(bootstrapper.thirdPartyCalls, 1);
    expect(find.text('third-ready'), findsOneWidget);
  });

  testWidgets('第三方与 Supabase 初始化等待地区决策完成', (tester) async {
    final regionGate = Completer<UserRegionBootstrapResult>();
    final bootstrapper = _FakeBootstrapper();

    await tester.pumpWidget(
      _host(
        bootstrapper: bootstrapper,
        watchThirdParty: true,
        regionGate: regionGate,
      ),
    );
    await tester.pump();
    expect(bootstrapper.localCalls, 1);
    expect(bootstrapper.thirdPartyCalls, 0);

    regionGate.complete(_chinaResolvedRegion);
    await tester.pump();
    await tester.pump();

    expect(bootstrapper.thirdPartyCalls, 1);
    expect(bootstrapper.supabaseUrls, ['https://china.supabase.test']);
    expect(find.text('third-ready'), findsOneWidget);
  });

  testWidgets('第三方报告只发布 bootstrapper 确认的 RevenueCat ready 状态', (tester) async {
    final bootstrapper = _FakeBootstrapper(revenueCatReady: true);

    await tester.pumpWidget(
      _host(bootstrapper: bootstrapper, watchThirdParty: true),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('revenuecat-ready'), findsOneWidget);
  });
}

Widget _host({
  required StartupBootstrapper bootstrapper,
  bool watchThirdParty = false,
  Completer<UserRegionBootstrapResult>? regionGate,
}) {
  final regionFuture = regionGate?.future ?? Future.value(_resolvedRegion);
  return ProviderScope(
    overrides: dedupeOverrides([
      startupBootstrapperProvider.overrideWithValue(bootstrapper),
      userRegionBootstrapProvider.overrideWith((ref) => regionFuture),
      supabaseUrlForThisRunProvider.overrideWith((ref) async {
        final userRegion = await ref.watch(userRegionBootstrapProvider.future);
        return userRegion.isChinaUser
            ? 'https://china.supabase.test'
            : 'https://global.supabase.test';
      }),
    ]),
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) {
          final local = ref.watch(localStartupProvider);
          final thirdParty = watchThirdParty
              ? ref.watch(thirdPartyStartupProvider)
              : null;
          if (thirdParty case AsyncData(:final value)) {
            return Text(
              value.isRevenueCatReady ? 'revenuecat-ready' : 'third-ready',
            );
          }
          return switch (local) {
            AsyncData() => const Text('ready'),
            AsyncError() => FilledButton(
              onPressed: () =>
                  unawaited(ref.read(localStartupProvider.notifier).retry()),
              child: const Text('error'),
            ),
            _ => const Text('loading'),
          };
        },
      ),
    ),
  );
}

const _resolvedRegion = UserRegionBootstrapResult(
  isChinaUser: false,
  source: UserRegionDecisionSource.remoteConfig,
  remoteConfig: RemoteConfig.defaults,
);

const _chinaResolvedRegion = UserRegionBootstrapResult(
  isChinaUser: true,
  source: UserRegionDecisionSource.remoteConfig,
  remoteConfig: RemoteConfig.defaults,
);

class _FakeBootstrapper implements StartupBootstrapper {
  _FakeBootstrapper({
    this.failLocalAttempts = 0,
    this.localGate,
    this.revenueCatReady = false,
  });

  final int failLocalAttempts;
  final Completer<StartupReport>? localGate;
  final bool revenueCatReady;
  int localCalls = 0;
  int thirdPartyCalls = 0;
  final supabaseUrls = <String?>[];

  @override
  Future<StartupReport> initializeLocal() async {
    localCalls += 1;
    if (localCalls <= failLocalAttempts) throw StateError('local failed');
    final gate = localGate;
    if (gate != null) return gate.future;
    return const StartupReport([]);
  }

  @override
  Future<ThirdPartyStartupReport> initializeThirdParty({
    required String? supabaseUrl,
  }) async {
    thirdPartyCalls += 1;
    supabaseUrls.add(supabaseUrl);
    return ThirdPartyStartupReport(
      issues: [],
      isSupabaseReady: false,
      isRevenueCatReady: revenueCatReady,
    );
  }
}
