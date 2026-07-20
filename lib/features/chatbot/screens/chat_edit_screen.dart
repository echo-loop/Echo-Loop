/// 聊天消息编辑页（全屏）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// 前端字符上限（兜底，与输入条一致）。
const int _maxChars = 4000;

/// 独立的消息编辑页：预填原文，用户改完点发送才提交。
///
/// - X 关闭：返回 null（取消，不改会话）；
/// - 发送：返回编辑后的文本（非空），由调用方截断该轮并重发。
///
/// 只负责「拿到编辑后的文本」，不感知会话状态；截断/重发在调用方（ChatView）编排。
class ChatEditScreen extends StatefulWidget {
  const ChatEditScreen({super.key, required this.initialText});

  /// 待编辑的原始文本。
  final String initialText;

  @override
  State<ChatEditScreen> createState() => _ChatEditScreenState();
}

class _ChatEditScreenState extends State<ChatEditScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  final FocusNode _focusNode = FocusNode();
  bool _hasText = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // 进入即聚焦并把光标置于末尾。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  /// 提交编辑：把文本回传给调用方（非空才有效）。
  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.chatEditTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.m,
            right: AppSpacing.m,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.m,
          ),
          child: Column(
            children: [const Spacer(), _buildInputBar(context, l10n)],
          ),
        ),
      ),
    );
  }

  /// 底部输入条：预填文本 + 发送按钮。
  Widget _buildInputBar(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            minLines: 1,
            maxLines: 8,
            inputFormatters: [LengthLimitingTextInputFormatter(_maxChars)],
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.filled(
              tooltip: l10n.chatSend,
              onPressed: _hasText ? _submit : null,
              icon: const Icon(Icons.arrow_upward),
            ),
          ),
        ],
      ),
    );
  }
}
