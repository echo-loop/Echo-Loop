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
import '../models/learning_progress.dart';
import '../providers/app_update_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/review_reminder_provider.dart';
import '../providers/study_stats_provider.dart';
import '../providers/study_task_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/time_provider.dart';
import '../services/review_reminder_service.dart';
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
  ProviderSubscription<Map<String, LearningProgress>>?
      _progressMapSubscription;
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

      // 监听学习进度变化，确保完成复习阶段后重新调度 per-audio 通知。
      // pendingStudyTaskCountProvider 只监听任务数量，完成复习后任务数
      // 可能不变（reviewReady → reviewUpcoming），导致通知不会被调度。
      _progressMapSubscription = ref.listenManual(
        learningProgressNotifierProvider.select((s) => s.progressMap),
        (_, __) {
          final service = ref.read(reviewReminderServiceProvider);
          _syncPerAudioReminders(service);
        },
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
    _progressMapSubscription?.close();
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

  /// 切换 tab 时调用，切到学习 tab 时刷新数据
  void _onTabSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    // 切换到学习 tab 时刷新数据
    if (index == 1) {
      _refreshStudyData();
    }
  }

  /// 刷新学习页数据，确保时间相关计算和统计使用最新值
  void _refreshStudyData() {
    ref.invalidate(studyTaskProvider);
    ref.invalidate(completedAudioProvider);
    ref.read(studyStatsNotifierProvider.notifier).refresh();
  }

  Future<void> _syncDailyReminder(int pendingTaskCount) async {
    final service = ref.read(reviewReminderServiceProvider);
    await service.syncDailyReminder(pendingTaskCount: pendingTaskCount);
    await _syncPerAudioReminders(service);
  }

  /// 收集当前处于复习阶段且 nextReviewAt 在未来的音频，调度单条通知
  Future<void> _syncPerAudioReminders(ReviewReminderService service) async {
    final progressMap = ref.read(
      learningProgressNotifierProvider.select((s) => s.progressMap),
    );
    final audioItems = ref.read(audioLibraryProvider).audioItems;

    // 按 id 建索引以便快速查找名称
    final audioNameById = {for (final a in audioItems) a.id: a.name};

    final now = ref.read(nowProvider)();
    final reminders = <PerAudioReminderInfo>[];

    for (final entry in progressMap.entries) {
      final progress = entry.value;
      if (!progress.isInReviewStage) continue;
      final reviewAt = progress.nextReviewAt;
      if (reviewAt == null || !reviewAt.isAfter(now)) continue;

      final name = audioNameById[entry.key];
      if (name == null) continue;

      reminders.add(
        PerAudioReminderInfo(
          audioId: entry.key,
          audioName: name,
          triggerAt: reviewAt,
          reviewRound: progress.completedReviewStages + 1,
        ),
      );
    }

    // 按 triggerAt 升序，取前 60 条（iOS 64 限制留余量）
    reminders.sort((a, b) => a.triggerAt.compareTo(b.triggerAt));
    final capped = reminders.length > 60 ? reminders.sublist(0, 60) : reminders;

    await service.syncPerAudioReminders(capped);
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
                  onDestinationSelected: _onTabSelected,
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
                  onDestinationSelected: _onTabSelected,
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
