import 'package:flutter/material.dart';

import '../../../database/app_database.dart' as db;
import '../../../l10n/app_localizations.dart';
import '../media_trim_clip.dart';
import '../media_trim_repository.dart';
import 'media_trim_format.dart';

Future<bool> showMediaTrimDiscardDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.mediaTrimDiscardTitle),
      content: Text(l10n.mediaTrimDiscardBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.mediaTrimKeepEditing),
        ),
        TextButton(
          key: const ValueKey('trim-discard'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.mediaTrimDiscard),
        ),
      ],
    ),
  );
  return discard ?? false;
}

/// 文本输入对话框。控制器由对话框自身持有并在其 dispose 中释放，
/// 避免关闭动画期间外部提前释放（见 troubleshooting 7.53）。
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialValue,
    required this.label,
    required this.validate,
    this.hint,
    this.note,
    this.fieldKey,
    this.keyboardType,
  });

  final String title;
  final String initialValue;
  final String label;
  final String? hint;
  final String? note;
  final Key? fieldKey;
  final TextInputType? keyboardType;

  /// 返回错误文案；通过时返回 null。
  final String? Function(String value) validate;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialValue.length,
        );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = widget.validate(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: widget.fieldKey,
              controller: _controller,
              autofocus: true,
              keyboardType: widget.keyboardType,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                errorText: _error,
              ),
            ),
            if (widget.note != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('trim-dialog-confirm'),
          onPressed: _submit,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

Future<String?> showMediaTrimRenameDialog(
  BuildContext context, {
  required String currentName,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: l10n.mediaTrimRename,
      initialValue: currentName,
      label: l10n.mediaTrimClipName,
      fieldKey: const ValueKey('trim-rename-input'),
      validate: (_) => null,
    ),
  );
}

Future<Duration?> showMediaTrimTimeDialog(
  BuildContext context, {
  required MediaTrimEdge edge,
  required Duration current,
  required bool snapsToSentences,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final value = await showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: edge == MediaTrimEdge.start
          ? l10n.mediaTrimStartTime
          : l10n.mediaTrimEndTime,
      initialValue: formatTrimTime(current),
      label: edge == MediaTrimEdge.start
          ? l10n.mediaTrimStart
          : l10n.mediaTrimEnd,
      hint: l10n.mediaTrimTimeHint,
      note: snapsToSentences ? l10n.mediaTrimTimeSnapNote : null,
      fieldKey: const ValueKey('trim-time-input'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validate: (value) =>
          parseTrimTime(value) == null ? l10n.mediaTrimTimeInvalid : null,
    ),
  );
  return value == null ? null : parseTrimTime(value);
}

/// 自动分段：选择目标时长，实时预览将生成的片段数。
Future<Duration?> showMediaTrimAutoSplitDialog(
  BuildContext context, {
  required MediaTrimBoundaries boundaries,
  required int existingClipCount,
}) {
  return showDialog<Duration>(
    context: context,
    builder: (context) => _AutoSplitDialog(
      boundaries: boundaries,
      existingClipCount: existingClipCount,
    ),
  );
}

class _AutoSplitDialog extends StatefulWidget {
  const _AutoSplitDialog({
    required this.boundaries,
    required this.existingClipCount,
  });

  final MediaTrimBoundaries boundaries;
  final int existingClipCount;

  @override
  State<_AutoSplitDialog> createState() => _AutoSplitDialogState();
}

class _AutoSplitDialogState extends State<_AutoSplitDialog> {
  static const List<int> _minuteOptions = [1, 2, 3, 5, 10];

  /// 只提供比材料短的段长：不短于材料的段长只会得到一整段，没有意义。
  late final List<int> _availableMinutes = [
    for (final minutes in _minuteOptions)
      if (Duration(minutes: minutes) < widget.boundaries.total) minutes,
  ];

  /// null 表示材料不超过最短段长，无可选项。
  late int? _minutes = _initialMinutes();

  /// 默认选能切出至少两段的最长选项。
  int? _initialMinutes() {
    final total = widget.boundaries.total;
    for (final minutes in [5, 3, 2, 1]) {
      if (total >= Duration(minutes: minutes * 2)) return minutes;
    }
    return _availableMinutes.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final minutes = _minutes;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AlertDialog(
      title: Text(l10n.mediaTrimAutoSplitTitle),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (minutes == null)
              Text(
                key: const ValueKey('trim-split-too-short'),
                l10n.mediaTrimAutoSplitTooShort(_minuteOptions.first),
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              Text(
                l10n.mediaTrimAutoSplitTarget,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _availableMinutes)
                    ChoiceChip(
                      key: ValueKey('trim-split-$option'),
                      label: Text(l10n.mediaTrimMinutes(option)),
                      selected: option == minutes,
                      onSelected: (_) => setState(() => _minutes = option),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.mediaTrimAutoSplitPreview(
                  widget.boundaries
                      .autoSplit(Duration(minutes: minutes))
                      .length,
                ),
                style: theme.textTheme.titleSmall,
              ),
            ],
            if (minutes != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.boundaries.hasSentences
                    ? l10n.mediaTrimAutoSplitBySentence
                    : l10n.mediaTrimAutoSplitEqual,
                style: muted,
              ),
            ],
            if (minutes != null && widget.existingClipCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                l10n.mediaTrimAutoSplitReplace(widget.existingClipCount),
                style: muted?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('trim-split-apply'),
          onPressed: minutes == null
              ? null
              : () => Navigator.pop(context, Duration(minutes: minutes)),
          child: Text(l10n.mediaTrimApply),
        ),
      ],
    );
  }
}

/// 保存目标选择：已有本地合集或新建合集。
Future<MediaTrimDestination?> showMediaTrimSaveDialog(
  BuildContext context, {
  required int clipCount,
  required List<db.Collection> collections,
  required String? preferredCollectionId,
  required String defaultCollectionName,
  required bool isFromManagedCollection,
}) {
  return showDialog<MediaTrimDestination>(
    context: context,
    builder: (context) => _SaveDialog(
      isFromManagedCollection: isFromManagedCollection,
      clipCount: clipCount,
      collections: collections,
      preferredCollectionId: preferredCollectionId,
      defaultCollectionName: defaultCollectionName,
    ),
  );
}

class _SaveDialog extends StatefulWidget {
  const _SaveDialog({
    required this.isFromManagedCollection,
    required this.clipCount,
    required this.collections,
    required this.preferredCollectionId,
    required this.defaultCollectionName,
  });

  /// 原材料来自播客或共享合集：这类合集由来源统一管理，需提示只能存到本地合集。
  final bool isFromManagedCollection;
  final int clipCount;
  final List<db.Collection> collections;
  final String? preferredCollectionId;
  final String defaultCollectionName;

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  /// 空字符串表示「新建合集」。
  static const String _newCollection = '';

  late String _target =
      widget.collections.any((c) => c.id == widget.preferredCollectionId)
      ? widget.preferredCollectionId!
      : _newCollection;
  late final TextEditingController _name = TextEditingController(
    text: widget.defaultCollectionName,
  );
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_target != _newCollection) {
      Navigator.pop(context, MediaTrimExistingCollection(_target));
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(
        () =>
            _nameError = AppLocalizations.of(context)!
                .mediaTrimFailureCollectionName,
      );
      return;
    }
    Navigator.pop(context, MediaTrimNewCollection(name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.mediaTrimSaveTitle(widget.clipCount)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isFromManagedCollection) ...[
                Container(
                  key: const ValueKey('trim-save-local-only'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.mediaTrimSaveLocalOnly,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                key: const ValueKey('trim-save-target'),
                isExpanded: true,
                initialValue: _target,
                decoration: InputDecoration(labelText: l10n.mediaTrimSaveTo),
                items: [
                  DropdownMenuItem(
                    value: _newCollection,
                    child: Row(
                      children: [
                        const Icon(Icons.create_new_folder_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.mediaTrimNewCollection),
                      ],
                    ),
                  ),
                  for (final collection in widget.collections)
                    DropdownMenuItem(
                      value: collection.id,
                      child: Row(
                        children: [
                          const Icon(Icons.folder_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              collection.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _target = value ?? _newCollection),
              ),
              if (_target == _newCollection) ...[
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('trim-new-collection'),
                  controller: _name,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.mediaTrimCollectionName,
                    errorText: _nameError,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.mediaTrimSaveNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('trim-confirm-save'),
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
