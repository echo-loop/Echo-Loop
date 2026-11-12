/// 声效设置页面
///
/// 集中管理 App 内的声音偏好，目前包含全局「音效」开关；后续背景音等声音类设置也放在这里。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// 声效设置页面
class SoundSettingsScreen extends ConsumerWidget {
  const SoundSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final soundEffectsEnabled = ref.watch(
      appSettingsProvider.select((s) => s.soundEffectsEnabled),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.soundSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        children: [
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.volume_up_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(l10n.soundEffects),
              value: soundEffectsEnabled,
              onChanged: ref
                  .read(appSettingsProvider.notifier)
                  .setSoundEffectsEnabled,
            ),
          ),
        ],
      ),
    );
  }
}
