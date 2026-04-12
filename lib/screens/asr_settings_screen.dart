/// 语音识别设置页。
///
/// iOS/macOS：全局开关 + 后端选择（Apple 自带 / 应用模型）+ 离线模型管理。
/// Android：全局开关 + 离线模型管理（固定应用模型）。
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/offline_asr_settings_provider.dart';
import '../services/asr/asr_model_manager.dart';

/// 语音识别设置页。
class AsrSettingsScreen extends ConsumerStatefulWidget {
  const AsrSettingsScreen({super.key});

  @override
  ConsumerState<AsrSettingsScreen> createState() => _AsrSettingsScreenState();
}

class _AsrSettingsScreenState extends ConsumerState<AsrSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 进入设置页时，如果离线模型未下载完成，自动恢复下载。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 仅对 failed 状态自动恢复下载，notDownloaded 等用户手动操作。
      final state = ref.read(offlineAsrSettingsProvider);
      if (state.enabled &&
          state.backend == AsrBackend.offline &&
          state.downloadStatus == AsrModelDownloadStatus.failed &&
          !state.isDownloading) {
        ref.read(offlineAsrSettingsProvider.notifier).retryDownload();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(offlineAsrSettingsProvider);
    final theme = Theme.of(context);
    final showBackendSelector = Platform.isIOS || Platform.isMacOS;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.speechRecognition)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 说明卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.speechRecognitionDescription,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 全局开关
          Card(
            child: SwitchListTile(
              title: Text(l10n.speechRecognition),
              subtitle: Text(
                state.enabled
                    ? l10n.speechRecognitionEnabled
                    : l10n.speechRecognitionDisabled,
              ),
              value: state.enabled,
              onChanged: (value) => _onEnabledToggle(context, ref, l10n, value),
            ),
          ),

          // 后端选择（仅 iOS/macOS）
          if (showBackendSelector && state.enabled) ...[
            const SizedBox(height: 16),
            _buildBackendSelector(context, l10n, state, theme),
          ],

          // 离线模型管理（backend == offline 且已启用）
          if (state.enabled && state.backend == AsrBackend.offline) ...[
            const SizedBox(height: 16),
            _buildOfflineModelCard(context, l10n, state, theme),
          ],

        ],
      ),
    );
  }

  // ========== 后端选择器 ==========

  Widget _buildBackendSelector(
    BuildContext context,
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
    ThemeData theme,
  ) {
    return Card(
      child: RadioGroup<AsrBackend>(
        groupValue: state.backend,
        onChanged: (value) {
          if (value != null) {
            ref.read(offlineAsrSettingsProvider.notifier).setBackend(value);
          }
        },
        child: Column(
          children: [
            RadioListTile<AsrBackend>(
              title: Text(l10n.asrBackendPlatform),
              subtitle: Text(l10n.asrBackendPlatformDescription),
              value: AsrBackend.platform,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            RadioListTile<AsrBackend>(
              title: Text(l10n.asrBackendOffline),
              subtitle: Text(l10n.asrBackendOfflineDescription),
              value: AsrBackend.offline,
            ),
          ],
        ),
      ),
    );
  }

  // ========== 离线模型管理 ==========

  Widget _buildOfflineModelCard(
    BuildContext context,
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
    ThemeData theme,
  ) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(l10n.localSpeechRecognition),
            subtitle: _buildModelSubtitle(l10n, state),
          ),

          // 下载进度条
          if (state.isDownloading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: state.downloadProgress),
                  const SizedBox(height: 4),
                  Text(
                    l10n.speechModelDownloading(
                      '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          // 下载失败
          if (state.downloadStatus == AsrModelDownloadStatus.failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage ?? l10n.speechModelDownloadFailed,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(offlineAsrSettingsProvider.notifier)
                        .retryDownload(),
                    child: Text(l10n.retryDownload),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildModelSubtitle(
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
  ) {
    final localSizeText = _formatBytes(state.localSizeBytes);
    final modelLabel = _modelLabel(state.recommendedModel.id);

    final isReady =
        state.downloadStatus == AsrModelDownloadStatus.downloaded;

    if (isReady) {
      return Text(
        '$modelLabel · ${l10n.speechModelReady(localSizeText)}',
        style: const TextStyle(color: Colors.green),
      );
    }

    if (state.isDownloading) {
      return Text(
        '$modelLabel · ${l10n.speechModelDownloading('${(state.downloadProgress * 100).toStringAsFixed(0)}%')}',
      );
    }

    if (state.localSizeBytes > 0) {
      return Text('$modelLabel · $localSizeText');
    }

    return Text(modelLabel);
  }

  // ========== 开关操作 ==========

  void _onEnabledToggle(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    bool value,
  ) {
    final notifier = ref.read(offlineAsrSettingsProvider.notifier);
    final state = ref.read(offlineAsrSettingsProvider);

    if (value) {
      notifier.enable();
    } else {
      // 关闭时：如果离线模型已下载，询问是否删除
      if (state.backend == AsrBackend.offline &&
          state.downloadStatus == AsrModelDownloadStatus.downloaded) {
        _confirmDisable(context, ref, l10n);
      } else {
        notifier.disable();
      }
    }
  }

  void _confirmDisable(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.disableSpeechRecognitionTitle),
        content: Text(l10n.disableSpeechRecognitionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(offlineAsrSettingsProvider.notifier).disable();
            },
            child: Text(l10n.keepModel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(offlineAsrSettingsProvider.notifier).disableAndDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.deleteModelAction),
          ),
        ],
      ),
    );
  }

  // ========== 工具方法 ==========

  static String _modelLabel(String modelId) {
    if (modelId.contains('tiny')) return 'Fast';
    if (modelId.contains('base')) return 'Balanced';
    if (modelId.contains('small')) return 'Accurate';
    return '';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}
