import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart'
    show getTemporaryDirectory, getApplicationCacheDirectory;
import '../database/app_database.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/app_update_info.dart';
import '../providers/app_update_provider.dart';
import '../providers/backup_provider.dart';
import '../providers/dev_version_override_provider.dart';
import '../providers/developer_options_provider.dart';
import '../providers/offline_asr_settings_provider.dart';
import '../providers/tts/tts_settings_provider.dart';
import '../services/tts/tts_engine.dart';
import '../providers/package_info_provider.dart';
import '../providers/reminder_settings_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../providers/tag_provider.dart';
import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../config/app_store_config.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/auth/screens/account_screen.dart';
import '../router/app_router.dart';
import '../features/onboarding_survey/providers/onboarding_survey_provider.dart';
import '../services/app_network_image_cache.dart';
import '../services/tts/tts_cache_store.dart';
import '../services/backup/backup_manifest.dart';
import '../services/backup/backup_service.dart';
import '../services/dictionary_download_manager.dart';
import '../services/orphan_file_cleanup_service.dart';
import '../services/temp_cleanup_service.dart';
import '../utils/file_size.dart';
import '../services/demo_data_seeder.dart';
import '../models/dict_entry.dart';
import '../services/dictionary_service.dart';
import '../theme/app_theme.dart';
import '../providers/dictionary/dictionary_registry.dart';
import '../providers/dictionary/visible_sources_provider.dart';
import '../widgets/dictionary/dict_source_presentation.dart';
import 'asr_settings_screen.dart';
import 'asr_test_screen.dart';
import 'dictionary_settings_screen.dart';
import 'tts_settings_screen.dart';
import 'learning_settings_screen.dart';
import 'log_viewer_screen.dart';
import 'playback_settings_screen.dart';
import 'preferences_viewer_screen.dart';
import 'storage_browser_screen.dart';
import 'reminder_settings_screen.dart';
import '../config/api_config.dart';
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
          _buildAccountSection(context, l10n),
          const SizedBox(height: AppSpacing.m),
          _buildSection(
            context,
            title: l10n.appearance,
            children: [
              _buildThemeModeTile(context, l10n, settings, settingsController),
              _buildLanguageTile(context, l10n, settings, settingsController),
              _buildNativeLanguageTile(
                context,
                l10n,
                settings,
                settingsController,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          _buildStudySection(context, ref, l10n),
          const SizedBox(height: AppSpacing.m),
          _buildAboutSection(context, ref, l10n),
          const SizedBox(height: AppSpacing.m),
          _buildStorageSection(context, ref, l10n),
          const SizedBox(height: AppSpacing.m),
          _buildVersionLabel(context, ref, l10n),
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

  /// 构建账号分组：登录、注册与后续账号管理入口。
  Widget _buildAccountSection(BuildContext context, AppLocalizations l10n) {
    final session = ref.watch(supabaseSessionProvider).valueOrNull;
    final isSignedIn = session != null;
    final accountSubtitle = session == null
        ? null
        : switch (authDisplayProviderForSession(session)) {
            AuthDisplayProvider.apple => l10n.authSignedInWithApple,
            AuthDisplayProvider.google => l10n.authSignedInWithGoogle,
            AuthDisplayProvider.email ||
            AuthDisplayProvider.unknown => compactAccountListIdentifier(
              session.user.email ?? session.user.id,
            ),
          };

    return _buildSection(
      context,
      title: l10n.account,
      children: [
        ListTile(
          leading: _emojiIcon('👤'),
          title: Text(l10n.account),
          subtitle: accountSubtitle == null
              ? null
              : Text(
                  accountSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSignedIn ? l10n.authSignedInStatus : l10n.authSignedOutStatus,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () =>
              context.push(isSignedIn ? AppRoutes.account : AppRoutes.login),
        ),
      ],
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

  /// 构建「学习」分组：提醒、学习、语音识别、语音合成、播放、词典等入口合并到同一张卡片中。
  Widget _buildStudySection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final reminderSettings = ref.watch(reminderSettingsNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final showAsr = ref.watch(showOfflineAsrSectionProvider);

    return _buildSection(
      context,
      title: l10n.learningSection,
      children: [
        ListTile(
          leading: _emojiIcon('🔔'),
          title: Text(l10n.reminderSettings),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reminderSettings.savedReviewReminderEnabled)
                Text(
                  reminderSettings.formattedTime,
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
        ListTile(
          leading: _emojiIcon('📚'),
          title: Text(l10n.learningSettings),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const LearningSettingsScreen(),
            ),
          ),
        ),
        if (showAsr)
          ListTile(
            leading: _emojiIcon('🎙️'),
            title: Text(l10n.speechRecognition),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ref.watch(offlineAsrSettingsProvider).backend ==
                          AsrBackend.platform
                      ? l10n.asrBackendPlatform
                      : l10n.asrBackendOffline,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AsrSettingsScreen(),
              ),
            ),
          ),
        ListTile(
          leading: _emojiIcon('🔊'),
          title: Text(l10n.ttsSettings),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _ttsEngineSummary(l10n, ref.watch(ttsSettingsProvider).engine),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TtsSettingsScreen()),
          ),
        ),
        ListTile(
          leading: _emojiIcon('▶️'),
          title: Text(l10n.playbackSettings),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PlaybackSettingsScreen(),
            ),
          ),
        ),
        ListTile(
          leading: _emojiIcon('📖'),
          title: Text(l10n.dictionarySettings),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dictSourceLabel(
                  l10n,
                  ref.watch(resolvedDefaultSourceIdProvider),
                ),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DictionarySettingsScreen(),
            ),
          ),
        ),
      ],
    );
  }

  /// 设置首页仅展示当前语音引擎品牌，口音和音色留在语音合成详情页展示。
  String _ttsEngineSummary(AppLocalizations l10n, TtsEngineKind engine) {
    return switch (engine) {
      TtsEngineKind.platform => platformSpeechEngineName(l10n),
      TtsEngineKind.echoLoop || TtsEngineKind.piper => l10n.asrBackendOffline,
    };
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

  /// 清空缓存：AI 分析缓存 + 临时目录（录音残留、导出/导入临时文件）
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

    // 1. 清空 SQLite 缓存（词级时间戳属于字幕数据，不在此清除）
    final dao = ref.read(sentenceAiCacheDaoProvider);
    final deleted = await dao.deleteAll();

    // 2. 清空内存缓存（句子 AI + AI 词典的 L1，否则清缓存后重查仍命中旧结果）
    ref.read(sentenceAiNotifierProvider).clearMemoryCache();
    ref.read(aiDictionarySourceProvider).clearMemoryCache();

    // 3. 清理临时目录（录音 .caf 残留、Library/Caches 下 app 自建导出/导入临时目录）
    final result = await cleanupAllTempFiles();

    // 3.5 清网络图片磁盘缓存（走 flutter_cache_manager API，自动清文件+索引）
    final imageFreed = await _clearNetworkImageCache();

    // 4. 清理非当前语言的词典文件 + 旧版遗留 dict.db
    final settings = ref.read(appSettingsProvider);
    final dictManager = DictionaryDownloadManager();
    final dictFreed = await dictManager.deleteUnusedDictionaries(
      settings.nativeLanguage,
    );
    dictManager.dispose();

    // 5. 清扫孤儿音频/字幕文件（磁盘有、DB 无引用）+ 全量清波形缓存
    final referencedRelPaths = await ref
        .read(audioItemDaoProvider)
        .getAllReferencedRelPaths();
    final orphanResult = await cleanupOrphanMediaFiles(
      referencedRelPaths: referencedRelPaths,
    );
    final waveformResult = await cleanupAllWaveforms();

    // 6. 清 TTS 合成音频缓存（可再生的 transient 磁盘缓存，含后台预热产物）
    final ttsFreed = await _clearTtsCache(ref);

    final totalFreed =
        result.freedBytes +
        imageFreed +
        dictFreed +
        orphanResult.freedBytes +
        waveformResult.freedBytes +
        ttsFreed;

    if (!context.mounted) return;
    final String message;
    if (deleted == 0 && totalFreed == 0) {
      message = l10n.clearCacheEmpty;
    } else if (totalFreed > 0) {
      message = l10n.clearCacheSuccessWithSize(formatBytes(totalFreed));
      ref.read(analyticsServiceProvider).track(Events.cacheCleared, {
        EventParams.bytesFreed: totalFreed,
      });
    } else {
      message = l10n.clearCacheSuccess;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 清网络图片磁盘缓存，返回释放字节数（best-effort）。
  ///
  /// 用 [AppNetworkImageCache] 的 `emptyCache()`（flutter_cache_manager 标准 API），
  /// 会同时清文件和 json 索引，避免直接删文件导致索引不一致。
  /// 字节数为清理前测量 `Library/Caches/app_network_images` 目录大小，量取失败计 0。
  Future<int> _clearNetworkImageCache() async {
    var freed = 0;
    try {
      final cachesDir = await getTemporaryDirectory();
      final imageDir = Directory(
        '${cachesDir.path}/${AppNetworkImageCache.cacheKey}',
      );
      if (await imageDir.exists()) {
        freed = await calculateDirectorySize(imageDir);
      }
    } catch (_) {}
    try {
      await AppNetworkImageCache.instance.emptyCache();
    } catch (_) {
      freed = 0;
    }
    return freed;
  }

  /// 清 TTS 合成音频缓存，返回释放字节数（best-effort）。
  ///
  /// TTS 缓存（`ApplicationCacheDirectory/tts_cache/`）是可再生的 transient 磁盘
  /// 缓存——含发音按钮合成产物与语音合成设置页的后台预热产物，清掉后下次发音
  /// 重新合成即可。仅清本 app 自建的 `tts_cache/` 子目录（删文件 + 删索引），
  /// 不触碰系统 `Library/Caches` 根（见 §7.5）。
  Future<int> _clearTtsCache(WidgetRef ref) async {
    try {
      final store = TtsCacheStore(
        resolveDao: () => ref.read(ttsCacheDaoProvider),
        resolveCacheDir: getApplicationCacheDirectory,
      );
      return await store.clearAll();
    } catch (_) {
      return 0;
    }
  }

  /// 构建关于信息区域
  Widget _buildAboutSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final updateState = ref.watch(appUpdateProvider);
    final isChecking = updateState is AppUpdateChecking;

    return _buildSection(
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
          onTap: isChecking ? null : () => _checkForUpdate(context, ref, l10n),
        ),
        ListTile(
          leading: _emojiIcon('📜'),
          title: Text(l10n.termsOfService),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => launchUrl(Uri.parse('https://www.echo-loop.top/terms')),
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
        if (defaultTargetPlatform == TargetPlatform.iOS)
          ListTile(
            leading: _emojiIcon('⭐'),
            title: Text(l10n.rateUs),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => launchUrl(
              appStoreReviewUri,
              mode: LaunchMode.externalApplication,
            ),
          ),
        ListTile(
          leading: _emojiIcon('👥'),
          title: Text(l10n.joinCommunity),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final isZh = Localizations.localeOf(context).languageCode == 'zh';
            final path = isZh ? '/zh-CN/social' : '/en/social';
            launchUrl(Uri.parse('$apiBaseUrl$path'));
          },
        ),
        ListTile(
          leading: SizedBox(
            width: 32,
            height: 32,
            child: Center(child: FaIcon(FontAwesomeIcons.github, size: 22)),
          ),
          title: Text(l10n.viewSourceCode),
          subtitle: const Text(
            'github.com/echo-loop/Echo-Loop',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              launchUrl(Uri.parse('https://github.com/echo-loop/Echo-Loop/')),
        ),
      ],
    );
  }

  /// 版本号标签，置于设置页最底部。
  /// 连续点击可解锁开发者选项。
  Widget _buildVersionLabel(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final versionDisplay = ref.watch(packageInfoProvider).version;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleVersionTap(context, ref, l10n),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            kReleaseMode
                ? 'Version $versionDisplay'
                : 'Version $versionDisplay (Debug)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
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
        ..showSnackBar(SnackBar(content: Text(l10n.developerOptionsEnabled)));
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

  /// 弹出版本号覆盖对话框（开发者选项）
  ///
  /// 输入框预填当前生效的版本号（已覆盖则为覆盖值，否则为真实版本号）。
  /// 确定后写入 [devVersionOverrideProvider]，下次检查更新即按此版本比较；
  /// 清除则恢复使用真实版本号。
  Future<void> _showVersionOverrideDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final realVersion = ref.read(packageInfoProvider).version;
    final current = ref.read(devVersionOverrideProvider);
    final textController = TextEditingController(text: current ?? realVersion);

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('版本号覆盖'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('真实版本号：$realVersion'),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '模拟版本号',
                hintText: '如 1.0.0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '设为低于远程 minimumVersion 触发强制更新，'
              '低于 latestVersion 触发可选更新。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          // 清除覆盖：返回空串作为清除信号
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('清除覆盖'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    textController.dispose();
    // null = 取消，不改动；'' = 清除；其它 = 设置覆盖
    if (result == null) return;
    ref.read(devVersionOverrideProvider.notifier).setOverride(result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.isEmpty
                ? '已清除版本号覆盖，恢复真实版本 $realVersion'
                : '已覆盖版本号为 $result，可点"检查更新"测试',
          ),
        ),
      );
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
        // 关闭开发者选项的开关（所有构建模式下均可见）
        SwitchListTile(
          secondary: _emojiIcon('🛠️'),
          title: Text(l10n.developerOptionsDisable),
          value: true,
          onChanged: (value) {
            if (!value) {
              ref.read(showDeveloperOptionsProvider.notifier).setEnabled(false);
            }
          },
        ),
        ListTile(
          leading: _emojiIcon('🔧'),
          title: Text(l10n.timeMachine),
          trailing: _trailingValue(
            context,
            formattedTimeMachine ?? l10n.timeMachineUseSystemTime,
          ),
          onTap: () => _showTimeMachineDialog(
            context,
            l10n,
            controller,
            settings.timeMachineDateTime,
          ),
        ),
        ListTile(
          leading: _emojiIcon('🏷'),
          title: const Text('版本号覆盖'),
          subtitle: const Text('模拟旧版本以测试更新弹窗，重启后自动重置'),
          trailing: _trailingValue(
            context,
            ref.watch(devVersionOverrideProvider) ?? '真实版本',
          ),
          onTap: () => _showVersionOverrideDialog(context, ref),
        ),
        ListTile(
          leading: _emojiIcon('🎙'),
          title: const Text('ASR 引擎测试'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AsrTestScreen()),
          ),
        ),
        ListTile(
          leading: _emojiIcon('📋'),
          title: const Text('日志'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LogViewerScreen()),
          ),
        ),
        ListTile(
          leading: _emojiIcon('🧭'),
          title: Text(l10n.resetNewUserGuide),
          onTap: () => _resetNewUserGuide(context, ref, l10n),
        ),
        ListTile(
          leading: _emojiIcon('📝'),
          title: Text(l10n.resetOnboarding),
          onTap: () => _resetOnboarding(context, ref, l10n),
        ),
        ListTile(
          leading: _emojiIcon('📊'),
          title: const Text('Analytics'),
          trailing: _trailingValue(
            context,
            ref.read(analyticsServiceProvider).channelName,
          ),
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
          leading: _emojiIcon('🎯'),
          title: const Text('字幕自动校准'),
          subtitle: const Text('AI 转录完成后按本地音频静音微调句边界'),
          trailing: Switch(
            value: settings.subtitleAutoAlignEnabled,
            onChanged: (value) => ref
                .read(appSettingsProvider.notifier)
                .setSubtitleAutoAlignEnabled(value),
          ),
        ),
        ListTile(
          leading: _emojiIcon('📤'),
          title: Text(l10n.exportData),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _handleExport(context, ref),
        ),
        ListTile(
          leading: _emojiIcon('📥'),
          title: Text(l10n.importData),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _handleImport(context, ref),
        ),
        ListTile(
          leading: _emojiIcon('📖'),
          title: const Text('词典查询'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showDictionaryLookupDialog(context),
        ),
        ListTile(
          leading: _emojiIcon('⚙️'),
          title: const Text('偏好设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PreferencesViewerScreen(),
            ),
          ),
        ),
        ListTile(
          leading: _emojiIcon('💾'),
          title: const Text('内部存储'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const StorageBrowserScreen(),
            ),
          ),
        ),
      ],
    );
  }

  /// 重置页面级新用户引导状态，便于开发调试重复验证引导流程。
  Future<void> _resetNewUserGuide(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    await ref
        .read(guideControllerProvider.notifier)
        .resetFlows(GuideFlowIds.all);

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.resetNewUserGuideDone)));
  }

  /// 重置 Onboarding 问卷状态：清空问卷答案 SP key，便于开发调试。
  ///
  /// 故意**不动**用户的界面语言（`locale` SP key）和其它设置——老用户
  /// 已经选过中文，重置 onboarding 不应把他们的偏好一起抹掉，否则热重启后
  /// 会回退到"跟随系统"。
  ///
  /// `initialOnboardingCompletedProvider` 在 `main()` 通过
  /// `overrideWithValue` 注入，运行期不可改写，因此重置后必须重启 App
  /// 才能再次进入问卷。
  Future<void> _resetOnboarding(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final storage = ref.read(onboardingStorageProvider);
    await storage.clear();

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.resetOnboardingDone)));
  }

  /// 显示词典查询对话框
  void _showDictionaryLookupDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _DictionaryLookupDialog(),
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
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(zipPath)],
          subject: fileName,
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : Rect.zero,
        );
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
    final minimumDateTime = minimumTimeMachineDateTime(DateTime.now());
    final baseDateTime = _normalizedPickerBaseDateTime(
      currentDateTime,
      minimumDateTime: minimumDateTime,
    );
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: baseDateTime,
      firstDate: DateTime(
        minimumDateTime.year,
        minimumDateTime.month,
        minimumDateTime.day,
      ),
      lastDate: DateTime(2100, 12, 31),
    );
    if (pickedDate == null) return null;

    return normalizedFutureTimeMachineDateTime(
      DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        baseDateTime.hour,
        baseDateTime.minute,
      ),
      DateTime.now(),
    );
  }

  /// 选择时光机时间，并保留已有日期部分。
  Future<DateTime?> _pickTime(
    BuildContext context,
    DateTime? currentDateTime,
  ) async {
    final baseDateTime = _normalizedPickerBaseDateTime(
      currentDateTime,
      minimumDateTime: minimumTimeMachineDateTime(DateTime.now()),
    );
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: baseDateTime.hour,
        minute: baseDateTime.minute,
      ),
    );
    if (pickedTime == null) return null;

    return normalizedFutureTimeMachineDateTime(
      DateTime(
        baseDateTime.year,
        baseDateTime.month,
        baseDateTime.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
      DateTime.now(),
    );
  }

  /// 为 picker 提供分钟精度的默认时间。
  DateTime _normalizedPickerBaseDateTime(
    DateTime? currentDateTime, {
    required DateTime minimumDateTime,
  }) {
    final baseDateTime = currentDateTime == null
        ? minimumDateTime
        : normalizedFutureTimeMachineDateTime(
            currentDateTime,
            minimumDateTime.subtract(const Duration(minutes: 1)),
          );
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

  /// 开发者选项中显示「当前值 + chevron」的 trailing，保持与普通设置项一致的视觉。
  Widget _trailingValue(BuildContext context, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        const SizedBox(width: AppSpacing.xs),
        const Icon(Icons.chevron_right),
      ],
    );
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

  Widget _buildNativeLanguageTile(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName =
        supportedNativeLanguages[settings.nativeLanguage] ??
        settings.nativeLanguage;
    return ListTile(
      leading: _emojiIcon('🗣️'),
      title: Text(l10n.nativeLanguage),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayName,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () =>
          _showNativeLanguageDialog(context, l10n, settings, controller),
    );
  }

  void _showNativeLanguageDialog(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.nativeLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: Text(
                l10n.nativeLanguageDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final entry in supportedNativeLanguages.entries)
              _buildNativeLanguageOption(
                context,
                settings,
                controller,
                entry.key,
                entry.value,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeLanguageOption(
    BuildContext context,
    AppSettingsState settings,
    AppSettings controller,
    String code,
    String label,
  ) {
    final isSelected = settings.nativeLanguage == code;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(label),
      selected: isSelected,
      onTap: () {
        if (!isSelected) {
          ref
              .read(analyticsServiceProvider)
              .track(Events.nativeLanguageChanged, {
                EventParams.previousLanguage: settings.nativeLanguage,
                EventParams.newLanguage: code,
              });
        }
        controller.setNativeLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  String _getThemeModeName(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => l10n.themeModeLight,
      ThemeMode.dark => l10n.themeModeDark,
      ThemeMode.system => l10n.themeModeSystem,
    };
  }

  String _getLanguageName(AppLocalizations l10n, Locale? locale) {
    if (locale == null) return l10n.languageSystem;
    if (locale.languageCode == 'zh') return l10n.languageChinese;
    if (locale.languageCode == 'en') return l10n.languageEnglish;
    return l10n.languageSystem;
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
        if (!isSelected) {
          ref.read(analyticsServiceProvider).track(Events.themeModeChanged, {
            EventParams.previousMode: settings.themeMode.name,
            EventParams.newMode: mode.name,
          });
        }
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: Text(
                l10n.languageDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _buildLanguageOption(
              context,
              l10n,
              settings,
              controller,
              null,
              '⚙️',
              l10n.languageSystem,
            ),
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
              const Locale('zh', 'CN'),
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
    Locale? locale,
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
        if (!isSelected) {
          ref.read(analyticsServiceProvider).track(Events.appLocaleChanged, {
            EventParams.previousLocale:
                settings.locale?.languageCode ?? 'system',
            EventParams.newLocale: locale?.languageCode ?? 'system',
          });
        }
        controller.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }
}

/// 词典查询对话框
///
/// 输入单词后调用 [DictionaryService.lookup] 查询，
/// 显示音标、释义、柯林斯星级和考试标签，未收录时提示。
class _DictionaryLookupDialog extends StatefulWidget {
  const _DictionaryLookupDialog();

  @override
  State<_DictionaryLookupDialog> createState() =>
      _DictionaryLookupDialogState();
}

class _DictionaryLookupDialogState extends State<_DictionaryLookupDialog> {
  final _controller = TextEditingController();
  DictEntry? _result;
  bool _searched = false;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _lookup() {
    final word = _controller.text.trim();
    if (word.isEmpty) return;

    final entry = DictionaryService.instance.lookup(word);
    setState(() {
      _result = entry;
      _searched = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('词典查询'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '输入单词...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _lookup,
                ),
              ),
              onSubmitted: (_) => _lookup(),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const CircularProgressIndicator()
            else if (_searched)
              _buildResult(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  /// 构建查询结果展示
  Widget _buildResult() {
    if (_result == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('未收录', style: TextStyle(color: Colors.red, fontSize: 16)),
      );
    }

    final entry = _result!;
    return Flexible(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 单词 + 音标
            SelectableText(
              '${entry.word}  ${entry.phonetic}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 柯林斯星级
            if (entry.collins > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '柯林斯: ${'★' * entry.collins}${'☆' * (5 - entry.collins)}',
                  style: TextStyle(color: Colors.orange[700]),
                ),
              ),

            // 考试标签
            if (entry.examTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  children: entry.examTags
                      .map(
                        (tag) => Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ),

            // 释义
            if (entry.translation != null)
              SelectableText(
                entry.translation!,
                style: const TextStyle(fontSize: 15),
              ),
          ],
        ),
      ),
    );
  }
}
