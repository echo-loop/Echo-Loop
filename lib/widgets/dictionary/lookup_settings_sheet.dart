/// 手动查词页的设置面板（右上角设置按钮打开）。
///
/// 设置只服务于查词页：「自动发音」「自动展开 AI 查词」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/dictionary/dictionary_settings_provider.dart';
import '../../services/app_logger.dart';
import '../common/settings_sheet_scaffold.dart';

class LookupSettingsSheet extends ConsumerWidget {
  const LookupSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(dictionarySettingsProvider);
    final notifier = ref.read(dictionarySettingsProvider.notifier);
    return SettingsSheetScaffold(
      title: l10n.lookupSettingsTitle,
      closeButtonKey: const Key('lookup-settings-close'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            key: const Key('lookup-settings-auto-speak'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.lookupAutoSpeak),
            value: settings.autoSpeakOnLookupPage,
            onChanged: (value) {
              AppLogger.log('Lookup', '设置变更 自动发音=$value');
              notifier.setAutoSpeakOnLookupPage(value);
            },
          ),
          SwitchListTile(
            key: const Key('lookup-settings-auto-ai'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.auto_awesome_outlined),
            title: Text(l10n.dictionaryAutoShowAiOnLookup),
            value: settings.autoShowAiOnLookup,
            onChanged: (value) {
              AppLogger.log('Lookup', '设置变更 自动展开AI查词=$value');
              notifier.setAutoShowAiOnLookup(value);
            },
          ),
        ],
      ),
    );
  }
}
