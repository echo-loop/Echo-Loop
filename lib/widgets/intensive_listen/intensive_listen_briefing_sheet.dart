/// 精听简报底部弹窗
///
/// 进入精听前显示，告知用户句子总数和操作提示，
/// 同时让用户在弹窗里选择本次会话的初始播放速度（与盲听/复述/跟读对齐）。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/intensive_listen_settings.dart';
import '../../theme/app_theme.dart';

/// 显示精听简报底部弹窗
///
/// [defaultPlaybackSpeed] 默认播放速度（默认 1.0），用户可在弹窗里改。
/// [onStartPractice] 点击"开始练习"时回调，参数为用户最终选定的速度
///   以及句间停顿倍数（-1.0 = 自动/smart 模式，>0 = multiplier 模式）。
Future<void> showIntensiveListenBriefingSheet({
  required BuildContext context,
  required int sentenceCount,
  Duration? estimatedDuration,
  double defaultPlaybackSpeed = 1.0,
  required void Function(double playbackSpeed, double pauseMultiplier)
  onStartPractice,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => IntensiveListenBriefingSheet(
      sentenceCount: sentenceCount,
      estimatedDuration: estimatedDuration,
      defaultPlaybackSpeed: defaultPlaybackSpeed,
      onStartPractice: onStartPractice,
    ),
  );
}

/// 精听简报弹窗内容
class IntensiveListenBriefingSheet extends StatefulWidget {
  /// 句子总数
  final int sentenceCount;

  /// 预估练习时长
  final Duration? estimatedDuration;

  /// 默认播放速度
  final double defaultPlaybackSpeed;

  /// 开始练习回调（带回最终选定的速度 + 句间停顿倍数）
  ///
  /// pauseMultiplier: -1.0 = 自动（smart 模式），>0 = multiplier 模式倍数。
  final void Function(double playbackSpeed, double pauseMultiplier)
  onStartPractice;

  const IntensiveListenBriefingSheet({
    super.key,
    required this.sentenceCount,
    this.estimatedDuration,
    this.defaultPlaybackSpeed = 1.0,
    required this.onStartPractice,
  });

  @override
  State<IntensiveListenBriefingSheet> createState() =>
      _IntensiveListenBriefingSheetState();
}

/// 句间停顿下拉选项：-1.0 = 自动（smart 模式），其余为段长倍数。
const List<double> _kPauseMultiplierOptions = [-1.0, 1.0, 2.0, 3.0, 4.0, 5.0];

class _IntensiveListenBriefingSheetState
    extends State<IntensiveListenBriefingSheet> {
  late double _playbackSpeed = widget.defaultPlaybackSpeed;
  double _pauseMultiplier = -1.0;

  /// 格式化预估时长
  String _formatEstimatedDuration(AppLocalizations l10n, Duration duration) {
    final minutes = (duration.inSeconds / 60).ceil();
    if (minutes < 1) return l10n.estimatedLessThanOneMinute;
    return l10n.estimatedMinutes(minutes);
  }

  /// 统一显示速度标签：整数速度显示为 1x，0.05 步进保留必要小数。
  String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) return '${speed.toInt()}x';
    if ((speed * 10).roundToDouble() == speed * 10) {
      return '${speed.toStringAsFixed(1)}x';
    }
    return '${speed.toStringAsFixed(2)}x';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 耳机图标
          Icon(Icons.hearing, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.m),

          // 标题
          Text(
            l10n.intensiveListenBriefingTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 练习提示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    l10n.intensiveListenBriefingTip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          // 句间停顿（自动 / 1x-5x 段长倍数）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.intensiveListenPauseLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                width: 80,
                child: DropdownButton<double>(
                  value: _pauseMultiplier,
                  isExpanded: true,
                  isDense: true,
                  elevation: 0,
                  underline: const SizedBox.shrink(),
                  items: _kPauseMultiplierOptions
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value < 0
                                ? l10n.intensiveListenPauseSmart
                                : '${value.toInt()}x',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _pauseMultiplier = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),

          // 播放速度（与盲听/复述/跟读对齐）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.playbackSpeed,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                width: 80,
                child: DropdownButton<double>(
                  value: _playbackSpeed,
                  isExpanded: true,
                  isDense: true,
                  elevation: 0,
                  underline: const SizedBox.shrink(),
                  items: IntensiveListenSettings.briefingPlaybackSpeedOptions
                      .map(
                        (speed) => DropdownMenuItem(
                          value: speed,
                          child: Text(_formatSpeed(speed)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _playbackSpeed = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),

          // 句子总数 + 预估时长
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.intensiveListenBriefingSentenceCount(widget.sentenceCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.estimatedDuration != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                  child: Text(
                    '·',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatEstimatedDuration(l10n, widget.estimatedDuration!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.l),

          // 开始练习按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onStartPractice(_playbackSpeed, _pauseMultiplier);
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.startPractice),
            ),
          ),
        ],
      ),
    );
  }
}
