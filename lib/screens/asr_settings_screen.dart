/// 语音识别设置页。
///
/// iOS/macOS：后端选择（Apple Speech / Echo Loop AI）+ 离线模型状态。
/// Android：离线模型状态（固定 Echo Loop AI）。
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echo_loop/widgets/common/svg_action_icon.dart';

import '../l10n/app_localizations.dart';
import '../providers/offline_asr_settings_provider.dart';
import '../providers/asr_model_installation_provider.dart';
import '../services/asr/asr_model_manager.dart';
import '../services/asr/offline_asr_engine.dart';
import '../theme/app_theme.dart';
import '../utils/download_failure_message.dart';

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
      ref
          .read(asrModelInstallationGateProvider)
          .ensureInstallationStatesLoaded();
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

          _SectionLabel(text: l10n.asrEngine),
          Card(
            child: Column(
              children: [
                if (showBackendSelector) ...[
                  _buildBackendSelector(l10n, state, theme),
                ] else ...[
                  ListTile(
                    title: Text(l10n.localSpeechRecognition),
                    subtitle: Text(l10n.asrBackendOfflineDescription),
                  ),
                ],
              ],
            ),
          ),

          if (state.backend == AsrBackend.offline) ...[
            const SizedBox(height: AppSpacing.m),
            _SectionLabel(text: l10n.asrBackendOffline),
            Card(child: _buildModelList(l10n, state, theme)),
          ] else if (state.totalDownloadedModelBytes > 0) ...[
            const SizedBox(height: AppSpacing.m),
            Card(child: _buildDownloadedModelsStorageRow(l10n, state, theme)),
          ],
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
            value: AsrBackend.platform,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          RadioListTile<AsrBackend>(
            title: Text(l10n.asrBackendOffline),
            subtitle: Text(
              l10n.asrBackendOfflineDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
            value: AsrBackend.offline,
          ),
        ],
      ),
    );
  }

  // ========== 离线模型信息 ==========

  Widget _buildModelList(
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
    ThemeData theme,
  ) {
    final rows = <Widget>[];
    for (var i = 0; i < availableModels.length; i++) {
      final model = availableModels[i];
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
      rows.add(_buildModelRow(l10n, theme, state, model));
    }
    return Column(children: rows);
  }

  Widget _buildModelRow(
    AppLocalizations l10n,
    ThemeData theme,
    OfflineAsrSettingsState state,
    AsrModelInfo model,
  ) {
    final modelState = state.modelStateOf(model.id);
    final isSelected = state.selectedModel.id == model.id;
    final isRecommended = state.recommendedModel.id == model.id;
    return ListTile(
      leading: Radio<String>(
        value: model.id,
        // ignore: deprecated_member_use
        groupValue: state.selectedModel.id,
        // ignore: deprecated_member_use
        onChanged: (_) =>
            ref.read(offlineAsrSettingsProvider.notifier).selectModel(model),
      ),
      title: Row(
        children: [
          Flexible(child: Text(_modelLabel(model.id))),
          if (isRecommended) ...[
            const SizedBox(width: 8),
            _RecommendedBadge(text: l10n.ttsModelRecommended, theme: theme),
          ],
        ],
      ),
      subtitle: _modelSubtitle(l10n, theme, model.id, modelState),
      trailing: _modelTrailing(context, l10n, model.id, modelState, isSelected),
      onTap: () =>
          ref.read(offlineAsrSettingsProvider.notifier).selectModel(model),
    );
  }

  Widget _modelSubtitle(
    AppLocalizations l10n,
    ThemeData theme,
    String modelId,
    AsrModelState state,
  ) {
    final approxSize = _approxModelSizeText(l10n, modelId);
    final description = _modelDescription(l10n, modelId);
    final showApproxInDescription = !state.isReady;
    final children = <Widget>[
      Text(
        showApproxInDescription ? '$description $approxSize' : description,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    ];
    if (state.isDownloading) {
      final pct = '${(state.downloadProgress * 100).toStringAsFixed(0)}%';
      children.add(const SizedBox(height: 6));
      children.add(LinearProgressIndicator(value: state.downloadProgress));
      children.add(const SizedBox(height: 2));
      children.add(Text(l10n.speechModelDownloading(pct)));
    } else if (state.downloadStatus == AsrModelDownloadStatus.failed) {
      children.add(
        Text(
          downloadFailureMessage(l10n, state.downloadError),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    } else if (state.isReady) {
      children.add(
        Text(
          l10n.speechModelReady(
            state.localSizeBytes > 0 ? _formatBytes(state.localSizeBytes) : '—',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.successColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget? _modelTrailing(
    BuildContext context,
    AppLocalizations l10n,
    String modelId,
    AsrModelState state,
    bool isSelected,
  ) {
    if (state.isDownloading && !isSelected) {
      return TextButton(
        onPressed: () => ref
            .read(offlineAsrSettingsProvider.notifier)
            .cancelDownload(modelId),
        child: Text(l10n.ttsCancelDownload),
      );
    }
    if (state.downloadStatus == AsrModelDownloadStatus.failed) {
      return TextButton(
        onPressed: () => ref
            .read(offlineAsrSettingsProvider.notifier)
            .retryDownload(modelId),
        child: Text(l10n.retryDownload),
      );
    }
    if (state.isReady && !isSelected) {
      return IconButton(
        icon: const SvgActionIcon(assetName: 'assets/icon/trash-bin.svg'),
        tooltip: l10n.deleteModelAction,
        onPressed: () =>
            _confirmDeleteModel(context, l10n, modelId, state.localSizeBytes),
      );
    }
    return null;
  }

  Widget _buildDownloadedModelsStorageRow(
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
    ThemeData theme,
  ) {
    return ListTile(
      leading: Icon(
        Icons.sd_storage_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(l10n.asrDownloadedModelsTitle),
      subtitle: Text(
        l10n.asrDownloadedModelsDesc(
          _formatBytes(state.totalDownloadedModelBytes),
        ),
      ),
      trailing: IconButton(
        icon: const SvgActionIcon(assetName: 'assets/icon/trash-bin.svg'),
        tooltip: l10n.deleteModelAction,
        onPressed: () => _confirmDeleteAllModels(context, l10n),
      ),
    );
  }

  void _confirmDeleteModel(
    BuildContext context,
    AppLocalizations l10n,
    String modelId,
    int localSizeBytes,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteModelConfirmTitle),
        content: Text(
          l10n.deleteModelConfirmMessage(_formatBytes(localSizeBytes)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(offlineAsrSettingsProvider.notifier)
                  .deleteModel(modelId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.deleteModelAction),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAllModels(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteModelConfirmTitle),
        content: Text(l10n.asrDeleteAllModelsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(offlineAsrSettingsProvider.notifier)
                  .deleteDownloadedModels(includeSelected: true);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
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

  static String _modelDescription(AppLocalizations l10n, String modelId) {
    if (modelId.contains('tiny')) return l10n.asrModelFastDescription;
    if (modelId.contains('base')) return l10n.asrModelBalancedDescription;
    if (modelId.contains('small')) return l10n.asrModelAccurateDescription;
    return l10n.asrBackendOfflineDescription;
  }

  static String _approxModelSizeText(AppLocalizations l10n, String modelId) {
    if (modelId.contains('tiny')) return l10n.speechModelApproxSize('100 MB');
    if (modelId.contains('base')) return l10n.speechModelApproxSize('150 MB');
    if (modelId.contains('small')) return l10n.speechModelApproxSize('360 MB');
    return '';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}

/// 分组小标题，与语音合成设置页保持一致。
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
