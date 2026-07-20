/// 订阅计划介绍页（Paywall）。
///
/// 标准移动订阅页：权益列表 + 平台本地化价格套餐 + 试用披露 + 自动续费披露 +
/// 恢复购买 + 条款/隐私链接 + 管理订阅。查看无需登录；购买 / 恢复前统一走
/// [ensureSignedInForAction] 要求登录（权益绑定 Supabase user_id）。
///
/// UI 只依赖 [SubscriptionPlan] DTO 与 [featureAccessProvider] 风格的状态读取，
/// 不接触 RevenueCat 类型；购买 / 恢复经 [SubscriptionController] 集中入口。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/revenuecat_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/app_logger.dart';
import '../../auth/sign_in_required_dialog.dart';
import '../../../theme/app_theme.dart';
import '../models/entitlement.dart';
import '../models/entitlement_source.dart';
import '../models/subscription_plan.dart';
import '../providers/subscription_availability.dart';
import '../providers/subscription_controller.dart';
import '../providers/subscription_plans_provider.dart';
import '../services/purchase_service.dart';
import '../services/subscription_management_launcher.dart';
import '../utils/member_status.dart';
import '../utils/plan_pricing.dart';

/// 订阅计划介绍 + 购买页。
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  /// 用户选中的套餐 id（null 时取推荐 / 第一个）。
  String? _selectedPlanId;

  /// 购买 / 恢复进行中。
  bool _busy = false;

  /// 网页支付：已打开浏览器结账、正在轮询后端等权益到账。
  bool _waitingForWeb = false;

  /// 商店包内用户主动切换到 Web 支付兜底。
  bool _useWebCheckoutFallback = false;

  final SubscriptionManagementLauncher _subscriptionManagementLauncher =
      SubscriptionManagementLauncher();

  @override
  void initState() {
    super.initState();
    // 页面首帧优先消费会话缓存，再让 SDK 在后台校验当前 offering/storefront。
    Future.microtask(() {
      if (!mounted) return;
      final webMode = ref.read(webCheckoutModeProvider);
      AppLogger.log(
        'Subscription',
        'paywall init refresh plans: webMode=$webMode',
      );
      unawaited(
        ref.read(subscriptionPlansProvider.notifier).refresh(force: true),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 防御：当前平台未启用订阅（未注入 RC key）时渲染占位页。正常入口
    // （设置页 / openPaywall）已在上游隐藏或拦截，这里兜住 deep link、
    // 调试入口等直接路由进入的路径。
    if (!ref.watch(subscriptionAvailabilityProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.premiumTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.premiumUnavailableOnPlatform,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final subState = ref.watch(subscriptionControllerProvider);
    final isPremium = subState.isActive;
    // direct 渠道复用统一套餐 UI，购买动作改为 Paddle 浏览器结账 + 回流对账。
    final webMode = ref.watch(webCheckoutModeProvider);
    final showStoreWebCheckoutFallback = ref.watch(
      showStoreWebCheckoutFallbackProvider,
    );
    final usingWebCheckout =
        webMode || (_useWebCheckoutFallback && showStoreWebCheckoutFallback);
    final usingStoreWebCheckoutFallback =
        _useWebCheckoutFallback && showStoreWebCheckoutFallback;
    final plansAsync = isPremium
        ? null
        : ref.watch(
            usingStoreWebCheckoutFallback
                ? paddleSubscriptionPlansProvider
                : subscriptionPlansProvider,
          );
    final specialOfferLabel = _specialOfferLabel(
      l10n,
      plansAsync?.valueOrNull ?? const [],
    );
    AppLogger.log(
      'Subscription',
      'paywall build: isPremium=$isPremium webMode=$webMode '
          'storeWebFallback=$_useWebCheckoutFallback '
          'showStoreWebFallback=$showStoreWebCheckoutFallback '
          'status=${subState.status} '
          'source=${subState.entitlement?.source.name ?? "none"} '
          'waitingForWeb=$_waitingForWeb busy=$_busy',
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.premiumTitle),
        // 恢复购买为低频操作（登录后通常自动对账获取权益），弱化为右上角文字 action。
        // 网页渠道没有平台恢复接口，但用户语义仍是「找回已购买权益」；
        // 底层转为后端权益同步。
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : (webMode ? _refreshEntitlement : _restore),
            child: Text(l10n.premiumRestore),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: isPremium
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: _buildMemberBody(l10n),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  20,
                                ),
                                children: [
                                  _Header(l10n: l10n),
                                  const SizedBox(height: 16),
                                  if (specialOfferLabel != null) ...[
                                    _SpecialOfferStrip(
                                      label: specialOfferLabel,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  _BenefitCard(l10n: l10n),
                                ],
                              ),
                            ),
                            _FixedPurchasePanel(
                              maxHeight: constraints.maxHeight * 0.52,
                              child: _buildPurchaseArea(
                                l10n,
                                webMode: usingWebCheckout,
                                showStoreWebCheckoutFallback:
                                    showStoreWebCheckoutFallback,
                                usingStoreWebCheckoutFallback:
                                    usingStoreWebCheckoutFallback,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  String? _specialOfferLabel(
    AppLocalizations l10n,
    List<SubscriptionPlan> plans,
  ) {
    final plan = _specialOfferPlan(plans);
    if (plan == null) return null;
    final offer = plan.introOffer;
    if (offer == null) return null;

    final percent = computeIntroOfferDiscountPercent(plan);
    final offerPeriodName = _offerPeriodName(l10n, plan);
    if (percent != null && percent > 0 && offerPeriodName.isNotEmpty) {
      return l10n.premiumSpecialOfferPercent(percent, offerPeriodName);
    }
    return l10n.premiumSpecialOfferIntro(
      _introLabelForOffer(l10n, plan, offer),
      _renewalLabelForPlan(l10n, plan, offer),
    );
  }

  SubscriptionPlan? _specialOfferPlan(List<SubscriptionPlan> plans) {
    final yearly = plans.where(
      (plan) => plan.period == SubscriptionPeriod.yearly,
    );
    final yearlyOffer = yearly.where(_hasDisplayablePaidIntroOffer).firstOrNull;
    if (yearlyOffer != null) return yearlyOffer;

    final monthly = plans.where(
      (plan) => plan.period == SubscriptionPeriod.monthly,
    );
    return monthly.where(_hasDisplayablePaidIntroOffer).firstOrNull;
  }

  bool _hasDisplayablePaidIntroOffer(SubscriptionPlan plan) {
    if (!_hasPaidIntroOffer(plan)) return false;
    return isIntroOfferDiscounted(plan) != false;
  }

  bool _hasPaidIntroOffer(SubscriptionPlan plan) {
    final offer = plan.introOffer;
    return offer != null && !offer.isFreeTrial;
  }

  /// 会员态页面主体：金色 hero + 到期信息卡 + 权益卡 + 管理订阅按钮。
  List<Widget> _buildMemberBody(AppLocalizations l10n) {
    final webMode = ref.watch(webCheckoutModeProvider);
    final entitlement =
        ref.watch(subscriptionControllerProvider).entitlement ??
        const Entitlement(isPremium: true);
    final plans = ref.watch(subscriptionPlansProvider).valueOrNull ?? const [];
    final summary = summarizeMembership(
      entitlement,
      now: DateTime.now(),
      plans: plans,
    );
    // 「管理订阅」按钮的显示与行为按订阅**实际来源**决定，与当前运行平台解耦：
    // - Paddle 来源（或来源未知且当前为 web 渠道）→ 打开 Paddle Customer Portal；
    // - Apple / Google 来源 → 交给 launcher 按来源打开对应平台管理页；
    // - 来源未知且非 web → 回退旧逻辑（有平台管理 URL 才展示，launcher 按当前渠道）。
    final source = entitlement.source;
    final isPaddle = source == EntitlementSource.paddle;
    final isKnownStore =
        source == EntitlementSource.apple || source == EntitlementSource.google;
    final usePortal =
        isPaddle || (source == EntitlementSource.unknown && webMode);
    final showManage =
        isPaddle ||
        isKnownStore ||
        (source == EntitlementSource.unknown &&
            (webMode || manageSubscriptionsUrl != null));
    return [
      _MemberHeroCard(l10n: l10n, summary: summary),
      const SizedBox(height: 16),
      _MembershipInfoTile(l10n: l10n, summary: summary),
      const SizedBox(height: 20),
      _BenefitCard(l10n: l10n),
      if (showManage) ...[
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.premiumAccent(
                Theme.of(context).brightness,
              ),
              foregroundColor: AppTheme.onPremiumAccent(
                Theme.of(context).brightness,
              ),
            ),
            onPressed: usePortal ? _openPaddlePortal : _openManageSubscription,
            child: Text(l10n.premiumManage),
          ),
        ),
      ],
    ];
  }

  Widget _buildPurchaseArea(
    AppLocalizations l10n, {
    required bool webMode,
    required bool showStoreWebCheckoutFallback,
    required bool usingStoreWebCheckoutFallback,
  }) {
    final plansAsync = ref.watch(
      usingStoreWebCheckoutFallback
          ? paddleSubscriptionPlansProvider
          : subscriptionPlansProvider,
    );
    return plansAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) {
        AppLogger.log('Subscription', 'paywall 套餐区错误态: error=$error');
        return _NoPlans(
          l10n: l10n,
          onRetry: () {
            AppLogger.log('Subscription', 'paywall 套餐重试点击');
            ref.invalidate(subscriptionPlansProvider);
          },
        );
      },
      data: (plans) {
        if (plans.isEmpty) {
          AppLogger.log('Subscription', 'paywall 套餐为空，展示重试');
          return _NoPlans(
            l10n: l10n,
            onRetry: () {
              AppLogger.log('Subscription', 'paywall 空套餐重试点击');
              ref.invalidate(subscriptionPlansProvider);
            },
          );
        }
        final selectedId = _effectiveSelection(plans);
        final selected = plans.firstWhere((p) => p.planId == selectedId);
        final yearlyValue = _yearlyValueOf(plans);
        final brightness = Theme.of(context).brightness;
        final accent = AppTheme.premiumAccent(brightness);
        final onAccent = AppTheme.onPremiumAccent(brightness);
        return Column(
          children: [
            for (var index = 0; index < plans.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _PlanCard(
                plan: plans[index],
                l10n: l10n,
                selected: plans[index].planId == selectedId,
                yearlyValue: plans[index].period == SubscriptionPeriod.yearly
                    ? yearlyValue
                    : null,
                onTap: () =>
                    setState(() => _selectedPlanId = plans[index].planId),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: onAccent,
                  disabledBackgroundColor: _waitingForWeb ? accent : null,
                  disabledForegroundColor: _waitingForWeb ? onAccent : null,
                ),
                onPressed: _busy || _waitingForWeb
                    ? null
                    : () => webMode
                          ? _startPaddleCheckout(
                              selected,
                              storeFallback: usingStoreWebCheckoutFallback,
                            )
                          : _purchase(selected),
                child: _ctaChild(l10n, selected),
              ),
            ),
            if (showStoreWebCheckoutFallback) ...[
              const SizedBox(height: 6),
              _StoreWebCheckoutSwitch(
                usingWebCheckout: usingStoreWebCheckoutFallback,
                onPressed: _busy || _waitingForWeb
                    ? null
                    : () {
                        setState(
                          () => _useWebCheckoutFallback =
                              !usingStoreWebCheckoutFallback,
                        );
                        AppLogger.log(
                          'Subscription',
                          '商店包 Web 支付切换: enabled=${!usingStoreWebCheckoutFallback}',
                        );
                      },
                l10n: l10n,
              ),
              const SizedBox(height: 2),
            ] else
              const SizedBox(height: 2),
            _LegalFooter(l10n: l10n),
          ],
        );
      },
    );
  }

  /// 发起 Paddle 结账：登录 → 服务端创建 transaction → 系统浏览器打开 →
  /// 等待 webhook 后刷新统一权益。打开 URL 本身永远不视为购买成功。
  Future<void> _startPaddleCheckout(
    SubscriptionPlan plan, {
    required bool storeFallback,
  }) async {
    final checkoutPlanId = _paddleCheckoutPlanId(plan, storeFallback);
    AppLogger.log(
      'Subscription',
      'Paddle checkout 点击: planId=$checkoutPlanId '
          'displayPlanId=${plan.planId} storeFallback=$storeFallback',
    );
    if (!await _ensureSignedIn() || !mounted) {
      AppLogger.log(
        'Subscription',
        'Paddle checkout 点击中止: planId=$checkoutPlanId reason=notSignedIn',
      );
      return;
    }
    setState(() => _busy = true);
    bool opened;
    Uri? uri;
    try {
      uri = await ref
          .read(subscriptionControllerProvider.notifier)
          .startPaddleCheckout(
            checkoutPlanId,
            allowStoreFallback: storeFallback,
          );
      AppLogger.log(
        'Subscription',
        'Paddle checkout URL 已获取: planId=$checkoutPlanId '
            'host=${uri.host} path=${uri.path}',
      );
      opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      AppLogger.log('Subscription', 'Paddle checkout 异常: $e');
      opened = false;
    }
    AppLogger.log(
      'Subscription',
      'Paddle checkout open result: opened=$opened '
          'host=${uri?.host ?? "null"} path=${uri?.path ?? "null"}',
    );
    if (!mounted) return;
    if (!opened) {
      _showMessage(AppLocalizations.of(context)!.premiumWebOpenFailed);
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _waitingForWeb = true;
    });
    unawaited(_pollEntitlement());
  }

  /// 商店包展示的套餐来自 RevenueCat，Paddle 后端只接受 direct 套餐 id。
  /// Web 兜底按周期映射到现有 Paddle plan，避免把商店商品 id 发给 Paddle。
  String _paddleCheckoutPlanId(SubscriptionPlan plan, bool storeFallback) {
    if (!storeFallback) return plan.planId;
    return switch (plan.period) {
      SubscriptionPeriod.monthly => 'plus_monthly',
      SubscriptionPeriod.yearly => 'plus_yearly',
      SubscriptionPeriod.lifetime => plan.planId,
    };
  }

  /// 轮询后端权益对账，直到到账（自动关闭）或超时（~2 分钟）。
  ///
  /// 权益真相在后端（RC webhook 落库），浏览器结账成功回跳不作数——必须回源确认。
  /// 用户从浏览器返回 App 时 resume 也会触发 refresh（main.dart），双保险。
  Future<void> _pollEntitlement() async {
    const interval = Duration(seconds: 5);
    const maxAttempts = 24; // ~2 分钟
    AppLogger.log(
      'Subscription',
      'Paddle checkout 权益轮询开始: maxAttempts=$maxAttempts',
    );
    for (var i = 0; i < maxAttempts; i++) {
      if (!mounted || !_waitingForWeb) {
        AppLogger.log(
          'Subscription',
          'Paddle checkout 权益轮询停止: attempt=${i + 1} '
              'mounted=$mounted waiting=$_waitingForWeb',
        );
        return;
      }
      try {
        await ref.read(subscriptionControllerProvider.notifier).refresh();
      } catch (error) {
        AppLogger.log(
          'Subscription',
          'Paddle checkout 权益轮询刷新异常: attempt=${i + 1} error=$error',
        );
      }
      if (!mounted) return;
      final state = ref.read(subscriptionControllerProvider);
      AppLogger.log(
        'Subscription',
        'Paddle checkout 权益轮询结果: attempt=${i + 1} '
            'status=${state.status.name} isActive=${state.isActive} '
            'isStale=${state.isStale} error=${state.error ?? "none"}',
      );
      if (state.isActive) {
        setState(() => _waitingForWeb = false);
        if (mounted) context.pop();
        return;
      }
      await Future<void>.delayed(interval);
    }
    AppLogger.log('Subscription', 'Paddle checkout 权益轮询超时');
    if (mounted) setState(() => _waitingForWeb = false);
  }

  /// Web 渠道恢复购买：直接触发后端对账并提示当前账号的权益状态。
  Future<void> _refreshEntitlement() async {
    AppLogger.log('Subscription', 'Web/direct 恢复购买点击：刷新后端权益');
    setState(() => _busy = true);
    try {
      await ref.read(subscriptionControllerProvider.notifier).refresh();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final state = ref.read(subscriptionControllerProvider);
      final active = state.isActive;
      AppLogger.log(
        'Subscription',
        'Web/direct 恢复购买结果: status=${state.status.name} '
            'isActive=$active isStale=${state.isStale} '
            'error=${state.error ?? "none"}',
      );
      _showMessage(active ? l10n.premiumRestored : l10n.premiumRestoreNone);
    } catch (error) {
      AppLogger.log('Subscription', 'Web/direct 恢复购买异常: $error');
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 解析当前生效选择：用户选中 > 推荐年付 > 第一个。
  String _effectiveSelection(List<SubscriptionPlan> plans) {
    final chosen = _selectedPlanId;
    if (chosen != null && plans.any((p) => p.planId == chosen)) return chosen;
    final yearly = plans.where((p) => p.period == SubscriptionPeriod.yearly);
    return yearly.isNotEmpty ? yearly.first.planId : plans.first.planId;
  }

  /// 计算年付折算（每月折合价 + 节省百分比），需同时存在月付与年付套餐，
  /// 否则返回空（UI 不展示折算）。
  YearlyValue? _yearlyValueOf(List<SubscriptionPlan> plans) {
    final monthly = plans
        .where((p) => p.period == SubscriptionPeriod.monthly)
        .firstOrNull;
    final yearly = plans
        .where((p) => p.period == SubscriptionPeriod.yearly)
        .firstOrNull;
    if (monthly == null || yearly == null) return null;
    return computeYearlyValue(monthly, yearly);
  }

  String _ctaLabel(AppLocalizations l10n, SubscriptionPlan plan) {
    if (plan.hasFreeTrial && plan.trialDays > 0) {
      return l10n.premiumStartTrial(plan.trialDays);
    }
    return l10n.premiumSubscribe;
  }

  Widget _ctaChild(AppLocalizations l10n, SubscriptionPlan plan) {
    if (!_waitingForWeb) {
      return Text(_ctaLabel(l10n, plan));
    }
    final onAccent = AppTheme.onPremiumAccent(Theme.of(context).brightness);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: onAccent),
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(l10n.premiumWebVerifying)),
      ],
    );
  }

  /// 购买 / 恢复前的统一登录门：权益需绑定 Supabase user_id（跨设备 / 可恢复），
  /// 复用全 App 通用的 [ensureSignedInForAction]（弹登录引导 → 跳登录页），
  /// 未登录返回 false，调用方据此中止本次动作。
  Future<bool> _ensureSignedIn() async {
    final l10n = AppLocalizations.of(context)!;
    final signedIn = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.authSignInTitle,
      message: l10n.premiumLoginRequired,
    );
    AppLogger.log('Subscription', '订阅动作登录门结果: signedIn=$signedIn');
    return signedIn;
  }

  Future<void> _purchase(SubscriptionPlan plan) async {
    // 购买前强制登录：权益需绑定 Supabase user_id（跨设备 / 可恢复）。
    if (!await _ensureSignedIn() || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(subscriptionControllerProvider.notifier)
          .purchase(plan.planId);
      if (mounted && ref.read(subscriptionControllerProvider).isActive) {
        context.pop();
      }
    } on PurchaseException catch (e) {
      if (!e.cancelled && mounted) {
        _showMessage(AppLocalizations.of(context)!.premiumPurchaseFailed);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(AppLocalizations.of(context)!.premiumPurchaseFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    // 恢复购买同样先登录：否则会对 RevenueCat 匿名身份恢复，权益绑不到 user_id。
    if (!await _ensureSignedIn() || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(subscriptionControllerProvider.notifier).restore();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final active = ref.read(subscriptionControllerProvider).isActive;
      _showMessage(active ? l10n.premiumRestored : l10n.premiumRestoreNone);
    } on PurchaseException catch (e) {
      if (mounted) {
        _showMessage(
          e.ownershipConflict
              ? AppLocalizations.of(context)!.premiumRestoreAccountMismatch
              : AppLocalizations.of(context)!.premiumPurchaseFailed,
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(AppLocalizations.of(context)!.premiumPurchaseFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openManageSubscription() async {
    final entitlement = ref.read(subscriptionControllerProvider).entitlement;
    // 按订阅**实际来源**打开管理页（Apple 订阅在 Android 上也能打开苹果网页管理页）。
    // 来源未知（老缓存 / 后端未返回）时 launcher 内部回退到按当前平台渠道。
    final opened = await _subscriptionManagementLauncher.open(
      source: entitlement?.source ?? EntitlementSource.unknown,
      productId: entitlement?.productId,
    );
    if (!opened && mounted) {
      _showMessage(AppLocalizations.of(context)!.premiumWebOpenFailed);
    }
  }

  Future<void> _openPaddlePortal() async {
    AppLogger.log('Subscription', 'Paddle Portal 点击');
    if (!await _ensureSignedIn() || !mounted) {
      AppLogger.log('Subscription', 'Paddle Portal 点击中止: reason=notSignedIn');
      return;
    }
    setState(() => _busy = true);
    try {
      final uri = await ref
          .read(subscriptionControllerProvider.notifier)
          .createPaddlePortal();
      AppLogger.log(
        'Subscription',
        'Paddle Portal URL 已获取: host=${uri.host} path=${uri.path}',
      );
      final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      AppLogger.log(
        'Subscription',
        'Paddle Portal open result: opened=$opened host=${uri.host}',
      );
      if (!opened && mounted) {
        _showMessage(AppLocalizations.of(context)!.premiumWebOpenFailed);
      }
    } catch (e) {
      AppLogger.log('Subscription', 'Paddle Portal 打开失败: $e');
      if (mounted) {
        _showMessage(AppLocalizations.of(context)!.premiumWebOpenFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 顶部使用 Echo Loop 品牌 logo，较皇冠图标更贴近应用识别。
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.18 : 0.06,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/icon/app-icon-1024-alpha.png',
              key: const ValueKey('paywall_header_logo'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.premiumTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.premiumTagline,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// 权益列表卡片：浅蓝染底圆角容器包裹勾选项，提升「权益打包感」。
class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final benefits = [
      l10n.premiumBenefitTranscription,
      l10n.premiumBenefitTranslation,
      l10n.premiumBenefitWordAnalysis,
      l10n.premiumBenefitAnalysis,
      l10n.premiumBenefitSenseGroups,
    ];
    final theme = Theme.of(context);
    final color = AppTheme.premiumAccent(theme.brightness);
    return Container(
      key: const ValueKey('paywall_benefit_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.premiumSelectedFill(theme.brightness),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final benefit in benefits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(benefit, style: theme.textTheme.bodyLarge),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SpecialOfferStrip extends StatelessWidget {
  const _SpecialOfferStrip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.dark
        ? const Color(0xFFD8B11E)
        : const Color(0xFFFCE76B);
    final textColor = const Color(0xFF111111);
    return Container(
      key: const ValueKey('paywall_special_offer'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 固定购买区按内容取实际高度，小屏超过上限时仅在面板内部滚动。
class _FixedPurchasePanel extends StatelessWidget {
  const _FixedPurchasePanel({required this.child, required this.maxHeight});
  final Widget child;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      key: const ValueKey('paywall_fixed_purchase_panel'),
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.40 : 0.32,
            ),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.10 : 0.03,
            ),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: child,
        ),
      ),
    );
  }
}

class _StoreWebCheckoutSwitch extends StatelessWidget {
  const _StoreWebCheckoutSwitch({
    required this.usingWebCheckout,
    required this.onPressed,
    required this.l10n,
  });

  final bool usingWebCheckout;
  final VoidCallback? onPressed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (usingWebCheckout) {
      return TextButton(
        style: _subtleTextButtonStyle(),
        onPressed: onPressed,
        child: Text(
          l10n.premiumUseStoreCheckout,
          style: _subtleTextStyle(theme),
        ),
      );
    }
    return TextButton(
      style: _subtleTextButtonStyle(),
      onPressed: onPressed,
      child: Text(
        l10n.premiumUseWebCheckoutFallback,
        style: _subtleTextStyle(theme),
      ),
    );
  }

  ButtonStyle _subtleTextButtonStyle() {
    return TextButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  TextStyle? _subtleTextStyle(ThemeData theme) {
    return theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.76),
      fontWeight: FontWeight.w400,
    );
  }
}

String _offerPeriodName(AppLocalizations l10n, SubscriptionPlan plan) {
  return switch (plan.period) {
    SubscriptionPeriod.yearly => l10n.premiumOfferPeriodYear,
    SubscriptionPeriod.monthly => l10n.premiumOfferPeriodMonth,
    _ => '',
  };
}

String _introLabelForOffer(
  AppLocalizations l10n,
  SubscriptionPlan plan,
  SubscriptionIntroOffer offer,
) {
  return switch (plan.period) {
    SubscriptionPeriod.yearly => l10n.premiumIntroFirstYear(offer.priceString),
    SubscriptionPeriod.monthly => l10n.premiumIntroFirstMonth(
      offer.priceString,
    ),
    _ => offer.priceString,
  };
}

String _renewalLabelForPlan(
  AppLocalizations l10n,
  SubscriptionPlan plan,
  SubscriptionIntroOffer offer,
) {
  return switch (plan.period) {
    SubscriptionPeriod.yearly => l10n.premiumRenewalPricePerYear(
      offer.renewalPriceString,
    ),
    SubscriptionPeriod.monthly => l10n.premiumRenewalPricePerMonth(
      offer.renewalPriceString,
    ),
    SubscriptionPeriod.lifetime => l10n.premiumRenewalPricePerPeriod(
      offer.renewalPriceString,
    ),
  };
}

/// 单个套餐选择卡片。
///
/// 标准订阅卡布局：左侧单选 + 套餐名（由 [SubscriptionPlan.period] 派生的简洁名，
/// **不用冗长的商店标题**），右侧价格 + 周期后缀。年付卡通过 [yearlyValue] 展示
/// 「每月折合价」与浮于卡片顶边的「超值推荐 · 立省 X%」徽标（脱离布局流，不遮挡）。
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.l10n,
    required this.selected,
    required this.onTap,
    this.yearlyValue,
  });

  final SubscriptionPlan plan;
  final AppLocalizations l10n;
  final bool selected;
  final VoidCallback onTap;

  /// 年付折算结果，仅年付卡传入；为 null 时不展示折算/推荐徽标。
  final YearlyValue? yearlyValue;

  /// 套餐周期的简洁名称（月度 / 年度 / 终身）。
  String _planName() => switch (plan.period) {
    SubscriptionPeriod.monthly => l10n.premiumPeriodMonthly,
    SubscriptionPeriod.yearly => l10n.premiumPeriodYearly,
    SubscriptionPeriod.lifetime => l10n.premiumPeriodLifetime,
  };

  /// 价格后缀（/月、/年、一次性）。
  String _priceSuffix() => switch (plan.period) {
    SubscriptionPeriod.monthly => l10n.premiumPriceSuffixMonth,
    SubscriptionPeriod.yearly => l10n.premiumPriceSuffixYear,
    SubscriptionPeriod.lifetime => l10n.premiumPriceSuffixLifetime,
  };

  /// 卡片右侧主价格：付费 intro offer 展示用户优惠价；免费试用仍展示续费价。
  String _displayPrice() {
    final offer = plan.introOffer;
    if (offer != null && !offer.isFreeTrial) return offer.priceString;
    return plan.priceString;
  }

  /// 卡片右侧价格后缀：付费 intro offer 只区分首月/首年，未知周期回退原周期。
  String _displayPriceSuffix() {
    final offer = plan.introOffer;
    if (offer != null && !offer.isFreeTrial) {
      return switch (offer.period) {
        SubscriptionOfferPeriod.year => l10n.premiumPriceSuffixFirstYear,
        SubscriptionOfferPeriod.month => l10n.premiumPriceSuffixFirstMonth,
        _ => _priceSuffix(),
      };
    }
    return _priceSuffix();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = AppTheme.premiumAccent(theme.brightness);
    final offer = plan.introOffer;
    final savePercent = yearlyValue?.savePercent;
    final perMonth = offer == null ? yearlyValue?.perMonth : null;

    // 副标题优先级：平台 intro offer > 每月折合价 > 试用提示。
    final String? subtitle = offer != null
        ? _offerSubtitle(l10n, offer)
        : (perMonth != null
              ? l10n.premiumPerMonthEquivalent(perMonth)
              : (plan.hasFreeTrial && plan.trialDays > 0
                    ? l10n.premiumStartTrial(plan.trialDays)
                    : null));
    AppLogger.log(
      'Subscription',
      'plan card display: id=${plan.planId} period=${plan.period} '
          'rawPrice=${plan.priceString} displayPrice=${_displayPrice()} '
          'suffix=${_displayPriceSuffix()} subtitle=${subtitle ?? "null"} '
          'savePercent=${savePercent ?? "null"} perMonth=${perMonth ?? "null"} '
          'introOffer=${_introLog(offer)}',
    );

    return Semantics(
      button: true,
      selected: selected,
      label: _planName(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.premiumSelectedFill(theme.brightness)
              : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? accent : cs.outline,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _planName(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (savePercent != null && savePercent > 0) ...[
                              const SizedBox(width: 8),
                              _RecommendedBadge(
                                label: l10n.premiumSavePercent(savePercent),
                              ),
                            ],
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              softWrap: false,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _displayPrice(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _displayPriceSuffix(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _offerSubtitle(AppLocalizations l10n, SubscriptionIntroOffer offer) {
    final renewal = _renewalLabelForPlan(l10n, plan, offer);
    if (offer.isFreeTrial && plan.trialDays > 0) {
      return l10n.premiumTryFreeThen(plan.trialDays, renewal);
    }
    return l10n.premiumOfferThen(
      _introLabelForOffer(l10n, plan, offer),
      renewal,
    );
  }

  String _introLog(SubscriptionIntroOffer? offer) {
    if (offer == null) return 'null';
    return '{price=${offer.priceString}, period=${offer.period}, '
        'units=${offer.periodNumberOfUnits}, cycles=${offer.cycles}, '
        'free=${offer.isFreeTrial}, renewal=${offer.renewalPriceString}}';
  }
}

/// 「超值推荐」浮动徽标：主色填充胶囊，浮于推荐卡顶边。
class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.dark
        ? const Color(0xFFD8B11E)
        : const Color(0xFFFCE76B);
    final textColor = const Color(0xFF111111);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 会员态英雄卡：金色渐变圆角卡，含皇冠、标题、tagline、套餐徽章、状态胶囊。
class _MemberHeroCard extends StatelessWidget {
  const _MemberHeroCard({required this.l10n, required this.summary});
  final AppLocalizations l10n;
  final MemberSummary summary;

  /// 套餐展示名（由周期派生，无法判定时用兜底「会员」）。
  String _planLabel() => switch (summary.period) {
    SubscriptionPeriod.monthly => l10n.premiumPlanMonthly,
    SubscriptionPeriod.yearly => l10n.premiumPlanYearly,
    SubscriptionPeriod.lifetime => l10n.premiumPlanLifetime,
    null => l10n.premiumPlanGeneric,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = AppTheme.premiumHeroGradient(theme.brightness);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium, size: 52, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            l10n.premiumTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.premiumActive,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              _HeroChip(label: _planLabel(), filled: true),
              _StatusChip(l10n: l10n, status: summary.status),
            ],
          ),
        ],
      ),
    );
  }
}

/// hero 卡内的套餐胶囊（半透明白底，白字）。
class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, this.filled = false});
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: filled ? 0.22 : 0.0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 状态胶囊：有效（绿点）/ 即将到期（琥珀点）/ 永久（金点），实心色底白字。
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.l10n, required this.status});
  final AppLocalizations l10n;
  final MemberStatusKind status;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final (String label, Color color) = switch (status) {
      MemberStatusKind.active => (
        l10n.premiumStatusActive,
        AppTheme.premiumStatusActiveColor(brightness),
      ),
      MemberStatusKind.expiring => (
        l10n.premiumStatusExpiring,
        AppTheme.premiumStatusExpiringColor(brightness),
      ),
      MemberStatusKind.lifetime => (
        l10n.premiumStatusLifetime,
        AppTheme.premiumGold(brightness),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 到期信息行卡片：续订日 / 到期日 / 永久说明。
class _MembershipInfoTile extends StatelessWidget {
  const _MembershipInfoTile({required this.l10n, required this.summary});
  final AppLocalizations l10n;
  final MemberSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final date = summary.expiresAtLocal;
    final dateStr = date == null
        ? null
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(date);

    final (
      IconData icon,
      String text,
      Color iconColor,
    ) = switch (summary.status) {
      MemberStatusKind.active => (
        Icons.autorenew,
        l10n.premiumRenewsOn(dateStr ?? ''),
        AppTheme.premiumStatusActiveColor(theme.brightness),
      ),
      MemberStatusKind.expiring => (
        Icons.schedule,
        l10n.premiumExpiresOn(dateStr ?? ''),
        AppTheme.premiumStatusExpiringColor(theme.brightness),
      ),
      MemberStatusKind.lifetime => (
        Icons.all_inclusive,
        l10n.premiumLifetimeAccessNote,
        AppTheme.premiumGold(theme.brightness),
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.premiumCurrentPlan,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPlans extends StatelessWidget {
  const _NoPlans({required this.l10n, required this.onRetry});
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          l10n.premiumNoPlans,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
      ],
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.56 : 0.62,
      ),
    );
    final buttonStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      children: [
        TextButton(
          style: buttonStyle,
          onPressed: () =>
              launchUrl(Uri.parse('https://www.echo-loop.top/terms')),
          child: Text(l10n.premiumTermsShort, style: style),
        ),
        TextButton(
          style: buttonStyle,
          onPressed: () =>
              launchUrl(Uri.parse('https://www.echo-loop.top/privacy')),
          child: Text(l10n.premiumPrivacyShort, style: style),
        ),
      ],
    );
  }
}
