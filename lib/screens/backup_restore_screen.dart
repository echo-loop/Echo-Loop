import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:echo_loop/widgets/common/svg_action_icon.dart';

import '../database/app_database.dart';
import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../l10n/app_localizations.dart';
import '../providers/backup_provider.dart';
import '../services/backup/backup_constants.dart';
import '../services/backup/backup_manifest.dart';
import '../services/backup/backup_progress.dart';
import '../services/backup/backup_service.dart';
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
  bool _closingBackupReadyDialog = false;

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
      _closingBackupReadyDialog = false;
      final path = await performExport(
        ref,
        onProgress: (value) => progress.value = value,
      );
      _trackBackupResult('backup', 'completed');
      if (!mounted) {
        await _deleteFile(path);
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      _temporaryBackupPath = path;
      await _showBackupReadyDialog(path);
    } catch (error) {
      _trackBackupResult('backup', 'failed');
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
    if (!isBackupFileName(pickedName)) {
      if (mounted) _showError(l10n.importInvalidFile);
      return;
    }

    final BackupManifest manifest;
    try {
      manifest = await readBackupManifest(ref, path);
    } on BackupException catch (error) {
      if (mounted) {
        final message = switch (error.code) {
          BackupFailureCode.unsupportedVersion ||
          BackupFailureCode.incompatibleVersion => l10n.importIncompatible,
          _ => l10n.importInvalidFile,
        };
        _showError(message);
      }
      return;
    } catch (_) {
      if (mounted) {
        _showError(l10n.importInvalidFile);
      }
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
          icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error),
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
      _trackBackupResult('restore', 'completed');
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importSuccess)));
    } catch (error) {
      _trackBackupResult('restore', 'failed');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(l10n.restoreFailed('$error'));
      }
    } finally {
      progress.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _trackBackupResult(String operation, String result) {
    ref.read(analyticsServiceProvider).track(Events.backupOperationResult, {
      EventParams.operation: operation,
      EventParams.result: result,
    });
  }

  Future<void> _showProgressDialog(ValueNotifier<BackupProgress> progress) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: BackupProgressDialog(progress: progress),
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
        barrierDismissible: false,
        builder: (dialogContext) {
          return BackupReadyDialog(
            title: l10n.backupReadyTitle,
            fileNameLabel: l10n.backupFileName,
            fileName: fileName,
            sizeLabel: l10n.backupSize,
            size: size,
            supportsDesktopSave: _supportsDesktopSave,
            downloadLabel: l10n.download,
            shareLabel: l10n.pdfShare,
            downloadFeedback: downloadFeedback,
            shareIcon: Platform.isAndroid
                ? const Icon(Icons.share_outlined)
                : const SvgActionIcon(assetName: 'assets/icon/share.svg'),
            onClose: () => unawaited(_closeBackupReadyDialog(dialogContext)),
            onDownload: () =>
                unawaited(_download(path, feedback: downloadFeedback)),
            onShare: () => unawaited(_share(path)),
          );
        },
      );
    } finally {
      downloadFeedback.dispose();
    }
  }

  /// 关闭完成弹窗时立即释放临时备份，避免连续备份留下旧文件。
  Future<void> _closeBackupReadyDialog(BuildContext dialogContext) async {
    if (_closingBackupReadyDialog) return;
    _closingBackupReadyDialog = true;
    final path = _temporaryBackupPath;
    _temporaryBackupPath = null;
    if (path != null) await _deleteFile(path);
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
  }

  Future<void> _download(
    String path, {
    ValueNotifier<String?>? feedback,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final file = File(path);
    final name = file.uri.pathSegments.last;
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.backupAndRestore,
      fileName: name,
      initialDirectory: _downloadsDirectory,
      type: FileType.custom,
      allowedExtensions: [backupFileExtension],
    );
    if (savePath == null) return;
    await copyBackupFileStreaming(file.path, savePath);
    if (feedback == null) return;
    feedback.value = l10n.downloadSuccess;
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

  /// 移动端 file_picker 保存接口要求整包 bytes，因此只开放系统分享。
  bool get _supportsDesktopSave =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

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

/// 备份或恢复进行中的进度弹窗：阶段文案加不确定 / 确定进度指示。
///
/// 无标题无按钮时 AlertDialog 默认上 16 / 下 24 的内边距会让内容偏上，
/// 这里统一为上下对称的 24。
class BackupProgressDialog extends StatelessWidget {
  const BackupProgressDialog({required this.progress, super.key});

  final ValueNotifier<BackupProgress> progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      contentPadding: const EdgeInsets.all(AppSpacing.l),
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
                        _progressText(l10n, value),
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
    );
  }

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
}

/// 备份完成提示弹窗。
///
/// 弹窗必须通过右上角关闭按钮退出，关闭按钮由调用方负责释放临时文件。
class BackupReadyDialog extends StatelessWidget {
  const BackupReadyDialog({
    required this.title,
    required this.fileNameLabel,
    required this.fileName,
    required this.sizeLabel,
    required this.size,
    required this.supportsDesktopSave,
    required this.downloadLabel,
    required this.shareLabel,
    required this.downloadFeedback,
    required this.shareIcon,
    required this.onClose,
    required this.onDownload,
    required this.onShare,
    super.key,
  });

  final String title;
  final String fileNameLabel;
  final String fileName;
  final String sizeLabel;
  final String size;
  final bool supportsDesktopSave;
  final String downloadLabel;
  final String shareLabel;
  final ValueNotifier<String?> downloadFeedback;
  final Widget shareIcon;
  final VoidCallback onClose;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      child: AlertDialog(
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
        titlePadding: EdgeInsets.zero,
        title: Padding(
          padding: const EdgeInsets.only(top: 8, right: 12),
          child: Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 20),
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
          ),
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
                title,
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
                      _infoItem(context, fileNameLabel, fileName),
                      const SizedBox(height: AppSpacing.m),
                      _infoItem(context, sizeLabel, size),
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
              if (supportsDesktopSave)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const SvgActionIcon(
                          assetName: 'assets/icon/download.svg',
                        ),
                        label: Text(downloadLabel),
                        onPressed: onDownload,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: FilledButton.icon(
                        icon: shareIcon,
                        label: Text(shareLabel),
                        onPressed: onShare,
                      ),
                    ),
                  ],
                )
              else
                FilledButton.icon(
                  icon: shareIcon,
                  label: Text(shareLabel),
                  onPressed: onShare,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(BuildContext context, String label, String value) {
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
}
