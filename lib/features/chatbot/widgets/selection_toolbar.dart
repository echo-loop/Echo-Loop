/// 选区气泡操作条：三端一致的横向灰色圆角胶囊，浮在选区上方（空间不足翻到下方）。
///
/// 独立、可复用：不与「聊天/markdown」耦合，任何走 Flutter 文本选择（`SelectionArea`
/// / `SelectableRegion` 的 `contextMenuBuilder`）的场景都可复用。传入选区锚点
/// （[TextSelectionToolbarAnchors]）与若干动作项（[SelectionToolbarAction]）即可。
///
/// 为何用 [CupertinoTextSelectionToolbar] 而非 [AdaptiveTextSelectionToolbar]：
/// 后者在 macOS 桌面自适应为纵向下拉菜单；前者三端一致渲染为横向胶囊（气泡感，带竖
/// 分隔线、自动明暗适配、自动处理锚点上/下溢出），即目标样式。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 选区操作条的单个动作项：文案 + 点击回调。
class SelectionToolbarAction {
  const SelectionToolbarAction({required this.label, required this.onPressed});

  /// 按钮文案（已本地化）。
  final String label;

  /// 点击回调。
  final VoidCallback onPressed;
}

/// 选区气泡操作条。
///
/// - [anchors]：选区锚点，来自 `SelectableRegionState.contextMenuAnchors`；
/// - [actions]：动作项列表（如「复制」「问 AI」），按顺序横向排布、以竖线分隔。
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    super.key,
    required this.anchors,
    required this.actions,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<SelectionToolbarAction> actions;

  /// 气泡与选中文字的间隔微调（像素）：把锚点朝文字方向收拢，让箭头更贴近选区。
  ///
  /// [CupertinoTextSelectionToolbar] 在锚点外还有固定内距 + 箭头，默认间隔偏大；
  /// 这里把上方锚点下移、下方锚点上移各 [_kAnchorInset] 像素以收紧观感。
  static const double _kAnchorInset = 8;
  static const double _kButtonHorizontalPadding = 16;
  static const double _kButtonVerticalPadding = 9;
  static const double _kButtonFontSize = 15;
  static const double _kButtonMinWidth = 72;

  /// 按「选区几何」计算锚点：气泡居中浮在选区上方（间隔已收紧，见 [_kAnchorInset]）。
  ///
  /// 不直接用 [SelectableRegionState.contextMenuAnchors]——后者在**右键**触发时返回
  /// 鼠标点击位置（导致气泡贴在点击处而非选区中间）；这里始终从选区端点几何算出，
  /// 桌面右键 / 移动长按均居中于选区上方。
  static TextSelectionToolbarAnchors anchorsForSelection(
    SelectableRegionState state,
  ) {
    final renderObject = state.context.findRenderObject();
    if (renderObject is! RenderBox) return state.contextMenuAnchors;
    final anchors = TextSelectionToolbarAnchors.fromSelection(
      renderBox: renderObject,
      startGlyphHeight: state.startGlyphHeight,
      endGlyphHeight: state.endGlyphHeight,
      selectionEndpoints: state.selectionEndpoints,
    );
    // 上方锚点下移、下方锚点上移，收紧气泡与文字的间隔。
    return TextSelectionToolbarAnchors(
      primaryAnchor: anchors.primaryAnchor.translate(0, _kAnchorInset),
      secondaryAnchor: anchors.secondaryAnchor?.translate(0, -_kAnchorInset),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonWidth = _evenButtonWidth(context);
    return CupertinoTextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      children: [
        for (final action in actions)
          _SelectionToolbarButton(
            key: ValueKey('selection_toolbar_button_${action.label}'),
            text: action.label,
            width: buttonWidth,
            onPressed: action.onPressed,
          ),
      ],
    );
  }

  /// 按最长文案统一按钮宽度，避免「复制 / 问 AI」这类短长文案让分割线偏移。
  double _evenButtonWidth(BuildContext context) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    var maxTextWidth = 0.0;
    for (final action in actions) {
      final painter = TextPainter(
        text: TextSpan(
          text: action.label,
          style: const TextStyle(fontSize: _kButtonFontSize),
        ),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      maxTextWidth = maxTextWidth < painter.width
          ? painter.width
          : maxTextWidth;
    }
    final contentWidth = maxTextWidth + _kButtonHorizontalPadding * 2;
    return contentWidth < _kButtonMinWidth ? _kButtonMinWidth : contentWidth;
  }
}

/// 选区操作条按钮：矮身 + 悬浮/按压背景反馈（桌面鼠标 + 移动点按皆适用）。
///
/// 竖直内边距 9（比原生 18 更矮、更贴气泡感）；悬浮/按压时叠加半透明底色，色随明暗
/// 主题取黑或白。父级 [CupertinoTextSelectionToolbar] 胶囊已裁剪圆角，首末按钮高亮
/// 自动跟随圆角。
class _SelectionToolbarButton extends StatefulWidget {
  const _SelectionToolbarButton({
    super.key,
    required this.text,
    required this.width,
    required this.onPressed,
  });

  final String text;
  final double width;
  final VoidCallback onPressed;

  @override
  State<_SelectionToolbarButton> createState() =>
      _SelectionToolbarButtonState();
}

class _SelectionToolbarButtonState extends State<_SelectionToolbarButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final tint = isDark ? CupertinoColors.white : CupertinoColors.black;
    final overlayAlpha = _pressed ? 0.16 : (_hovered ? 0.08 : 0.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        // 直接约束按钮本体宽度，不用 Expanded/Align 撑满父约束，避免 toolbar 误判换页。
        child: Container(
          width: widget.width,
          alignment: Alignment.center,
          color: tint.withValues(alpha: overlayAlpha),
          padding: const EdgeInsets.symmetric(
            horizontal: SelectionToolbar._kButtonHorizontalPadding,
            vertical: SelectionToolbar._kButtonVerticalPadding,
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: SelectionToolbar._kButtonFontSize,
              color: tint,
            ),
          ),
        ),
      ),
    );
  }
}
