/// 收藏导出选项弹窗：勾选要导出的句子 / 词汇
///
/// 数量为 0 的类别禁用且默认不勾选；两类都未勾选时不能确认。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/favorites_export/favorites_export_options.dart';

/// 打开导出选项弹窗，确认返回选项，取消返回 null
Future<FavoritesExportOptions?> showFavoritesExportDialog(
  BuildContext context, {
  required int sentenceCount,
  required int wordCount,
}) {
  return showDialog<FavoritesExportOptions>(
    context: context,
    builder: (_) => _FavoritesExportDialog(
      sentenceCount: sentenceCount,
      wordCount: wordCount,
    ),
  );
}

class _FavoritesExportDialog extends StatefulWidget {
  final int sentenceCount;
  final int wordCount;

  const _FavoritesExportDialog({
    required this.sentenceCount,
    required this.wordCount,
  });

  @override
  State<_FavoritesExportDialog> createState() => _FavoritesExportDialogState();
}

class _FavoritesExportDialogState extends State<_FavoritesExportDialog> {
  late FavoritesExportOptions _options = FavoritesExportOptions(
    includeSentences: widget.sentenceCount > 0,
    includeWords: widget.wordCount > 0,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.favoritesExportDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              l10n.favoritesExportSentencesOption(widget.sentenceCount),
            ),
            value: _options.includeSentences,
            onChanged: widget.sentenceCount > 0
                ? (value) => setState(() {
                    _options = _options.copyWith(includeSentences: value);
                  })
                : null,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.favoritesExportWordsOption(widget.wordCount)),
            value: _options.includeWords,
            onChanged: widget.wordCount > 0
                ? (value) => setState(() {
                    _options = _options.copyWith(includeWords: value);
                  })
                : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _options.hasContent
              ? () => Navigator.pop(context, _options)
              : null,
          child: Text(l10n.favoritesExportConfirm),
        ),
      ],
    );
  }
}
