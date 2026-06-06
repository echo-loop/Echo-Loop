/// Tab 导航外壳组件
///
/// 从 main.dart 的 MainScreen 提取，使用 StatefulNavigationShell
/// 实现 Tab 切换并保持各 Tab 状态。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/app_update_info.dart';
import '../models/learning_progress.dart';
import '../models/reminder_settings.dart';
import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../database/providers.dart';
import '../providers/app_update_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/notification_permission_provider.dart';
import '../providers/reminder_settings_provider.dart';
import '../providers/review_reminder_provider.dart';
import '../providers/study_stats_provider.dart';
import '../providers/study_task_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/time_provider.dart';
import '../services/app_logger.dart';
import '../services/review_reminder_service.dart';
import '../services/review_reminder_time_calculator.dart';
import '../providers/new_user_guide_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/guide_flow.dart';
import '../widgets/notification_permission_dialog.dart';
import 'app_router.dart' show rootNavigatorKey;

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
  ProviderSubscription<Map<String, LearningProgress>>? _progressMapSubscription;
  ProviderSubscription<AppUpdateState>? _appUpdateSubscription;
  ProviderSubscription<ReminderSettings>? _reminderSettingsSubscription;
  ProviderSubscription<int>? _notificationPromptSubscription;
  ProviderSubscription<GuideControllerState>? _guideWaitSubscription;
  late final AppLifecycleListener _lifecycleListener;

  /// 资源库 tab 图标的引导 target key；在整个 shell 生命周期内保持稳定。
  final GlobalKey _keyLibraryNav = GlobalKey();

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _onAppResume);

    // 版本更新监听提前注册，确保首次触发 appUpdateProvider.build() → 后台检查。
    // 同一版本的重复结果不再弹窗（冷启动后用户未处理 → 回前台不反复打扰）。
    _appUpdateSubscription = ref.listenManual<AppUpdateState>(appUpdateProvider, (
      previous,
      next,
    ) {
      if (next is! AppUpdateResult || next.type == AppUpdateType.none) return;
      if (previous is AppUpdateResult &&
          previous.type == next.type &&
          previous.info?.latestVersion == next.info?.latestVersion) {
        AppLogger.log(
          'AppUpdate',
          'listener skipped: same version ${next.info?.latestVersion}',
        );
        return;
      }
      AppLogger.log(
        'AppUpdate',
        'listener show dialog: ${next.info?.latestVersion} (${next.type.name})',
      );
      _showUpdateDialog(next);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 启动时同步系统通知权限状态到 SP，防止已授权设备误弹 pre-prompt
      ref
          .read(notificationPermissionServiceProvider)
          .syncSystemAuthorizationStatus();

      AppLogger.log('StartupLoad', 'library bootstrap start');
      try {
        await ref.read(audioLibraryProvider.notifier).loadLibrary();
        final audioState = ref.read(audioLibraryProvider);
        AppLogger.log(
          'StartupLoad',
          'library bootstrap audio done: stateItems=${audioState.audioItems.length}',
        );

        await ref.read(collectionListProvider.notifier).loadCollections();
        final collectionState = ref.read(collectionListProvider);
        AppLogger.log(
          'StartupLoad',
          'library bootstrap collections done: '
              'stateCollections=${collectionState.rawCollections.length}',
        );

        ref.read(tagListProvider.notifier).loadTags();
        ref.read(audioLibraryProvider.notifier).backfillDurations();
        // 先把旧字幕文件内容 backfill 进 DB 列，再补统计（统计优先读列）。
        await ref.read(audioLibraryProvider.notifier).backfillTranscriptSrt();
        ref.read(audioLibraryProvider.notifier).backfillTranscriptStats();
      } catch (e, st) {
        AppLogger.log('StartupLoad', 'library bootstrap failed: $e');
        AppLogger.log('StartupLoad', st.toString());
      }
      // 学习进度加载失败时给用户 snackbar 反馈，而不是默默吞掉；
      // isLoading 已在 notifier 内部重置，状态不会卡死。
      try {
        await ref.read(learningProgressNotifierProvider.notifier).loadAll();
      } catch (_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.learningProgressLoadFailed),
            action: SnackBarAction(
              label: l10n.retry,
              onPressed: () => ref
                  .read(learningProgressNotifierProvider.notifier)
                  .loadAll()
                  .catchError((_) {
                    /* 重试失败不再嵌套提示 */
                  }),
            ),
          ),
        );
      }

      // 启动时调度收藏复习提醒 + per-audio 提醒
      await _syncSavedReviewReminder();

      _pendingTaskCountSubscription = ref.listenManual<int>(
        pendingStudyTaskCountProvider,
        (_, __) {
          // 任务数变化时重新同步 per-audio 提醒
          final service = ref.read(reviewReminderServiceProvider);
          _syncPerAudioReminders(service);
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

      // 监听提醒设置变更，触发重新同步通知调度
      _reminderSettingsSubscription = ref.listenManual<ReminderSettings>(
        reminderSettingsNotifierProvider,
        (_, next) {
          _onReminderSettingsChanged(next);
        },
      );

      // 监听通知权限 pre-prompt 触发器：价值锚点（首次完成 sub_stage / 收藏）
      // 调用 `maybeTriggerPrompt()` 通过判定后会把计数 +1，本监听弹出对话框。
      // 用根 navigator context 弹，保证覆盖所有子路由。
      //
      // **延迟 500ms**：锚点常在子页面里触发（如 BlindListenPlayerScreen
      // 完成对话框确认后 `completeCurrentSubStage` 紧接 `exitLearningMode` +
      // `context.pop()`）。若立即 push dialog 到 root navigator，紧随其后的
      // pop 会把 dialog 当作栈顶给关掉。给 in-flight 导航 500ms 落定再弹。
      //
      // **等 guide flow 结束**：sub_stage 完成回到学习计划页同时会触发新手引导
      // showcase（如 `learning_plan_pause_learning`），两个 modal 同时出现会
      // 互相挡住、抢占用户注意力。polling 等 `guideControllerProvider.isActive`
      // 转为 false 后再弹 pre-prompt。
      _notificationPromptSubscription = ref.listenManual<int>(
        notificationPromptTriggerProvider,
        (previous, next) async {
          AppLogger.log(
            'NotifPerm',
            'MainShell listener: previous=$previous next=$next',
          );
          if (previous == null || previous == next) return;

          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!mounted) {
            AppLogger.log(
              'NotifPerm',
              'MainShell listener: unmounted during delay, skip',
            );
            ref
                .read(notificationPromptTriggerProvider.notifier)
                .onDialogClosed();
            return;
          }

          // 等待所有正在显示的 guide flow（showcase tooltip 等）结束。
          // 事件驱动：通过 listen guideControllerProvider，active 转 inactive
          // 的瞬间触发；如果 guide 永远不结束，dialog 也不弹——那是 guide 系统的 bug。
          await _waitForGuideToFinish();
          if (!mounted) {
            ref
                .read(notificationPromptTriggerProvider.notifier)
                .onDialogClosed();
            return;
          }

          final ctx = rootNavigatorKey.currentContext;
          if (ctx == null) {
            AppLogger.log(
              'NotifPerm',
              'MainShell listener: rootNavigatorKey.currentContext is null, skip',
            );
            ref
                .read(notificationPromptTriggerProvider.notifier)
                .onDialogClosed();
            return;
          }
          AppLogger.log('NotifPerm', 'MainShell listener: showing dialog');
          try {
            await maybeShowBookmarkNotificationPrompt(ctx, ref);
            AppLogger.log('NotifPerm', 'MainShell listener: dialog closed');
          } finally {
            ref
                .read(notificationPromptTriggerProvider.notifier)
                .onDialogClosed();
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _pendingTaskCountSubscription?.close();
    _progressMapSubscription?.close();
    _appUpdateSubscription?.close();
    _reminderSettingsSubscription?.close();
    _notificationPromptSubscription?.close();
    _guideWaitSubscription?.close();
    super.dispose();
  }

  /// 等待 guide flow 结束（事件驱动）。如果当前没有 active guide 立刻 return；
  /// 否则监听 [guideControllerProvider]，active 转 inactive 时 complete。
  ///
  /// 竞态防护：listenManual 注册后二次检查 isActive，防止 guide 在检查和注册
  /// 之间转为 inactive 导致 completer 永远不完成。
  Future<void> _waitForGuideToFinish() {
    final controller = ref.read(guideControllerProvider);
    if (!controller.isActive) {
      return Future.value();
    }
    final completer = Completer<void>();
    late ProviderSubscription<GuideControllerState> sub;
    sub = ref.listenManual<GuideControllerState>(guideControllerProvider, (
      previous,
      next,
    ) {
      if (!next.isActive && !completer.isCompleted) {
        sub.close();
        _guideWaitSubscription = null;
        AppLogger.log(
          'NotifPerm',
          'MainShell listener: guide finished, resuming pre-prompt',
        );
        completer.complete();
      }
    });
    _guideWaitSubscription = sub;

    // 二次检查：防止 guide 在 listenManual 注册前瞬间转为 inactive
    if (!ref.read(guideControllerProvider).isActive) {
      if (!completer.isCompleted) {
        sub.close();
        _guideWaitSubscription = null;
        AppLogger.log(
          'NotifPerm',
          'MainShell listener: guide already finished after listen, '
              'resuming pre-prompt',
        );
        completer.complete();
      }
      return completer.future;
    }

    AppLogger.log(
      'NotifPerm',
      'MainShell listener: guide active '
          '(${controller.activeFlowId}), '
          'waiting via listener…',
    );
    return completer.future;
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

  /// Tab 切换埋点：StatefulShellRoute 的 Tab 切换不经过 Navigator，
  /// AnalyticsObserver 无法自动捕获，需手动上报。
  static const _tabScreenNames = [
    'collections',
    'study',
    'favorites',
    'settings',
  ];

  /// 切换 tab 时调用，切到学习 tab 时刷新数据
  void _onTabSelected(int index) {
    // Tab 切换埋点
    final screenName = _tabScreenNames[index];
    ref.read(analyticsServiceProvider).track(Events.screenView, {
      EventParams.screenName: screenName,
    });

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

  /// App 回到前台回调：刷新学习数据 + 后台检查版本更新 + 同步通知权限
  void _onAppResume() {
    AppLogger.log('AppUpdate', 'onAppResume: trigger checkInBackground');
    _refreshStudyData();
    ref.read(appUpdateProvider.notifier).checkInBackground();
    // 回前台时同步系统通知权限状态，覆盖用户在系统设置中手动变更的情况
    ref
        .read(notificationPermissionServiceProvider)
        .syncSystemAuthorizationStatus();
  }

  /// 提醒设置变更回调：重新同步收藏复习提醒和音频复习提醒
  ///
  /// 先手动同步 timeCalculator（避免与 ref.listen 的执行顺序竞争），
  /// 再根据开关状态调度或取消通知。
  Future<void> _onReminderSettingsChanged(ReminderSettings settings) async {
    AppLogger.log(
      'ReviewReminder',
      'settings changed savedEnabled=${settings.savedReviewReminderEnabled} '
          'time=${settings.formattedTime} '
          'perAudioEnabled=${settings.perAudioReminderEnabled}',
    );
    final service = ref.read(reviewReminderServiceProvider);

    // 确保 service 使用最新时间，不依赖 ref.listen 的执行顺序
    service.updateTimeCalculator(
      FixedTimeReminderCalculator(
        hour: settings.savedReviewReminderHour,
        minute: settings.savedReviewReminderMinute,
      ),
    );

    // 收藏复习提醒：开关关闭时 cancel，开启时重新调度
    if (!settings.savedReviewReminderEnabled) {
      await service.cancelSavedReviewReminder();
    } else {
      await _syncSavedReviewReminder();
    }

    // per-audio 提醒：开关关闭时全量 cancel，开启时重新调度
    if (!settings.perAudioReminderEnabled) {
      await service.cancelAllPerAudioReminders();
    } else {
      await _syncPerAudioReminders(service);
    }
    AppLogger.log(
      'ReviewReminder',
      'settings changed resync complete time=${settings.formattedTime}',
    );
  }

  /// 查询收藏数据并调度收藏复习提醒
  ///
  /// 收藏句子或单词任一不为空时才调度，否则取消。
  Future<void> _syncSavedReviewReminder() async {
    final settings = ref.read(reminderSettingsNotifierProvider);
    final service = ref.read(reviewReminderServiceProvider);

    if (!settings.savedReviewReminderEnabled) {
      await service.cancelSavedReviewReminder();
      return;
    }

    // 轻量查询，只在 App 启动和设置变更时执行
    final sentenceCount = await ref.read(bookmarkDaoProvider).countAll();
    final words = await ref.read(savedWordDaoProvider).getAll();
    final hasSaved = sentenceCount > 0 || words.isNotEmpty;

    await service.syncSavedReviewReminder(hasSavedContent: hasSaved);
    await _syncPerAudioReminders(service);
  }

  /// 收集当前处于复习阶段且 nextReviewAt 在未来的音频，调度单条通知
  Future<void> _syncPerAudioReminders(ReviewReminderService service) async {
    final settings = ref.read(reminderSettingsNotifierProvider);
    if (!settings.perAudioReminderEnabled) {
      await service.cancelAllPerAudioReminders();
      return;
    }

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
      if (progress.isPaused) continue;
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

    // ----- 新手引导 flow：仅首次安装首次启动时在学习 tab 提示去资源库 -----
    // 触发条件（全部满足才显示）：
    //   1. 当前在学习 tab（默认落地位置）；
    //   2. `first_launch_done` 哨兵未曾设置过（本次启动属于首次启动）；
    //   3. 学习进度加载完毕且为空。
    // 说明：
    //   - 哨兵（2）保证"以后版本的新安装识别准确"；
    //   - 学习进度 gate（3）为本次引入哨兵机制前已存在的老用户兜底——他们
    //     升级后哨兵同样缺失，会被误判为首启，需要靠"已有学习进度"排除。
    //     不用资源库是否为空来判断：Examples 合集在首启时会被预装入库，
    //     `audioItems` 对新老用户都不为空，无法区分。学习进度只有用户真正
    //     学习过才会生成，天然可区分。
    //   - GuideRegistry 的 seen 持久化继续保证"看过一次就不再出现"。
    final isFirstLaunch = ref.watch(isFirstLaunchProvider);
    final progress = ref.watch(learningProgressNotifierProvider);
    final hasNoProgress = !progress.isLoading && progress.progressMap.isEmpty;
    final isFreshInstall = isFirstLaunch && hasNoProgress;
    final stepLibraryNav = GuideStep(
      key: _keyLibraryNav,
      title: l10n.guideMainShellVisitLibraryTitle,
      description: l10n.guideMainShellVisitLibraryDescription,
    );
    final flows = <GuideFlow>[
      GuideFlow(
        flowId: GuideFlowIds.mainShellVisitLibrary,
        shouldRun: widget.navigationShell.currentIndex == 1 && isFreshInstall,
        steps: [stepLibraryNav],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;

        return GuideFlowSequenceHost(
          flows: flows,
          child: Scaffold(
            body: Row(
              children: [
                if (isWideScreen)
                  NavigationRail(
                    extended: constraints.maxWidth >= 800,
                    selectedIndex: widget.navigationShell.currentIndex,
                    onDestinationSelected: _onTabSelected,
                    destinations: [
                      NavigationRailDestination(
                        icon: GuideTarget(
                          step: stepLibraryNav,
                          targetPadding: const EdgeInsets.fromLTRB(
                            16,
                            6,
                            16,
                            36,
                          ),
                          child: const Icon(Icons.library_music_outlined),
                        ),
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
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: [
                      NavigationDestination(
                        icon: GuideTarget(
                          step: stepLibraryNav,
                          targetPadding: const EdgeInsets.fromLTRB(
                            16,
                            6,
                            16,
                            36,
                          ),
                          child: const Icon(Icons.library_music_outlined),
                        ),
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
          ),
        );
      },
    );
  }
}
