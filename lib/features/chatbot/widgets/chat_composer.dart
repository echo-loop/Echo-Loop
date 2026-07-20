/// 输入条：多行自适应 TextField + 发送/停止切换按钮。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// 前端字符上限（兜底，后端仍会截断）。
const int _maxChars = 4000;

/// 发送按钮亮蓝色（对齐 ChatGPT 风格，iOS 系统蓝）。
const Color _sendBlue = Color(0xFF0A84FF);

/// 发送/停止按钮尺寸与图标大小（比 Material 默认略小）。
const double _buttonSize = 28;
const double _buttonIconSize = 18;

/// 输入条。
/// - 语音插槽：预留 leading 区（本次不实现）；未来语音转文字结果回填输入框后仍走
///   onSend，契约不变。
/// - 键盘行为：移动端 IME 显示「换行」键（点击换行）；桌面/硬键盘（本项目支持
///   macOS）Enter=发送、Shift+Enter=换行。发送只经发送按钮或桌面 Enter。
/// - 空文本或未在流式时按钮为「发送」（空文本禁用）；流式中按钮为「停止」。
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.placeholder,
    required this.isStreaming,
    required this.onSend,
    required this.onStop,
    this.focusNode,
    this.attachedTop = false,
  });

  final String placeholder;
  final bool isStreaming;
  final Future<void> Function(String text) onSend;
  final VoidCallback onStop;

  /// 上方是否紧接引用条：为 true 时取消顶部留白与上方两角圆角，
  /// 使输入框与引用条无缝衔接成同一块。
  final bool attachedTop;

  /// 外部传入的焦点（用于「追问」后 requestFocus 弹键盘）；不传则内部自建。
  final FocusNode? focusNode;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _controller = TextEditingController();

  /// 焦点：优先用外部传入（谁创建谁销毁），否则内部自建并在 dispose 销毁。
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool get _ownsFocusNode => widget.focusNode == null;
  bool _hasText = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // 键处理直接挂在 TextField 自己的 FocusNode 上，避免额外包一层 Focus
    // 造成两个焦点节点、硬件键盘事件被重复派发（"physical key already pressed"）。
    _focusNode.onKeyEvent = _onKeyEvent;
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    // 外部传入的焦点由外部销毁，仅销毁自建的。
    if (_ownsFocusNode) {
      _focusNode.dispose();
    } else {
      _focusNode.onKeyEvent = null; // 归还前解绑，避免悬挂回调。
    }
    super.dispose();
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  /// 发送：清空输入框、期间禁用发送键。
  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || widget.isStreaming) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await widget.onSend(text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 桌面/硬键盘：Enter 发送、Shift+Enter 换行。
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    final shiftDown =
        HardwareKeyboard.instance.isShiftPressed; // Shift+Enter → 换行
    if (shiftDown) return KeyEventResult.ignored;
    _handleSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSend = _hasText && !_sending && !widget.isStreaming;

    // 输入 pill 底色回到与背景统一（亮=白/surface，暗=分级灰）；不靠填色区分，而是
    // 用一层柔和阴影把输入框从统一背景中「抬起」，更显眼（对齐参考图的浮起 pill）。
    final fieldColor = isDark ? scheme.surfaceContainerHigh : Colors.white;
    // 边框弱化（与引用区同透明度）：连着引用区时其顶边与引用区底边同位重叠成一条细线。
    final fieldBorder = isDark
        ? Colors.transparent
        : scheme.outlineVariant.withValues(alpha: 0.35);
    // 柔和投影仅在独立输入（无引用区）时启用：连着引用区时若加阴影，会在引用/输入
    // 交界处向上晕出一道灰带、破坏「紧密相连、平滑过度」。暗色黑投影不可见。
    final fieldShadow = widget.attachedTop
        ? const <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ];

    // ChatGPT 风格：一整条浅灰 pill 占满宽度，左右留较大边距、底部留白避免贴底。
    return Container(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          // 连着引用条时顶部留白归零，两块无缝相接。
          padding: EdgeInsets.only(
            left: AppSpacing.m,
            right: AppSpacing.m,
            top: widget.attachedTop ? 0 : AppSpacing.s,
            bottom: AppSpacing.m,
          ),
          child: Container(
            // 固定圆角（不随高度变全 pill），按钮四周留 s 边距避开右下圆角弧线。
            padding: const EdgeInsets.all(
              AppSpacing.s,
            ).copyWith(left: AppSpacing.m),
            decoration: BoxDecoration(
              color: fieldColor,
              border: Border.all(color: fieldBorder),
              boxShadow: fieldShadow,
              // 连着引用条时取消上方两角圆角，仅保留下方两角。
              borderRadius: widget.attachedTop
                  ? const BorderRadius.vertical(
                      bottom: Radius.circular(AppSpacing.l),
                    )
                  : BorderRadius.circular(AppSpacing.l),
            ),
            child: Row(
              // 垂直居中：单行时文字与发送按钮都在 pill 正中；多行增高时同步居中。
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    // 输入字号收窄一号（默认 bodyLarge 16 偏大），更贴近聊天输入观感。
                    style: const TextStyle(fontSize: 15, height: 1.3),
                    // 移动端键盘显示「换行」键；桌面 Enter 发送由 [_onKeyEvent] 处理。
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    cursorColor: _sendBlue, // 光标与发送按钮同色
                    // 点输入框以外任意处（消息区/标题/把手/空白）失焦并收键盘，
                    // 输入框本身照常输入（对齐登录页 onTapOutside 惯例）。
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxChars),
                    ],
                    decoration: InputDecoration(
                      hintText: widget.placeholder,
                      // placeholder 弱化：取更浅的 outline 色再降透明度，避免抢眼。
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: scheme.outline.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                _buildActionButton(context, l10n, canSend),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 发送 / 停止 切换按钮。
  Widget _buildActionButton(
    BuildContext context,
    AppLocalizations l10n,
    bool canSend,
  ) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.isStreaming) {
      return IconButton.filled(
        tooltip: l10n.chatStop,
        onPressed: widget.onStop,
        iconSize: _buttonIconSize,
        icon: const Icon(Icons.stop),
        style: IconButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
          minimumSize: const Size.square(_buttonSize),
          maximumSize: const Size.square(_buttonSize),
          padding: EdgeInsets.zero,
          // 去掉默认 48dp 触摸目标留白，否则会把整条输入 pill 撑高（移动端尤明显）。
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return IconButton.filled(
      tooltip: l10n.chatSend,
      onPressed: canSend ? _handleSend : null,
      iconSize: _buttonIconSize,
      icon: const Icon(Icons.arrow_upward),
      style: IconButton.styleFrom(
        // 亮蓝发送按钮（对齐 ChatGPT 风格），不用 Material 默认偏暗的 primary。
        backgroundColor: _sendBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _sendBlue.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.square(_buttonSize),
        maximumSize: const Size.square(_buttonSize),
        padding: EdgeInsets.zero,
        // 去掉默认 48dp 触摸目标留白，否则会把整条输入 pill 撑高（移动端尤明显）。
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
