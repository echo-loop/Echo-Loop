import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import '../l10n/app_localizations.dart';
import '../providers/backup_provider.dart';
import '../services/backup/backup_constants.dart';
import '../services/backup/backup_manifest.dart';
import '../services/backup/backup_progress.dart';
import '../theme/app_theme.dart';
import '../utils/file_size.dart';

/// 用户数据备份与恢复页面。
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  String? _temporaryBackupPath;
  bool _busy = false;

  /// 用户下载目录路径（用于文件选择器默认打开目录）。
  static String? get _downloadsDirectory {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return '$home/Downloads';
  }

  @override
  void dispose() {
    final path = _temporaryBackupPath;
    if (path != null) unawaited(_deleteFile(path));
    super.dispose();
  }

  Future<void> _backup() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final progress = ValueNotifier<BackupProgress>(
      const BackupProgress(stage: 'exportingDatabase'),
    );
    unawaited(_showProgressDialog(progress));
    await Future<void>.delayed(Duration.zero);

    try {
      final oldPath = _temporaryBackupPath;
      if (oldPath != null) await _deleteFile(oldPath);
      final path = await performExport(
        ref,
        onProgress: (value) => progress.value = value,
      );
      if (!mounted) {
        await _deleteFile(path);
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      _temporaryBackupPath = path;
      await _showBackupReadyDialog(path);
    } catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(l10n.backupFailed('$error'));
      }
    } finally {
      progress.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [backupFileExtension],
      initialDirectory: _downloadsDirectory,
    );
    final path = result?.files.firstOrNull?.path;
    if (path == null) return;
    final pickedName =
        result?.files.firstOrNull?.name ?? File(path).uri.pathSegments.last;
    if (!_isBackupFileName(pickedName)) {
      if (mounted) _showError(l10n.importInvalidFile);
      return;
    }

    final BackupManifest manifest;
    try {
      manifest = await readBackupManifest(ref, path);
    } catch (_) {
      if (mounted) _showError(l10n.importInvalidFile);
      return;
    }
    if (manifest.schemaVersion > AppDatabase.currentSchemaVersion) {
      if (mounted) _showError(l10n.importIncompatible);
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
          ),
          title: Text(l10n.restoreOverwriteTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _manifestRow(
                l10n.backupTime,
                DateFormat.yMd().add_Hm().format(manifest.createdAt.toLocal()),
              ),
              _manifestRow(l10n.backupVersion, manifest.appVersion),
              _manifestRow(l10n.backupFileCount, '${manifest.mediaFileCount}'),
              _manifestRow(l10n.backupSize, manifest.formattedSize),
              const SizedBox(height: AppSpacing.m),
              Text(
                l10n.restoreOverwriteMessage,
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(l10n.restoreOverwriteAction),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final progress = ValueNotifier<BackupProgress>(
      const BackupProgress(stage: 'importingExtracting'),
    );
    unawaited(_showProgressDialog(progress));
    await Future<void>.delayed(Duration.zero);
    try {
      await performImport(
        ref,
        path,
        onProgress: (value) => progress.value = value,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importSuccess)));
    } catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(l10n.restoreFailed('$error'));
      }
    } finally {
      progress.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showProgressDialog(ValueNotifier<BackupProgress> progress) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<BackupProgress>(
            valueListenable: progress,
            builder: (_, value, __) {
              final progressValue = value.progress;
              final determinate = progressValue >= 0 && progressValue <= 1;
              return ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 260),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.8,
                            value: determinate ? progressValue : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Text(
                            _progressText(AppLocalizations.of(context)!, value),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (determinate) ...[
                      const SizedBox(height: AppSpacing.m),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: progressValue),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(progressValue * 100).round()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showBackupReadyDialog(String path) async {
    final l10n = AppLocalizations.of(context)!;
    final file = File(path);
    final fileName = file.uri.pathSegments.last;
    final size = formatBytes(await file.length());
    final downloadFeedback = ValueNotifier<String?>(null);
    if (!mounted) return;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final colorScheme = theme.colorScheme;
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.xl,
            ),
            contentPadding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.xl,
              AppSpacing.m,
              AppSpacing.l,
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    l10n.backupReadyTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s,
                        vertical: AppSpacing.l,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoItem(
                            context,
                            label: l10n.backupFileName,
                            value: fileName,
                          ),
                          const SizedBox(height: AppSpacing.m),
                          _buildInfoItem(
                            context,
                            label: l10n.backupSize,
                            value: size,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  ValueListenableBuilder<String?>(
                    valueListenable: downloadFeedback,
                    builder: (_, value, __) {
                      if (value == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.m,
                              vertical: AppSpacing.s,
                            ),
                            child: Text(
                              value,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(CupertinoIcons.arrow_down_to_line),
                          label: Text(l10n.download),
                          onPressed: () => unawaited(
                            _download(path, feedback: downloadFeedback),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: FilledButton.icon(
                          icon: Icon(
                            Platform.isIOS || Platform.isMacOS
                                ? CupertinoIcons.share
                                : Icons.share_outlined,
                          ),
                          label: Text(l10n.pdfShare),
                          onPressed: () => unawaited(_share(path)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      downloadFeedback.dispose();
    }
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  Future<void> _download(String path, {ValueNotifier<String?>? feedback}) async {
    final l10n = AppLocalizations.of(context)!;
    final file = File(path);
    final name = file.uri.pathSegments.last;
    final bytes = await file.readAsBytes();
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.backupAndRestore,
      fileName: name,
      initialDirectory: _downloadsDirectory,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: [backupFileExtension],
    );
    if (savePath == null) return;
    if (!Platform.isIOS && !Platform.isAndroid) {
      await File(savePath).writeAsBytes(bytes);
    }
    if (feedback == null) return;
    feedback.value = l10n.exportSuccess;
    unawaited(_clearDialogFeedback(feedback, l10n.exportSuccess));
  }

  Future<void> _share(String path) async {
    final fileName = File(path).uri.pathSegments.last;
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/octet-stream')],
      subject: fileName,
      sharePositionOrigin: box == null
          ? Rect.zero
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Widget _manifestRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: AppSpacing.m),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  String _progressText(AppLocalizations l10n, BackupProgress progress) {
    return switch (progress.stage) {
      'exportingDatabase' => l10n.exportingDatabase,
      'exportingPreferences' => l10n.exportingPreferences,
      'exportingMedia' => l10n.exportingMedia,
      'exportingResources' => l10n.exportingResources,
      'exportingPacking' => l10n.exportingPacking,
      'importingExtracting' => l10n.importingExtracting,
      'importingMedia' => l10n.importingMedia,
      'importingResources' => l10n.importingResources,
      'importingDatabase' => l10n.importingDatabase,
      'importingPreferences' => l10n.importingPreferences,
      _ => progress.stage,
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static bool _isBackupFileName(String name) {
    return name.toLowerCase().endsWith('.$backupFileExtension');
  }

  static Future<void> _clearDialogFeedback(
    ValueNotifier<String?> feedback,
    String expectedValue,
  ) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    if (feedback.value == expectedValue) {
      feedback.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupAndRestore)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(l10n.backupData),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_busy,
                  onTap: _backup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: Text(l10n.restoreData),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_busy,
                  onTap: _restore,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
