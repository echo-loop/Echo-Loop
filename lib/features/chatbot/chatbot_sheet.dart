/// 以 bottom sheet 打开 chatbot。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'models/chatbot_config.dart';
import 'providers/chat_session_controller.dart';
import 'widgets/chat_header_actions.dart';
import 'widgets/chat_view.dart';

/// 以 bottom sheet 打开 chatbot（命名参数，对齐项目 showXxxSheet 惯例）。
///
/// 默认高度 80% 屏高，可拖 header 拉高/拉低（夹在 40%~95%），下拉过阈值即关闭
/// （手感参考查词面板 `dictionary_panel.dart`）。不用 DraggableScrollableSheet
/// （其 scrollController 与 ChatMessageList 自己的贴底/回底 controller 结构性冲突）；
/// 也关掉内建整体下拉（enableDrag:false），关闭统一由 header 手势接管。controller
/// 保活常驻（keepAlive），关面板不再销毁 → 内容保留、重开续上；关闭时显式调 [stop]
/// 中断在途流并保留已生成部分（省后端 token），不再依赖 autoDispose 自动取消。
Future<void> showChatbotSheet({
  required BuildContext context,
  required ChatbotConfig config,
}) async {
  // 关面板前先拿 container：await 后 context 虽仍有效，此处一次性读更稳。
  final container = ProviderScope.containerOf(context, listen: false);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // 内建整体下拉关闭会与自定义 header 拖拽调高冲突，关掉后由 header 手势统一接管。
    enableDrag: false,
    // 与 ChatView / composer 同底色（scheme.surface）：消除 sheet 默认 _sheetBlack
    // 灰块与近黑底栏的倒挂接缝，整个面板明暗两套皆统一底色。
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ChatbotSheetBody(config: config),
  );
  // 关面板即停在途流：保活下 controller 不销毁，需显式中断，保留已生成部分为 done。
  container.read(chatSessionControllerProvider(config).notifier).stop();
}

/// sheet 内容：可拖拽调高、把手 + 标题 + 新会话 + ChatView。
///
/// 高度/下拉关闭手势照搬查词面板（[dictionary_panel] 的 `_onHandleDrag*`）：默认 80%，
/// 上拉放大（≤95%）、下拉缩小（≥40%），下拉过 [_kDismissOverdrag] 即关闭。
class _ChatbotSheetBody extends StatefulWidget {
  const _ChatbotSheetBody({required this.config});

  final ChatbotConfig config;

  @override
  State<_ChatbotSheetBody> createState() => _ChatbotSheetBodyState();
}

class _ChatbotSheetBodyState extends State<_ChatbotSheetBody> {
  ChatbotConfig get config => widget.config;

  /// 当前面板高度（像素）；null = 用默认 3/5。用户拖 header 调整。
  double? _sheetHeight;

  /// 拖拽过程中的「逻辑高度」（仅手势期间有值，可低于下限，记录手指真实位置）。
  /// 渲染用的 [_sheetHeight] 夹在下限上不真的缩更小；本值低于下限即「关闭意图」。
  double? _dragLogicalHeight;

  /// 触发下滑关闭的 overdrag 阈值（像素）：低于下限再多拉这么多即关闭。
  static const double _kDismissOverdrag = 80;

  /// 高度下限：屏高 40%
  double get _minSheetHeight => MediaQuery.sizeOf(context).height * 0.4;

  /// 高度上限：屏高 95%
  double get _maxSheetHeight => MediaQuery.sizeOf(context).height * 0.95;

  /// 默认高度：屏高 80%
  double get _defaultSheetHeight => MediaQuery.sizeOf(context).height * 0.8;

  /// 拖拽开始：以当前高度初始化逻辑高度。
  void _onHandleDragStart(DragStartDetails details) {
    _dragLogicalHeight = _sheetHeight ?? _defaultSheetHeight;
  }

  /// 拖拽 header 调高：上拉（delta.dy<0）放大、下拉缩小。逻辑高度可低于下限。
  void _onHandleDrag(DragUpdateDetails details) {
    final base = _dragLogicalHeight ?? _sheetHeight ?? _defaultSheetHeight;
    final logical = (base - details.delta.dy).clamp(0.0, _maxSheetHeight);
    _dragLogicalHeight = logical;
    setState(() {
      _sheetHeight = logical.clamp(_minSheetHeight, _maxSheetHeight).toDouble();
    });
  }

  /// 拖拽结束：逻辑高度低于下限超阈值（下拉到底再继续拉）则关闭面板。
  void _onHandleDragEnd(DragEndDetails details) {
    final logical = _dragLogicalHeight ?? _minSheetHeight;
    _dragLogicalHeight = null;
    if (_minSheetHeight - logical > _kDismissOverdrag && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('chat_sheet_sizer'),
      height: _sheetHeight ?? _defaultSheetHeight,
      child: Column(
        children: [
          // 把手 + 标题行整段作拖拽面（拉高/拉低/下拉关闭）；行内按钮靠手势竞技场
          // 区分（纯 tap→按钮、竖直移动→拖拽），同查词面板。
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _onHandleDragStart,
            onVerticalDragUpdate: _onHandleDrag,
            onVerticalDragEnd: _onHandleDragEnd,
            child: _dragHandleArea(context),
          ),
          const Divider(height: 1),
          // 键盘只浮输入框：不再整块上推，仅内容区底部让出键盘高度 → composer 浮到
          // 键盘上方、消息区收缩，header/把手固定不动。
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ChatView(config: config),
            ),
          ),
        ],
      ),
    );
  }

  /// 把手 + 标题 + 新会话按钮（拖拽面内容）。
  Widget _dragHandleArea(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 顶部把手
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        _header(context),
      ],
    );
  }

  /// 标题 + 新会话按钮。
  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.m),
      child: Row(
        children: [
          Expanded(
            child: Text(
              config.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ChatNewChatButton(config: config),
          const SizedBox(width: AppSpacing.s),
        ],
      ),
    );
  }
}
