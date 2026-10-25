/// 复述简报底部弹窗
///
/// 进入段落复述前显示，用户选择目标段落时长和段间停顿，
/// 复用 [showParagraphSelectionSheet] 通用组件。
library;

import 'package:flutter/material.dart';
import '../../database/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../models/study_stage.dart';
import '../../models/stage_settings_overrides.dart' show BriefingPauseChoice;
import '../../providers/new_user_guide_provider.dart';
import '../../utils/retell_duration_estimator.dart';
import '../common/paragraph_selection_sheet.dart';
import '../study/study_stage_visuals.dart';

/// 根据学习阶段计算段落复述的默认目标段落时长（秒）
///
/// 默认按轮次递增（v2 plan）：
/// - firstLearn / review0 / review1 → 10s（review0/1 在 v2 plan 下无复述，
///   但 v1 兼容路径仍可能调用，保留 10s）
/// - review2 → 15s
/// - review4 → 20s
/// - review7 → 25s
/// - review14 → 30s
/// - review28 → 30s
int retellDefaultSeconds(LearningStage? stage) {
  return switch (stage) {
    null ||
    LearningStage.firstLearn ||
    LearningStage.review0 ||
    LearningStage.review1 => 10,
    LearningStage.review2 => 15,
    LearningStage.review4 => 20,
    LearningStage.review7 => 25,
    LearningStage.review14 => 30,
    LearningStage.review28 => 30,
    LearningStage.completed => 10,
  };
}

/// 显示复述简报底部弹窗
///
/// [sentences] 完整句子列表（用于 DP 预览段落数 + 预估时长真实公式）
/// [stageLabel] 可选的阶段名（如"第三轮复习"），显示在标题下方
/// [defaultKeywordRatio] 可见词比例的初始值（按音频难度 + 学习阶段算）。
///   传入则弹窗显示"可见词比例"下拉行，用户可调整；
///   `onStartPractice` 回调会带回最终选定的档位。
/// [onStartPractice] 点击"开始练习"时回调，传递选中的目标时长、停顿倍数、可见词比例
///   pauseMultiplier: -1.0 = 自动（智能模式），>0 = 段长倍数
///   playbackSpeed: 本次复述会话使用的播放速度
/// [onSkip] 可选，提供时在"开始练习"左侧显示「跳过」按钮（宽度比例 1:2）。
///   仅按计划学习触发的入口传入；自由练习入口不传（用户既然主动点开练习，
///   再让他点跳过没意义）。
///
/// 预估时长由 [estimateRetellSessionDuration] 按真实播放+停顿公式动态计算，
/// 随段落时长 / 停顿倍数下拉框选择实时刷新。不接受静态文本参数。
Future<void> showRetellBriefingSheet({
  required BuildContext context,
  required List<Sentence> sentences,
  required void Function(
    Duration targetDuration,
    BriefingPauseChoice pause,
    KeywordRatio? keywordRatio,
    double playbackSpeed,
  )
  onStartPractice,
  void Function(
    Duration targetDuration,
    BriefingPauseChoice pause,
    KeywordRatio? keywordRatio,
    double playbackSpeed,
  )?
  onSelectionChanged,
  int defaultSeconds = 30,
  String? stageLabel,
  KeywordRatio? defaultKeywordRatio,
  double defaultPlaybackSpeed = 1.0,
  int repeatCount = 1,
  BriefingPauseChoice defaultPause = const BriefingPauseChoice.smart(),
  VoidCallback? onSkip,
}) {
  final l10n = AppLocalizations.of(context)!;
  final visual = studyStageVisual(StudyStage.retell, l10n);
  return showParagraphSelectionSheet(
    context: context,
    icon: visual.icon,
    iconColor: visual.iconColor,
    title: l10n.retellBriefingTitle,
    subtitle: l10n.retellBriefingSubtitle,
    sentences: sentences,
    defaultSeconds: defaultSeconds,
    showPauseMultiplier: true,
    showPlaybackSpeed: true,
    playbackSpeedOptions: RetellSettings.briefingPlaybackSpeedOptions,
    defaultPlaybackSpeed: defaultPlaybackSpeed,
    // 与复述 🔧 面板一致(固定间隔 + 句长倍数)。
    fixedPauseOptions: RetellSettings.fixedPauseOptions,
    pauseMultiplierOptions: RetellSettings.multiplierOptions,
    defaultPause: defaultPause,
    stageLabel: stageLabel,
    estimateDurationBuilder: (targetSeconds, pauseMultiplier) =>
        repeatCount == 0
        ? null
        : estimateRetellSessionDuration(
            sentences: sentences,
            targetSeconds: targetSeconds,
            pauseMultiplier: pauseMultiplier,
            repeatCount: repeatCount,
          ),
    defaultKeywordRatio: defaultKeywordRatio,
    onStartPractice: (_, _, _) {},
    onStartPracticeWithPlaybackSpeed:
        (targetDuration, pause, keywordRatio, playbackSpeed) {
          onStartPractice(targetDuration, pause, keywordRatio, playbackSpeed);
        },
    onSelectionChanged: onSelectionChanged,
    skipLabel: onSkip != null ? l10n.retellSkip : null,
    onSkip: onSkip,
    // 仅按计划学习路径才显示「跳过」按钮 + 配套新手引导。
    skipGuideFlowId: onSkip != null ? GuideFlowIds.retellBriefingSkip : null,
    skipGuideTitle: onSkip != null ? l10n.guideRetellSkipTitle : null,
    skipGuideDescription: onSkip != null
        ? l10n.guideRetellSkipDescription
        : null,
  );
}
