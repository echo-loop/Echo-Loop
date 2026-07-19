import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import '../l10n/app_localizations.dart';
import '../providers/new_user_guide_provider.dart';
import '../services/app_logger.dart';

/// 单个页面级引导步骤。
///
/// [key] 同时用于 [Showcase] widget 的 key 和 `startShowCase` 调用，
/// 由 screen 在 state 中持有，传给对应的 [GuideTarget] 和 [GuideFlow]。
/// 同一个 step 需要被 [GuideFlow.steps] 和 [GuideTarget] 引用**同一个实例**
/// （或者至少是相同的 key），这样 Host 能在 `startShowCase` 时拿到对应的
/// key，并且 showcaseview 能在 tree 里通过 key 定位到目标 widget。
class GuideStep {
  final GlobalKey key;

  /// 标题可选：当按钮/目标本身已承载功能名称时，留空避免与描述重复。
  final String? title;
  final String description;

  /// 可选的富文本描述：用于在 description 中嵌入 Icon 等 widget。
  /// 传入时取代 [description] 字符串渲染，支持 [Text.rich] + [WidgetSpan] 内联图标。
  final Widget? descriptionWidget;

  const GuideStep({
    required this.key,
    this.title,
    required this.description,
    this.descriptionWidget,
  });

  bool get hasTitle => title != null && title!.isNotEmpty;
}

/// 单个页面级引导 flow 的声明。
class GuideFlow {
  final String flowId;
  final bool shouldRun;
  final List<GuideStep> steps;

  const GuideFlow({
    required this.flowId,
    required this.shouldRun,
    required this.steps,
  });
}

/// 页面渲染完成到 tooltip 出现之间的等待时间，给用户一点反应时间。
const Duration _kGuideAppearDelay = Duration(milliseconds: 500);

/// 在 screen 内按顺序声明并启动一组页面级 flow。
///
/// 对齐 showcaseview 官方示例：flow 启动时 **一次性** 把所有 step 的 key
/// 传给 `ShowcaseView.get().startShowCase([...])`，推进完全由 showcaseview
/// 内部处理（next 按钮 / barrier 点击），tour 结束时通过
/// [GuideShowcaseBus] 走回 controller 标记已看。
class GuideFlowSequenceHost extends ConsumerStatefulWidget {
  final List<GuideFlow> flows;
  final Widget child;

  const GuideFlowSequenceHost({
    super.key,
    required this.flows,
    required this.child,
  });

  @override
  ConsumerState<GuideFlowSequenceHost> createState() =>
      _GuideFlowSequenceHostState();
}

class _GuideFlowSequenceHostState extends ConsumerState<GuideFlowSequenceHost> {
  ProviderSubscription<GuideControllerState>? _guideSubscription;
  bool _attemptScheduled = false;
  bool _lastTickerEnabled = true;

  @override
  void initState() {
    super.initState();
    _guideSubscription = ref.listenManual<GuideControllerState>(
      guideControllerProvider,
      _onControllerStateChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAttempt();
    });
  }

  void _onControllerStateChanged(
    GuideControllerState? previous,
    GuideControllerState next,
  ) {
    if (!mounted) return;
    final resetChanged =
        previous != null && previous.resetGeneration != next.resetGeneration;
    if (resetChanged || !next.isActive) {
      _attemptScheduled = false;
      _scheduleAttempt();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (tickerEnabled && !_lastTickerEnabled) {
      _attemptScheduled = false;
      _scheduleAttempt();
    }
    _lastTickerEnabled = tickerEnabled;
  }

  @override
  void didUpdateWidget(covariant GuideFlowSequenceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_flowsConfigChanged(oldWidget.flows, widget.flows)) {
      _attemptScheduled = false;
      _scheduleAttempt();
    }
  }

  @override
  void dispose() {
    _guideSubscription?.close();
    super.dispose();
  }

  bool _flowsConfigChanged(List<GuideFlow> a, List<GuideFlow> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].flowId != b[i].flowId || a[i].shouldRun != b[i].shouldRun) {
        return true;
      }
    }
    return false;
  }

  void _scheduleAttempt() {
    if (_attemptScheduled ||
        widget.flows.isEmpty ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    _attemptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _attemptScheduled = false;
      if (!mounted) return;
      await _tryStartNext();
    });
  }

  Future<void> _tryStartNext() async {
    if (!mounted) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    final showcase = _tryGetShowcase();
    if (showcase == null) return;
    // 新手引导总开关关闭时，直接不启动任何 flow；纯 widget 测试若未注入
    // SharedPreferences，也跳过引导，避免后台 tour 干扰与引导无关的断言。
    if (!_canStartGuide()) return;
    if (ref.read(guideControllerProvider).isActive) return;

    final registry = ref.read(guideRegistryProvider);
    for (final flow in widget.flows) {
      if (!flow.shouldRun || flow.steps.isEmpty) continue;
      if (await registry.isSeen(flow.flowId)) continue;
      if (!mounted) return;

      final started = await ref
          .read(guideControllerProvider.notifier)
          .startFlow(flow.flowId);
      if (!mounted) return;
      if (!started) continue;

      GuideShowcaseBus.setOnEnd(() {
        ref.read(guideControllerProvider.notifier).completeActiveFlow();
      });
      final keys = flow.steps.map((s) => s.key).toList();
      AppLogger.log(
        'Guide',
        'host startShowCase flow=${flow.flowId} keys=${keys.length} (delayed)',
      );

      await Future<void>.delayed(_kGuideAppearDelay);
      if (!mounted) return;
      if (!TickerMode.valuesOf(context).enabled) return;

      showcase.startShowCase(keys);
      return;
    }
  }

  bool _canStartGuide() {
    try {
      return ref.read(guideEnabledProvider);
    } on UnimplementedError catch (error) {
      if (error.toString().contains('sharedPreferencesProvider')) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastKeys = <GlobalKey>{
      for (final flow in widget.flows)
        if (flow.steps.isNotEmpty) flow.steps.last.key,
    };
    return _GuideFlowLastStepKeys(keys: lastKeys, child: widget.child);
  }
}

/// 向下层 [GuideTarget] 暴露各 flow 的最后一步 key 集合，
/// 用于把最后一步的按钮文案从“下一步”切换为“知道了”。
class _GuideFlowLastStepKeys extends InheritedWidget {
  const _GuideFlowLastStepKeys({required this.keys, required super.child});

  final Set<GlobalKey> keys;

  static Set<GlobalKey> of(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<_GuideFlowLastStepKeys>();
    return widget?.keys ?? const <GlobalKey>{};
  }

  @override
  bool updateShouldNotify(_GuideFlowLastStepKeys oldWidget) {
    if (identical(keys, oldWidget.keys)) return false;
    if (keys.length != oldWidget.keys.length) return true;
    return !keys.containsAll(oldWidget.keys);
  }
}

/// 获取全局 [ShowcaseView]；未注册（如纯 unit 测试环境）时返回 null。
ShowcaseView? _tryGetShowcase() {
  try {
    return ShowcaseView.get();
  } catch (_) {
    return null;
  }
}

/// 引导 tooltip 的视觉方案（light / dark 双主题）。
class _GuideTooltipScheme {
  const _GuideTooltipScheme._({
    required this.surface,
    required this.title,
    required this.description,
    required this.actionBg,
    required this.actionText,
    required this.barrier,
    required this.barrierOpacity,
  });

  final Color surface;
  final Color title;
  final Color description;
  final Color actionBg;
  final Color actionText;
  final Color barrier;
  final double barrierOpacity;

  static const _light = _GuideTooltipScheme._(
    surface: Color(0xFFFFFFFF),
    title: Color(0xFF0F1115),
    description: Color(0xFF5A6270),
    actionBg: Color(0xFF111418),
    actionText: Color(0xFFFFFFFF),
    barrier: Color(0xFF0A0D12),
    barrierOpacity: 0.55,
  );

  static const _dark = _GuideTooltipScheme._(
    surface: Color(0xFF1B1E23),
    title: Color(0xFFF4F5F7),
    description: Color(0xFF9BA3AE),
    actionBg: Color(0xFFF4F5F7),
    actionText: Color(0xFF0F1115),
    // 夜间模式不走"加深"套路：深色场景再盖黑 barrier 会把卡片和外围一起压成
    // 近黑，挖孔看不出来。改用浅色 barrier 把外围洗成中灰，挖孔内的深色卡片
    // 反而成为画面里最暗的区域，和亮色模式一样形成"挖孔凸显"的视觉逻辑。
    barrier: Color(0xFFE5E7EB),
    barrierOpacity: 0.45,
  );

  static _GuideTooltipScheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

/// 引导 tooltip 的几何与字体 tokens（与配色解耦）。
abstract class _GuideTooltipStyle {
  static const tooltipRadius = BorderRadius.all(Radius.circular(14));
  static const tooltipPadding = EdgeInsets.fromLTRB(18, 16, 18, 14);
  static const titlePadding = EdgeInsets.only(bottom: 8);
  static const targetPadding = EdgeInsets.all(4);
  static const targetRadius = BorderRadius.all(Radius.circular(16));
  static const actionRadius = BorderRadius.all(Radius.circular(8));
  static const actionPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 8,
  );

  static TextStyle title(Color color) => TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: color,
  );

  static TextStyle description(Color color) => TextStyle(
    fontSize: 13,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle action(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: color,
  );
}

/// 可复用的 showcase target 包装器。
///
/// 本身是一个无状态的薄包装：只负责把 [step.key] 设给 [Showcase] widget
/// 并应用统一的视觉方案。Key 由 screen 侧管理，和 [GuideFlow] 里声明的
/// key 同一实例，确保 `startShowCase([keys])` 能正确定位到目标。
class GuideTarget extends StatelessWidget {
  final GuideStep step;
  final Widget child;

  /// 可选的高亮区域外扩 padding。未指定时使用默认值 [_GuideTooltipStyle.targetPadding]。
  ///
  /// 用于少数 child 无法覆盖整个期望高亮区域的场景（如 NavigationDestination
  /// 的 icon 槽只含图标，不含 label），通过外扩 padding 把相邻区域一起纳入高亮。
  final EdgeInsets? targetPadding;

  const GuideTarget({
    super.key,
    required this.step,
    required this.child,
    this.targetPadding,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = _GuideTooltipScheme.of(context);
    final isLastStep = _GuideFlowLastStepKeys.of(context).contains(step.key);
    final actionName = isLastStep ? l10n.guideDone : l10n.guideNext;
    // 两个 Showcase 分支共用同一份 padding，避免分支间漂移。
    final effectiveTargetPadding =
        targetPadding ?? _GuideTooltipStyle.targetPadding;

    final semanticsLabel = step.hasTitle ? step.title : step.description;

    // 若提供了 descriptionWidget，走 Showcase.withWidget 自定义 container；
    // 按钮在 container 内部渲染，点击时调 ShowcaseView.next() 推进流程，
    // 保持与默认 tooltip 视觉一致。
    if (step.descriptionWidget != null) {
      return Showcase.withWidget(
        key: step.key,
        targetPadding: effectiveTargetPadding,
        targetBorderRadius: _GuideTooltipStyle.targetRadius,
        overlayColor: scheme.barrier,
        overlayOpacity: scheme.barrierOpacity,
        container: _RichTooltipContainer(
          title: step.hasTitle ? step.title : null,
          description: step.descriptionWidget!,
          actionName: actionName,
          scheme: scheme,
        ),
        child: Semantics(label: semanticsLabel, child: child),
      );
    }

    return Showcase(
      key: step.key,
      title: step.hasTitle ? step.title : null,
      description: step.description,

      // 表面
      tooltipBackgroundColor: scheme.surface,
      tooltipBorderRadius: _GuideTooltipStyle.tooltipRadius,
      tooltipPadding: _GuideTooltipStyle.tooltipPadding,
      targetPadding: effectiveTargetPadding,
      targetBorderRadius: _GuideTooltipStyle.targetRadius,

      // 版式（title 为空时不设置 titleTextStyle / titlePadding，避免留白）
      titleTextStyle: step.hasTitle
          ? _GuideTooltipStyle.title(scheme.title)
          : null,
      descTextStyle: _GuideTooltipStyle.description(scheme.description),
      titlePadding: step.hasTitle ? _GuideTooltipStyle.titlePadding : null,
      titleAlignment: Alignment.centerLeft,
      descriptionAlignment: Alignment.centerLeft,
      titleTextAlign: TextAlign.left,
      descriptionTextAlign: TextAlign.left,

      // barrier（遮罩）
      overlayColor: scheme.barrier,
      overlayOpacity: scheme.barrierOpacity,

      // 动作按钮——默认 next 行为由 showcaseview 接管，过最后一步自动 onFinish。
      tooltipActionConfig: const TooltipActionConfig(
        alignment: MainAxisAlignment.end,
        position: TooltipActionPosition.inside,
        actionGap: 8,
        gapBetweenContentAndAction: 12,
      ),
      tooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          name: actionName,
          backgroundColor: scheme.actionBg,
          textStyle: _GuideTooltipStyle.action(scheme.actionText),
          borderRadius: _GuideTooltipStyle.actionRadius,
          padding: _GuideTooltipStyle.actionPadding,
        ),
      ],
      child: Semantics(label: semanticsLabel, child: child),
    );
  }
}

/// 富文本 tooltip 容器，用于 [GuideStep.descriptionWidget] 场景。
///
/// 完整复刻默认 tooltip 的视觉方案（surface + radius + padding + action button），
/// 并将 action 按钮内嵌在容器中，点击时调用 [ShowcaseView.next] 推进流程。
class _RichTooltipContainer extends StatelessWidget {
  final String? title;
  final Widget description;
  final String actionName;
  final _GuideTooltipScheme scheme;

  const _RichTooltipContainer({
    required this.title,
    required this.description,
    required this.actionName,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title!.isNotEmpty;
    return IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: _GuideTooltipStyle.tooltipPadding,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: _GuideTooltipStyle.tooltipRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasTitle) ...[
              Text(
                title!,
                textAlign: TextAlign.left,
                style: _GuideTooltipStyle.title(scheme.title),
              ),
              const SizedBox(height: 8),
            ],
            DefaultTextStyle(
              style: _GuideTooltipStyle.description(scheme.description),
              child: description,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: scheme.actionBg,
                borderRadius: _GuideTooltipStyle.actionRadius,
                child: InkWell(
                  borderRadius: _GuideTooltipStyle.actionRadius,
                  onTap: () {
                    try {
                      ShowcaseView.get().next();
                    } catch (_) {
                      // 无 ShowcaseView（测试环境）时忽略
                    }
                  },
                  child: Padding(
                    padding: _GuideTooltipStyle.actionPadding,
                    child: Text(
                      actionName,
                      style: _GuideTooltipStyle.action(scheme.actionText),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
