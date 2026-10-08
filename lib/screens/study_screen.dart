import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../features/usage/usage_event.dart';
import '../features/usage/usage_providers.dart';
import '../services/runtime_endpoint_router.dart';
import '../database/daos/stage_completion_dao.dart';
import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../providers/audio_library_provider.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../providers/study_stats_provider.dart';
import '../providers/study_task_provider.dart';
import '../providers/time_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../services/app_logger.dart';
import '../services/startup_trace.dart';
import '../widgets/speech_permission_dialog.dart';
import '../widgets/guide_flow.dart';
import '../widgets/learning_progress_icon.dart';
import '../widgets/media_type_icon.dart';
import '../widgets/study/study_stats_header.dart';

/// 学习 Tab 待复习分组标题图标。
const String _studyReviewIconAsset = 'assets/icon/refresh.svg';

/// 学习 Tab 首次学习分组标题图标。
const String _studyReadingIconAsset = 'assets/icon/reading.svg';

/// 学习任务列表页
///
/// 页面结构（从上到下）：
/// 1. AppBar（标题）
/// 2. 统计 Chips + 7天柱状图
/// 3. Ready to Review（可开始的复习）
/// 4. Upcoming Reviews（默认折叠）
/// 5. First Study（首次学习任务）
/// 6. Completed（默认折叠）
class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  /// 引导 step 的 key 需在整个页面生命周期内保持稳定，故放在 State 中持有。
  final GlobalKey _keyStatsHeader = GlobalKey();
  final GlobalKey _keyStreakChip = GlobalKey();

  @override
  void initState() {
    super.initState();
    activeStartupTrace?.mark('study_tab_mounted');
    AppLogger.log('StartupLoad', 'study_screen_mounted');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        activeStartupTrace?.mark('study_tab_first_frame_rendered');
        AppLogger.log('StartupLoad', 'study_screen_first_frame_rendered');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final audioLibraryState = ref.watch(audioLibraryProvider);
    final progressState = ref.watch(learningProgressNotifierProvider);
    final tasks = ref.watch(studyTaskProvider);
    final completedAudios = ref.watch(completedAudioProvider);
    final now = ref.watch(nowProvider)();
    final statsAsync = ref.watch(studyStatsNotifierProvider);
    final isBootstrappingStudy =
        audioLibraryState.isLoading || progressState.isLoading;

    final recentCompletionsAsync = ref.watch(recentCompletionsProvider);

    final readyReviews = tasks
        .where((t) => t.type == StudyTaskType.reviewReady)
        .toList();
    final upcomingReviews = tasks
        .where((t) => t.type == StudyTaskType.reviewUpcoming)
        .toList();
    final firstStudies = tasks
        .where((t) => t.type == StudyTaskType.firstStudy)
        .toList();

    // 判断空状态类型
    final hasAnyTask = tasks.isNotEmpty || completedAudios.isNotEmpty;

    // AppBar streak chip（始终显示，可点击进入活动日历）
    final streak = statsAsync.valueOrNull?.streak ?? 0;
    final isStreakActive = streak > 0;
    final streakChip = Padding(
      padding: const EdgeInsets.only(right: AppSpacing.m),
      child: GestureDetector(
        onTap: () {
          ref.read(analyticsServiceProvider).track(
            Events.activityCalendarViewed,
            {EventParams.streak: streak},
          );
          context.push(AppRoutes.activityCalendar);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isStreakActive
                ? Colors.orange.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: isStreakActive
                    ? Colors.orange
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.streakDays(streak),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isStreakActive
                      ? Colors.orange.shade800
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // ----- 新手引导 flow 声明 -----
    final stepStatsHeader = GuideStep(
      key: _keyStatsHeader,
      title: l10n.guideStudyStatsHeaderTitle,
      description: l10n.guideStudyStatsHeaderDescription,
    );
    final stepStreakChip = GuideStep(
      key: _keyStreakChip,
      description: l10n.guideStudyStreakDescription,
    );
    // 门槛：用户本周已经累计过学习时长才触发引导。
    final hasStudyTime = (statsAsync.valueOrNull?.weekTotalSeconds ?? 0) > 0;
    final flows = <GuideFlow>[
      GuideFlow(
        flowId: GuideFlowIds.studyStatsStreak,
        shouldRun: hasStudyTime,
        steps: [stepStatsHeader, stepStreakChip],
      ),
    ];

    return GuideFlowSequenceHost(
      flows: flows,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.studyTasks),
          actions: [GuideTarget(step: stepStreakChip, child: streakChip)],
        ),
        // 仅在「正在预热且尚无任何任务可展示」时显示骨架，避免冷启动闪空态；
        // 已有任务时即使触发运行期 reload（如社区合集后台同步）也保留任务，不闪骨架。
        body: (isBootstrappingStudy && !hasAnyTask)
            ? const _StudyLoadingSkeleton()
            : !hasAnyTask
            ? const _EmptyState(type: _EmptyStateType.noTasks)
            : tasks.isEmpty && completedAudios.isNotEmpty
            ? _buildAllDoneContent(
                context,
                l10n,
                completedAudios,
                stepStatsHeader,
              )
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.m,
                  vertical: AppSpacing.s,
                ),
                children: [
                  // 加入学习社群邀请（置顶，保持单行紧凑高度，颜色对齐发现入口）
                  const _CommunityInviteCard(),
                  const SizedBox(height: AppSpacing.s),

                  // 统计 Chips + 柱状图
                  GuideTarget(
                    step: stepStatsHeader,
                    child: const StudyStatsHeader(),
                  ),
                  const SizedBox(height: AppSpacing.l),

                  // 学习任务区
                  if (readyReviews.isNotEmpty ||
                      upcomingReviews.isNotEmpty ||
                      firstStudies.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (readyReviews.isNotEmpty) ...[
                          _TaskSection(
                            title: l10n.readyToReview(readyReviews.length),
                            iconAsset: _studyReviewIconAsset,
                            tasks: readyReviews,
                            l10n: l10n,
                            now: now,
                          ),
                          const SizedBox(height: AppSpacing.m),
                        ],
                        if (upcomingReviews.isNotEmpty) ...[
                          _CollapsibleSection(
                            title: l10n.upcomingReviews(upcomingReviews.length),
                            summary: l10n.upcomingReviewsSummary(
                              upcomingReviews.length,
                            ),
                            initiallyExpanded: false,
                            children: upcomingReviews
                                .map(
                                  (t) =>
                                      _TaskCard(task: t, l10n: l10n, now: now),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: AppSpacing.m),
                        ],
                        if (firstStudies.isNotEmpty) ...[
                          _TaskSection(
                            title: l10n.firstStudySection(firstStudies.length),
                            iconAsset: _studyReadingIconAsset,
                            tasks: firstStudies,
                            l10n: l10n,
                            now: now,
                          ),
                          const SizedBox(height: AppSpacing.m),
                        ],
                      ],
                    ),

                  // 最近完成（过去24小时，默认折叠）
                  ...recentCompletionsAsync.whenOrNull(
                        data: (completions) => completions.isNotEmpty
                            ? [
                                _RecentCompletionsSection(
                                  completions: completions,
                                  l10n: l10n,
                                  now: now,
                                ),
                                const SizedBox(height: AppSpacing.m),
                              ]
                            : null,
                      ) ??
                      [],

                  // Completed (默认折叠) — 放在最下面
                  if (completedAudios.isNotEmpty) ...[
                    _CompletedSection(completedAudios: completedAudios),
                    const SizedBox(height: AppSpacing.m),
                  ],
                ],
              ),
      ),
    );
  }

  /// 全部完成时的内容
  Widget _buildAllDoneContent(
    BuildContext context,
    AppLocalizations l10n,
    List<({String audioId, String audioName})> completedAudios,
    GuideStep stepStatsHeader,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        const _CommunityInviteCard(),
        const SizedBox(height: AppSpacing.s),
        GuideTarget(step: stepStatsHeader, child: const StudyStatsHeader()),
        const SizedBox(height: AppSpacing.xl),
        const _EmptyState(type: _EmptyStateType.allDone),
        if (completedAudios.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.m),
          _CompletedSection(completedAudios: completedAudios),
        ],
      ],
    );
  }
}

// ============================================================
// Task Sections
// ============================================================

/// 任务区段（固定 SVG 图标 + 标题 + 卡片列表）
class _TaskSection extends StatelessWidget {
  final String title;
  final String iconAsset;
  final List<StudyTask> tasks;
  final AppLocalizations l10n;
  final DateTime now;

  const _TaskSection({
    required this.title,
    required this.iconAsset,
    required this.tasks,
    required this.l10n,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 区段标题
        Row(
          children: [
            SvgPicture.asset(iconAsset, width: 20, height: 20),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        ...tasks.map((task) => _TaskCard(task: task, l10n: l10n, now: now)),
      ],
    );
  }
}

/// 可折叠区段（标题 + 摘要 + 展开后的内容）
class _CollapsibleSection extends StatelessWidget {
  final String title;
  final String summary;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _CollapsibleSection({
    required this.title,
    required this.summary,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(
          summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.only(
          left: AppSpacing.m,
          right: AppSpacing.m,
          bottom: AppSpacing.s,
        ),
        children: children,
      ),
    );
  }
}

// ============================================================
// Enhanced Task Card
// ============================================================

/// 增强版任务卡片
///
/// 左侧色条指示任务类型，显示子阶段、进度条、细化按钮文案、逾期视觉强调。
class _TaskCard extends ConsumerWidget {
  final StudyTask task;
  final AppLocalizations l10n;
  final DateTime now;

  const _TaskCard({required this.task, required this.l10n, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDisabled = task.type == StudyTaskType.reviewUpcoming;
    final stageLabel = _stageSubStageLabel(l10n, task.stage, task.subStage);
    final statusText = _statusText(context, l10n, task, now);
    final isOverdue = task.isOverdue;

    // 获取进度数据
    final progressMap = ref.watch(learningProgressNotifierProvider).progressMap;
    final progress = progressMap[task.audioId];
    final audioItem = ref
        .watch(audioLibraryProvider)
        .audioItems
        .where((item) => item.id == task.audioId)
        .firstOrNull;
    final plan = ref.watch(learningPlanForAudioProvider(task.audioId));
    final completedKeys = ref
        .watch(learningProgressNotifierProvider)
        .completionsFor(task.audioId);
    final progressPercent =
        progress?.progressPercent(plan, completedKeys) ?? 0.0;

    // 左侧色条颜色
    final accentColor = isOverdue
        ? theme.colorScheme.error
        : task.type == StudyTaskType.firstStudy
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          ref
              .read(usageTrackerProvider)
              .record(
                UsageEvent.studyTaskTapped,
                analyticsParams: {
                  EventParams.audioId: task.audioId,
                  EventParams.audioName: task.audioName,
                  EventParams.taskType: task.type.name.toLowerCase(),
                  EventParams.stage: task.stage.name,
                  EventParams.subStage: task.subStage.name,
                  EventParams.isOverdue: task.isOverdue ? 1 : 0,
                },
              );
          if (!context.mounted) return;
          context.push(AppRoutes.audioLearningPlan(task.audioId));
        },
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 左侧色条
              Container(width: 4, color: accentColor),
              // 内容区
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, AppSpacing.m, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          LearningProgressIcon(
                            progress: progress,
                            size: 36,
                            iconSize: 18,
                            isVideo: audioItem?.isVideo ?? false,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.audioName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Wrap(
                                  spacing: AppSpacing.s,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      stageLabel,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    if (statusText.isNotEmpty)
                                      _StatusBadge(
                                        text: statusText,
                                        isOverdue: isOverdue,
                                        isInProgress:
                                            statusText ==
                                            l10n.learningInProgress,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          FilledButton.tonal(
                            onPressed: isDisabled
                                ? null
                                : () async {
                                    final allowed =
                                        await ensureSpeechReadyForSubStage(
                                          context,
                                          ref,
                                          task.subStage,
                                        );
                                    if (!allowed || !context.mounted) return;
                                    context.push(
                                      AppRoutes.audioLearningPlan(
                                        task.audioId,
                                        autoStart: true,
                                      ),
                                    );
                                  },
                            child: Text(_actionLabel(l10n, task)),
                          ),
                        ],
                      ),
                      // 进度条
                      if (progressPercent > 0) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            minHeight: 4,
                            color: accentColor,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 从 LearningProgressState 获取任务进度百分比的闭包
// ============================================================
// Completed Section
// ============================================================

/// 已完成音频折叠区
class _CompletedSection extends ConsumerWidget {
  final List<({String audioId, String audioName})> completedAudios;

  const _CompletedSection({required this.completedAudios});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final audioItems = ref.watch(audioLibraryProvider).audioItems;
    return Card(
      child: ExpansionTile(
        title: Text(
          l10n.completedSection(completedAudios.length),
          style: theme.textTheme.titleSmall,
        ),
        initiallyExpanded: false,
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.only(
          left: AppSpacing.m,
          right: AppSpacing.m,
          bottom: AppSpacing.s,
        ),
        children: completedAudios
            .map(
              (audio) => ListTile(
                dense: true,
                leading: MediaTypeIcon(
                  isVideo:
                      audioItems
                          .where((item) => item.id == audio.audioId)
                          .firstOrNull
                          ?.isVideo ??
                      false,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                title: Text(audio.audioName),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  context.push(AppRoutes.audioLearningPlan(audio.audioId));
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

// ============================================================
// Recent Completions Section
// ============================================================

/// 最近完成折叠区（过去 24 小时的子步骤完成记录）
class _RecentCompletionsSection extends StatelessWidget {
  final List<RecentCompletion> completions;
  final AppLocalizations l10n;
  final DateTime now;

  const _RecentCompletionsSection({
    required this.completions,
    required this.l10n,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        title: Text(
          l10n.recentCompletions(completions.length),
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          l10n.recentCompletionsSummary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        initiallyExpanded: false,
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.only(
          left: AppSpacing.m,
          right: AppSpacing.m,
          bottom: AppSpacing.s,
        ),
        children: completions
            .map(
              (c) => _RecentCompletionTile(completion: c, l10n: l10n, now: now),
            )
            .toList(),
      ),
    );
  }
}

/// 单条最近完成记录卡片
class _RecentCompletionTile extends ConsumerWidget {
  final RecentCompletion completion;
  final AppLocalizations l10n;
  final DateTime now;

  const _RecentCompletionTile({
    required this.completion,
    required this.l10n,
    required this.now,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final audioItems = ref.watch(audioLibraryProvider).audioItems;
    final progress = ref
        .watch(learningProgressNotifierProvider)
        .progressMap[completion.audioId];
    final isVideo =
        audioItems
            .where((item) => item.id == completion.audioId)
            .firstOrNull
            ?.isVideo ??
        false;
    final stage = LearningStage.fromKey(completion.stage);
    final subStage = SubStageType.fromKey(completion.subStage);
    final stageLabel = _stageSubStageLabel(l10n, stage, subStage);
    final timeAgo = _timeAgo(l10n, now, completion.completedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push(AppRoutes.audioLearningPlan(completion.audioId));
        },
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 左侧绿色条标记本条子步骤已完成（不用对钩，避免误认为整个音频已学完）。
              Container(width: 4, color: LearningProgressIcon.completedColor),
              // 内容区
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, AppSpacing.m, 10),
                  child: Row(
                    children: [
                      SizedBox(
                        key: const ValueKey('recent_completion_media_icon'),
                        width: 36,
                        height: 36,
                        child: LearningProgressIcon(
                          progress: progress,
                          isVideo: isVideo,
                          size: 36,
                          iconSize: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              completion.audioName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              stageLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      _StatusBadge(
                        text: timeAgo,
                        isOverdue: false,
                        isInProgress: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 相对时间文案（刚刚 / X分钟前 / X小时前）
String _timeAgo(AppLocalizations l10n, DateTime now, DateTime completedAt) {
  final diff = now.difference(completedAt);
  if (diff.inMinutes < 1) return l10n.timeAgoJustNow;
  if (diff.inHours < 1) return l10n.timeAgoMinutes(diff.inMinutes);
  return l10n.timeAgoHours(diff.inHours);
}

// ============================================================
// Community Invite Card
// ============================================================

/// 学习社群邀请条。
///
/// 学习 Tab 顶部置顶，保持单行紧凑样式：
/// 图标 + 标题 + 副标题 + chevron，颜色对齐发现入口。
/// 点击行为与设置页「加入社区」一致：按 locale 打开对应社群页面。
class _CommunityInviteCard extends ConsumerWidget {
  const _CommunityInviteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final palette = _CommunityInvitePalette.resolve(theme.brightness);
    const radius = BorderRadius.all(Radius.circular(12));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.backgroundStart, palette.backgroundEnd],
        ),
        border: Border.all(color: palette.border),
        boxShadow: palette.shadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            splashColor: palette.inkSplash,
            highlightColor: palette.inkHighlight,
            onTap: () async {
              ref
                  .read(analyticsServiceProvider)
                  .track(Events.communityInviteTapped);
              final isZh = Localizations.localeOf(context).languageCode == 'zh';
              final path = isZh ? '/zh-CN/social' : '/en/social';
              final uri = runtimeEndpointRouter.apiUri(path);
              await launchUrl(uri);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Icon(Icons.group_rounded, size: 20, color: palette.icon),
                  const SizedBox(width: 10),
                  Text(
                    l10n.aboutCommunity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.title,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.joinCommunityInviteSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.subtitle,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 20, color: palette.chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityInvitePalette {
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color border;
  final Color icon;
  final Color title;
  final Color subtitle;
  final Color chevron;
  final Color inkSplash;
  final Color inkHighlight;
  final List<BoxShadow> shadow;

  const _CommunityInvitePalette({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.border,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chevron,
    required this.inkSplash,
    required this.inkHighlight,
    required this.shadow,
  });

  static _CommunityInvitePalette resolve(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _CommunityInvitePalette(
        backgroundStart: const Color(0xFF102A36),
        backgroundEnd: const Color(0xFF172D46),
        border: const Color(0x6672C7D6),
        icon: const Color(0xFF8AD8E4),
        title: const Color(0xFFE7F4F8),
        subtitle: const Color(0xFFB8CBD4),
        chevron: const Color(0xCC79D6E6),
        inkSplash: const Color(0x3379D6E6),
        inkHighlight: const Color(0x1A79D6E6),
        shadow: const [],
      );
    }

    return _CommunityInvitePalette(
      backgroundStart: const Color(0xFFEAF8FA),
      backgroundEnd: const Color(0xFFDDEFFA),
      border: const Color(0xFFA9D5DF),
      icon: const Color(0xFF32758D),
      title: const Color(0xFF17384A),
      subtitle: const Color(0xFF587080),
      chevron: const Color(0xCC3B7F94),
      inkSplash: const Color(0x26256B86),
      inkHighlight: const Color(0x14256B86),
      shadow: const [
        BoxShadow(
          color: Color(0x1A256B86),
          blurRadius: 16,
          offset: Offset(0, 7),
        ),
      ],
    );
  }
}

// ============================================================
// Empty States
// ============================================================

enum _EmptyStateType { noTasks, allDone }

/// 空状态组件
class _EmptyState extends StatelessWidget {
  final _EmptyStateType type;

  const _EmptyState({required this.type});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isNoTasks = type == _EmptyStateType.noTasks;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标容器
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isNoTasks ? theme.colorScheme.primary : Colors.amber)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                isNoTasks
                    ? Icons.library_music_outlined
                    : Icons.celebration_outlined,
                size: 40,
                color: isNoTasks
                    ? theme.colorScheme.primary
                    : Colors.amber.shade700,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              isNoTasks ? l10n.noStudyTasks : l10n.allDoneTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              isNoTasks ? l10n.noStudyTasksHint : l10n.allDoneHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (isNoTasks) ...[
              const SizedBox(height: AppSpacing.l),
              FilledButton.tonal(
                onPressed: () {
                  final shell = StatefulNavigationShell.of(context);
                  shell.goBranch(0);
                },
                child: Text(l10n.goToLibrary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 学习页冷启动骨架屏。
///
/// 与正式页面结构保持近似，只表达"学习数据正在加载"，避免误闪"暂无任务"空态。
class _StudyLoadingSkeleton extends StatelessWidget {
  const _StudyLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: const [
        _SkeletonBlock(height: 72, radius: 24),
        SizedBox(height: AppSpacing.s),
        _SkeletonBlock(height: 164, radius: 28),
        SizedBox(height: AppSpacing.l),
        _SkeletonRow(widthFactors: [0.18, 0.28]),
        SizedBox(height: AppSpacing.m),
        _SkeletonTaskCard(),
        SizedBox(height: AppSpacing.m),
        _SkeletonTaskCard(),
      ],
    );
  }
}

class _SkeletonTaskCard extends StatelessWidget {
  const _SkeletonTaskCard();

  @override
  Widget build(BuildContext context) {
    return const _SkeletonBlock(height: 156, radius: 28);
  }
}

class _SkeletonRow extends StatelessWidget {
  final List<double> widthFactors;

  const _SkeletonRow({required this.widthFactors});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            for (var i = 0; i < widthFactors.length; i++) ...[
              _SkeletonBlock(
                width: constraints.maxWidth * widthFactors[i],
                height: 18,
                radius: 999,
              ),
              if (i != widthFactors.length - 1)
                const SizedBox(width: AppSpacing.s),
            ],
          ],
        );
      },
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _SkeletonBlock({
    this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ============================================================
// Helper functions
// ============================================================

/// 生成阶段+子阶段的组合标签
String _stageSubStageLabel(
  AppLocalizations l10n,
  LearningStage stage,
  SubStageType subStage,
) {
  final subStageName = _subStageName(l10n, subStage);
  if (stage == LearningStage.firstLearn) {
    return l10n.subStageLabelFirstLearn(subStageName);
  }
  final stageName = _stageName(l10n, stage);
  return l10n.subStageLabelReview(stageName, subStageName);
}

/// 子步骤本地化名称
String _subStageName(AppLocalizations l10n, SubStageType subStage) {
  return switch (subStage) {
    SubStageType.blindListen => l10n.stepBlindListening,
    SubStageType.intensiveListen => l10n.stepIntensiveListening,
    SubStageType.listenAndRepeat => l10n.stepShadowing,
    SubStageType.retell => l10n.stepRetelling,
    SubStageType.reviewDifficultPractice => l10n.reviewDifficultPracticeTitle,
    SubStageType.reviewRetellParagraph => l10n.stepRetelling,
    SubStageType.reviewRetellSummary => l10n.stepRetelling,
  };
}

/// 阶段本地化名称
String _stageName(AppLocalizations l10n, LearningStage stage) {
  return switch (stage) {
    LearningStage.firstLearn => l10n.firstStudy,
    LearningStage.review0 => l10n.reviewRound0,
    LearningStage.review1 => l10n.reviewRound1,
    LearningStage.review2 => l10n.reviewRound2,
    LearningStage.review4 => l10n.reviewRound4,
    LearningStage.review7 => l10n.reviewRound7,
    LearningStage.review14 => l10n.reviewRound14,
    LearningStage.review28 => l10n.reviewRound28,
    LearningStage.completed => l10n.learningCompleted,
  };
}

/// 按钮文案：本轮尚无完成记录=开始，已有完成记录=继续。
/// 复习任务与首次学习统一按"是否已开始本轮"判定，不再区分类型。
String _actionLabel(AppLocalizations l10n, StudyTask task) {
  return task.hasRoundProgress ? l10n.continueButton : l10n.startButton;
}

/// 状态标签（学习中 / 逾期 / 倒计时等）
///
/// "学习中"始终使用中性色，逾期使用 error 色，其余使用 surface 色。
class _StatusBadge extends StatelessWidget {
  final String text;
  final bool isOverdue;
  final bool isInProgress;

  const _StatusBadge({
    required this.text,
    required this.isOverdue,
    required this.isInProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // "学习中"统一使用中性色，不受逾期影响
    final useErrorStyle = isOverdue && !isInProgress;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: useErrorStyle
            ? theme.colorScheme.error.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: useErrorStyle
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: useErrorStyle ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

/// 状态文案（逾期、距离可复习时间等）
///
/// 本轮已有真实完成记录（[StudyTask.hasRoundProgress]）→ "学习中"
/// 逾期分级：无时长/>7天→"待复习"，≤7天→"待复习 · X天前到期"，<1天→"待复习 · X小时前到期"
String _statusText(
  BuildContext context,
  AppLocalizations l10n,
  StudyTask task,
  DateTime now,
) {
  // 本轮已有真实完成记录 → 显示"学习中"（基于 stage_completions 历史，
  // 而非 subStage 位置推导——待解锁任务本轮未解锁、无完成记录，永不命中）
  if (task.hasRoundProgress) {
    return l10n.learningInProgress;
  }
  if (task.isOverdue) {
    final overdue = task.overdueDuration;
    if (overdue == null || overdue.inDays > 7) return l10n.reviewDue;
    if (overdue.inDays > 0) return l10n.overdueDays(overdue.inDays);
    final hours = overdue.inHours.clamp(1, 999);
    return l10n.overdueHours(hours);
  }
  if (task.type == StudyTaskType.reviewUpcoming) {
    final nextAt = task.nextReviewAt;
    if (nextAt == null) return '';
    final diff = nextAt.difference(now);
    if (diff.inDays > 0) return l10n.availableInDays(diff.inDays);
    final hours = diff.inHours.clamp(1, 999);
    return l10n.availableInHours(hours);
  }
  return '';
}
