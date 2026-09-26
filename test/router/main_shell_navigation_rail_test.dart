import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/desktop_sidebar_provider.dart';
import 'package:echo_loop/router/widgets/main_shell_navigation_rail.dart';
import 'package:echo_loop/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  Widget buildApp({required ValueChanged<int> onDestinationSelected}) {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Row(
            children: [
              MainShellNavigationRail(
                selectedIndex: 0,
                onDestinationSelected: onDestinationSelected,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('wide rail toggles labels and remembers the collapsed state', (
    tester,
  ) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      buildApp(onDestinationSelected: (index) => selectedIndex = index),
    );
    await tester.pumpAndSettle();

    var rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.byTooltip('收起侧边栏'), findsOneWidget);
    const railFinder = ValueKey('main-shell-navigation-rail');
    final railRect = tester.getRect(find.byKey(railFinder));
    expect(railRect.width, closeTo(172, 0.1));
    final selectedIconCenterX = tester
        .getCenter(find.byIcon(Icons.library_music))
        .dx;
    final toggleRect = tester.getRect(
      find.byKey(const ValueKey('main-shell-sidebar-toggle')),
    );
    final expandedToggleCenterX = toggleRect.center.dx;
    expect(railRect.bottom - toggleRect.bottom, closeTo(16, 0.1));
    expect(railRect.right - toggleRect.right, closeTo(8, 0.1));
    final railBackground = tester.widget<NavigationRail>(
      find.byKey(railFinder),
    );
    final railTheme = Theme.of(tester.element(find.byType(NavigationRail)));
    expect(
      railBackground.backgroundColor,
      railTheme.navigationRailTheme.backgroundColor,
    );

    await tester.tap(find.byKey(const ValueKey('main-shell-sidebar-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    var transitioningWidth = tester.getRect(find.byKey(railFinder)).width;
    expect(transitioningWidth, greaterThan(72));
    expect(transitioningWidth, lessThan(172));
    expect(
      tester.getCenter(find.byIcon(Icons.library_music)).dx,
      closeTo(selectedIconCenterX, 0.1),
    );
    var transitioningRailRect = tester.getRect(find.byKey(railFinder));
    var transitioningToggleRect = tester.getRect(
      find.byKey(const ValueKey('main-shell-sidebar-toggle')),
    );
    expect(transitioningToggleRect.center.dx, greaterThan(selectedIconCenterX));
    expect(transitioningToggleRect.center.dx, lessThan(expandedToggleCenterX));
    expect(
      transitioningRailRect.bottom - transitioningToggleRect.bottom,
      closeTo(16, 0.1),
    );

    await tester.pumpAndSettle();

    rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.labelType, NavigationRailLabelType.none);
    expect(tester.getRect(find.byKey(railFinder)).width, closeTo(72, 0.1));
    expect(
      tester.getCenter(find.byIcon(Icons.library_music)).dx,
      closeTo(selectedIconCenterX, 0.1),
    );
    final collapsedToggleRect = tester.getRect(
      find.byKey(const ValueKey('main-shell-sidebar-toggle')),
    );
    expect(collapsedToggleRect.center.dx, closeTo(selectedIconCenterX, 0.1));
    expect(
      tester.getRect(find.byKey(railFinder)).bottom -
          collapsedToggleRect.bottom,
      closeTo(16, 0.1),
    );
    expect(find.byTooltip('展开侧边栏'), findsOneWidget);
    expect(
      preferences.getBool(DesktopSidebarExpandedNotifier.storageKey),
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('main-shell-sidebar-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    transitioningWidth = tester.getRect(find.byKey(railFinder)).width;
    expect(transitioningWidth, greaterThan(72));
    expect(transitioningWidth, lessThan(172));
    expect(
      tester.getCenter(find.byIcon(Icons.library_music)).dx,
      closeTo(selectedIconCenterX, 0.1),
    );
    transitioningRailRect = tester.getRect(find.byKey(railFinder));
    transitioningToggleRect = tester.getRect(
      find.byKey(const ValueKey('main-shell-sidebar-toggle')),
    );
    expect(transitioningToggleRect.center.dx, greaterThan(selectedIconCenterX));
    expect(transitioningToggleRect.center.dx, lessThan(expandedToggleCenterX));
    expect(
      transitioningRailRect.bottom - transitioningToggleRect.bottom,
      closeTo(16, 0.1),
    );

    await tester.pumpAndSettle();
    rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(tester.getRect(find.byKey(railFinder)).width, closeTo(172, 0.1));
    expect(
      tester.getCenter(find.byIcon(Icons.library_music)).dx,
      closeTo(selectedIconCenterX, 0.1),
    );
    expect(
      preferences.getBool(DesktopSidebarExpandedNotifier.storageKey),
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.school_outlined));
    expect(selectedIndex, 1);
  });

  testWidgets('collapsed rail always offers a way to expand and view labels', (
    tester,
  ) async {
    await preferences.setBool(DesktopSidebarExpandedNotifier.storageKey, false);
    await tester.pumpWidget(buildApp(onDestinationSelected: (_) {}));
    await tester.pumpAndSettle();

    var rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('main-shell-navigation-rail')))
          .width,
      closeTo(72, 0.1),
    );
    final railIconCenterX = tester
        .getCenter(find.byIcon(Icons.library_music))
        .dx;
    final toggleRect = tester.getRect(
      find.byKey(const ValueKey('main-shell-sidebar-toggle')),
    );
    expect(toggleRect.center.dx, closeTo(railIconCenterX, 0.1));
    expect(
      tester
              .getRect(find.byKey(const ValueKey('main-shell-navigation-rail')))
              .bottom -
          toggleRect.bottom,
      closeTo(16, 0.1),
    );
    expect(find.byTooltip('展开侧边栏'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('main-shell-sidebar-toggle')));
    await tester.pumpAndSettle();

    rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.byTooltip('收起侧边栏'), findsOneWidget);
    expect(
      preferences.getBool(DesktopSidebarExpandedNotifier.storageKey),
      isTrue,
    );
  });
}
