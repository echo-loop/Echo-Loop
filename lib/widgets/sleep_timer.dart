/// 自由播放器睡眠定时器（定时停止）UI。
///
/// [SleepTimerButton] 放在 AppBar 右上角，点击在按钮**下方**弹出气泡浮层
/// （[_SleepTimerPopup]）选择预设时长，到点自动暂停播放。复用「循环设置」浮层的
/// 视觉与交互骨架（[OverlayPortal] + 透明遮罩点外关闭 + 指向锚点的小三角），
/// 唯一差异是箭头朝上、浮层定位在按钮下方。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/listening_practice/sleep_timer_provider.dart';
import '../theme/app_theme.dart';

/// 剩余时长格式化为 `mm:ss`。
String _formatRemaining(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// AppBar 睡眠定时器按钮：点击在按钮下方弹出预设时长浮层。
///
/// 激活态（计时进行中）图标用实心 [Icons.timer] + 主色；未激活用 [Icons.timer_outlined]
/// + 弱化灰。仅监听 `isActive` 避免每秒重建 AppBar；剩余时间通过无障碍 label 暴露。
class SleepTimerButton extends ConsumerStatefulWidget {
  const SleepTimerButton({super.key});

  @override
  ConsumerState<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends ConsumerState<SleepTimerButton> {
  final OverlayPortalController _portalController = OverlayPortalController();
  final GlobalKey _buttonKey = GlobalKey();

  /// 浮层宽度与屏幕安全边距。
  static const double _popupWidth = 144;
  static const double _margin = 16;

  /// 构建悬浮内容：依据按钮在屏幕中的位置把浮层定位到按钮下方并对齐箭头。
  Widget _buildOverlay(BuildContext overlayContext) {
    final overlayBox =
        Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;
    final buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || buttonBox == null) {
      return const SizedBox.shrink();
    }

    final screen = overlayBox.size;
    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final buttonCenterX = buttonTopLeft.dx + buttonBox.size.width / 2;

    final width = math.min(_popupWidth, screen.width - _margin * 2);
    // 居中对齐按钮，再夹紧到屏幕内
    final left = (buttonCenterX - width / 2).clamp(
      _margin,
      screen.width - _margin - width,
    );
    final caretX = buttonCenterX - left;
    // 浮层顶边贴在按钮下方留 8px 间隙
    final top = buttonTopLeft.dy + buttonBox.size.height + 8;

    return Stack(
      children: [
        // 透明遮罩：点击浮层外部关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _portalController.hide,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          // 吸收浮层范围内的点击，避免穿透到遮罩误关闭
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: _SleepTimerPopup(
              width: width,
              caretX: caretX,
              onSelected: _portalController.hide,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timerState = ref.watch(sleepTimerProvider);
    final isActive = timerState.isActive;
    final colorScheme = Theme.of(context).colorScheme;

    // 激活时把剩余时间放进无障碍 label（AppBar 视觉上不显示数字）。
    final label = isActive && timerState.remaining != null
        ? l10n.sleepTimerA11yActive(_formatRemaining(timerState.remaining!))
        : l10n.sleepTimer;

    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: _buildOverlay,
      child: Semantics(
        button: true,
        label: label,
        onTap: _portalController.toggle,
        child: ExcludeSemantics(
          // 右侧留边距，避免图标紧贴屏幕边缘
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s),
            child: IconButton(
              key: _buttonKey,
              tooltip: l10n.sleepTimer,
              icon: Icon(isActive ? Icons.timer : Icons.timer_outlined),
              iconSize: 22,
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.6),
              onPressed: _portalController.toggle,
            ),
          ),
        ),
      ),
    );
  }
}

/// 睡眠定时器浮层内容（气泡卡片 + 朝上箭头）。
///
/// 未激活：列出预设时长，点选即启动并关闭浮层。激活中：顶部显示剩余时间 + 「关闭定时」，
/// 下方列出预设（当前档打勾，可直接改成别的时长 = 重设）。
class _SleepTimerPopup extends ConsumerWidget {
  const _SleepTimerPopup({
    required this.width,
    required this.caretX,
    required this.onSelected,
  });

  /// 气泡宽度。
  final double width;

  /// 朝上箭头尖端相对卡片左边缘的水平位置。
  final double caretX;

  /// 选择预设/关闭后回调（用于收起浮层）。
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final timerState = ref.watch(sleepTimerProvider);
    final controller = ref.read(sleepTimerProvider.notifier);

    // 激活时当前生效的档位（分钟），用于打勾；剩余按上取整匹配最接近的档位不可靠，
    // 故仅在剩余 <= 该档总时长时不严格判定——这里以「剩余分钟向上取整」近似标记。
    final activeMinutes = timerState.remaining == null
        ? null
        : timerState.remaining!.inSeconds <= 0
        ? null
        : ((timerState.remaining!.inSeconds + 59) ~/ 60);

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

    // 激活态：剩余时间 + 关闭定时
    if (timerState.isActive && timerState.remaining != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          child: Column(
            children: [
              Text(
                _formatRemaining(timerState.remaining!),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                l10n.sleepTimerRemaining,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
      children.add(_divider(theme));
      children.add(
        _PopupRow(
          icon: Icons.close,
          label: l10n.sleepTimerOff,
          color: theme.colorScheme.error,
          onTap: () {
            controller.cancel();
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
        _PopupRow(
          label: l10n.sleepTimerMinutes(minutes),
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          trailing: selected
              ? Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
              : null,
          selected: selected,
          onTap: () {
            controller.start(Duration(minutes: minutes));
            onSelected();
          },
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 朝上箭头：贴在卡片顶边、指向 AppBar 按钮（下移 1px 盖住接缝）
        ExcludeSemantics(
          child: Transform.translate(
            offset: const Offset(0, 1),
            child: CustomPaint(
              size: Size(width, 8),
              painter: _CaretUpPainter(caretX: caretX, color: surface),
            ),
          ),
        ),
        Material(
          elevation: 8,
          color: surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              // stretch 让每行铺满浮层宽度，hover/选中高亮覆盖整行（内容仍居中）
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ],
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

/// 浮层中的一行：整行可点，左标签 + 可选行尾图标（勾选/图标）。
class _PopupRow extends StatelessWidget {
  const _PopupRow({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.trailing,
    this.selected = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  /// 行首图标（如「关闭定时」的 close）。
  final IconData? icon;

  /// 行尾组件（如选中勾选）。
  final Widget? trailing;

  /// 是否选中（无障碍语义）。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: 10,
          ),
          // 内容统一居中；行尾图标（如打勾）绝对定位到右侧，不挤偏居中的标签
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: AppSpacing.s),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (trailing != null) Positioned(right: 0, child: trailing!),
            ],
          ),
        ),
      ),
    );
  }
}

/// 气泡朝上箭头：等腰三角，底边在下贴卡片、尖端朝上指向 AppBar 按钮。
class _CaretUpPainter extends CustomPainter {
  const _CaretUpPainter({required this.caretX, required this.color});

  /// 尖端相对左边缘的水平位置。
  final double caretX;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const halfWidth = 8.0;
    final x = caretX.clamp(halfWidth, size.width - halfWidth);
    final path = Path()
      ..moveTo(x - halfWidth, size.height)
      ..lineTo(x + halfWidth, size.height)
      ..lineTo(x, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretUpPainter old) =>
      old.caretX != caretX || old.color != color;
}
