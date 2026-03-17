/// Tab 导航外壳组件
///
/// 从 main.dart 的 MainScreen 提取，使用 StatefulNavigationShell
/// 实现 Tab 切换并保持各 Tab 状态。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/app_update_info.dart';
import '../providers/app_update_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/review_reminder_provider.dart';
import '../providers/study_task_provider.dart';
import '../providers/tag_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_dialog.dart';

/// 主导航壳组件 — 包含 NavigationRail / NavigationBar + 内容区域
class MainShell extends ConsumerStatefulWidget {
  /// go_router 提供的 StatefulNavigationShell
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  ProviderSubscription<int>? _pendingTaskCountSubscription;
  ProviderSubscription<AppUpdateState>? _appUpdateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(audioLibraryProvider.notifier).loadLibrary().then((_) {
        ref.read(collectionListProvider.notifier).loadCollections();
        ref.read(tagListProvider.notifier).loadTags();
        ref.read(audioLibraryProvider.notifier).backfillDurations();
        ref.read(audioLibraryProvider.notifier).backfillTranscriptStats();
      });
      await ref.read(learningProgressNotifierProvider.notifier).loadAll();

      _pendingTaskCountSubscription = ref.listenManual<int>(
        pendingStudyTaskCountProvider,
        (_, next) {
          _syncDailyReminder(next);
        },
        fireImmediately: true,
      );

      // 监听版本更新状态，弹出对话框
      _appUpdateSubscription = ref.listenManual<AppUpdateState>(
        appUpdateProvider,
        (_, next) {
          if (next is AppUpdateResult && next.type != AppUpdateType.none) {
            _showUpdateDialog(next);
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _pendingTaskCountSubscription?.close();
    _appUpdateSubscription?.close();
    super.dispose();
  }

  /// 显示版本更新对话框
  void _showUpdateDialog(AppUpdateResult result) {
    if (!mounted || result.info == null) return;
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

  Future<void> _syncDailyReminder(int pendingTaskCount) async {
    await ref
        .read(reviewReminderServiceProvider)
        .syncDailyReminder(pendingTaskCount: pendingTaskCount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;

        return Scaffold(
          body: Row(
            children: [
              if (isWideScreen)
                NavigationRail(
                  extended: constraints.maxWidth >= 800,
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    widget.navigationShell.goBranch(
                      index,
                      initialLocation:
                          index == widget.navigationShell.currentIndex,
                    );
                  },
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.library_music_outlined),
                      selectedIcon: const Icon(
                        Icons.library_music,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.library),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.school_outlined),
                      selectedIcon: const Icon(
                        Icons.school,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.study),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.bookmark_border),
                      selectedIcon: const Icon(
                        Icons.bookmark,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.favorites),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(
                        Icons.person,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.profile),
                    ),
                  ],
                ),
              Expanded(child: widget.navigationShell),
            ],
          ),
          bottomNavigationBar: isWideScreen
              ? null
              : NavigationBar(
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    widget.navigationShell.goBranch(
                      index,
                      initialLocation:
                          index == widget.navigationShell.currentIndex,
                    );
                  },
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.library_music_outlined),
                      selectedIcon: const Icon(
                        Icons.library_music,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.library,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.school_outlined),
                      selectedIcon: const Icon(
                        Icons.school,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.study,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.bookmark_border),
                      selectedIcon: const Icon(
                        Icons.bookmark,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.favorites,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(
                        Icons.person,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.profile,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
