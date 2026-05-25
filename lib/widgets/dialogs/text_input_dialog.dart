/// 文本输入通用对话框
///
/// 合并了音频重命名、合集重命名、创建合集等场景。
/// 提供带验证的文本输入框 + 确认/取消按钮。
library;

import 'package:flutter/material.dart';

/// 显示文本输入对话框
///
/// 返回用户输入的文本（已 trim），取消时返回 `null`。
///
/// [title] 对话框标题。
/// [labelText] 输入框标签。
/// [hintText] 输入框提示文本（可选）。
/// [initialValue] 初始值（可选）。
/// [confirmLabel] 确认按钮文本。
/// [cancelLabel] 取消按钮文本。
/// [validator] 自定义验证函数，返回错误消息或 null。
Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  required String labelText,
  String? hintText,
  String? initialValue,
  required String confirmLabel,
  required String cancelLabel,
  String? Function(String)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _TextInputDialog(
      title: title,
      labelText: labelText,
      hintText: hintText,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      validator: validator,
    ),
  );
}

/// 文本输入对话框组件（内部使用 StatefulWidget 管理输入状态）
class _TextInputDialog extends StatefulWidget {
  final String title;
  final String labelText;
  final String? hintText;
  final String? initialValue;
  final String confirmLabel;
  final String cancelLabel;
  final String? Function(String)? validator;

  const _TextInputDialog({
    required this.title,
    required this.labelText,
    this.hintText,
    this.initialValue,
    required this.confirmLabel,
    required this.cancelLabel,
    this.validator,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 验证并提交
  void _submit() {
    final text = _controller.text.trim();

    // 有自定义验证器时由验证器决定是否允许提交
    if (widget.validator != null) {
      final error = widget.validator!(text);
      if (error != null) {
        setState(() => _errorText = error);
        return;
      }
    } else if (text.isEmpty) {
      // 无验证器时默认拒绝空值
      return;
    }

    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, textAlign: TextAlign.center),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
        onChanged: (_) {
          setState(() {
            // 清除之前的错误 + 刷新按钮状态
            _errorText = null;
          });
        },
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.cancelLabel),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _controller.text.trim().isEmpty ? null : _submit,
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
