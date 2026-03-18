/// 跟读录音结果卡片（共享组件）
///
/// 录音评分结果卡片：评级 Badge + 播放录音按钮。
/// 跟读页面和难句补练页面共用。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/speech_practice_models.dart';
import '../../theme/app_theme.dart';

/// 评分阈值配置。
class RatingThresholds {
  /// Perfect 阈值。
  final double perfect;

  /// Excellent 阈值。
  final double excellent;

  /// Good 阈值。
  final double good;

  /// Fair 阈值。
  final double fair;

  const RatingThresholds({
    required this.perfect,
    required this.excellent,
    required this.good,
    required this.fair,
  });

  /// 跟读场景默认阈值。
  static const listenAndRepeat = RatingThresholds(
    perfect: 0.95,
    excellent: 0.80,
    good: 0.60,
    fair: 0.40,
  );

  /// 复述场景阈值（比跟读宽松）。
  static const retell = RatingThresholds(
    perfect: 0.90,
    excellent: 0.75,
    good: 0.50,
    fair: 0.20,
  );
}

/// 跟读录音结果卡。
class SpeechPracticeResultCard extends StatelessWidget {
  final AppLocalizations l10n;
  final SpeechPracticeAttempt attempt;
  final bool isPlayingAttempt;
  final VoidCallback? onPlayAttempt;

  /// 评分阈值，默认跟读阈值。
  final RatingThresholds thresholds;

  const SpeechPracticeResultCard({
    super.key,
    required this.l10n,
    required this.attempt,
    required this.isPlayingAttempt,
    this.onPlayAttempt,
    this.thresholds = RatingThresholds.listenAndRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme);
    final ratingStyle = _ratingStyle(theme);
    final hasTranscript = (attempt.finalTranscript ?? '').isNotEmpty;
    if (!hasTranscript) {
      return Text(
        _feedbackText(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ratingStyle.backgroundStart, ratingStyle.backgroundEnd],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ratingStyle.borderColor),
          ),
          child: Text(
            _ratingLabel(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: ratingStyle.textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const Spacer(),
        if (attempt.hasRecording) ...[
          const SizedBox(width: AppSpacing.xs),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.28,
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              visualDensity: VisualDensity.compact,
              splashRadius: 16,
              tooltip: isPlayingAttempt
                  ? l10n.stop
                  : l10n.listenAndRepeatPlayRecordingButton,
              onPressed: onPlayAttempt,
              icon: Icon(
                isPlayingAttempt
                    ? Icons.stop_rounded
                    : Icons.volume_up_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.76,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _ratingLabel() {
    final score = attempt.score ?? 0;
    if (score >= thresholds.perfect) {
      return l10n.listenAndRepeatRatingPerfect;
    }
    if (score >= thresholds.excellent) {
      return l10n.listenAndRepeatRatingExcellent;
    }
    if (score >= thresholds.good) {
      return l10n.listenAndRepeatRatingGood;
    }
    if (score >= thresholds.fair) {
      return l10n.listenAndRepeatRatingFair;
    }
    return l10n.listenAndRepeatRatingKeepGoing;
  }

  String _feedbackText() {
    return switch (attempt.status) {
      SpeechPracticeAttemptStatus.noEnglishDetected =>
        l10n.listenAndRepeatRecognitionNoEnglish,
      SpeechPracticeAttemptStatus.permissionDenied =>
        l10n.listenAndRepeatRecognitionPermissionDenied,
      SpeechPracticeAttemptStatus.unavailable =>
        l10n.listenAndRepeatRecognitionUnavailable,
      SpeechPracticeAttemptStatus.error => l10n.listenAndRepeatRecognitionError,
      SpeechPracticeAttemptStatus.awaitingFinal ||
      SpeechPracticeAttemptStatus.passed ||
      SpeechPracticeAttemptStatus.belowThreshold ||
      SpeechPracticeAttemptStatus.recording ||
      SpeechPracticeAttemptStatus.idle => '',
    };
  }

  Color _statusColor(ThemeData theme) {
    return switch (attempt.status) {
      SpeechPracticeAttemptStatus.passed => const Color(0xFF2E9B51),
      SpeechPracticeAttemptStatus.awaitingFinal => theme.colorScheme.primary,
      SpeechPracticeAttemptStatus.belowThreshold ||
      SpeechPracticeAttemptStatus.noEnglishDetected ||
      SpeechPracticeAttemptStatus.permissionDenied ||
      SpeechPracticeAttemptStatus.unavailable ||
      SpeechPracticeAttemptStatus.error => theme.colorScheme.error,
      _ => theme.colorScheme.onSurface,
    };
  }

  RatingBadgeStyle _ratingStyle(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final score = attempt.score ?? 0;

    // Perfect — 金色
    if (score >= thresholds.perfect) {
      return isDark
          ? const RatingBadgeStyle(
              textColor: Color(0xFFFFE082),
              backgroundStart: Color(0x33C9A030),
              backgroundEnd: Color(0x1A7A5F14),
              borderColor: Color(0x40E0B84A),
            )
          : const RatingBadgeStyle(
              textColor: Color(0xFF8B6914),
              backgroundStart: Color(0xFFFFF8E1),
              backgroundEnd: Color(0xFFFFF0B8),
              borderColor: Color(0xFFE0C068),
            );
    }

    // Excellent — 绿色
    if (score >= thresholds.excellent) {
      return isDark
          ? const RatingBadgeStyle(
              textColor: Color(0xFFB9F5C8),
              backgroundStart: Color(0x3347B66B),
              backgroundEnd: Color(0x1A245B38),
              borderColor: Color(0x4057C878),
            )
          : const RatingBadgeStyle(
              textColor: Color(0xFF1E7A3D),
              backgroundStart: Color(0xFFEAF8EF),
              backgroundEnd: Color(0xFFDDF2E4),
              borderColor: Color(0xFFA8D6B6),
            );
    }

    // Good — 黄绿色
    if (score >= thresholds.good) {
      return isDark
          ? const RatingBadgeStyle(
              textColor: Color(0xFFE4F3B2),
              backgroundStart: Color(0x33A4B84B),
              backgroundEnd: Color(0x1A56611F),
              borderColor: Color(0x40BDD460),
            )
          : const RatingBadgeStyle(
              textColor: Color(0xFF687A18),
              backgroundStart: Color(0xFFF6F8DF),
              backgroundEnd: Color(0xFFEEF3C8),
              borderColor: Color(0xFFD6DD9A),
            );
    }

    // Fair — 橙色（鼓励）
    if (score >= thresholds.fair) {
      return isDark
          ? const RatingBadgeStyle(
              textColor: Color(0xFFF7D79B),
              backgroundStart: Color(0x33C68A38),
              backgroundEnd: Color(0x1A6D4617),
              borderColor: Color(0x40E0A450),
            )
          : const RatingBadgeStyle(
              textColor: Color(0xFF8A5A14),
              backgroundStart: Color(0xFFFFF1DD),
              backgroundEnd: Color(0xFFF9E3BF),
              borderColor: Color(0xFFE6C48C),
            );
    }

    // Keep Going (< 0.40) — 柔和蓝灰（避免红色带来的负面感）
    return isDark
        ? const RatingBadgeStyle(
            textColor: Color(0xFFB0BEC5),
            backgroundStart: Color(0x33607D8B),
            backgroundEnd: Color(0x1A37474F),
            borderColor: Color(0x4078909C),
          )
        : const RatingBadgeStyle(
            textColor: Color(0xFF546E7A),
            backgroundStart: Color(0xFFECEFF1),
            backgroundEnd: Color(0xFFE0E4E8),
            borderColor: Color(0xFFB0BEC5),
          );
  }
}

/// 评级 Badge 样式
class RatingBadgeStyle {
  final Color textColor;
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color borderColor;

  const RatingBadgeStyle({
    required this.textColor,
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.borderColor,
  });
}
