import 'dart:async';

import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/user_region/user_region_bootstrapper.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/providers/startup_bootstrap_provider.dart';
import 'package:echo_loop/widgets/app_startup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_providers.dart';

void main() {
  testWidgets('品牌页保持到本地数据与地区决策都就绪', (tester) async {
    final regionGate = Completer<UserRegionBootstrapResult>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          localStartupProvider.overrideWith(_ReadyLocalStartupController.new),
          userRegionBootstrapProvider.overrideWith((ref) => regionGate.future),
        ]),
        child: const MaterialApp(
          home: AppStartupGate(
            splashScreen: Text('startup splash'),
            child: Text('business route'),
          ),
        ),
      ),
    );

    expect(find.text('startup splash'), findsOneWidget);
    expect(find.text('business route'), findsNothing);

    regionGate.complete(
      const UserRegionBootstrapResult(
        isChinaUser: false,
        source: UserRegionDecisionSource.remoteConfig,
        remoteConfig: RemoteConfig.defaults,
      ),
    );
    await tester.pump();

    expect(find.text('startup splash'), findsNothing);
    expect(find.text('business route'), findsOneWidget);
  });

  testWidgets('本地启动失败时地区就绪后仍可进入降级页面', (tester) async {
    final regionGate = Completer<UserRegionBootstrapResult>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          localStartupProvider.overrideWith(_FailedLocalStartupController.new),
          userRegionBootstrapProvider.overrideWith((ref) => regionGate.future),
        ]),
        child: const MaterialApp(
          home: AppStartupGate(
            splashScreen: Text('startup splash'),
            child: Text('degraded route'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('startup splash'), findsOneWidget);

    regionGate.complete(
      const UserRegionBootstrapResult(
        isChinaUser: false,
        source: UserRegionDecisionSource.systemFallback,
        remoteConfig: RemoteConfig.defaults,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('degraded route'), findsOneWidget);
  });
}

class _ReadyLocalStartupController extends LocalStartupController {
  @override
  Future<StartupReport> build() async => const StartupReport([]);
}

class _FailedLocalStartupController extends LocalStartupController {
  @override
  Future<StartupReport> build() async => throw StateError('database failed');
}
