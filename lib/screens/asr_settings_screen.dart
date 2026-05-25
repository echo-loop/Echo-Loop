/// 语音识别设置页。
///
/// iOS/macOS：全局开关 + 后端选择（Apple Speech / Echo Loop AI）+ 离线模型状态。
/// Android：全局开关 + 离线模型状态（固定 Echo Loop AI）。
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/offline_asr_settings_provider.dart';
import '../services/asr/asr_model_manager.dart';
import '../theme/app_theme.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          // 说明文字（轻量，无背景）
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s,
              0,
              AppSpacing.s,
              AppSpacing.m,
            ),
            child: Text(
              l10n.speechRecognitionDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // 主卡片：开关 + 后端选择 + 模型状态
          Card(
            child: Column(
              children: [
                // 全局开关
                SwitchListTile(
                  title: Text(l10n.speechRecognition),
                  subtitle: Text(
                    state.enabled
                        ? l10n.speechRecognitionEnabled
                        : l10n.speechRecognitionDisabled,
                  ),
                  value: state.enabled,
                  onChanged: (v) => _onEnabledToggle(context, ref, l10n, v),
                ),

                // 以下内容仅在开启时显示
                if (state.enabled) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // iOS/macOS：后端选择
                  if (showBackendSelector) ...[
                    _buildBackendSelector(l10n, state, theme),
                  ],

                  // Android：无后端选择，直接显示模型状态
                  if (!showBackendSelector) ...[
                    _buildOfflineModelTile(l10n, state, theme),
                  ],

                  // 离线模型进度/错误（选中 offline 时）
                  if (state.backend == AsrBackend.offline)
                    _buildOfflineStatus(l10n, state, theme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== 后端选择器（iOS/macOS）==========

  Widget _buildBackendSelector(
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
    ThemeData theme,
  ) {
    return RadioGroup<AsrBackend>(
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
            subtitle: Text(
              l10n.asrBackendPlatformDescription,
              style: theme.textTheme.bodySmall,
            ),
            value: AsrBackend.platform,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          RadioListTile<AsrBackend>(
            title: Text(l10n.asrBackendOffline),
            subtitle: _buildOfflineSubtitle(l10n, state, theme),
            value: AsrBackend.offline,
          ),
        ],
      ),
    );
  }

  // ========== 离线模型信息 ==========

  /// Echo Loop AI 的 subtitle：显示模型档位 + 状态。
  Widget _buildOfflineSubtitle(
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
    ThemeData theme,
  ) {
    final modelLabel = _modelLabel(state.recommendedModel.id);
    final statusText = _modelStatusText(l10n, state);

    final tierText = l10n.asrModelTier(modelLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.asrBackendOfflineDescription,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          statusText.isEmpty ? tierText : '$tierText\n$statusText',
          style: theme.textTheme.bodySmall?.copyWith(
            color: state.downloadStatus == AsrModelDownloadStatus.downloaded
                ? Colors.green
                : state.downloadStatus == AsrModelDownloadStatus.failed
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Android 直接显示模型信息的 ListTile。
  Widget _buildOfflineModelTile(
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
    ThemeData theme,
  ) {
    final modelLabel = _modelLabel(state.recommendedModel.id);
    final statusText = _modelStatusText(l10n, state);

    final tierText = l10n.asrModelTier(modelLabel);

    return ListTile(
      title: Text(l10n.localSpeechRecognition),
      subtitle: Text(
        statusText.isEmpty ? tierText : '$tierText\n$statusText',
        style: TextStyle(
          color: state.downloadStatus == AsrModelDownloadStatus.downloaded
              ? Colors.green
              : null,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 模型状态文字（Ready · 358 MB / Downloading 45% / 空）。
  String _modelStatusText(
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
  ) {
    if (state.downloadStatus == AsrModelDownloadStatus.downloaded) {
      return l10n.speechModelReady(_formatBytes(state.localSizeBytes));
    }
    if (state.isDownloading) {
      return l10n.speechModelDownloading(
        '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
      );
    }
    if (state.downloadStatus == AsrModelDownloadStatus.failed) {
      return l10n.speechModelDownloadFailed;
    }
    return '';
  }

  /// 下载进度条 / 错误提示（在 Card 底部展开）。
  Widget _buildOfflineStatus(
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
    ThemeData theme,
  ) {
    if (state.isDownloading) {
      return Padding(
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
      );
    }

    if (state.downloadStatus == AsrModelDownloadStatus.failed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.errorMessage ?? l10n.speechModelDownloadFailed,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(offlineAsrSettingsProvider.notifier).retryDownload(),
              child: Text(l10n.retryDownload),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
    var deleteModel = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.disableSpeechRecognitionTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.disableSpeechRecognitionMessage),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => deleteModel = !deleteModel),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: deleteModel,
                        onChanged: (v) =>
                            setState(() => deleteModel = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.alsoDeleteModel,
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                final notifier = ref.read(offlineAsrSettingsProvider.notifier);
                if (deleteModel) {
                  notifier.disableAndDelete();
                } else {
                  notifier.disable();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(l10n.disableAction),
            ),
          ],
        ),
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
