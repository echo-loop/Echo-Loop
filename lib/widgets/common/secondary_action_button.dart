import 'package:flutter/material.dart';


/// 底部操作区的低强调按钮。
///
/// 用于和主按钮并排的“返回 / 跳过 / 取消下载”等次要操作。
/// 保留弱化底色和描边，避免看起来像普通文本。
class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      // 宽度随文字自适应，文字过长时换行而不是截断
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
