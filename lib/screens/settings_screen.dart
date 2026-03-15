import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/app_database.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/app_update_info.dart';
import '../providers/app_update_provider.dart';
import '../providers/developer_options_provider.dart';
import '../providers/package_info_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/word_ai_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/tag_provider.dart';
import '../services/demo_data_seeder.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          _buildStorageSection(context, ref, l10n),
          const SizedBox(height: AppSpacing.m),
          _buildAboutSection(context, ref, l10n),
          if (showDeveloperOptions) ...[
            const SizedBox(height: AppSpacing.m),
            _buildDeveloperSection(
                context, ref, l10n, settings, settingsController),
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

    // 清空 SQLite 缓存
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
              onTap: () =>
                  launchUrl(Uri.parse('mailto:support@echo-loop.top')),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Center(
          child: Text(
            'v$version',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
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
    final currentDbName =
        enabled ? 'echo_loop.db' : 'echo_loop_demo.db';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo mode error: $e')),
      );
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
