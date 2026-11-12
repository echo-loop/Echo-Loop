/// 收藏复习完成后的庆祝与统计总结。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../features/scheduled_flashcard/domain/review_session_summary.dart';
import '../../theme/app_theme.dart';
import '../common/dot_lottie_decoder.dart';

const _confettiAnimationAsset = 'assets/animation/confetti.lottie';

/// 为收藏句和收藏词汇复习复用同一套完成总结布局。
class ReviewCompletionSummary extends StatefulWidget {
  const ReviewCompletionSummary({
    super.key,
    required this.title,
    required this.summary,
    required this.onExit,
    required this.doneLabel,
    required this.durationLabel,
    required this.reviewedLabel,
    required this.retentionLabel,
    required this.ratingsLabel,
    required this.againLabel,
    required this.goodLabel,
    required this.easyLabel,
  });

  final String title;
  final ReviewSessionSummary summary;
  final VoidCallback onExit;
  final String doneLabel;
  final String durationLabel;
  final String reviewedLabel;
  final String retentionLabel;
  final String ratingsLabel;
  final String againLabel;
  final String goodLabel;
  final String easyLabel;

  @override
  State<ReviewCompletionSummary> createState() =>
      _ReviewCompletionSummaryState();
}

class _ReviewCompletionSummaryState extends State<ReviewCompletionSummary> {
  Timer? _animationDelayTimer;
  bool _shouldAnimate = false;

  @override
  void initState() {
    super.initState();
    _animationDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _shouldAnimate = true);
      }
    });
  }

  @override
  void dispose() {
    _animationDelayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                _confettiAnimationAsset,
                key: const Key('review-completion-confetti'),
                decoder: decodeDotLottieAnimation,
                repeat: true,
                animate: _shouldAnimate,
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                widget.title,
                key: const Key('review-completion-title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              _SummaryCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            icon: Icons.timer_outlined,
                            label: widget.durationLabel,
                            value: _formatDuration(
                              widget.summary.elapsed,
                              isZh,
                            ),
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            icon: Icons.style_outlined,
                            label: widget.reviewedLabel,
                            value: '${widget.summary.reviewedCount}',
                            color: AppTheme.successColor,
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            icon: null,
                            iconEmoji: '🧠',
                            label: widget.retentionLabel,
                            value:
                                '${(widget.summary.retentionRate * 100).toStringAsFixed(1)}%',
                            color: const Color(0xFF2B6C8F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Divider(color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: AppSpacing.s),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.ratingsLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _RatingRow(
                      key: const Key('review-completion-again'),
                      label: widget.againLabel,
                      count: widget.summary.againCount,
                      total: widget.summary.ratingCount,
                      color: const Color(0xFFC56B45),
                    ),
                    _RatingRow(
                      key: const Key('review-completion-good'),
                      label: widget.goodLabel,
                      count: widget.summary.goodCount,
                      total: widget.summary.ratingCount,
                      color: const Color(0xFF4D9271),
                    ),
                    _RatingRow(
                      key: const Key('review-completion-easy'),
                      label: widget.easyLabel,
                      count: widget.summary.easyCount,
                      total: widget.summary.ratingCount,
                      color: const Color(0xFF2B6C8F),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('review-completion-done'),
                  onPressed: widget.onExit,
                  child: Text(widget.doneLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration value, bool isZh) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);
    if (minutes > 0) {
      return isZh ? '$minutes分$seconds秒' : '${minutes}m ${seconds}s';
    }
    return isZh ? '$seconds秒' : '${seconds}s';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(AppSpacing.l), child: child),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    this.iconEmoji,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData? icon;
  final String? iconEmoji;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      iconEmoji == null
          ? Icon(icon, color: color, size: 22)
          : Text(iconEmoji ?? '', style: const TextStyle(fontSize: 22)),
      const SizedBox(height: AppSpacing.xs),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ],
  );
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    super.key,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : count / total * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(child: Text(label)),
          SizedBox(
            width: 30,
            child: Text(
              '$count',
              textAlign: TextAlign.start,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(
            width: 14,
            child: Text('·', textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 68,
            child: Text(
              '${percent.toStringAsFixed(1)}%',
              textAlign: TextAlign.start,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
