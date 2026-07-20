/// PremiumFeature.aiChat 接入 featureAccessProvider 的三态回归。
library;

import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/providers/feature_access_provider.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/services/free_allowance_policy.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedController extends SubscriptionController {
  _FixedController(this._state);
  final EntitlementState _state;
  @override
  EntitlementState build() => _state;
}

void main() {
  ProviderContainer makeContainer({
    required EntitlementState state,
    FreeAllowancePolicy policy = const AlwaysAllowPolicy(),
    bool authenticated = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        subscriptionControllerProvider.overrideWith(
          () => _FixedController(state),
        ),
        freeAllowancePolicyProvider.overrideWithValue(policy),
        isAuthenticatedProvider.overrideWithValue(authenticated),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  const feature = PremiumFeature.aiChat;
  const pro = EntitlementState(
    status: EntitlementStatus.premium,
    entitlement: Entitlement(isPremium: true),
  );

  test('未登录 → false', () {
    final c = makeContainer(
      state: const EntitlementState.free(),
      authenticated: false,
    );
    expect(c.read(featureAccessProvider(feature)), isFalse);
  });

  test('会员 → true', () {
    final c = makeContainer(state: pro);
    expect(c.read(featureAccessProvider(feature)), isTrue);
  });

  test('免费登录 + AlwaysAllow（现网策略）→ 放行', () {
    final c = makeContainer(state: const EntitlementState.free());
    expect(c.read(featureAccessProvider(feature)), isTrue);
  });
}
