import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/providers/feature_access_provider.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/services/free_allowance_policy.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/mock_providers.dart';

/// 固定 state 的 controller 替身（仿 FakeAppSettings 模式：extends + override build）。
class _FixedController extends SubscriptionController {
  _FixedController(this._state);
  final EntitlementState _state;
  @override
  EntitlementState build() => _state;
}

class _DenyPolicy implements FreeAllowancePolicy {
  const _DenyPolicy();
  @override
  bool allows(PremiumFeature feature) => false;
}

void main() {
  ProviderContainer makeContainer({
    required EntitlementState state,
    FreeAllowancePolicy policy = const AlwaysAllowPolicy(),
    bool authenticated = true,
  }) {
    final container = ProviderContainer(
      overrides: dedupeOverrides([
        subscriptionControllerProvider.overrideWith(
          () => _FixedController(state),
        ),
        freeAllowancePolicyProvider.overrideWithValue(policy),
        isAuthenticatedProvider.overrideWithValue(authenticated),
      ]),
    );
    addTearDown(container.dispose);
    return container;
  }

  const feature = PremiumFeature.aiTranscription;
  const pro = EntitlementState(
    status: EntitlementStatus.premium,
    entitlement: Entitlement(isPremium: true),
  );

  test('未登录 → 锁定（即便 pro 状态 + 放行策略，权益仅登录后有效）', () {
    final container = makeContainer(state: pro, authenticated: false);
    expect(container.read(featureAccessProvider(feature)), isFalse);
  });

  test('未登录 + free + 放行策略 → 仍锁定（免费额度不发放给未登录用户）', () {
    final container = makeContainer(
      state: const EntitlementState.free(),
      authenticated: false,
    );
    expect(container.read(featureAccessProvider(feature)), isFalse);
  });

  test('pro → 解锁（不论免费额度策略）', () {
    final container = makeContainer(state: pro, policy: const _DenyPolicy());
    expect(container.read(featureAccessProvider(feature)), isTrue);
  });

  test('free + 放行策略 → 解锁', () {
    final container = makeContainer(state: const EntitlementState.free());
    expect(container.read(featureAccessProvider(feature)), isTrue);
  });

  test('free + 拒绝策略 → 锁定', () {
    final container = makeContainer(
      state: const EntitlementState.free(),
      policy: const _DenyPolicy(),
    );
    expect(container.read(featureAccessProvider(feature)), isFalse);
  });

  test('unknown 中间态按未持权益处理，由免费额度策略兜底', () {
    final allow = makeContainer(state: const EntitlementState.unknown());
    expect(allow.read(featureAccessProvider(feature)), isTrue);

    final deny = makeContainer(
      state: const EntitlementState.unknown(),
      policy: const _DenyPolicy(),
    );
    expect(deny.read(featureAccessProvider(feature)), isFalse);
  });
}
