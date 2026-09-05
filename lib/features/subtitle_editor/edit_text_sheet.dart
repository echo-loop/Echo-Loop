import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 显示编辑句子文本的底部面板。
///
/// 返回修改后的文本（已 trim），取消时返回 `null`。
Future<String?> showEditTextSheet({
  required BuildContext context,
  required int sentenceIndex,
  required String initialText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _EditTextSheet(
      sentenceIndex: sentenceIndex,
      initialText: initialText,
    ),
  );
}

class _EditTextSheet extends StatefulWidget {
  final int sentenceIndex;
  final String initialText;

  const _EditTextSheet({
    required this.sentenceIndex,
    required this.initialText,
  });

  @override
  State<_EditTextSheet> createState() => _EditTextSheetState();
}

class _EditTextSheetState extends State<_EditTextSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽指示条
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.m),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 标题
              Text(
                l10n.editSentenceTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.m),

              // 输入框
              TextField(
                controller: _controller,
                autofocus: true,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.25,
                ),
                decoration: InputDecoration(
                  labelText: l10n.editSentenceLabel,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  floatingLabelStyle: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                onSubmitted: (_) => _submit(),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: AppSpacing.m),

              // 按钮行
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _controller.text.trim().isEmpty ? null : _submit,
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
