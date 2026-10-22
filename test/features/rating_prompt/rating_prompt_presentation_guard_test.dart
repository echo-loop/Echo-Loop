import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:echo_loop/features/rating_prompt/rating_prompt_presentation_guard.dart';

void main() {
  testWidgets('保留挂载的计划页在切 Tab、后台、root 覆盖及卸载时不可展示', (tester) async {
    RatingPromptPresentationGuard? guard;
    BuildContext? planContext;
    var rootCurrent = true;
    final router = GoRouter(
      initialLocation: '/plan',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/plan',
                  builder: (context, _) {
                    planContext = context;
                    return TextButton(
                      onPressed: () {
                        guard = RatingPromptPresentationGuard(
                          context: context,
                          isRootRouteCurrent: () => rootCurrent,
                        );
                      },
                      child: const Text('完成返回'),
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/other',
                  builder: (_, _) => const Text('其他 Tab'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成返回'));
    final presentation = guard ?? (throw StateError('未创建展示检查器'));
    expect(presentation.canPresent, isTrue);

    router.go('/other');
    await tester.pumpAndSettle();
    expect(planContext?.mounted, isTrue);
    expect(presentation.canPresent, isFalse);
    router.go('/plan');
    await tester.pumpAndSettle();
    expect(presentation.canPresent, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(presentation.canPresent, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(presentation.canPresent, isTrue);
    rootCurrent = false;
    expect(presentation.canPresent, isFalse);
    rootCurrent = true;
    await tester.pumpWidget(const SizedBox());
    expect(presentation.canPresent, isFalse);
  });
}
