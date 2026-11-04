import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:echo_loop/features/subscription/widgets/member_tab_badge.dart';

class _FixedSubscriptionController extends SubscriptionController {
  _FixedSubscriptionController(this._state);
  final EntitlementState _state;

  @override
  EntitlementState build() => _state;
}

void main() {
  Future<void> pumpBadge(WidgetTester tester, EntitlementState state) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionControllerProvider.overrideWith(
            () => _FixedSubscriptionController(state),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MemberTabBadge(child: Icon(Icons.person_outline)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('已确认会员时显示 VIP 角标', (tester) async {
    await pumpBadge(
      tester,
      const EntitlementState(
        status: EntitlementStatus.premium,
        entitlement: Entitlement(isPremium: true, productId: 'pro_yearly'),
      ),
    );

    expect(find.text('VIP'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('免费用户不显示角标', (tester) async {
    await pumpBadge(tester, const EntitlementState.free());

    expect(find.text('VIP'), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('权益未知（冷启动中间态）时不显示角标，避免误标', (tester) async {
    await pumpBadge(tester, const EntitlementState.unknown());

    expect(find.text('VIP'), findsNothing);
  });
}
