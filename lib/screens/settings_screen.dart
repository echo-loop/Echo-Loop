import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/app_database.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/app_update_info.dart';
import '../providers/app_update_provider.dart';
import '../providers/backup_provider.dart';
import '../providers/developer_options_provider.dart';
import '../providers/package_info_provider.dart';
import '../providers/reminder_settings_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/word_ai_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/tag_provider.dart';
import '../analytics/analytics_providers.dart';
import '../services/backup/backup_manifest.dart';
import '../services/backup/backup_service.dart';
import '../services/demo_data_seeder.dart';
import '../theme/app_theme.dart';
import 'log_viewer_screen.dart';
import 'reminder_settings_screen.dart';
import '../widgets/app_update_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// 连续点击版本号解锁开发者选项的计数器
  int _devTapCount = 0;
  DateTime? _lastDevTap;

  /// 用户下载目录路径（用于文件选择器默认打开目录）
  static String? get _downloadsDirectory {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return '$home/Downloads';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final showDeveloperOptions = ref.watch(showDeveloperOptionsProvider);
    final settingsController = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          _buildSection(
            context,
            title: l10n.appearance,
            children: [
              _buildThemeModeTile(context, l10n, settings, settingsController),
              _buildLanguageTile(context, l10n, settings, settingsController),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          _buildReminderSection(context, ref, l10n),
          const SizedBox(height: AppSpacing.m),
          _buildStorageSection(context, ref, l10n),
          const SizedBox(height: AppSpacing.m),
          _buildAboutSection(context, ref, l10n),
          if (showDeveloperOptions) ...[
            const SizedBox(height: AppSpacing.m),
            _buildDeveloperSection(
              context,
              ref,
              l10n,
              settings,
              settingsController,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.s,
            AppSpacing.m,
            AppSpacing.s,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(child: Column(children: _intersperseDividers(children))),
      ],
    );
  }

  /// 构建提醒设置入口
  Widget _buildReminderSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final settings = ref.watch(reminderSettingsNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return _buildSection(
      context,
      title: l10n.reminderSectionTitle,
      children: [
        ListTile(
          leading: _emojiIcon('🔔'),
          title: Text(l10n.reminderSettings),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (settings.savedReviewReminderEnabled)
                Text(
                  settings.formattedTime,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ReminderSettingsScreen(),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建存储管理区域
  Widget _buildStorageSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return _buildSection(
      context,
      title: l10n.storage,
      children: [
        ListTile(
          leading: _emojiIcon('🗑️'),
          title: Text(l10n.clearCache),
          onTap: () => _clearAiCache(context, ref, l10n),
        ),
      ],
    );
  }

  /// 清空 AI 缓存（翻译 + 解析 + 单词解析）
  Future<void> _clearAiCache(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearCache),
        content: Text(l10n.clearCacheConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // 清空 SQLite 缓存（词级时间戳属于字幕数据，不在此清除）
    final dao = ref.read(sentenceAiCacheDaoProvider);
    final deleted = await dao.deleteAll();

    // 清空内存缓存
    ref.read(sentenceAiNotifierProvider).clearMemoryCache();
    ref.read(wordAiNotifierProvider).clearMemoryCache();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted > 0 ? l10n.clearCacheSuccess : l10n.clearCacheEmpty,
        ),
      ),
    );
  }

  /// 构建关于信息区域
  ///
  /// 包含检查更新、服务条款、隐私政策、意见反馈四个入口，
  /// 以及底部居中灰色版本号标签。
  Widget _buildAboutSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final version = ref.watch(packageInfoProvider).version;
    final updateState = ref.watch(appUpdateProvider);
    final isChecking = updateState is AppUpdateChecking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          context,
          title: l10n.about,
          children: [
            ListTile(
              leading: _emojiIcon('🔄'),
              title: Text(l10n.checkForUpdate),
              trailing: isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: isChecking
                  ? null
                  : () => _checkForUpdate(context, ref, l10n),
            ),
            ListTile(
              leading: _emojiIcon('📜'),
              title: Text(l10n.termsOfService),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  launchUrl(Uri.parse('https://www.echo-loop.top/terms')),
            ),
            ListTile(
              leading: _emojiIcon('🔒'),
              title: Text(l10n.privacyPolicy),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  launchUrl(Uri.parse('https://www.echo-loop.top/privacy')),
            ),
            ListTile(
              leading: _emojiIcon('✉️'),
              title: Text(l10n.writeFeedback),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => launchUrl(Uri.parse('mailto:support@echo-loop.top')),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleVersionTap(context, ref, l10n),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'v$version',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 连续点击版本号解锁开发者选项。
  ///
  /// 两次点击间隔超过 1 秒重置计数。
  /// 第 4 次起显示剩余次数提示，第 7 次解锁。
  /// 已解锁时点击提示"已开启"。
  void _handleVersionTap(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    if (ref.read(showDeveloperOptionsProvider)) return;

    final now = DateTime.now();
    if (_lastDevTap != null &&
        now.difference(_lastDevTap!) > const Duration(seconds: 1)) {
      _devTapCount = 0;
    }
    _lastDevTap = now;
    _devTapCount++;

    if (_devTapCount >= 7) {
      _devTapCount = 0;
      ref.read(showDeveloperOptionsProvider.notifier).setEnabled(true);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(l10n.developerOptionsEnabled)),
        );
    }
  }

  /// 手动检查更新
  Future<void> _checkForUpdate(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final result = await ref.read(appUpdateProvider.notifier).manualCheck();
    if (!context.mounted) return;

    if (result.type == AppUpdateType.none || result.info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.info == null ? l10n.checkUpdateFailed : l10n.alreadyLatest,
          ),
        ),
      );
    } else {
      final isForce = result.type == AppUpdateType.forceUpdate;
      final downloadUrl = AppUpdate.getDownloadUrl(result.info!);
      showAppUpdateDialog(
        context: context,
        info: result.info!,
        isForceUpdate: isForce,
        downloadUrl: downloadUrl,
        onDismiss: () => ref.read(appUpdateProvider.notifier).dismiss(),
      );
    }
  }

  /// 构建开发者选项区域
  Widget _buildDeveloperSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    final formattedTimeMachine = _formatTimeMachineDateTime(
      context,
      settings.timeMachineDateTime,
    );
    return _buildSection(
      context,
      title: l10n.developer,
      children: [
        // Release 构建下显示关闭开发者选项的开关
        if (kReleaseMode)
          SwitchListTile(
            secondary: _emojiIcon('🛠️'),
            title: Text(l10n.developerOptionsDisable),
            value: true,
            onChanged: (value) {
              if (!value) {
                ref
                    .read(showDeveloperOptionsProvider.notifier)
                    .setEnabled(false);
              }
            },
          ),
        ListTile(
          leading: _emojiIcon('🔧'),
          title: Text(l10n.timeMachine),
          subtitle: Text(
            formattedTimeMachine == null
                ? l10n.timeMachineUseSystemTime
                : '${l10n.timeMachineCurrentTime}: $formattedTimeMachine',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showTimeMachineDialog(
            context,
            l10n,
            controller,
            settings.timeMachineDateTime,
          ),
        ),
        ListTile(
          leading: _emojiIcon('📋'),
          title: const Text('日志'),
          subtitle: const Text('查看应用内运行日志'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LogViewerScreen()),
          ),
        ),
        ListTile(
          leading: _emojiIcon('📊'),
          title: const Text('Analytics'),
          subtitle: Text(
            '通道: ${ref.read(analyticsServiceProvider).channelName}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final service = ref.read(analyticsServiceProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('当前通道: ${service.channelName}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        ListTile(
          leading: _emojiIcon('🎭'),
          title: Text(l10n.demoMode),
          subtitle: Text(l10n.demoModeSubtitle),
          trailing: settings.isDemoModeLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: settings.isDemoMode,
                  onChanged: (value) =>
                      _toggleDemoMode(context, ref, controller, value),
                ),
        ),
        ListTile(
          leading: _emojiIcon('📤'),
          title: Text(l10n.exportData),
          subtitle: Text(l10n.exportDataSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _handleExport(context, ref),
        ),
        ListTile(
          leading: _emojiIcon('📥'),
          title: Text(l10n.importData),
          subtitle: Text(l10n.importDataSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _handleImport(context, ref),
        ),
      ],
    );
  }

  /// 切换演示模式。
  ///
  /// 切库 3 步：准备目标库 → 切换指向 → 重新加载数据。
  /// 开启时创建演示数据库并 seed，关闭时切回生产数据库并清理文件。
  Future<void> _toggleDemoMode(
    BuildContext context,
    WidgetRef ref,
    AppSettings controller,
    bool enabled,
  ) async {
    controller.setDemoModeLoading(true);

    // 记住当前数据库名称，异常时用于恢复连接
    final currentDbName = enabled ? 'echo_loop.db' : 'echo_loop_demo.db';

    try {
      // Step 1: 关闭旧数据库（避免 Drift "multiple databases" 警告）
      await closeCurrentDatabase();

      if (enabled) {
        // Step 2a: 创建并 seed demo 库（幂等）
        final demoDb = AppDatabase(openConnectionWithName('echo_loop_demo.db'));
        await DemoDataSeeder(demoDb).seedIfEmpty();
        // Step 3a: 切换指向
        switchAppDatabase(demoDb, ref);
      } else {
        // Step 2b: 创建 prod 库
        final prodDb = AppDatabase(openConnectionWithName('echo_loop.db'));
        // Step 3b: 切换指向
        switchAppDatabase(prodDb, ref);
        // 清理演示文件（demo 数据库已关闭）
        await DemoDataSeeder.cleanupFiles();
      }

      // Step 4: 重新加载数据（与 MainShell.initState 一致）
      await ref.read(audioLibraryProvider.notifier).loadLibrary();
      ref.read(collectionListProvider.notifier).loadCollections();
      ref.read(tagListProvider.notifier).loadTags();
      await ref.read(learningProgressNotifierProvider.notifier).loadAll();

      await controller.setDemoMode(enabled);
    } catch (e) {
      // 恢复数据库连接，防止 app 处于无数据库状态
      final fallbackDb = AppDatabase(openConnectionWithName(currentDbName));
      switchAppDatabase(fallbackDb, ref);
      await ref.read(audioLibraryProvider.notifier).loadLibrary();
      ref.read(collectionListProvider.notifier).loadCollections();
      ref.read(tagListProvider.notifier).loadTags();
      await ref.read(learningProgressNotifierProvider.notifier).loadAll();

      controller.setDemoModeLoading(false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Demo mode error: $e')));
    }
  }

  /// 处理导出数据操作
  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    var progressStage = l10n.exporting;

    // 显示进度对话框
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    // 进度文字通过外部更新
                    return Text(progressStage);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    var dialogOpen = true;
    try {
      debugPrint('[Backup] Starting export...');
      final zipPath = await performExport(
        ref,
        onProgress: (p) {
          debugPrint('[Backup] Progress: ${p.stage} ${p.progress}');
          progressStage = _localizeProgress(l10n, p.stage);
        },
      );
      debugPrint('[Backup] Export done: $zipPath');

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;

      // 保存文件：移动端用分享面板，桌面端用保存对话框
      final fileName = zipPath.split('/').last;
      if (Platform.isIOS || Platform.isAndroid) {
        await Share.shareXFiles([XFile(zipPath)], subject: fileName);
      } else {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: l10n.exportData,
          fileName: fileName,
          initialDirectory: _downloadsDirectory,
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );
        if (savePath != null) {
          await File(zipPath).copy(savePath);
          debugPrint('[Backup] Saved to: $savePath');
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.exportSuccess)));
          }
        }
      }
      // 清理临时文件
      try {
        await File(zipPath).delete();
      } catch (_) {}
    } catch (e, stack) {
      debugPrint('[Backup] Export error: $e');
      debugPrint('[Backup] Stack: $stack');
      if (!context.mounted) return;
      if (dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.exportData} error: $e')));
    }
  }

  /// 处理导入数据操作
  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    // Step 1: 选择文件
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      initialDirectory: _downloadsDirectory,
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    // Step 2: 读取 manifest 预览
    BackupManifest manifest;
    try {
      manifest = await readBackupManifest(ref, filePath);
    } on BackupException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importInvalidFile)));
      return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importInvalidFile)));
      return;
    }

    if (!context.mounted) return;

    // Step 3: 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildManifestRow(
              l10n.backupTime,
              DateFormat.yMd().add_Hm().format(manifest.createdAt.toLocal()),
            ),
            _buildManifestRow(l10n.backupVersion, manifest.appVersion),
            _buildManifestRow(
              l10n.backupFileCount,
              '${manifest.mediaFileCount}',
            ),
            _buildManifestRow(l10n.backupSize, manifest.formattedSize),
            const SizedBox(height: AppSpacing.m),
            Text(
              l10n.importConfirmMessage,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.importData),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Step 4: 检查版本兼容性
    if (manifest.schemaVersion > AppDatabase.currentSchemaVersion) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importIncompatible)));
      return;
    }

    // Step 5: 执行导入（带进度）
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: AppSpacing.l),
              Text(l10n.importing),
            ],
          ),
        ),
      ),
    );

    try {
      await performImport(ref, filePath);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 关闭进度对话框
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importSuccess)));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 关闭进度对话框

      final message = e is BackupException && e.message == 'incompatibleVersion'
          ? l10n.importIncompatible
          : '${l10n.importData} error: $e';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// 构建 manifest 预览行
  Widget _buildManifestRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// 将进度阶段 key 转为本地化文字
  String _localizeProgress(AppLocalizations l10n, String stage) {
    switch (stage) {
      case 'exportingDatabase':
        return l10n.exportingDatabase;
      case 'exportingPreferences':
        return l10n.exportingPreferences;
      case 'exportingMedia':
        return l10n.exportingMedia;
      case 'exportingPacking':
        return l10n.exportingPacking;
      case 'importingExtracting':
        return l10n.importingExtracting;
      case 'importingMedia':
        return l10n.importingMedia;
      case 'importingDatabase':
        return l10n.importingDatabase;
      case 'importingPreferences':
        return l10n.importingPreferences;
      default:
        return stage;
    }
  }

  /// 显示时光机设置对话框。
  ///
  /// 对话框内允许分别选择日期与时间，并支持恢复系统时间。
  Future<void> _showTimeMachineDialog(
    BuildContext context,
    AppLocalizations l10n,
    AppSettings controller,
    DateTime? initialDateTime,
  ) async {
    DateTime? selectedDateTime = initialDateTime;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final formattedDateTime = _formatTimeMachineDateTime(
              context,
              selectedDateTime,
            );
            return AlertDialog(
              title: Text(l10n.timeMachine),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDateTime == null
                        ? l10n.timeMachineUseSystemTime
                        : '${l10n.timeMachineCurrentTime}: $formattedDateTime',
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final nextDateTime = await _pickDate(
                              dialogContext,
                              selectedDateTime,
                            );
                            if (nextDateTime == null) return;
                            setState(() {
                              selectedDateTime = nextDateTime;
                            });
                          },
                          child: Text(l10n.timeMachineSelectDate),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final nextDateTime = await _pickTime(
                              dialogContext,
                              selectedDateTime,
                            );
                            if (nextDateTime == null) return;
                            setState(() {
                              selectedDateTime = nextDateTime;
                            });
                          },
                          child: Text(l10n.timeMachineSelectTime),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          selectedDateTime = null;
                        });
                      },
                      child: Text(l10n.timeMachineReset),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    await controller.setTimeMachineDateTime(selectedDateTime);
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 选择时光机日期，并保留已有时间部分。
  Future<DateTime?> _pickDate(
    BuildContext context,
    DateTime? currentDateTime,
  ) async {
    final baseDateTime = _normalizedPickerBaseDateTime(currentDateTime);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: baseDateTime,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (pickedDate == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      baseDateTime.hour,
      baseDateTime.minute,
    );
  }

  /// 选择时光机时间，并保留已有日期部分。
  Future<DateTime?> _pickTime(
    BuildContext context,
    DateTime? currentDateTime,
  ) async {
    final baseDateTime = _normalizedPickerBaseDateTime(currentDateTime);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: baseDateTime.hour,
        minute: baseDateTime.minute,
      ),
    );
    if (pickedTime == null) return null;

    return DateTime(
      baseDateTime.year,
      baseDateTime.month,
      baseDateTime.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  /// 为 picker 提供分钟精度的默认时间。
  DateTime _normalizedPickerBaseDateTime(DateTime? currentDateTime) {
    final baseDateTime = currentDateTime ?? DateTime.now();
    return DateTime(
      baseDateTime.year,
      baseDateTime.month,
      baseDateTime.day,
      baseDateTime.hour,
      baseDateTime.minute,
    );
  }

  String? _formatTimeMachineDateTime(BuildContext context, DateTime? dateTime) {
    if (dateTime == null) return null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat('yyyy-MM-dd HH:mm', locale).format(dateTime);
  }

  /// 构建 emoji 图标（Learna AI 风格）
  Widget _emojiIcon(String emoji) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
    );
  }

  /// 在 children 之间插入浅灰分割线
  List<Widget> _intersperseDividers(List<Widget> children) {
    if (children.length <= 1) return children;
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(const Divider(height: 1, indent: 56));
      }
    }
    return result;
  }

  Widget _buildThemeModeTile(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _emojiIcon('🎨'),
      title: Text(l10n.themeMode),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getThemeModeName(l10n, settings.themeMode),
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showThemeModeDialog(context, l10n, settings, controller),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _emojiIcon('🌐'),
      title: Text(l10n.language),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getLanguageName(l10n, settings.locale),
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showLanguageDialog(context, l10n, settings, controller),
    );
  }

  String _getThemeModeName(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => l10n.themeModeLight,
      ThemeMode.dark => l10n.themeModeDark,
      ThemeMode.system => l10n.themeModeSystem,
    };
  }

  String _getLanguageName(AppLocalizations l10n, Locale locale) {
    return switch (locale.languageCode) {
      'zh' => l10n.languageChinese,
      _ => l10n.languageEnglish,
    };
  }

  void _showThemeModeDialog(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.themeMode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context,
              l10n,
              settings,
              controller,
              ThemeMode.system,
              '⚙️',
              l10n.themeModeSystem,
            ),
            _buildThemeOption(
              context,
              l10n,
              settings,
              controller,
              ThemeMode.light,
              '☀️',
              l10n.themeModeLight,
            ),
            _buildThemeOption(
              context,
              l10n,
              settings,
              controller,
              ThemeMode.dark,
              '🌛',
              l10n.themeModeDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
    ThemeMode mode,
    String emoji,
    String label,
  ) {
    final isSelected = settings.themeMode == mode;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      selected: isSelected,
      onTap: () {
        controller.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              context,
              l10n,
              settings,
              controller,
              const Locale('en'),
              '🇺🇸',
              l10n.languageEnglish,
            ),
            _buildLanguageOption(
              context,
              l10n,
              settings,
              controller,
              const Locale('zh'),
              '🇨🇳',
              l10n.languageChinese,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
    Locale locale,
    String emoji,
    String label,
  ) {
    final isSelected = settings.locale == locale;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      selected: isSelected,
      onTap: () {
        controller.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }
}
