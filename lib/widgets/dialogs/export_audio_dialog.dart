/// 音频导出选项对话框
///
/// 允许用户选择导出音频文件、字幕文件或两者。
/// 返回 [ExportAudioSelection] 表示用户选择，取消时返回 null。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 导出选择结果
class ExportAudioSelection {
  /// 是否包含音频文件
  final bool includeAudio;

  /// 是否包含字幕文件
  final bool includeTranscript;

  const ExportAudioSelection({
    required this.includeAudio,
    required this.includeTranscript,
  });
}

/// 显示音频导出选项对话框
///
/// [hasTranscript] 为 false 时，字幕选项置灰不可选。
/// 返回用户的导出选择，取消时返回 null。
Future<ExportAudioSelection?> showExportAudioDialog({
  required BuildContext context,
  required bool hasTranscript,
}) {
  return showDialog<ExportAudioSelection>(
    context: context,
    builder: (ctx) => _ExportAudioDialogContent(hasTranscript: hasTranscript),
  );
}

class _ExportAudioDialogContent extends StatefulWidget {
  final bool hasTranscript;

  const _ExportAudioDialogContent({required this.hasTranscript});

  @override
  State<_ExportAudioDialogContent> createState() =>
      _ExportAudioDialogContentState();
}

class _ExportAudioDialogContentState extends State<_ExportAudioDialogContent> {
  bool _includeAudio = false;
  late bool _includeTranscript = widget.hasTranscript;

  bool get _canExport => _includeAudio || _includeTranscript;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.exportAudio),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.exportSelectFiles,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ExportOptionTile(
                  label: l10n.exportAudioFile,
                  checked: _includeAudio,
                  onChanged: (v) => setState(() => _includeAudio = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ExportOptionTile(
                  label: l10n.exportSubtitleFile,
                  checked: _includeTranscript,
                  enabled: widget.hasTranscript,
                  onChanged: (v) => setState(() => _includeTranscript = v),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _canExport
              ? () => Navigator.pop(
                  context,
                  ExportAudioSelection(
                    includeAudio: _includeAudio,
                    includeTranscript: _includeTranscript,
                  ),
                )
              : null,
          child: Text(l10n.exportAudio),
        ),
      ],
    );
  }
}

/// 导出选项行 — 紧凑的 checkbox + 图标 + 文字布局
class _ExportOptionTile extends StatelessWidget {
  final String label;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ExportOptionTile({
    required this.label,
    required this.checked,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = enabled ? 1.0 : 0.4;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: checked
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => onChanged(!checked) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: checked,
                    onChanged: enabled ? (v) => onChanged(v ?? false) : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: checked
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
