/// 复述 AI 评估报告正文。
///
/// 纯展示层：只根据一份（可能仍在流式增长的）[RetellReviewEvaluation] 快照渲染，
/// 不读 provider、不发起副作用。所有 section 按「字段是否已到达」逐个出现，
/// 半成品条目（要点文本为空、语法原句为空）直接跳过，避免流式过程中的空行闪烁。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/retell_review_evaluation.dart';
import '../../services/audio_preview_controller.dart';
import '../../theme/app_theme.dart';
import '../common/playback_controls.dart';
import 'retell_review_corrections.dart';
import 'retell_review_key_points.dart';
import 'retell_review_rating_style.dart';
import 'retell_review_transcript_card.dart';

/// 评估报告正文（可滚动）。
class RetellReviewReport extends StatelessWidget {
  final RetellReviewEvaluation evaluation;

  /// 是否仍在接收增量帧；为 true 时底部显示「正在生成…」提示。
  final bool isStreaming;

  final String recordingPath;
  final AudioPreviewController preview;
  final Future<void> Function() onBeforePlayback;

  const RetellReviewReport({
    super.key,
    required this.evaluation,
    required this.isStreaming,
    required this.recordingPath,
    required this.preview,
    required this.onBeforePlayback,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 用 keyPoint 判定条目是否成形：它是要点里唯一必填的文本，且按 schema 键序
    // 第一个到达；原文摘录在 added 时合法为空，不能当信号。
    final keyPoints = [
      for (final item in evaluation.keyPoints)
        if (item.keyPoint.isNotEmpty) item,
    ];
    final corrections = [
      for (final item in evaluation.corrections)
        if (item.transcript.isNotEmpty) item,
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        _RatingHero(
          evaluation: evaluation,
          recordingPath: recordingPath,
          preview: preview,
          onBeforePlayback: onBeforePlayback,
        ),
        // 转录是后面所有判定的共同依据，排在结论之后、逐条要点之前；默认只露 1 行。
        if (evaluation.transcript.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          RetellReviewTranscriptCard(transcript: evaluation.transcript),
        ],
        if (keyPoints.isNotEmpty) ...[
          _SectionLabel(
            title: l10n.retellAiReviewKeyPoints,
            visual: retellKeyPointsSectionVisual(context),
            trailing: RetellReviewStatusTally(keyPoints: keyPoints),
          ),
          for (final item in keyPoints)
            RetellReviewKeyPointCard(keyPoint: item),
        ],
        // 纠错是逐条可操作的具体项，排在唯一一条整体建议之前。
        if (corrections.isNotEmpty) ...[
          _SectionLabel(
            title: l10n.retellAiReviewCorrections,
            visual: retellCorrectionsSectionVisual(context),
          ),
          for (final item in corrections)
            RetellReviewCorrectionCard(correction: item),
        ],
        if (evaluation.suggestion.isNotEmpty) ...[
          _SectionLabel(
            title: l10n.retellAiReviewSuggestion,
            visual: retellSuggestionSectionVisual(context),
          ),
          RetellReviewSuggestionCallout(text: evaluation.suggestion),
        ],
        if (isStreaming) const _GeneratingPill(),
      ],
    );
  }
}

/// 顶部结论区：评级词 + 五档进度 + 总评 + 录音试听，按评级着色。
class _RatingHero extends StatelessWidget {
  final RetellReviewEvaluation evaluation;
  final String recordingPath;
  final AudioPreviewController preview;
  final Future<void> Function() onBeforePlayback;

  const _RatingHero({
    required this.evaluation,
    required this.recordingPath,
    required this.preview,
    required this.onBeforePlayback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final visual = retellRatingVisual(context, l10n, evaluation.rating);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: visual.container,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: visual.accent.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: visual.accent.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: Icon(visual.icon, size: 22, color: visual.accent),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visual.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: visual.accent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    _RatingPips(accent: visual.accent, level: visual.level),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              _ReviewRecordingButton(
                recordingPath: recordingPath,
                preview: preview,
                onBeforePlayback: onBeforePlayback,
                accent: visual.accent,
              ),
            ],
          ),
          if (evaluation.summary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Text(
              evaluation.summary,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// 五档评级进度块；评级未到达时全部为暗档。
class _RatingPips extends StatelessWidget {
  final Color accent;
  final int level;

  const _RatingPips({required this.accent, required this.level});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < retellRatingLevelCount; i++)
        Container(
          width: 20,
          height: 5,
          margin: EdgeInsets.only(
            right: i == retellRatingLevelCount - 1 ? 0 : 4,
          ),
          decoration: BoxDecoration(
            color: i < level ? accent : accent.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
    ],
  );
}

/// 小节标题：语义色图标 + 标题，右侧可挂统计信息。
///
/// 用 titleMedium 而不是 titleSmall：正文要点是 bodyMedium/w600，与 titleSmall
/// 同为 14px，只差一档字重——中文字体上几乎分辨不出，标题会读起来像正文。
/// 靠字号 + 字重两个维度拉开层级，比继续加粗有效。
///
/// 图标是扫读锚点：报告里三个小节内容形态各不相同（清单 / 对照 / 一段话），
/// 纯文字标题在长列表里不够显眼。
class _SectionLabel extends StatelessWidget {
  final String title;

  /// 标题图标与其语义色，见 [retellKeyPointsSectionVisual] 等。
  final RetellSectionVisual visual;

  final Widget? trailing;

  const _SectionLabel({
    required this.title,
    required this.visual,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: AppSpacing.l,
      bottom: AppSpacing.s,
      left: AppSpacing.xs,
    ),
    child: Row(
      children: [
        Icon(visual.icon, size: 18, color: visual.color),
        const SizedBox(width: AppSpacing.s - 2),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.m),
          Expanded(child: trailing!),
        ],
      ],
    ),
  );
}

/// 流式未结束的提示，告诉用户后面还有内容会出现。
class _GeneratingPill extends StatelessWidget {
  const _GeneratingPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.l),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Text(
            AppLocalizations.of(context)!.retellAiReviewGenerating,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero 内复用页面级播放服务，用户可在看报告时直接试听本次录音。
///
/// 无局部播放状态：报告是长列表，按钮滑出视口就会被回收，任何存在 State 里的
/// 播放状态都会随之丢失。这里直接观察 controller 的 [ValueListenable]，重建后读到
/// 的就是当前真实状态。
class _ReviewRecordingButton extends StatelessWidget {
  final String recordingPath;
  final AudioPreviewController preview;
  final Future<void> Function() onBeforePlayback;
  final Color accent;

  const _ReviewRecordingButton({
    required this.recordingPath,
    required this.preview,
    required this.onBeforePlayback,
    required this.accent,
  });

  Future<void> _handleTap(BuildContext context) async {
    if (preview.isPlaying) {
      await preview.stop();
      return;
    }
    await onBeforePlayback();
    if (!context.mounted) return;
    await preview.play(recordingPath);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<bool>(
      valueListenable: preview.isPlayingListenable,
      builder: (context, isPlaying, _) => PlaybackCenterButton(
        tooltip: isPlaying
            ? l10n.retellAiReviewStopRecording
            : l10n.retellAiReviewPlayRecording,
        onPressed: () => _handleTap(context),
        // 与评级色一致的图标，不再使用实心底色，避免按钮比评级词还抢眼。
        size: 40,
        icon: isPlaying
            ? Icon(Icons.stop_rounded, size: 22, color: accent)
            : playbackToggleGlyph(
                PlaybackToggleIcon.play,
                color: accent,
                size: 22,
              ),
      ),
    );
  }
}
