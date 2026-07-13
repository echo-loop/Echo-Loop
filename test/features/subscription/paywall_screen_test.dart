import 'package:echo_loop/config/revenuecat_config.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/models/subscription_plan.dart';
import 'package:echo_loop/features/subscription/providers/subscription_availability.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/providers/subscription_plans_provider.dart';
import 'package:echo_loop/features/subscription/screens/paywall_screen.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 固定权益态的 controller 替身（不跑对账 / 监听 / 订阅流）。
class _FixedController extends SubscriptionController {
  _FixedController(this._state);
  final EntitlementState _state;
  @override
  EntitlementState build() => _state;
}

/// 记录购买 / 恢复调用次数的替身，用于验证登录门是否拦截了动作。
class _SpyController extends SubscriptionController {
  _SpyController(this._state);
  final EntitlementState _state;
  int purchaseCalls = 0;
  int restoreCalls = 0;
  @override
  EntitlementState build() => _state;
  @override
  Future<void> purchase(String planId) async => purchaseCalls++;
  @override
  Future<void> restore() async => restoreCalls++;
}

class _FixedPlansController extends SubscriptionPlansController {
  _FixedPlansController(this._plans);

  final List<SubscriptionPlan> _plans;

  @override
  AsyncValue<List<SubscriptionPlan>> build() => AsyncData(_plans);

  @override
  Future<void> refresh({bool force = false}) async {}
}

const _plans = [
  SubscriptionPlan(
    planId: 'monthly',
    title: 'Monthly',
    priceString: r'$4.99',
    period: SubscriptionPeriod.monthly,
  ),
  SubscriptionPlan(
    planId: 'yearly',
    title: 'Yearly',
    priceString: r'$39.99',
    period: SubscriptionPeriod.yearly,
    hasFreeTrial: true,
    trialDays: 7,
  ),
];

Widget _harness({
  required EntitlementState state,
  List<SubscriptionPlan> plans = _plans,
  bool? authenticated,
  SubscriptionController Function()? controller,
  // 测试宿主（macOS/无 key）默认不支持订阅，这里默认置 true 以覆盖购买页 UI。
  bool available = true,
  // 网页支付渠道（侧载 APK / 桌面）：切换到浏览器结账购买态。
  bool webCheckout = false,
}) {
  return ProviderScope(
    overrides: [
      subscriptionAvailabilityProvider.overrideWithValue(available),
      webCheckoutModeProvider.overrideWithValue(webCheckout),
      subscriptionControllerProvider.overrideWith(
        controller ?? () => _FixedController(state),
      ),
      subscriptionPlansProvider.overrideWith(
        () => _FixedPlansController(plans),
      ),
      if (authenticated != null)
        isAuthenticatedProvider.overrideWithValue(authenticated),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('en'), Locale('zh')],
      home: PaywallScreen(),
    ),
  );
}

void main() {
  // manageSubscriptionsUrl 依赖 Platform（Linux CI 恒为 null），固定为商店链接使
  // 「管理订阅」按钮的断言不随宿主平台漂移。
  setUp(() {
    debugManageSubscriptionsUrlOverride = () =>
        'https://apps.apple.com/account/subscriptions';
  });
  tearDown(() => debugManageSubscriptionsUrlOverride = null);

  testWidgets('平台未启用订阅：渲染占位页，不展示套餐与购买 CTA', (tester) async {
    await tester.pumpWidget(
      _harness(state: const EntitlementState.free(), available: false),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Subscriptions are not yet available on this platform'),
      findsOneWidget,
    );
    expect(find.text('Monthly'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Restore Purchases'), findsNothing);
  });

  testWidgets('网页支付渠道：展示网页结账 CTA，不展示商店套餐卡与恢复购买', (tester) async {
    await tester.pumpWidget(
      _harness(state: const EntitlementState.free(), webCheckout: true),
    );
    await tester.pumpAndSettle();

    // 权益列表仍展示
    expect(find.text('More AI subtitle transcription'), findsOneWidget);
    expect(find.text('Special offer:'), findsNothing);
    // 网页结账 CTA + 说明，不出现商店套餐卡
    expect(
      find.widgetWithText(FilledButton, 'Continue to checkout'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Plans, current prices, and offers are shown on the secure checkout page.',
      ),
      findsOneWidget,
    );
    expect(find.text('Monthly'), findsNothing);
    expect(find.text('Yearly'), findsNothing);
    // appbar action 为「刷新」，非商店「恢复购买」
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Restore Purchases'), findsNothing);
  });

  testWidgets('free 用户：展示权益、套餐卡片、试用 CTA 与恢复购买', (tester) async {
    await tester.pumpWidget(_harness(state: const EntitlementState.free()));
    await tester.pumpAndSettle();

    // 权益列表
    expect(find.text('Get more AI-powered learning'), findsOneWidget);
    expect(find.text('More AI subtitle transcription'), findsOneWidget);
    expect(find.text('More AI translation'), findsOneWidget);
    expect(find.text('More AI word explanation'), findsOneWidget);
    expect(find.text('More AI sentence breakdown'), findsOneWidget);
    expect(find.text('More AI sentence chunking'), findsOneWidget);
    expect(find.text('Special offer:'), findsNothing);
    expect(find.byKey(const ValueKey('paywall_header_logo')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('More AI subtitle transcription')).dy <
          tester.getTopLeft(find.text('More AI translation')).dy,
      isTrue,
    );
    expect(
      tester.getTopLeft(find.text('More AI translation')).dy <
          tester.getTopLeft(find.text('More AI word explanation')).dy,
      isTrue,
    );
    expect(
      tester.getTopLeft(find.text('More AI word explanation')).dy <
          tester.getTopLeft(find.text('More AI sentence breakdown')).dy,
      isTrue,
    );
    expect(
      tester.getTopLeft(find.text('More AI sentence breakdown')).dy <
          tester.getTopLeft(find.text('More AI sentence chunking')).dy,
      isTrue,
    );
    // 套餐卡片用派生简洁名（非冗长商店标题）
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text(r'$39.99'), findsOneWidget);
    // 价格周期后缀
    expect(find.text('/mo'), findsOneWidget);
    expect(find.text('/yr'), findsOneWidget);
    // 年付折算：每月折合价 + 推荐徽标含立省百分比（$4.99 vs $39.99 → 33%、$3.33/mo）
    expect(find.text(r'≈ $3.33/mo'), findsOneWidget);
    expect(find.text('Save 33%'), findsOneWidget);
    final saveBadge = tester.widget<Text>(find.text('Save 33%'));
    expect(saveBadge.style?.color, const Color(0xFF111111));
    // 默认选中年付（带试用）→ CTA 为试用文案
    expect(
      find.widgetWithText(FilledButton, 'Start 7-day free trial'),
      findsOneWidget,
    );
    // 恢复购买入口（合规必需）
    expect(find.text('Restore Purchases'), findsOneWidget);
    // 购买相关信息固定在底部，避免权益列表变长时 CTA 被挤出首屏。
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(
      find.text('Auto-renews. Manage or cancel in your App Store account.'),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('Terms'),
        matching: find.byKey(const ValueKey('paywall_fixed_purchase_panel')),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('Yearly'), matching: find.byType(ListView)),
      findsNothing,
    );
  });

  testWidgets('选中月付套餐后 CTA 变为订阅', (tester) async {
    await tester.pumpWidget(_harness(state: const EntitlementState.free()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Subscribe'), findsOneWidget);
  });

  testWidgets('已是会员（终身/无到期）：展示会员态、永久状态与管理订阅，不展示套餐卡', (tester) async {
    await tester.pumpWidget(
      _harness(
        state: const EntitlementState(
          status: EntitlementStatus.premium,
          entitlement: Entitlement(isPremium: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're a member"), findsOneWidget);
    expect(find.text('Manage Subscription'), findsOneWidget);
    // 无到期时间 → 永久状态 + 永久说明；套餐无法判定 → 兜底「会员」徽章
    expect(find.text('Lifetime'), findsOneWidget);
    expect(find.text('Lifetime access, no renewal needed'), findsOneWidget);
    expect(find.text('Membership'), findsOneWidget);
    // 购买套餐卡不应出现
    expect(find.widgetWithText(FilledButton, 'Subscribe'), findsNothing);
    expect(find.text('Terms'), findsNothing);
    expect(find.text('Privacy'), findsNothing);
    // 恢复购买已移到 AppBar，两态均可用（已订阅用户偶尔也需恢复）
    expect(find.text('Restore Purchases'), findsOneWidget);
  });

  testWidgets('年付首期促销：展示首年价、续费价与相对月付折扣', (tester) async {
    const promoPlans = [
      SubscriptionPlan(
        planId: 'monthly',
        title: 'Monthly',
        priceString: r'$8.99',
        period: SubscriptionPeriod.monthly,
      ),
      SubscriptionPlan(
        planId: 'yearly',
        title: 'Yearly',
        priceString: r'$59.99',
        period: SubscriptionPeriod.yearly,
        introOffer: SubscriptionIntroOffer(
          priceString: r'US$30.00',
          period: SubscriptionOfferPeriod.year,
          periodNumberOfUnits: 1,
          cycles: 1,
          isFreeTrial: false,
          renewalPriceString: r'US$59.99',
        ),
      ),
    ];
    await tester.pumpWidget(
      _harness(state: const EntitlementState.free(), plans: promoPlans),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'First year US$30.00, then US$59.99/yr'), findsOneWidget);
    final offerSubtitle = tester.widget<Text>(
      find.text(r'First year US$30.00, then US$59.99/yr'),
    );
    expect(offerSubtitle.maxLines, 1);
    expect(find.text('Special offer: 50% off your first year'), findsOneWidget);
    final offerHeadline = tester.widget<Text>(
      find.text('Special offer: 50% off your first year'),
    );
    expect(offerHeadline.style?.color, const Color(0xFF111111));
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('paywall_special_offer')),
        matching: find.byKey(const ValueKey('paywall_benefit_card')),
      ),
      findsNothing,
    );
    expect(
      tester
              .getTopLeft(find.byKey(const ValueKey('paywall_special_offer')))
              .dy <
          tester
              .getTopLeft(find.byKey(const ValueKey('paywall_benefit_card')))
              .dy,
      isTrue,
    );
    expect(find.text(r'US$30.00'), findsOneWidget);
    expect(find.text('/first yr'), findsOneWidget);
    expect(find.text('Save 72%'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Subscribe'), findsOneWidget);
  });

  testWidgets('非 50% 首期促销：顶部优惠条动态显示真实折扣', (tester) async {
    const promoPlans = [
      SubscriptionPlan(
        planId: 'monthly',
        title: 'Monthly',
        priceString: r'$12.00',
        period: SubscriptionPeriod.monthly,
        introOffer: SubscriptionIntroOffer(
          priceString: r'$3.00',
          period: SubscriptionOfferPeriod.month,
          periodNumberOfUnits: 1,
          cycles: 1,
          isFreeTrial: false,
          renewalPriceString: r'$12.00',
        ),
      ),
    ];
    await tester.pumpWidget(
      _harness(state: const EntitlementState.free(), plans: promoPlans),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Special offer: 75% off your first month'),
      findsOneWidget,
    );
  });

  testWidgets('首期价不低于续费价：不显示顶部优惠条', (tester) async {
    const promoPlans = [
      SubscriptionPlan(
        planId: 'yearly',
        title: 'Yearly',
        priceString: r'$98.00',
        period: SubscriptionPeriod.yearly,
        introOffer: SubscriptionIntroOffer(
          priceString: r'$98.00',
          period: SubscriptionOfferPeriod.year,
          periodNumberOfUnits: 1,
          cycles: 1,
          isFreeTrial: false,
          renewalPriceString: r'$98.00',
        ),
      ),
    ];
    await tester.pumpWidget(
      _harness(state: const EntitlementState.free(), plans: promoPlans),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Special offer:'), findsNothing);
  });

  testWidgets('小屏购买区保持紧凑，CTA 可见且法律链接弱化显示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(state: const EntitlementState.free()));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('paywall_fixed_purchase_panel'));
    expect(tester.getSize(panel).height, lessThan(360));
    expect(
      find.widgetWithText(FilledButton, 'Start 7-day free trial').hitTestable(),
      findsOneWidget,
    );

    final terms = tester.widget<Text>(find.text('Terms'));
    final privacy = tester.widget<Text>(find.text('Privacy'));
    expect(terms.style?.color, isNot(ThemeData().colorScheme.primary));
    expect(privacy.style?.color, terms.style?.color);
    final panelTop = tester.getTopLeft(panel).dy;
    final monthlyTop = tester.getTopLeft(find.text('Monthly')).dy;
    final yearlyTop = tester.getTopLeft(find.text('Yearly')).dy;
    final monthlyHeight = tester.getSize(find.text('Monthly')).height;
    final termsRight = tester.getTopRight(find.text('Terms')).dx;
    final privacyLeft = tester.getTopLeft(find.text('Privacy')).dx;
    expect(monthlyTop - panelTop, lessThan(32));
    expect(yearlyTop - (monthlyTop + monthlyHeight), greaterThanOrEqualTo(24));
    expect(privacyLeft - termsRight, greaterThanOrEqualTo(24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('会员（年付续订中）：展示年度会员套餐、有效状态与续订日期', (tester) async {
    await tester.pumpWidget(
      _harness(
        state: EntitlementState(
          status: EntitlementStatus.premium,
          entitlement: Entitlement(
            isPremium: true,
            productId: 'yearly', // 匹配 _plans 的 yearly → 年度会员
            expiresAt: DateTime.utc(2027, 1, 1),
            willRenew: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Annual membership'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('Renews on'), findsOneWidget);
  });

  testWidgets('会员（月付不再续订）：展示月度会员、即将到期状态与到期日期', (tester) async {
    await tester.pumpWidget(
      _harness(
        state: EntitlementState(
          status: EntitlementStatus.premium,
          entitlement: Entitlement(
            isPremium: true,
            productId: 'monthly', // 匹配 _plans 的 monthly → 月度会员
            expiresAt: DateTime.utc(2026, 8, 1),
            willRenew: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly membership'), findsOneWidget);
    expect(find.text('Expiring'), findsOneWidget);
    expect(find.textContaining('Expires on'), findsOneWidget);
  });

  testWidgets('未登录点订阅：弹统一登录引导、不发起购买', (tester) async {
    final spy = _SpyController(const EntitlementState.free());
    await tester.pumpWidget(
      _harness(
        state: const EntitlementState.free(),
        authenticated: false,
        controller: () => spy,
      ),
    );
    await tester.pumpAndSettle();

    // 默认选中年付（试用）→ 点主 CTA 发起购买
    await tester.tap(
      find.widgetWithText(FilledButton, 'Start 7-day free trial'),
    );
    await tester.pumpAndSettle();

    // 走通用 ensureSignedInForAction 登录引导弹窗，且未真正发起购买
    expect(find.text('Sign in to Echo Loop'), findsOneWidget);
    expect(spy.purchaseCalls, 0);
  });

  testWidgets('未登录点恢复购买：弹统一登录引导、不发起恢复', (tester) async {
    final spy = _SpyController(const EntitlementState.free());
    await tester.pumpWidget(
      _harness(
        state: const EntitlementState.free(),
        authenticated: false,
        controller: () => spy,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore Purchases'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Echo Loop'), findsOneWidget);
    expect(spy.restoreCalls, 0);
  });

  testWidgets('已登录点订阅：不弹登录、直接发起购买', (tester) async {
    final spy = _SpyController(const EntitlementState.free());
    await tester.pumpWidget(
      _harness(
        state: const EntitlementState.free(),
        authenticated: true,
        controller: () => spy,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Start 7-day free trial'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Echo Loop'), findsNothing);
    expect(spy.purchaseCalls, 1);
  });
}
