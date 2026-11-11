/// 胶囊选择器（通用组件）
///
/// 胶囊按钮显示当前值。同一次连续触摸完成两种选择：
/// - 轻点：弹出选项浮层（标题为 [CapsuleSelector.title]），点选项即应用，点浮层外关闭。
/// - 长按滑动：按住超过长按时长后弹出浮层（提示为 [CapsuleSelector.dragHint]），
///   手指不离开屏幕上下滑动高亮选项，松手即应用。
///
/// 取消：松手时手指离开按钮与浮层的纵向范围，或没有滑动到其他选项，值保持不变。
///
/// 组件与具体业务无关：选项的文字由 [CapsuleSelector.labelOf] 生成，
/// 当前值对应的高亮下标由 [CapsuleSelector.highlightIndexOf] 决定。
/// 选项文字应保持简短，因为浮层宽度固定。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 胶囊按钮的高度；宽度由 [CapsuleSelector.size] 决定
const double _pillHeight = 36;

/// 浮层中单个选项的尺寸
const double _panelWidth = 120;
const double _optionHeight = 36;
const double _optionSpacing = 4;
const double _optionRadius = 14;

/// 浮层内边距与圆角
const double _panelHorizontalPadding = 10;
const double _panelTopPadding = 8;
const double _panelBottomPadding = 10;
const double _panelRadius = 20;

/// 浮层与按钮胶囊之间的间距
const double _panelGap = 12;

/// 浮层与屏幕左右边缘的最小距离
const double _screenMargin = 8;

/// 手指离开按钮 / 浮层纵向范围多远时视为取消
const double _cancelMargin = 48;

/// 胶囊选择器。
class CapsuleSelector<T> extends StatefulWidget {
  const CapsuleSelector({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    required this.title,
    required this.dragHint,
    this.highlightIndexOf,
    this.size = 56,
  });

  /// 当前值，胶囊上显示 [labelOf] 生成的文字
  final T value;

  /// 可选项，需按显示顺序排列（滑动方向与之对应）
  final List<T> options;

  /// 生成选项与胶囊的文字
  final String Function(T value) labelOf;

  /// 选定新值后回调；选中与当前值相同的选项时不回调
  final ValueChanged<T> onChanged;

  /// 轻点打开浮层时的标题
  final String title;

  /// 长按滑动打开浮层时的提示
  final String dragHint;

  /// 当前值在 [options] 中的高亮下标。
  /// 默认取 `options.indexOf(value)`，找不到时高亮第一项。
  final int Function(T value)? highlightIndexOf;

  /// 胶囊点击区域的边长；胶囊宽度与之相同，高度固定
  final double size;

  @override
  State<CapsuleSelector<T>> createState() => _CapsuleSelectorState<T>();
}

class _CapsuleSelectorState<T> extends State<CapsuleSelector<T>> {
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey _rowKey = GlobalKey();
  final ValueNotifier<int> _highlightedIndex = ValueNotifier<int>(0);

  OverlayEntry? _panelEntry;
  Timer? _longPressTimer;

  /// 长按已触发，当前触摸处于滑动选择中
  bool _isDragging = false;

  /// 滑动过程中高亮过其他选项；没有滑动就松手时不改变值
  bool _hasSlid = false;

  /// 手指正按在按钮上，用于按压态背景
  bool _isPressed = false;

  /// 当前驱动这次触摸的手指。多指触摸时只响应第一根手指，其余手指一律忽略。
  int? _activePointer;

  bool get _isPanelOpen => _panelEntry != null;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    // 组件销毁时不能再 setState，直接移除浮层即可。
    _panelEntry?.remove();
    _panelEntry = null;
    _highlightedIndex.dispose();
    super.dispose();
  }

  /// 当前值对应的高亮下标，找不到或越界时取第一项。
  int _indexOfValue() {
    final index =
        widget.highlightIndexOf?.call(widget.value) ??
        widget.options.indexOf(widget.value);
    return index < 0 ? 0 : index.clamp(0, widget.options.length - 1);
  }

  void _handlePointerDown(PointerDownEvent event) {
    // 已有手指在操作时，忽略额外按下的手指，避免覆盖计时器或误结束拖动。
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    setState(() => _isPressed = true);
    // 浮层打开时由遮罩接管点击，这里不会收到事件；防御性地直接忽略。
    if (_isPanelOpen) return;
    _longPressTimer = Timer(kLongPressTimeout, _startDragging);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    if (!_isDragging) return;
    final index = _optionIndexForDrag(event.position);
    if (index == _highlightedIndex.value) return;
    _highlightedIndex.value = index;
    _hasSlid = true;
    unawaited(HapticFeedback.selectionClick());
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _longPressTimer?.cancel();
    _longPressTimer = null;
    setState(() => _isPressed = false);
    if (_isDragging) {
      _isDragging = false;
      final isCancelled = _isFarFromControl(event.position.dy);
      if (!isCancelled && _hasSlid) {
        _applyIndex(_highlightedIndex.value);
      }
      _removePanel();
      return;
    }
    // 未达到长按时长即松手：轻点，打开浮层等待选择。
    if (!_isPanelOpen) _showPanel(isDragMode: false);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _isDragging = false;
    setState(() => _isPressed = false);
    _removePanel();
  }

  void _startDragging() {
    _longPressTimer = null;
    _isDragging = true;
    _hasSlid = false;
    _showPanel(isDragMode: true);
  }

  void _selectOption(int index) {
    _applyIndex(index);
    _removePanel();
  }

  void _applyIndex(int index) {
    final option = widget.options[index];
    if (option == widget.value) return;
    widget.onChanged(option);
  }

  /// 指针进入选项列表后按实际命中行高亮；在列表外保持当前高亮项。
  int _optionIndexForDrag(Offset globalPosition) {
    final listBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (listBox != null) {
      final localPosition = listBox.globalToLocal(globalPosition);
      if (localPosition.dx >= 0 &&
          localPosition.dx <= listBox.size.width &&
          localPosition.dy >= 0 &&
          localPosition.dy <= listBox.size.height) {
        final optionPitch = _optionHeight + _optionSpacing;
        final index = ((localPosition.dy - _optionHeight / 2) / optionPitch)
            .round();
        return index.clamp(0, widget.options.length - 1);
      }
    }

    return _highlightedIndex.value;
  }

  /// 手指纵向离开按钮与浮层范围即视为取消。
  bool _isFarFromControl(double globalDy) {
    final buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return true;
    final buttonTop = buttonBox.localToGlobal(Offset.zero).dy;
    final buttonBottom = buttonTop + buttonBox.size.height;
    final rowBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final panelTop = rowBox == null
        ? buttonTop
        : rowBox.localToGlobal(Offset.zero).dy;
    return globalDy < panelTop - _cancelMargin ||
        globalDy > buttonBottom + _cancelMargin;
  }

  void _showPanel({required bool isDragMode}) {
    if (_isPanelOpen) return;
    final buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return;
    final buttonTopLeft = buttonBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.sizeOf(context);
    final panelWidth = math.min(
      _panelWidth,
      screenSize.width - _screenMargin * 2,
    );
    final optionWidth = panelWidth - _panelHorizontalPadding * 2;
    final buttonCenterX = buttonTopLeft.dx + buttonBox.size.width / 2;
    // 浮层水平居中于按钮，但不超出屏幕两侧。
    final left = math.min(
      math.max(buttonCenterX - panelWidth / 2, _screenMargin),
      screenSize.width - panelWidth - _screenMargin,
    );
    // 浮层底部贴着胶囊顶部，留出箭头与间距。
    final pillTop =
        buttonTopLeft.dy + (buttonBox.size.height - _pillHeight) / 2;
    final desiredPanelHeight =
        _panelTopPadding +
        _panelBottomPadding +
        widget.options.length * _optionHeight +
        (widget.options.length - 1) * _optionSpacing;
    final panelHeight = math.min(
      desiredPanelHeight,
      math.max(0.0, pillTop - _panelGap - _screenMargin),
    );
    if (panelHeight == 0) return;
    final bottom = screenSize.height - pillTop + _panelGap;
    final labels = [
      for (final option in widget.options) widget.labelOf(option),
    ];

    _highlightedIndex.value = _indexOfValue();
    _panelEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          // 轻点模式：遮罩点击浮层外部即关闭。
          // 滑动模式：吞掉命中测试，避免手指经过的按钮出现悬浮反馈（松手也不会误触它们）。
          Positioned.fill(
            child: isDragMode
                ? const AbsorbPointer()
                : GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _removePanel,
                  ),
          ),
          Positioned(
            left: left,
            bottom: bottom,
            child: _CapsulePanel(
              width: panelWidth,
              height: panelHeight,
              optionWidth: optionWidth,
              rowKey: _rowKey,
              labels: labels,
              highlightedIndex: _highlightedIndex,
              onSelect: _selectOption,
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_panelEntry!);
    setState(() {});
  }

  void _removePanel() {
    _panelEntry?.remove();
    _panelEntry = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 默认无底色，与导航按钮一致；按压用中性底色，激活（浮层打开）用主题主色。
    final isActive = _isPanelOpen;
    final Color? pillColor = isActive
        ? colorScheme.primary
        : _isPressed
        ? colorScheme.surfaceContainerHighest
        : null;
    // 空闲时与两侧导航图标一样用 60% 透明度的灰色，避免比主按钮还醒目。
    final Color textColor = isActive
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: 0.6);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: Semantics(
        button: true,
        label: widget.title,
        hint: widget.dragHint,
        child: SizedBox.square(
          key: _buttonKey,
          dimension: widget.size,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(_pillHeight / 2),
              ),
              child: SizedBox(
                width: widget.size,
                height: _pillHeight,
                child: Center(
                  child: Text(
                    widget.labelOf(widget.value),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
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

/// 选项浮层：标题与当前高亮选项在上，选项纵向排列在下，底部带指向按钮的箭头。
class _CapsulePanel extends StatelessWidget {
  const _CapsulePanel({
    required this.width,
    required this.height,
    required this.optionWidth,
    required this.rowKey,
    required this.labels,
    required this.highlightedIndex,
    required this.onSelect,
  });

  final double width;
  final double height;
  final double optionWidth;
  final GlobalKey rowKey;
  final List<String> labels;
  final ValueListenable<int> highlightedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: colorScheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_panelRadius),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _panelHorizontalPadding,
            _panelTopPadding,
            _panelHorizontalPadding,
            _panelBottomPadding,
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: highlightedIndex,
            builder: (context, highlighted, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView.separated(
                      key: rowKey,
                      padding: EdgeInsets.zero,
                      itemCount: labels.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: _optionSpacing),
                      itemBuilder: (context, index) => _CapsuleOption(
                        width: optionWidth,
                        label: labels[index],
                        isHighlighted: index == highlighted,
                        onTap: () => onSelect(index),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CapsuleOption extends StatelessWidget {
  const _CapsuleOption({
    required this.width,
    required this.label,
    required this.isHighlighted,
    required this.onTap,
  });

  final double width;
  final String label;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isHighlighted
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    final borderRadius = BorderRadius.circular(_optionRadius);
    // Ink 承载选中态的填充，InkWell 的悬浮 / 按压高亮叠在其上，选中项同样有反馈。
    return Ink(
      decoration: BoxDecoration(
        color: isHighlighted ? colorScheme.primary : null,
        borderRadius: borderRadius,
      ),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        hoverColor: foreground.withValues(alpha: 0.08),
        highlightColor: foreground.withValues(alpha: 0.12),
        child: SizedBox(
          width: width,
          height: _optionHeight,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
