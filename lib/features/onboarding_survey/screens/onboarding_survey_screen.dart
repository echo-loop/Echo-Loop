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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../analytics/models/event_names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../services/app_logger.dart';
import '../models/onboarding_answers.dart';
import '../models/onboarding_question.dart';
import '../providers/onboarding_survey_provider.dart';
import '../providers/user_onboarding_sync_provider.dart';
import '../widgets/survey_choice_tile.dart';

/// 当前所在步骤。
/// - examType 仅在 goal == exam 时进入。
/// - referralSource 紧跟在 dailyMinutes 之后，用于运营画像。
/// - summary 是答完所有题后的方法论介绍页，点击"开始学习"才真正提交并进入主界面。
enum _SurveyStep { goal, examType, dailyMinutes, referralSource, summary }

/// 选完答案到自动跳下一步之间的延迟，留出选中高亮的视觉反馈。
const _autoAdvanceDelay = Duration(milliseconds: 220);

/// 学习目标 emoji 映射。
const _goalEmoji = <String, String>{
  OnboardingGoal.exam: '🎯',
  OnboardingGoal.daily: '☕',
  OnboardingGoal.work: '💼',
  OnboardingGoal.travel: '✈️',
  OnboardingGoal.content: '🎬',
  OnboardingGoal.other: '💭',
};

/// 每日时长 emoji 映射：用植物生长隐喻投入度递增。
const _dailyMinutesEmoji = <String, String>{
  OnboardingDailyMinutes.m5: '⚡',
  OnboardingDailyMinutes.m10: '🌱',
  OnboardingDailyMinutes.m20: '🌿',
  OnboardingDailyMinutes.m30: '🌳',
  OnboardingDailyMinutes.flexible: '🎈',
};

/// 单个渠道的品牌图标 + 品牌色。
typedef _BrandToken = ({FaIconData icon, Color color});

/// 来源渠道 → 平台图标 + 品牌色映射。
///
/// FontAwesome 11.0 已收录 weixin / bilibili / github / youtube / reddit /
/// xTwitter / tiktok / instagram / google / googlePlay / appStore 等主流品牌图标。
/// 中国特有的小红书 / 快手 / 百度无官方品牌图标，回退到通用 solid icon。
/// "抖音"与 TikTok 实质上是同一公司同一 app 国内外双版本，复用 tiktok 图标。
/// 品牌色取自各平台官方主视觉，朋友推荐 / 其他保持中性灰。
const _referralBrand = <String, _BrandToken>{
  // 中文渠道
  OnboardingReferralSource.xiaohongshu: (
    icon: FontAwesomeIcons.book,
    color: Color(0xFFFF2442),
  ),
  OnboardingReferralSource.wechat: (
    icon: FontAwesomeIcons.weixin,
    color: Color(0xFF07C160),
  ),
  OnboardingReferralSource.douyin: (
    icon: FontAwesomeIcons.tiktok,
    color: Color(0xFF000000),
  ),
  OnboardingReferralSource.kuaishou: (
    icon: FontAwesomeIcons.video,
    color: Color(0xFFFF4906),
  ),
  OnboardingReferralSource.bilibili: (
    icon: FontAwesomeIcons.bilibili,
    color: Color(0xFF00AEEC),
  ),
  OnboardingReferralSource.baiduSearch: (
    icon: FontAwesomeIcons.magnifyingGlass,
    color: Color(0xFF2932E1),
  ),
  // 英文渠道
  OnboardingReferralSource.youtube: (
    icon: FontAwesomeIcons.youtube,
    color: Color(0xFFFF0000),
  ),
  OnboardingReferralSource.reddit: (
    icon: FontAwesomeIcons.reddit,
    color: Color(0xFFFF4500),
  ),
  OnboardingReferralSource.xTwitter: (
    icon: FontAwesomeIcons.xTwitter,
    color: Color(0xFF000000),
  ),
  OnboardingReferralSource.tiktok: (
    icon: FontAwesomeIcons.tiktok,
    color: Color(0xFF000000),
  ),
  OnboardingReferralSource.instagram: (
    icon: FontAwesomeIcons.instagram,
    color: Color(0xFFE4405F),
  ),
  OnboardingReferralSource.googleSearch: (
    icon: FontAwesomeIcons.google,
    color: Color(0xFF4285F4),
  ),
  // 通用渠道
  OnboardingReferralSource.github: (
    icon: FontAwesomeIcons.github,
    color: Color(0xFF181717),
  ),
  OnboardingReferralSource.appStore: (
    icon: FontAwesomeIcons.appStore,
    color: Color(0xFF007AFF),
  ),
  OnboardingReferralSource.googlePlay: (
    icon: FontAwesomeIcons.googlePlay,
    color: Color(0xFF34A853),
  ),
  OnboardingReferralSource.friend: (
    icon: FontAwesomeIcons.userGroup,
    color: Color(0xFF1976D2),
  ),
  OnboardingReferralSource.other: (
    icon: FontAwesomeIcons.ellipsis,
    color: Color(0xFF4A5568),
  ),
};

/// Summary 页 4 条要点对应的 emoji，按 point1..4 顺序。
const _summaryEmojis = <String>['🎧', '🧩', '🔁', '🗣️'];

/// 把 emoji 字符包装成 SurveyChoiceTile 可用的 leading Widget。null 透传。
Widget? _emojiLeading(String? emoji) {
  if (emoji == null) return null;
  return Text(emoji, style: const TextStyle(fontSize: 20, height: 1.0));
}

/// 来源渠道 leading：品牌图标 + 品牌主色，方便用户快速识别熟悉的平台。
Widget _referralLeading(BuildContext context, String code) {
  final theme = Theme.of(context);
  final brand = _referralBrand[code];
  if (brand == null) {
    return FaIcon(
      FontAwesomeIcons.ellipsis,
      size: 18,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  // 黑色品牌标志在 AMOLED 背景上不可见，深色模式下改用主题前景色。
  final color =
      theme.brightness == Brightness.dark &&
          brand.color.computeLuminance() < 0.08
      ? theme.colorScheme.onSurface
      : brand.color;
  return FaIcon(brand.icon, size: 18, color: color);
}

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
    _scheduleAdvance(() => _goToStep(_SurveyStep.referralSource));
  }

  void _selectReferralSource(String code) {
    if (_submitting) return;
    ref.read(onboardingAnswersProvider.notifier).setReferralSource(code);
    _trackAnswer(OnboardingQuestionId.referralSource, code);
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

    unawaited(ref.read(onboardingSyncProvider).onLocalAnswersChanged());

    final analytics = ref.read(analyticsServiceProvider);
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    await analytics.track(Events.onboardingSurveyCompleted, {
      EventParams.goal: answers.goal!,
      if (answers.examType != null) EventParams.examType: answers.examType!,
      EventParams.dailyMinutes: answers.dailyMinutes!,
      EventParams.referralSource: answers.referralSource!,
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
    await analytics.setUserProperty(
      UserProperties.referralSource,
      answers.referralSource,
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
                        : _buildQuestionLayout(
                            l10n,
                            answers,
                            currentIndex,
                            totalSteps,
                          ),
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

  /// 总步骤数：goal=exam → 4，其它 → 3。summary 页不计入指示点。
  int _totalSteps(OnboardingAnswers answers) {
    if (_step == _SurveyStep.summary) return 0;
    return answers.goal == OnboardingGoal.exam ? 4 : 3;
  }

  /// 当前所处的逻辑步骤索引（0-based），用于点状指示器。
  int _currentIndex(OnboardingAnswers answers) {
    final isExam = answers.goal == OnboardingGoal.exam;
    switch (_step) {
      case _SurveyStep.goal:
        return 0;
      case _SurveyStep.examType:
        return 1;
      case _SurveyStep.dailyMinutes:
        return isExam ? 2 : 1;
      case _SurveyStep.referralSource:
        return isExam ? 3 : 2;
      case _SurveyStep.summary:
        return 0; // 不展示，配合 _totalSteps=0 隐藏指示点
    }
  }

  /// 题目页布局：可滚动 + 居中 + AnimatedSwitcher 在三个题目步骤之间淡入淡出。
  Widget _buildQuestionLayout(
    AppLocalizations l10n,
    OnboardingAnswers answers,
    int currentIndex,
    int totalSteps,
  ) {
    final eyebrow = totalSteps > 0 ? '${currentIndex + 1} / $totalSteps' : '';
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      child: _buildQuestionStepBody(l10n, answers, eyebrow),
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
    String eyebrow,
  ) {
    switch (_step) {
      case _SurveyStep.goal:
        return _buildGoalStep(l10n, answers, eyebrow);
      case _SurveyStep.examType:
        return _buildExamTypeStep(l10n, answers, eyebrow);
      case _SurveyStep.dailyMinutes:
        return _buildDailyMinutesStep(l10n, answers, eyebrow);
      case _SurveyStep.referralSource:
        return _buildReferralSourceStep(l10n, answers, eyebrow);
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
                            emoji: _summaryEmojis[i],
                            text: points[i],
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

  Widget _buildGoalStep(
    AppLocalizations l10n,
    OnboardingAnswers answers,
    String eyebrow,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: l10n.onboardingQ1Prompt, eyebrow: eyebrow),
        const SizedBox(height: 24),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionExam,
          leading: _emojiLeading(_goalEmoji[OnboardingGoal.exam]),
          selected: answers.goal == OnboardingGoal.exam,
          onTap: () => _selectGoal(OnboardingGoal.exam),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionDaily,
          leading: _emojiLeading(_goalEmoji[OnboardingGoal.daily]),
          selected: answers.goal == OnboardingGoal.daily,
          onTap: () => _selectGoal(OnboardingGoal.daily),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionWork,
          leading: _emojiLeading(_goalEmoji[OnboardingGoal.work]),
          selected: answers.goal == OnboardingGoal.work,
          onTap: () => _selectGoal(OnboardingGoal.work),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionTravel,
          leading: _emojiLeading(_goalEmoji[OnboardingGoal.travel]),
          selected: answers.goal == OnboardingGoal.travel,
          onTap: () => _selectGoal(OnboardingGoal.travel),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionContent,
          leading: _emojiLeading(_goalEmoji[OnboardingGoal.content]),
          selected: answers.goal == OnboardingGoal.content,
          onTap: () => _selectGoal(OnboardingGoal.content),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ1OptionOther,
          leading: _emojiLeading(_goalEmoji[OnboardingGoal.other]),
          selected: answers.goal == OnboardingGoal.other,
          onTap: () => _selectGoal(OnboardingGoal.other),
        ),
      ],
    );
  }

  Widget _buildExamTypeStep(
    AppLocalizations l10n,
    OnboardingAnswers answers,
    String eyebrow,
  ) {
    final selected = answers.examType;
    // 中文用户保留全部考试；其它语言用户只展示国际通用考试 + Other，
    // 因为中高考 / 四六级 / 专四专八 都是中国国内考试。
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: l10n.onboardingExamPrompt, eyebrow: eyebrow),
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
    String eyebrow,
  ) {
    final selected = answers.dailyMinutes;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: l10n.onboardingQ2Prompt, eyebrow: eyebrow),
        const SizedBox(height: 24),
        SurveyChoiceTile(
          label: l10n.onboardingQ2Option5,
          leading: _emojiLeading(_dailyMinutesEmoji[OnboardingDailyMinutes.m5]),
          selected: selected == OnboardingDailyMinutes.m5,
          onTap: () => _selectDailyMinutes(OnboardingDailyMinutes.m5),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ2Option10,
          leading: _emojiLeading(
            _dailyMinutesEmoji[OnboardingDailyMinutes.m10],
          ),
          selected: selected == OnboardingDailyMinutes.m10,
          onTap: () => _selectDailyMinutes(OnboardingDailyMinutes.m10),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ2Option20,
          leading: _emojiLeading(
            _dailyMinutesEmoji[OnboardingDailyMinutes.m20],
          ),
          selected: selected == OnboardingDailyMinutes.m20,
          onTap: () => _selectDailyMinutes(OnboardingDailyMinutes.m20),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ2Option30,
          leading: _emojiLeading(
            _dailyMinutesEmoji[OnboardingDailyMinutes.m30],
          ),
          selected: selected == OnboardingDailyMinutes.m30,
          onTap: () => _selectDailyMinutes(OnboardingDailyMinutes.m30),
        ),
        SurveyChoiceTile(
          label: l10n.onboardingQ2OptionFlexible,
          leading: _emojiLeading(
            _dailyMinutesEmoji[OnboardingDailyMinutes.flexible],
          ),
          selected: selected == OnboardingDailyMinutes.flexible,
          onTap: () => _selectDailyMinutes(OnboardingDailyMinutes.flexible),
        ),
      ],
    );
  }

  /// 来源渠道选择步骤：中英文用户看到的渠道不同，整体按重要度排序——
  /// 中文优先小红书 / 短视频 / B 站，英文优先 App Store / Reddit / YouTube。
  /// "其他"始终垫底。
  Widget _buildReferralSourceStep(
    AppLocalizations l10n,
    OnboardingAnswers answers,
    String eyebrow,
  ) {
    final selected = answers.referralSource;
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';

    // 按重要度排序的渠道编码列表（locale 完整版本）。
    // 中文：小红书 → 抖音/快手 → B 站 → 微信 → 应用商店 → 百度 → GitHub → 朋友 → 其他
    // 英文：App Store → Reddit → YouTube → TikTok/IG → X → Google search → GitHub → Friend → Other
    // 中文：小红书 → 微信 → GitHub → B 站 → 抖音 → 快手 → 百度搜索 → 应用商店 → 朋友推荐 → 其他
    //  Google Play 不出现在中文列表，国内基本无法使用。
    // 英文：Reddit → YouTube → Google search → GitHub → TikTok → X / Twitter → Instagram → Friend → App Store → Google Play → Other
    final codes = isChinese
        ? const [
            OnboardingReferralSource.xiaohongshu,
            OnboardingReferralSource.wechat,
            OnboardingReferralSource.github,
            OnboardingReferralSource.bilibili,
            OnboardingReferralSource.douyin,
            OnboardingReferralSource.kuaishou,
            OnboardingReferralSource.baiduSearch,
            OnboardingReferralSource.appStore,
            OnboardingReferralSource.friend,
            OnboardingReferralSource.other,
          ]
        : const [
            OnboardingReferralSource.reddit,
            OnboardingReferralSource.youtube,
            OnboardingReferralSource.googleSearch,
            OnboardingReferralSource.github,
            OnboardingReferralSource.tiktok,
            OnboardingReferralSource.xTwitter,
            OnboardingReferralSource.instagram,
            OnboardingReferralSource.friend,
            OnboardingReferralSource.appStore,
            OnboardingReferralSource.googlePlay,
            OnboardingReferralSource.other,
          ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(text: l10n.onboardingQ3Prompt, eyebrow: eyebrow),
        const SizedBox(height: 24),
        for (final code in codes)
          SurveyChoiceTile(
            label: _referralSourceLabel(l10n, code),
            leading: _referralLeading(context, code),
            selected: selected == code,
            onTap: () => _selectReferralSource(code),
          ),
      ],
    );
  }

  /// 渠道编码 → 本地化文案。集中映射，方便后续增删项时只改一处。
  String _referralSourceLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case OnboardingReferralSource.xiaohongshu:
        return l10n.onboardingQ3OptionXiaohongshu;
      case OnboardingReferralSource.wechat:
        return l10n.onboardingQ3OptionWechat;
      case OnboardingReferralSource.douyin:
        return l10n.onboardingQ3OptionDouyin;
      case OnboardingReferralSource.kuaishou:
        return l10n.onboardingQ3OptionKuaishou;
      case OnboardingReferralSource.bilibili:
        return l10n.onboardingQ3OptionBilibili;
      case OnboardingReferralSource.baiduSearch:
        return l10n.onboardingQ3OptionBaiduSearch;
      case OnboardingReferralSource.youtube:
        return l10n.onboardingQ3OptionYoutube;
      case OnboardingReferralSource.reddit:
        return l10n.onboardingQ3OptionReddit;
      case OnboardingReferralSource.xTwitter:
        return l10n.onboardingQ3OptionXTwitter;
      case OnboardingReferralSource.tiktok:
        return l10n.onboardingQ3OptionTiktok;
      case OnboardingReferralSource.instagram:
        return l10n.onboardingQ3OptionInstagram;
      case OnboardingReferralSource.googleSearch:
        return l10n.onboardingQ3OptionGoogleSearch;
      case OnboardingReferralSource.github:
        return l10n.onboardingQ3OptionGithub;
      case OnboardingReferralSource.appStore:
        return l10n.onboardingQ3OptionAppStore;
      case OnboardingReferralSource.googlePlay:
        return l10n.onboardingQ3OptionGooglePlay;
      case OnboardingReferralSource.friend:
        return l10n.onboardingQ3OptionFriend;
      default:
        return l10n.onboardingQ3OptionOther;
    }
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

/// summary 页的单条要点行：左侧 emoji，右侧文字。
class _SummaryPoint extends StatelessWidget {
  const _SummaryPoint({
    required this.emoji,
    required this.text,
    required this.textColor,
    required this.textStyle,
  });

  final String emoji;
  final String text;
  final Color textColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 1),
          child: Text(emoji, style: const TextStyle(fontSize: 24, height: 1.2)),
        ),
        Expanded(
          child: Text(
            text,
            style: textStyle?.copyWith(
              color: textColor,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// 顶部条：左侧"上一步"小按钮，右侧节段进度条。
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 28, 8),
      child: Row(
        children: [
          SizedBox(
            height: 36,
            width: 80,
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
          const SizedBox(width: 8),
          Expanded(
            child: total == 0
                ? const SizedBox.shrink()
                : _SegmentedProgress(
                    currentIndex: currentIndex,
                    total: total,
                    activeColor: colorScheme.primary,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 节段进度条：N 段等宽横条，已完成 + 当前段为 primary 色，未完成为浅灰。
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({
    required this.currentIndex,
    required this.total,
    required this.activeColor,
  });

  final int currentIndex;
  final int total;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(total, (i) {
        final reached = i <= currentIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 4,
              decoration: BoxDecoration(
                color: reached ? activeColor : colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 题干区块：左对齐的 eyebrow（步骤计数）+ 题干文本。
class _Prompt extends StatelessWidget {
  const _Prompt({required this.text, required this.eyebrow});
  final String text;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow.isNotEmpty) ...[
          Text(
            eyebrow,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          text,
          textAlign: TextAlign.start,
          style: textTheme.headlineSmall?.copyWith(
            fontSize: 22,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
