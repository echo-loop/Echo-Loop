/// 跟读设置底部弹窗
///
/// 支持配置每句循环次数和句间停顿模式（智能/固定/倍数）。
/// 所有修改即时生效（直接写回 Provider），设置仅对当次跟读有效。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../models/intensive_listen_settings.dart';
import '../../providers/shadowing/shadowing_settings_provider.dart';
import '../../theme/app_theme.dart';

/// 显示跟读设置底部弹窗
void showShadowingSettingsSheet({required BuildContext context}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _ShadowingSettingsSheet(),
  );
}

/// 跟读设置面板（即时生效，无需确认按钮）
class _ShadowingSettingsSheet extends ConsumerWidget {
  const _ShadowingSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(shadowingSettingsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽条
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 标题
            Text(
              l10n.listenAndRepeatSettings,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 临时提示
            Text(
              l10n.listenAndRepeatSettingsTemporaryHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // 控制模式
            _buildControlModeSection(l10n, theme, settings, ref),

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
      ),
    );
  }

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
                  .read(shadowingSettingsProvider.notifier)
                  .update(
                    settings.copyWith(controlMode: selected.first),
                  );
            },
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                settings.isManualMode
                    ? l10n.listenAndRepeatControlModeManualDesc
                    : l10n.listenAndRepeatControlModeAutoDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
        Text(l10n.intensiveListenRepeatCount, style: theme.textTheme.bodyLarge),
        DropdownButton<int>(
          value: settings.repeatCount,
          underline: const SizedBox.shrink(),
          items: List.generate(10, (i) => i + 1).map((count) {
            return DropdownMenuItem(
              value: count,
              child: Text(l10n.intensiveListenRepeatCountValue(count)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(shadowingSettingsProvider.notifier)
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
              .read(shadowingSettingsProvider.notifier)
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
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                l10n.listenAndRepeatPauseSmartDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );

      case PauseMode.fixed:
        final options = IntensiveListenSettings.fixedPauseOptions;
        var idx = options.indexOf(settings.fixedPauseSeconds);
        if (idx < 0) idx = 2; // 回退到 5 秒
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
                      .read(shadowingSettingsProvider.notifier)
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
            DropdownButton<double>(
              value: settings.pauseMultiplier,
              underline: const SizedBox.shrink(),
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
                      .read(shadowingSettingsProvider.notifier)
                      .update(
                        settings.copyWith(pauseMultiplier: value),
                      );
                }
              },
            ),
          ],
        );
    }
  }
}
