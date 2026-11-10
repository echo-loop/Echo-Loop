/// 锚定气泡浮层共享组件。
///
/// 提炼自 Free Player「循环设置」「睡眠定时器」两个浮层的视觉与交互骨架：
/// [OverlayPortal] + 透明遮罩点外关闭 + 指向锚点的小三角 + 圆角卡片，供速度选择器
/// 等其它需要"贴控件弹出"的锚定菜单复用，保证全应用浮层观感统一。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 气泡浮层相对锚点的弹出方向。
enum BubbleDirection {
  /// 浮层在锚点**上方**，箭头朝下指向锚点（如底部控制栏的按钮）。
  up,

  /// 浮层在锚点**下方**，箭头朝上指向锚点（如 AppBar 按钮）。
  down,
}

/// 锚定气泡浮层。
///
/// 把 [child]（触发按钮）作为锚点，点击经 [controller] 控制在其上方/下方弹出
/// [contentBuilder] 构建的内容，外面套上气泡卡片（圆角 16 + elevation 8 + 指向锚点
/// 的小三角）。浮层水平居中对齐锚点并夹紧在屏幕内（左右各留 [margin]），箭头随之
/// 平移始终对准锚点中心；浮层下方铺一层透明遮罩，点击外部即关闭。
class AnchoredBubble extends StatefulWidget {
  const AnchoredBubble({
    super.key,
    required this.controller,
    required this.direction,
    required this.width,
    required this.contentBuilder,
    required this.child,
    this.gap = 8,
    this.margin = 16,
    this.color,
    this.borderColor,
    this.borderRadius = 16,
    this.showCaret = true,
  });

  /// 浮层显隐控制器（由调用方持有，触发按钮的 onTap 用同一个 toggle）。
  final OverlayPortalController controller;

  /// 弹出方向。
  final BubbleDirection direction;

  /// 浮层期望宽度（会被夹紧到屏幕内）。
  final double width;

  /// 浮层卡片内部内容（不含卡片外壳与三角）。
  final WidgetBuilder contentBuilder;

  /// 锚点（触发按钮）。
  final Widget child;

  /// 浮层与锚点之间的间隙。
  final double gap;

  /// 浮层与屏幕左右的安全边距。
  final double margin;

  /// 卡片底色；为 null 时使用 surface。
  final Color? color;

  /// 卡片描边色；为 null 时不描边。箭头的斜边同色描边，与卡片无缝相接。
  final Color? borderColor;

  /// 卡片圆角半径。
  final double borderRadius;

  /// 是否绘制指向锚点的箭头；为 false 时只绘制卡片。
  final bool showCaret;

  @override
  State<AnchoredBubble> createState() => _AnchoredBubbleState();
}

class _AnchoredBubbleState extends State<AnchoredBubble> {
  final GlobalKey _anchorKey = GlobalKey();

  /// 依据锚点在屏幕中的位置定位浮层并对齐箭头。
  Widget _buildOverlay(BuildContext overlayContext) {
    final overlayBox =
        Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;
    final anchorBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || anchorBox == null) {
      return const SizedBox.shrink();
    }

    final screen = overlayBox.size;
    final anchorTopLeft = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final anchorCenterX = anchorTopLeft.dx + anchorBox.size.width / 2;

    final width = math.min(widget.width, screen.width - widget.margin * 2);
    // 居中对齐锚点，再夹紧到屏幕内
    final left = (anchorCenterX - width / 2).clamp(
      widget.margin,
      screen.width - widget.margin - width,
    );
    final caretX = anchorCenterX - left;

    // 吸收浮层范围内的点击，避免穿透到遮罩误关闭
    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: BubbleCard(
        width: width,
        caretX: caretX,
        direction: widget.direction,
        color: widget.color,
        borderColor: widget.borderColor,
        borderRadius: widget.borderRadius,
        showCaret: widget.showCaret,
        child: widget.contentBuilder(overlayContext),
      ),
    );

    return Stack(
      children: [
        // 透明遮罩：点击浮层外部关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.controller.hide,
          ),
        ),
        if (widget.direction == BubbleDirection.up)
          Positioned(
            left: left,
            // 浮层底边到屏幕底部的距离：贴在锚点上方留 gap
            bottom: screen.height - anchorTopLeft.dy + widget.gap,
            width: width,
            child: content,
          )
        else
          Positioned(
            left: left,
            // 浮层顶边贴在锚点下方留 gap
            top: anchorTopLeft.dy + anchorBox.size.height + widget.gap,
            width: width,
            child: content,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: widget.controller,
      overlayChildBuilder: _buildOverlay,
      child: KeyedSubtree(key: _anchorKey, child: widget.child),
    );
  }
}

/// 气泡卡片：圆角卡片 + 指向锚点的小三角。
///
/// [caretX] 是箭头尖端相对卡片左边缘的水平位置；[direction] 决定三角在卡片下方（up）
/// 还是上方（down）。可独立使用（如调用方自行处理定位时）。
class BubbleCard extends StatelessWidget {
  const BubbleCard({
    super.key,
    required this.width,
    required this.caretX,
    required this.direction,
    required this.child,
    this.color,
    this.borderColor,
    this.borderRadius = 16,
    this.showCaret = true,
  });

  /// 是否绘制箭头；为 false 时只绘制卡片。
  final bool showCaret;

  /// 卡片与箭头的底色；为 null 时使用 surface。
  final Color? color;

  /// 卡片描边色；为 null 时不描边。
  final Color? borderColor;

  /// 卡片圆角半径。
  final double borderRadius;

  /// 卡片宽度。
  final double width;

  /// 箭头尖端相对卡片左边缘的水平位置。
  final double caretX;

  /// 箭头方向。
  final BubbleDirection direction;

  /// 卡片内部内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Theme.of(context).colorScheme.surface;

    // 箭头贴卡片边缘并平移 1px 盖住接缝：up 三角在卡片下方上移 1px；down 在上方下移 1px
    final caret = ExcludeSemantics(
      child: Transform.translate(
        offset: Offset(0, direction == BubbleDirection.up ? -1 : 1),
        child: CustomPaint(
          size: Size(width, 8),
          painter: CaretPainter(
            caretX: caretX,
            color: cardColor,
            direction: direction,
            borderColor: borderColor,
          ),
        ),
      ),
    );

    final card = Material(
      elevation: 8,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: width, child: child),
    );

    if (!showCaret) return card;

    // 朝上的箭头在卡片上方：卡片的 elevation 阴影会盖住先绘制的箭头，
    // 所以用 Stack 把箭头放在卡片之后绘制，保证箭头可见。
    if (direction == BubbleDirection.down) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(padding: const EdgeInsets.only(top: 8), child: card),
          Positioned(top: 0, left: 0, right: 0, height: 8, child: caret),
        ],
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [card, caret]);
  }
}

/// 气泡浮层中的一行：整行可点、内容居中，可选行首图标与行尾组件（如选中勾选），
/// 选中态加粗。供睡眠定时器、速度选择器等气泡浮层菜单共用。
///
/// 行尾组件用 [Stack] 绝对定位到右侧，不会挤偏居中的标签。
class BubbleMenuRow extends StatelessWidget {
  const BubbleMenuRow({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.icon,
    this.trailing,
    this.selected = false,
  });

  /// 行文案。
  final String label;

  /// 整行点击回调。
  final VoidCallback onTap;

  /// 文案/行首图标颜色（默认 onSurface）。
  final Color? color;

  /// 行首图标（如「关闭定时」的 close）。
  final IconData? icon;

  /// 行尾组件（如选中勾选）。
  final Widget? trailing;

  /// 是否选中（加粗 + 无障碍语义）。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurface;
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
                    Icon(icon, size: 18, color: effectiveColor),
                    const SizedBox(width: AppSpacing.s),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: effectiveColor,
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

/// 气泡箭头：等腰三角，尖端指向锚点。
///
/// [direction] 为 up（浮层在上）时尖端朝下，为 down（浮层在下）时尖端朝上。
class CaretPainter extends CustomPainter {
  const CaretPainter({
    required this.caretX,
    required this.color,
    required this.direction,
    this.borderColor,
  });

  /// 尖端相对左边缘的水平位置。
  final double caretX;

  /// 三角填充色（与卡片背景同色）。
  final Color color;

  /// 箭头方向。
  final BubbleDirection direction;

  /// 两条斜边的描边色，与卡片描边一致；为 null 时不描边。
  /// 卡片描边只画在圆角矩形上，箭头需要自己描边，否则与卡片交接处会断开。
  final Color? borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    const halfWidth = 8.0;
    const borderWidth = 1.0;
    final x = caretX.clamp(halfWidth, size.width - halfWidth);
    // 底边贴卡片的一侧（up 时在上，down 时在下），尖端指向另一侧
    final baseY = direction == BubbleDirection.up ? 0.0 : size.height;
    final tipY = direction == BubbleDirection.up ? size.height : 0.0;
    final leftBase = Offset(x - halfWidth, baseY);
    final rightBase = Offset(x + halfWidth, baseY);
    final tip = Offset(x, tipY);

    final fill = Path()
      ..moveTo(leftBase.dx, leftBase.dy)
      ..lineTo(rightBase.dx, rightBase.dy)
      ..lineTo(tip.dx, tip.dy)
      ..close();
    canvas.drawPath(fill, Paint()..color = color);

    final edgeColor = borderColor;
    if (edgeColor == null) return;
    // 只描两条斜边，底边留空，由箭头覆盖卡片描边，使两者无缝相接
    final edges = Path()
      ..moveTo(leftBase.dx, leftBase.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(rightBase.dx, rightBase.dy);
    canvas.drawPath(
      edges,
      Paint()
        ..color = edgeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  bool shouldRepaint(CaretPainter old) =>
      old.caretX != caretX ||
      old.color != color ||
      old.direction != direction ||
      old.borderColor != borderColor;
}
