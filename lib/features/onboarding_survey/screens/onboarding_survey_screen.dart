/// Onboarding 问卷页。
///
/// 设计要点：
/// - PopScope.canPop=false 拦截物理返回 / 边缘滑动
/// - 选完一题自动跳下一题（自动前进，按需提供小号"上一步"）
/// - "应对考试"展开二级菜单（考试类型）；其它选项直接进入时长
/// - 完成时先 await 写 SP，再切状态，最后导航——保证崩溃也不会丢一致性
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../analytics/models/event_names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../services/app_logger.dart';
import '../models/onboarding_answers.dart';
import '../models/onboarding_question.dart';
import '../providers/onboarding_survey_provider.dart';
import '../widgets/survey_choice_tile.dart';

/// 当前所在步骤。
/// - examType 仅在 goal == exam 时进入。
/// - summary 是答完所有题后的方法论介绍页，点击"开始学习"才真正提交并进入主界面。
enum _SurveyStep { goal, examType, dailyMinutes, summary }

/// 选完答案到自动跳下一步之间的延迟，留出选中高亮的视觉反馈。
const _autoAdvanceDelay = Duration(milliseconds: 220);

class OnboardingSurveyScreen extends ConsumerStatefulWidget {
  const OnboardingSurveyScreen({super.key});

  @override
  ConsumerState<OnboardingSurveyScreen> createState() =>
      _OnboardingSurveyScreenState();
}

class _OnboardingSurveyScreenState
    extends ConsumerState<OnboardingSurveyScreen> {
  _SurveyStep _step = _SurveyStep.goal;
  final List<_SurveyStep> _history = [];
  Timer? _advanceTimer;
  late final DateTime _startedAt;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsServiceProvider).track(
        Events.onboardingSurveyShown,
        const {EventParams.isFirstLaunch: true},
      );
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────── 选项处理 ───────────────────────

  void _selectGoal(String code) {
    if (_submitting) return;
    final notifier = ref.read(onboardingAnswersProvider.notifier);
    notifier.setGoal(code);
    _trackAnswer(OnboardingQuestionId.goal, code);

    if (code == OnboardingGoal.exam) {
      _scheduleAdvance(() => _goToStep(_SurveyStep.examType));
      return;
    }

    // daily / work / travel / content / other：直接进时长选择
    _scheduleAdvance(() => _goToStep(_SurveyStep.dailyMinutes));
  }

  void _selectExamType(String code) {
    if (_submitting) return;
    ref.read(onboardingAnswersProvider.notifier).setExamType(code);
    _trackAnswer(OnboardingQuestionId.examType, code);
    _scheduleAdvance(() => _goToStep(_SurveyStep.dailyMinutes));
  }

  Future<void> _selectDailyMinutes(String code) async {
    if (_submitting) return;
    ref.read(onboardingAnswersProvider.notifier).setDailyMinutes(code);
    _trackAnswer(OnboardingQuestionId.dailyMinutes, code);
    // 进入方法论介绍页，由用户点击"开始学习"按钮触发实际提交。
    _scheduleAdvance(() => _goToStep(_SurveyStep.summary));
  }

  // ─────────────────────── 步骤导航 ───────────────────────

  void _scheduleAdvance(
    VoidCallback action, {
    Duration delay = _autoAdvanceDelay,
  }) {
    _advanceTimer?.cancel();
    _advanceTimer = Timer(delay, () {
      if (!mounted) return;
      action();
    });
  }

  void _goToStep(_SurveyStep next) {
    setState(() {
      _history.add(_step);
      _step = next;
    });
  }

  void _onBackPressed() {
    if (_submitting) return;
    _advanceTimer?.cancel();
    if (_history.isEmpty) return;
    setState(() {
      _step = _history.removeLast();
    });
  }

  // ─────────────────────── 提交与埋点 ───────────────────────

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final answers = ref.read(onboardingAnswersProvider);
    try {
      await ref.read(onboardingAnswersProvider.notifier).submit();
    } catch (e, st) {
      AppLogger.log('OnboardingSurvey', 'submit failed: $e');
      AppLogger.log('OnboardingSurvey', st.toString());
      if (mounted) setState(() => _submitting = false);
      return;
    }

    final analytics = ref.read(analyticsServiceProvider);
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    await analytics.track(Events.onboardingSurveyCompleted, {
      EventParams.goal: answers.goal!,
      if (answers.examType != null) EventParams.examType: answers.examType!,
      EventParams.dailyMinutes: answers.dailyMinutes!,
      EventParams.elapsedSeconds: elapsed,
    });
    await analytics.setUserProperty(UserProperties.englishGoal, answers.goal);
    if (answers.examType != null) {
      await analytics.setUserProperty(
        UserProperties.examType,
        answers.examType,
      );
    }
    await analytics.setUserProperty(
      UserProperties.dailyMinutesTarget,
      answers.dailyMinutes,
    );

    if (!mounted) return;
    context.go(AppRoutes.study);
  }

  void _trackAnswer(String questionId, String code) {
    ref.read(analyticsServiceProvider).track(
      Events.onboardingSurveyQuestionAnswered,
      {EventParams.questionId: questionId, EventParams.answerCode: code},
    );
  }

  // ─────────────────────── 渲染 ───────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final answers = ref.watch(onboardingAnswersProvider);
    final totalSteps = _totalSteps(answers);
    final currentIndex = _currentIndex(answers);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _TopBar(
                    onBack: _history.isEmpty ? null : _onBackPressed,
                    backLabel: l10n.onboardingBack,
                    currentIndex: currentIndex,
                    total: totalSteps,
                  ),
                  Expanded(
                    child: _step == _SurveyStep.summary
                        ? _buildSummaryLayout(l10n)
                        : _buildQuestionLayout(l10n, answers),
                  ),
                ],
              ),
              if (_submitting)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x33000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 总步骤数：goal=exam → 3，其它 → 2。summary 页不计入指示点。
  int _totalSteps(OnboardingAnswers answers) {
    if (_step == _SurveyStep.summary) return 0;
    return answers.goal == OnboardingGoal.exam ? 3 : 2;
  }

  /// 当前所处的逻辑步骤索引（0-based），用于点状指示器。
  int _currentIndex(OnboardingAnswers answers) {
    switch (_step) {
      case _SurveyStep.goal:
        return 0;
      case _SurveyStep.examType:
        return 1;
      case _SurveyStep.dailyMinutes:
        return answers.goal == OnboardingGoal.exam ? 2 : 1;
      case _SurveyStep.summary:
        return 0; // 不展示，配合 _totalSteps=0 隐藏指示点
    }
  }

  /// 题目页布局：可滚动 + 居中 + AnimatedSwitcher 在三个题目步骤之间淡入淡出。
  Widget _buildQuestionLayout(
    AppLocalizations l10n,
    OnboardingAnswers answers,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _buildQuestionStepBody(l10n, answers),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionStepBody(
    AppLocalizations l10n,
    OnboardingAnswers answers,
  ) {
    switch (_step) {
      case _SurveyStep.goal:
        return _buildGoalStep(l10n, answers);
      case _SurveyStep.examType:
        return _buildExamTypeStep(l10n, answers);
      case _SurveyStep.dailyMinutes:
        return _buildDailyMinutesStep(l10n, answers);
      case _SurveyStep.summary:
        // summary 走 _buildSummaryLayout，不会进入这里
        return const SizedBox.shrink();
    }
  }

  /// 方法论介绍页布局：内容区垂直居中（headline + 4 要点），
  /// "开始学习"按钮固定在底部，处于拇指可达区域。
  Widget _buildSummaryLayout(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final points = [
      l10n.onboardingSummaryPoint1,
      l10n.onboardingSummaryPoint2,
      l10n.onboardingSummaryPoint3,
      l10n.onboardingSummaryPoint4,
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            children: [
              // 内容区：headline + 要点，整体在上半部分垂直居中
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        l10n.onboardingSummaryEyebrow,
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 字号刻意稍小：英文长句（如 "Improving listening & speaking"）
                      // 在 headlineSmall(24sp) 下会自动折行让 "speaking" 单独一行；
                      // 21sp 下中英文三行手动断行均能稳定一行展示。
                      Text(
                        l10n.onboardingSummaryHeadline,
                        style: textTheme.titleLarge?.copyWith(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 40),
                      for (var i = 0; i < points.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == points.length - 1 ? 0 : 18,
                          ),
                          child: _SummaryPoint(
                            text: points[i],
                            color: colorScheme.primary,
                            textColor: colorScheme.onSurface,
                            textStyle: textTheme.bodyLarge,
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // 权限预告：紧贴"开始学习"按钮上方，确保总能看到（无论滚动）。
                // 纯展示，让用户对开始后的系统弹窗有预期；不实现拦截 / 跳设置等。
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        l10n.onboardingPermissionsHint,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _PermissionPreviewChip(
                            icon: Icons.notifications_outlined,
                            label: l10n.onboardingPermissionsNotification,
                            color: colorScheme.onSurfaceVariant,
                            textStyle: textTheme.bodySmall,
                          ),
                          _PermissionPreviewChip(
                            icon: Icons.mic_outlined,
                            label: l10n.onboardingPermissionsMicrophone,
                            color: colorScheme.onSurfaceVariant,
                            textStyle: textTheme.bodySmall,
                          ),
                          _PermissionPreviewChip(
                            icon: Icons.record_voice_over_outlined,
                            label: l10n.onboardingPermissionsSpeech,
                            color: colorScheme.onSurfaceVariant,
                            textStyle: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              // 底部按钮区
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton(
                  onPressed: _submitting ? null : _finish,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(l10n.onboardingStart),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalStep(AppLocalizations l10n, OnboardingAnswers answers) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: l10n.onboardingQ1Prompt),
        const SizedBox(height: 24),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionExam,
          selected: answers.goal == OnboardingGoal.exam,
          onTap: () => _selectGoal(OnboardingGoal.exam),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionDaily,
          selected: answers.goal == OnboardingGoal.daily,
          onTap: () => _selectGoal(OnboardingGoal.daily),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionWork,
          selected: answers.goal == OnboardingGoal.work,
          onTap: () => _selectGoal(OnboardingGoal.work),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionTravel,
          selected: answers.goal == OnboardingGoal.travel,
          onTap: () => _selectGoal(OnboardingGoal.travel),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionContent,
          selected: answers.goal == OnboardingGoal.content,
          onTap: () => _selectGoal(OnboardingGoal.content),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionOther,
          selected: answers.goal == OnboardingGoal.other,
          onTap: () => _selectGoal(OnboardingGoal.other),
        ),
      ],
    );
  }

  Widget _buildExamTypeStep(AppLocalizations l10n, OnboardingAnswers answers) {
    final selected = answers.examType;
    // 中文用户保留全部考试；其它语言用户只展示国际通用考试 + Other，
    // 因为中高考 / 四六级 / 专四专八 都是中国国内考试。
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: l10n.onboardingExamPrompt),
        const SizedBox(height: 24),
        if (isChinese) ...[
          SurveyChoiceTile(
            label: l10n.onboardingExamGaokao,
            selected: selected == OnboardingExamType.gaokao,
            onTap: () => _selectExamType(OnboardingExamType.gaokao),
          ),
          SurveyChoiceTile(
            label: l10n.onboardingExamCet,
            selected: selected == OnboardingExamType.cet,
            onTap: () => _selectExamType(OnboardingExamType.cet),
          ),
          SurveyChoiceTile(
            label: l10n.onboardingExamTem,
            selected: selected == OnboardingExamType.tem,
            onTap: () => _selectExamType(OnboardingExamType.tem),
          ),
        ],
        SurveyChoiceTile(
          label: l10n.onboardingExamIelts,
          selected: selected == OnboardingExamType.ielts,
          onTap: () => _selectExamType(OnboardingExamType.ielts),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingExamToefl,
          selected: selected == OnboardingExamType.toefl,
          onTap: () => _selectExamType(OnboardingExamType.toefl),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingExamOther,
          selected: selected == OnboardingExamType.other,
          onTap: () => _selectExamType(OnboardingExamType.other),
        ),
      ],
    );
  }

  Widget _buildDailyMinutesStep(
    AppLocalizations l10n,
    OnboardingAnswers answers,
  ) {
    final selected = answers.dailyMinutes;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: l10n.onboardingQ2Prompt),
        const SizedBox(height: 24),
        SurveyChoiceTile(
          label: l10n.onboardingQ2Option5,
          selected: selected == OnboardingDailyMinutes.m5,
          onTap: () => _selectDailyMinutes(OnboardingDailyMinutes.m5),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ2Option10,
          selected: selected == OnboardingDailyMinutes.m10,
          onTap: () => _selectDailyMinutes(OnboardingDailyMinutes.m10),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ2Option20,
          selected: selected == OnboardingDailyMinutes.m20,
          onTap: () => _selectDailyMinutes(OnboardingDailyMinutes.m20),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ2Option30,
          selected: selected == OnboardingDailyMinutes.m30,
          onTap: () => _selectDailyMinutes(OnboardingDailyMinutes.m30),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ2OptionFlexible,
          selected: selected == OnboardingDailyMinutes.flexible,
          onTap: () => _selectDailyMinutes(OnboardingDailyMinutes.flexible),
        ),
      ],
    );
  }

}

/// summary 页底部的权限预告 chip：图标 + 简短 label，仅展示，无交互。
class _PermissionPreviewChip extends StatelessWidget {
  const _PermissionPreviewChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textStyle,
  });

  final IconData icon;
  final String label;
  final Color color;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: textStyle?.copyWith(color: color)),
      ],
    );
  }
}

/// summary 页的单条要点行：带圆形 check 图标，留有充足留白。
class _SummaryPoint extends StatelessWidget {
  const _SummaryPoint({
    required this.text,
    required this.color,
    required this.textColor,
    required this.textStyle,
  });

  final String text;
  final Color color;
  final Color textColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2, right: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 18, color: color),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: textStyle?.copyWith(
                color: textColor,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 顶部条：左侧"上一步"小按钮，右侧步骤指示点。
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.backLabel,
    required this.currentIndex,
    required this.total,
  });

  final VoidCallback? onBack;
  final String backLabel;
  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          SizedBox(
            height: 36,
            child: onBack == null
                ? const SizedBox.shrink()
                : TextButton.icon(
                    onPressed: onBack,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: Text(
                      backLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
          ),
          const Spacer(),
          _Dots(currentIndex: currentIndex, total: total),
        ],
      ),
    );
  }
}

/// 步骤指示点：当前步骤为实心，其它为浅色。
class _Dots extends StatelessWidget {
  const _Dots({required this.currentIndex, required this.total});

  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? colorScheme.primary : colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

/// 题干文字。
class _Prompt extends StatelessWidget {
  const _Prompt({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
