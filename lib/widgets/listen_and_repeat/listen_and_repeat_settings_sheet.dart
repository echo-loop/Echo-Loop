/// 跟读设置底部弹窗
///
/// 支持配置每句循环次数和句间停顿模式（智能/固定/倍数）。
/// 所有修改即时生效（直接写回 Provider），设置仅对当次跟读有效。
library;

import 'package:flutter/material.dart';
import '../common/app_dropdown.dart';
import '../common/setting_labeled_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/repeat_count_options.dart';
import '../../providers/listen_and_repeat/listen_and_repeat_settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/playback_speed.dart';
import '../common/settings_sheet_scaffold.dart';

/// 显示跟读设置底部弹窗
void showListenAndRepeatSettingsSheet({required BuildContext context}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _ListenAndRepeatSettingsSheet(),
  );
}

/// 跟读设置面板（即时生效，无需确认按钮）
class _ListenAndRepeatSettingsSheet extends ConsumerWidget {
  const _ListenAndRepeatSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(listenAndRepeatSettingsProvider);

    return SettingsSheetScaffold(
      title: l10n.listenAndRepeatSettings,
      subtitle: l10n.listenAndRepeatSettingsTemporaryHint,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 控制模式
          _buildControlModeSection(l10n, theme, settings, ref),
          const SizedBox(height: AppSpacing.l),

          // 参考音频来源：原音 / 本地 Kokoro
          _buildReferenceSourceSection(l10n, theme, settings, ref),
          const SizedBox(height: AppSpacing.l),

          // 播放速度（手动/自动模式下都生效）
          _buildPlaybackSpeedSection(l10n, theme, settings, ref),

          // 自动模式才显示循环次数和停顿设置
          if (!settings.isManualMode) ...[
            const SizedBox(height: AppSpacing.l),

            // 每句循环次数
            _buildRepeatCountRow(l10n, theme, settings, ref),
            const SizedBox(height: AppSpacing.l),

            // 句间停顿
            Text(
              l10n.intensiveListenPauseLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            // 模式切换
            _buildPauseModeSelector(l10n, settings, ref),
            const SizedBox(height: AppSpacing.m),

            // 模式详情
            _buildPauseModeDetail(l10n, theme, settings, ref),
          ],
        ],
      ),
    );
  }

  /// 参考音频来源：原媒体片段或本地 TTS 朗读。
  Widget _buildReferenceSourceSection(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.listenAndRepeatReferenceLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ShadowingReferenceSource>(
            segments: [
              ButtonSegment(
                value: ShadowingReferenceSource.original,
                label: Text(l10n.listenAndRepeatReferenceOriginal),
                icon: const Icon(Icons.audiotrack, size: 18),
              ),
              ButtonSegment(
                value: ShadowingReferenceSource.localTts,
                label: Text(l10n.listenAndRepeatReferenceTts),
                icon: const Icon(Icons.record_voice_over, size: 18),
              ),
            ],
            selected: {settings.referenceSource},
            onSelectionChanged: (selected) {
              ref
                  .read(listenAndRepeatSettingsProvider.notifier)
                  .update(settings.copyWith(referenceSource: selected.first));
            },
            showSelectedIcon: false,
          ),
        ),
        if (settings.referenceSource == ShadowingReferenceSource.localTts) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.listenAndRepeatReferenceTtsHint,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// 播放速度滑块
  ///
  /// 速度仅对当前会话生效，使用统一离散档位。
  Widget _buildPlaybackSpeedSection(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingLabeledRow(
          label: Text(
            l10n.playbackSpeed,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Text(
            _formatSpeed(settings.playbackSpeed),
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Slider(
          value: playbackSpeedSliderValue(settings.playbackSpeed),
          min: 0,
          max: (kUnifiedPlaybackSpeeds.length - 1).toDouble(),
          divisions: kUnifiedPlaybackSpeeds.length - 1,
          label: _formatSpeed(settings.playbackSpeed),
          onChanged: (value) {
            final speed = playbackSpeedFromSliderValue(value);
            ref
                .read(listenAndRepeatSettingsProvider.notifier)
                .update(settings.copyWith(playbackSpeed: speed));
          },
        ),
      ],
    );
  }

  /// 统一显示速度标签：始终保留一位小数。
  String _formatSpeed(double speed) => formatPlaybackSpeedLabel(speed);

  /// 控制模式选择区域
  Widget _buildControlModeSection(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.listenAndRepeatControlModeLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ShadowingControlMode>(
            segments: [
              ButtonSegment(
                value: ShadowingControlMode.auto,
                label: Text(l10n.listenAndRepeatControlModeAuto),
                icon: const Icon(Icons.autorenew, size: 18),
              ),
              ButtonSegment(
                value: ShadowingControlMode.manual,
                label: Text(l10n.listenAndRepeatControlModeManual),
                icon: const Icon(Icons.touch_app, size: 18),
              ),
            ],
            selected: {settings.controlMode},
            onSelectionChanged: (selected) {
              ref
                  .read(listenAndRepeatSettingsProvider.notifier)
                  .update(settings.copyWith(controlMode: selected.first));
            },
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                settings.isManualMode
                    ? l10n.listenAndRepeatControlModeManualDesc
                    : l10n.listenAndRepeatControlModeAutoDesc,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 每句循环次数选择行
  Widget _buildRepeatCountRow(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            l10n.intensiveListenRepeatCount,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        AppDropdown<int>(
          value: settings.repeatCount,
          items: [
            ...kRepeatCountOptions.where((count) => count != 0).map((count) {
              return DropdownMenuItem(
                value: count,
                child: Text(l10n.intensiveListenRepeatCountValue(count)),
              );
            }),
            DropdownMenuItem(value: 0, child: Text(l10n.infiniteRepeat)),
          ],
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(listenAndRepeatSettingsProvider.notifier)
                  .update(settings.copyWith(repeatCount: value));
            }
          },
        ),
      ],
    );
  }

  /// 停顿模式切换（SegmentedButton）
  Widget _buildPauseModeSelector(
    AppLocalizations l10n,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<PauseMode>(
        segments: [
          ButtonSegment(
            value: PauseMode.smart,
            label: Text(l10n.intensiveListenPauseSmart),
          ),
          ButtonSegment(
            value: PauseMode.fixed,
            label: Text(l10n.intensiveListenPauseFixed),
          ),
          ButtonSegment(
            value: PauseMode.multiplier,
            label: Text(l10n.intensiveListenPauseMultiplierMode),
          ),
        ],
        selected: {settings.pauseMode},
        onSelectionChanged: (selected) {
          ref
              .read(listenAndRepeatSettingsProvider.notifier)
              .update(settings.copyWith(pauseMode: selected.first));
        },
        showSelectedIcon: false,
      ),
    );
  }

  /// 停顿模式详情区域
  Widget _buildPauseModeDetail(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    switch (settings.pauseMode) {
      case PauseMode.smart:
        return Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                l10n.listenAndRepeatPauseSmartDesc,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ],
        );

      case PauseMode.fixed:
        final options = IntensiveListenSettings.fixedPauseOptions;
        var idx = options.indexOf(settings.fixedPauseSeconds);
        if (idx < 0) idx = 2; // 回退到 3 秒
        return Row(
          children: [
            Expanded(
              child: Slider(
                value: idx.toDouble(),
                min: 0,
                max: (options.length - 1).toDouble(),
                divisions: options.length - 1,
                label: '${options[idx]}s',
                onChanged: (v) {
                  ref
                      .read(listenAndRepeatSettingsProvider.notifier)
                      .update(
                        settings.copyWith(
                          fixedPauseSeconds: options[v.round()],
                        ),
                      );
                },
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${settings.fixedPauseSeconds}s',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case PauseMode.multiplier:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.intensiveListenPauseMultiplierLabel,
              style: theme.textTheme.bodyLarge,
            ),
            AppDropdown<double>(
              value: settings.pauseMultiplier,
              items: IntensiveListenSettings.multiplierOptions.map((value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(
                    l10n.intensiveListenPauseMultiplierValue(
                      value.toStringAsFixed(
                        value == value.roundToDouble() ? 0 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(listenAndRepeatSettingsProvider.notifier)
                      .update(settings.copyWith(pauseMultiplier: value));
                }
              },
            ),
          ],
        );
    }
  }
}
