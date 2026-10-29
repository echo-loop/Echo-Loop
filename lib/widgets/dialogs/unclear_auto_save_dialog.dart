/// 「听不太懂」自动收藏说明弹窗
///
/// 用户第一次在精听中点「听不太懂」、进入讲解页之前弹出，说明该操作会自动收藏句子，
/// 并提供快捷开关直接修改 [LearningSettings.autoSaveOnUnclear]。
/// 弹窗不可点外部关闭，确保一次展示后必定由调用方记录「已提示」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/learning_settings_provider.dart';
import '../../theme/app_theme.dart';

/// 展示「听不太懂」自动收藏说明弹窗，关闭后返回。
Future<void> showUnclearAutoSaveDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const UnclearAutoSaveDialog(),
  );
}

/// 说明弹窗本体。开关状态直接读写学习设置，切换即时生效。
class UnclearAutoSaveDialog extends ConsumerWidget {
  const UnclearAutoSaveDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final enabled = ref.watch(
      learningSettingsProvider.select((s) => s.autoSaveOnUnclear),
    );

    return AlertDialog(
      title: Text(l10n.unclearAutoSaveDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.unclearAutoSaveDialogMessage),
          const SizedBox(height: AppSpacing.s),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              enabled
                  ? l10n.unclearAutoSaveSwitchOn
                  : l10n.unclearAutoSaveSwitchOff,
            ),
            value: enabled,
            onChanged: (value) => ref
                .read(learningSettingsProvider.notifier)
                .setAutoSaveOnUnclear(value),
          ),
          Text(
            l10n.unclearAutoSaveDialogHint,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.unclearAutoSaveDialogConfirm),
        ),
      ],
    );
  }
}
