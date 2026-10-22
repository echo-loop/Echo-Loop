import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/router/route_transition_observer.dart';

void main() {
  testWidgets('等待 root Navigator 退场动画，不依赖分支路由动画', (tester) async {
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final observer = RouteTransitionObserver();
    ModalRoute<dynamic>? planRoute;
    late RoutePopTransition transition;
    late Future<String?> playerResult;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [observer],
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              planRoute = ModalRoute.of(context);
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      transition = observer.watchNextPop();
                      final rootNavigator =
                          rootNavigatorKey.currentState ??
                          (throw StateError('root Navigator 没有挂载'));
                      playerResult = rootNavigator.push<String>(
                        MaterialPageRoute<String>(
                          builder: (_) => const Scaffold(body: Text('练习')),
                        ),
                      );
                    },
                    child: const Text('开始练习'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('开始练习'));
    await tester.pumpAndSettle();

    final innerPlanRoute =
        planRoute ?? (throw StateError('分支 Navigator 中没有学习计划路由'));
    expect(
      innerPlanRoute.secondaryAnimation?.status,
      AnimationStatus.dismissed,
    );

    var transitionSettled = false;
    final settling = transition.completed.then((_) {
      transitionSettled = true;
    });
    final rootNavigator =
        rootNavigatorKey.currentState ??
        (throw StateError('root Navigator 已卸载'));

    final dialogResult = rootNavigator.push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const Scaffold(body: Text('完成确认')),
      ),
    );
    await tester.pumpAndSettle();
    rootNavigator.pop('dismissed');
    expect(await dialogResult, 'dismissed');
    await tester.pumpAndSettle();
    expect(transitionSettled, isFalse);

    rootNavigator.pop('completed');

    expect(await playerResult, 'completed');
    expect(transitionSettled, isFalse);
    expect(
      innerPlanRoute.secondaryAnimation?.status,
      AnimationStatus.dismissed,
    );

    await tester.pumpAndSettle();
    await settling;

    expect(transitionSettled, isTrue);
    expect(transition.returnedToPreviousRoute, isTrue);
    transition.cancel();
  });
}
