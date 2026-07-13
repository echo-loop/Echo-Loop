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
import '../../../config/web_purchase_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/app_logger.dart';
import '../../auth/sign_in_required_dialog.dart';
import '../../../theme/app_theme.dart';
import '../models/entitlement.dart';
import '../models/subscription_plan.dart';
import '../providers/subscription_availability.dart';
import '../providers/subscription_controller.dart';
import '../providers/subscription_identity.dart';
import '../providers/subscription_plans_provider.dart';
import '../services/purchase_service.dart';
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

  @override
  void initState() {
    super.initState();
    // 页面首帧优先消费会话缓存，再让 SDK 在后台校验当前 offering/storefront。
    Future.microtask(() {
      if (!mounted) return;
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
    // 网页支付渠道（侧载 APK / 桌面）：购买改为浏览器结账 + 回流对账，不展示商店套餐卡。
    final webMode = ref.watch(webCheckoutModeProvider);
    final plansAsync = webMode || isPremium
        ? null
        : ref.watch(subscriptionPlansProvider);
    final specialOfferLabel = webMode
        ? null
        : _specialOfferLabel(l10n, plansAsync?.valueOrNull ?? const []);
    AppLogger.log(
      'Subscription',
      'paywall build: isPremium=$isPremium webMode=$webMode '
          'status=${subState.status} waitingForWeb=$_waitingForWeb busy=$_busy',
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.premiumTitle),
        // 恢复购买为低频操作（登录后通常自动对账获取权益），弱化为右上角文字 action。
        // 网页渠道无平台「恢复」，改为「刷新」——直接触发后端权益对账。
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : (webMode ? _refreshEntitlement : _restore),
            child: Text(webMode ? l10n.premiumRefresh : l10n.premiumRestore),
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
                              child: webMode
                                  ? _buildWebPurchaseArea(l10n)
                                  : _buildPurchaseArea(l10n),
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
    final plan = plans.where(_hasPaidIntroOffer).firstOrNull;
    if (plan == null) return null;
    final offer = plan.introOffer;
    if (offer == null) return null;
    final discounted = isIntroOfferDiscounted(plan);
    if (discounted == false) return null;

    final percent = computeIntroOfferDiscountPercent(plan);
    if (percent != null && percent > 0) {
      return l10n.premiumSpecialOfferPercent(
        percent,
        _offerPeriodName(l10n, offer),
      );
    }
    return l10n.premiumSpecialOfferIntro(
      _introLabelForOffer(l10n, offer),
      _renewalLabelForPlan(l10n, plan, offer),
    );
  }

  bool _hasPaidIntroOffer(SubscriptionPlan plan) {
    final offer = plan.introOffer;
    return offer != null && !offer.isFreeTrial;
  }

  /// 会员态页面主体：金色 hero + 到期信息卡 + 权益卡 + 管理订阅按钮。
  List<Widget> _buildMemberBody(AppLocalizations l10n) {
    final entitlement =
        ref.watch(subscriptionControllerProvider).entitlement ??
        const Entitlement(isPremium: true);
    final plans = ref.watch(subscriptionPlansProvider).valueOrNull ?? const [];
    final summary = summarizeMembership(
      entitlement,
      now: DateTime.now(),
      plans: plans,
    );
    return [
      _MemberHeroCard(l10n: l10n, summary: summary),
      const SizedBox(height: 16),
      _MembershipInfoTile(l10n: l10n, summary: summary),
      const SizedBox(height: 20),
      _BenefitCard(l10n: l10n),
      // 「管理订阅」仅在有可跳转的管理页时展示（网页支付渠道无稳定深链时隐藏，
      // 避免死按钮）。
      if (manageSubscriptionsUrl != null) ...[
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
            onPressed: _openManageSubscription,
            child: Text(l10n.premiumManage),
          ),
        ),
      ],
    ];
  }

  Widget _buildPurchaseArea(AppLocalizations l10n) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    return plansAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _NoPlans(
        l10n: l10n,
        onRetry: () => ref.invalidate(subscriptionPlansProvider),
      ),
      data: (plans) {
        if (plans.isEmpty) {
          return _NoPlans(
            l10n: l10n,
            onRetry: () => ref.invalidate(subscriptionPlansProvider),
          );
        }
        final selectedId = _effectiveSelection(plans);
        final selected = plans.firstWhere((p) => p.planId == selectedId);
        final yearlyValue = _yearlyValueOf(plans);
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
                  backgroundColor: AppTheme.premiumAccent(
                    Theme.of(context).brightness,
                  ),
                  foregroundColor: AppTheme.onPremiumAccent(
                    Theme.of(context).brightness,
                  ),
                ),
                onPressed: _busy ? null : () => _purchase(selected),
                child: Text(_ctaLabel(l10n, selected)),
              ),
            ),
            const SizedBox(height: 2),
            _LegalFooter(l10n: l10n),
          ],
        );
      },
    );
  }

  /// 网页支付购买区：无商店套餐卡，改为「托管 Paywall + 回流对账」。
  ///
  /// 套餐、本地化价格与 Paddle 促销由 RevenueCat 托管 Paywall 展示，
  /// 客户端不硬编码也不复刻 Paddle discount。
  Widget _buildWebPurchaseArea(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (_waitingForWeb) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Flexible(child: Text(l10n.premiumWebVerifying)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : _manualCheckEntitlement,
              child: Text(l10n.premiumWebCheckDone),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.premiumAccent(theme.brightness),
                foregroundColor: AppTheme.onPremiumAccent(theme.brightness),
              ),
              onPressed: _busy ? null : _startWebCheckout,
              child: Text(l10n.premiumWebCheckoutCta),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.premiumWebCheckoutHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 2),
        _LegalFooter(l10n: l10n),
      ],
    );
  }

  /// 发起网页结账：登录 → 拼带 user_id 的 Web Purchase Link → in-app browser 打开 →
  /// 进入等待态并轮询后端对账（不阻塞 UI，用户可点「我已完成支付」立即复核）。
  Future<void> _startWebCheckout() async {
    if (!await _ensureSignedIn() || !mounted) return;
    final userId = ref.read(subscriptionIdentityProvider).userId;
    final uri = userId == null ? null : buildWebPurchaseUri(userId);
    if (uri == null) {
      AppLogger.log(
        'Subscription',
        'web checkout open skipped: userIdPresent=${userId != null} uri=null',
      );
      _showMessage(AppLocalizations.of(context)!.premiumWebOpenFailed);
      return;
    }
    bool opened;
    try {
      opened = await launchUrl(uri);
    } catch (e) {
      // 无可用浏览器 / 平台拒绝时 launchUrl 会抛异常，与「返回 false」同样处理，
      // 不让异常冒泡为未捕获错误。
      AppLogger.log('Subscription', 'web checkout launchUrl 异常: $e');
      opened = false;
    }
    AppLogger.log(
      'Subscription',
      'web checkout open result: opened=$opened host=${uri.host} path=${uri.path}',
    );
    if (!mounted) return;
    if (!opened) {
      _showMessage(AppLocalizations.of(context)!.premiumWebOpenFailed);
      return;
    }
    setState(() => _waitingForWeb = true);
    unawaited(_pollEntitlement());
  }

  /// 轮询后端权益对账，直到到账（自动关闭）或超时（~2 分钟）。
  ///
  /// 权益真相在后端（RC webhook 落库），浏览器结账成功回跳不作数——必须回源确认。
  /// 用户从浏览器返回 App 时 resume 也会触发 refresh（main.dart），双保险。
  Future<void> _pollEntitlement() async {
    const interval = Duration(seconds: 3);
    const maxAttempts = 40; // ~2 分钟
    for (var i = 0; i < maxAttempts; i++) {
      if (!mounted || !_waitingForWeb) return;
      await ref.read(subscriptionControllerProvider.notifier).refresh();
      if (!mounted) return;
      if (ref.read(subscriptionControllerProvider).isActive) {
        setState(() => _waitingForWeb = false);
        if (mounted) context.pop();
        return;
      }
      await Future<void>.delayed(interval);
    }
    if (mounted) setState(() => _waitingForWeb = false);
  }

  /// 「我已完成支付」：立即回源对账一次（不必等轮询间隔）。
  Future<void> _manualCheckEntitlement() async {
    setState(() => _busy = true);
    try {
      await ref.read(subscriptionControllerProvider.notifier).refresh();
      if (!mounted) return;
      if (ref.read(subscriptionControllerProvider).isActive) {
        setState(() => _waitingForWeb = false);
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 刷新权益（网页渠道的 appbar action）：直接触发后端对账并提示当前状态。
  Future<void> _refreshEntitlement() async {
    setState(() => _busy = true);
    try {
      await ref.read(subscriptionControllerProvider.notifier).refresh();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final active = ref.read(subscriptionControllerProvider).isActive;
      _showMessage(active ? l10n.premiumRestored : l10n.premiumRestoreNone);
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

  /// 购买 / 恢复前的统一登录门：权益需绑定 Supabase user_id（跨设备 / 可恢复），
  /// 复用全 App 通用的 [ensureSignedInForAction]（弹登录引导 → 跳登录页），
  /// 未登录返回 false，调用方据此中止本次动作。
  Future<bool> _ensureSignedIn() async {
    final l10n = AppLocalizations.of(context)!;
    return ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.authSignInTitle,
      message: l10n.premiumLoginRequired,
    );
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
    } catch (_) {
      if (mounted) {
        _showMessage(AppLocalizations.of(context)!.premiumPurchaseFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openManageSubscription() async {
    final url = manageSubscriptionsUrl;
    if (url != null) await launchUrl(Uri.parse(url));
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

String _offerPeriodName(AppLocalizations l10n, SubscriptionIntroOffer offer) {
  return switch (offer.period) {
    SubscriptionOfferPeriod.year when offer.periodNumberOfUnits == 1 =>
      l10n.premiumOfferPeriodYear,
    SubscriptionOfferPeriod.month when offer.periodNumberOfUnits == 1 =>
      l10n.premiumOfferPeriodMonth,
    _ => l10n.premiumOfferPeriodGeneric,
  };
}

String _introLabelForOffer(
  AppLocalizations l10n,
  SubscriptionIntroOffer offer,
) {
  return switch (offer.period) {
    SubscriptionOfferPeriod.year when offer.periodNumberOfUnits == 1 =>
      l10n.premiumIntroFirstYear(offer.priceString),
    SubscriptionOfferPeriod.month when offer.periodNumberOfUnits == 1 =>
      l10n.premiumIntroFirstMonth(offer.priceString),
    _ => l10n.premiumIntroFirstPeriod(offer.priceString),
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

  /// 卡片右侧主价格：付费首期优惠展示用户首年实际支付价；免费试用仍展示续费价。
  String _displayPrice() {
    final offer = plan.introOffer;
    if (offer != null && !offer.isFreeTrial) return offer.priceString;
    return plan.priceString;
  }

  /// 卡片右侧价格后缀：付费首年优惠需要明确这是首年价格。
  String _displayPriceSuffix() {
    final offer = plan.introOffer;
    if (offer != null &&
        !offer.isFreeTrial &&
        plan.period == SubscriptionPeriod.yearly) {
      return l10n.premiumPriceSuffixFirstYear;
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

    // 副标题优先级：平台首期促销 > 每月折合价 > 试用提示。
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
    return l10n.premiumOfferThen(_introLabelForOffer(l10n, offer), renewal);
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
