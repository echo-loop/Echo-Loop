/// 自由播放器睡眠定时器（定时停止）UI。
///
/// [SleepTimerButton] 放在 AppBar 右上角，点击在按钮**下方**弹出气泡浮层
/// （[_SleepTimerPopup]）选择预设时长，到点自动暂停播放。复用「循环设置」浮层的
/// 视觉与交互骨架（[OverlayPortal] + 透明遮罩点外关闭 + 指向锚点的小三角），
/// 唯一差异是箭头朝上、浮层定位在按钮下方。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/listening_practice/sleep_timer_provider.dart';
import '../providers/media_playback/media_sleep_timer_provider.dart';
import '../theme/app_theme.dart';
import 'common/anchored_bubble.dart';
import 'package:flutter_riverpod/misc.dart';

/// 剩余时长格式化为 `mm:ss`。
String _formatRemaining(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// AppBar 睡眠定时器按钮：点击在按钮下方弹出预设时长浮层。
///
/// 未激活用弱化 [Icons.timer_outlined]；激活态改为轻量倒计时胶囊，直接在 AppBar
/// 暴露剩余时间，同时仍保持低视觉权重。
class SleepTimerButton extends ConsumerStatefulWidget {
  const SleepTimerButton({super.key, this.forMediaPlayback = false});

  /// 媒体随心听入口：复用同一套菜单与倒计时展示，到点暂停 media_kit 播放器。
  const SleepTimerButton.mediaPlayback({super.key}) : forMediaPlayback = true;

  final bool forMediaPlayback;

  @override
  ConsumerState<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends ConsumerState<SleepTimerButton> {
  final OverlayPortalController _portalController = OverlayPortalController();

  /// 自由播放器睡眠定时器的保活链接（仅非媒体入口持有）。
  ///
  /// 宿主页被其他全屏页覆盖（如进入句子详情）时 Riverpod 3 会暂停监听，autoDispose
  /// 的定时器会随之销毁、计时被取消。持有该链接后，覆盖期间定时器保持运行；本按钮
  /// 卸载（离开页面）时释放，仍保持「离开页面即取消」语义。
  KeepAliveLink? _timerKeepAlive;

  @override
  void initState() {
    super.initState();
    if (!widget.forMediaPlayback) {
      _timerKeepAlive = ref.read(sleepTimerProvider.notifier).holdKeepAlive();
    }
  }

  @override
  void dispose() {
    _timerKeepAlive?.close();
    super.dispose();
  }

  /// 浮层宽度与锚点尺寸。
  static const double _popupWidth = 144;
  static const double _anchorWidth = 64;
  static const double _anchorHeight = 42;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timerState = widget.forMediaPlayback
        ? ref.watch(mediaSleepTimerProvider)
        : ref.watch(sleepTimerProvider);
    final isActive = timerState.isActive;
    final colorScheme = Theme.of(context).colorScheme;
    final remaining = timerState.remaining;

    // 激活时把剩余时间放进无障碍 label，视觉上则改为轻量倒计时胶囊。
    final label = isActive && remaining != null
        ? l10n.sleepTimerA11yActive(_formatRemaining(remaining))
        : l10n.sleepTimer;

    return AnchoredBubble(
      controller: _portalController,
      direction: BubbleDirection.down,
      width: _popupWidth,
      // 与播放速度浮层同样式：surface 底色、outlineVariant 描边、圆角 20，无箭头
      color: Theme.of(context).colorScheme.surface,
      borderColor: Theme.of(context).colorScheme.outlineVariant,
      borderRadius: 20,
      showCaret: false,
      contentBuilder: (_) => _SleepTimerPopup(
        onSelected: _portalController.hide,
        forMediaPlayback: widget.forMediaPlayback,
      ),
      child: Semantics(
        button: true,
        label: label,
        onTap: _portalController.toggle,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s),
            child: Tooltip(
              message: label,
              child: SizedBox(
                width: _anchorWidth,
                height: _anchorHeight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: isActive && remaining != null
                      ? Align(
                          key: const ValueKey('active-countdown'),
                          alignment: Alignment.centerRight,
                          child: _TapTarget(
                            borderRadius: BorderRadius.circular(999),
                            onTap: _portalController.toggle,
                            child: _ActiveCountdownCapsule(
                              text: _formatRemaining(remaining),
                            ),
                          ),
                        )
                      : Align(
                          key: const ValueKey('inactive-icon'),
                          alignment: Alignment.centerRight,
                          child: _TapTarget(
                            borderRadius: BorderRadius.circular(999),
                            onTap: _portalController.toggle,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.timer_outlined,
                                size: 22,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 睡眠定时器浮层内容（气泡卡片内部内容）。
///
/// 由调用方用 [AnchoredBubble] 锚定到 AppBar 按钮下方并套上气泡卡片外壳，本组件只负责
/// 卡片内的预设列表。未激活：列出预设时长，点选即启动并关闭浮层。激活中：显示「关闭
/// 定时」与预设列表，当前档位打勾，用户可直接切到其他时长完成重设。
class _SleepTimerPopup extends ConsumerWidget {
  const _SleepTimerPopup({
    required this.onSelected,
    required this.forMediaPlayback,
  });

  /// 选择预设/关闭后回调（用于收起浮层）。
  final VoidCallback onSelected;
  final bool forMediaPlayback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final timerState = forMediaPlayback
        ? ref.watch(mediaSleepTimerProvider)
        : ref.watch(sleepTimerProvider);
    final activeMinutes = timerState.presetMinutes;

    final children = <Widget>[];

    // 标题头：让用户明白浮层用途，下方接一条浅色分割线
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        child: Text(
          l10n.sleepTimer,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
    children.add(_divider(theme));

    if (timerState.isActive && timerState.remaining != null) {
      children.add(
        BubbleMenuRow(
          icon: Icons.close,
          label: l10n.sleepTimerOff,
          color: theme.colorScheme.error,
          onTap: () {
            if (forMediaPlayback) {
              ref.read(mediaSleepTimerProvider.notifier).cancel();
            } else {
              ref.read(sleepTimerProvider.notifier).cancel();
            }
            onSelected();
          },
        ),
      );
      children.add(_divider(theme));
    }

    // 预设时长档位
    for (final minutes in sleepTimerPresets) {
      final selected = minutes == activeMinutes;
      children.add(
        BubbleMenuRow(
          label: l10n.sleepTimerMinutes(minutes),
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          trailing: selected
              ? Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
              : null,
          selected: selected,
          onTap: () {
            if (forMediaPlayback) {
              ref
                  .read(mediaSleepTimerProvider.notifier)
                  .start(Duration(minutes: minutes));
            } else {
              ref
                  .read(sleepTimerProvider.notifier)
                  .start(Duration(minutes: minutes));
            }
            onSelected();
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      // stretch 让每行铺满浮层宽度，hover/选中高亮覆盖整行（内容仍居中）
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _divider(ThemeData theme) => Divider(
    height: 1,
    thickness: 1,
    color: theme.colorScheme.outlineVariant,
    indent: AppSpacing.m,
    endIndent: AppSpacing.m,
  );
}

class _TapTarget extends StatelessWidget {
  const _TapTarget({
    required this.child,
    required this.borderRadius,
    required this.onTap,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: borderRadius, onTap: onTap, child: child),
    );
  }
}

/// 激活态 AppBar 入口：用低存在感胶囊直接显示剩余倒计时。
class _ActiveCountdownCapsule extends StatelessWidget {
  const _ActiveCountdownCapsule({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.primary.withValues(alpha: 0.86),
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
