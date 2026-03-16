/// 难句补练/收藏复习设置底部弹窗
///
/// 支持配置盲听循环次数、跟读循环次数和句间停顿模式。
/// 所有修改即时生效，设置仅对当次练习有效。
/// 提供两个入口函数分别对应难句补练和收藏复习 Provider。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/difficult_practice_settings.dart';
import '../../models/intensive_listen_settings.dart';
import '../../providers/learning_session/bookmark_review_provider.dart';
import '../../providers/learning_session/review_difficult_practice_provider.dart';
import '../../theme/app_theme.dart';

/// 显示难句补练设置底部弹窗
void showDifficultPracticeSettingsSheet({required BuildContext context}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _DifficultPracticeSettingsSheet(
      settingsSelector: (ref) =>
          ref.watch(reviewDifficultPracticeProvider.select((s) => s.settings)),
      onUpdate: (ref, settings) => ref
          .read(reviewDifficultPracticeProvider.notifier)
          .updateSettings(settings),
    ),
  );
}

/// 显示收藏复习设置底部弹窗
void showBookmarkReviewSettingsSheet({required BuildContext context}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _DifficultPracticeSettingsSheet(
      settingsSelector: (ref) =>
          ref.watch(bookmarkReviewProvider.select((s) => s.settings)),
      onUpdate: (ref, settings) =>
          ref.read(bookmarkReviewProvider.notifier).updateSettings(settings),
    ),
  );
}

/// 设置面板（即时生效，无需确认按钮）
///
/// 通过 [settingsSelector] 和 [onUpdate] 回调实现多 Provider 复用。
class _DifficultPracticeSettingsSheet extends ConsumerWidget {
  final DifficultPracticeSettings Function(WidgetRef ref) settingsSelector;
  final void Function(WidgetRef ref, DifficultPracticeSettings settings)
  onUpdate;

  const _DifficultPracticeSettingsSheet({
    required this.settingsSelector,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = settingsSelector(ref);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: SingleChildScrollView(
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
              l10n.difficultPracticeSettings,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 临时提示
            Text(
              l10n.difficultPracticeSettingsHint,
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

              // 盲听循环次数
              _buildRepeatRow(
                label: l10n.difficultPracticeBlindListenRepeat,
                value: settings.blindListenRepeatCount,
                l10n: l10n,
                theme: theme,
                onChanged: (value) => onUpdate(
                  ref,
                  settings.copyWith(blindListenRepeatCount: value),
                ),
              ),
              const SizedBox(height: AppSpacing.m),

              // 跟读循环次数
              _buildRepeatRow(
                label: l10n.difficultPracticeShadowReadingRepeat,
                value: settings.shadowReadingRepeatCount,
                l10n: l10n,
                theme: theme,
                onChanged: (value) => onUpdate(
                  ref,
                  settings.copyWith(shadowReadingRepeatCount: value),
                ),
              ),
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
      ),
    );
  }

  /// 控制模式选择区域（自动/手动）
  Widget _buildControlModeSection(
    AppLocalizations l10n,
    ThemeData theme,
    DifficultPracticeSettings settings,
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
              onUpdate(ref, settings.copyWith(controlMode: selected.first));
            },
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

  /// 循环次数选择行
  Widget _buildRepeatRow({
    required String label,
    required int value,
    required AppLocalizations l10n,
    required ThemeData theme,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyLarge),
        DropdownButton<int>(
          value: value,
          underline: const SizedBox.shrink(),
          items: List.generate(10, (i) => i + 1).map((count) {
            return DropdownMenuItem(
              value: count,
              child: Text(l10n.intensiveListenRepeatCountValue(count)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  /// 停顿模式切换（SegmentedButton）
  Widget _buildPauseModeSelector(
    AppLocalizations l10n,
    DifficultPracticeSettings settings,
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
          onUpdate(ref, settings.copyWith(pauseMode: selected.first));
        },
      ),
    );
  }

  /// 停顿模式详情区域
  Widget _buildPauseModeDetail(
    AppLocalizations l10n,
    ThemeData theme,
    DifficultPracticeSettings settings,
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
                l10n.intensiveListenPauseSmartDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );

      case PauseMode.fixed:
        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: IntensiveListenSettings.fixedPauseOptions.map((seconds) {
            final isSelected = settings.fixedPauseSeconds == seconds;
            return ChoiceChip(
              label: Text(l10n.intensiveListenPauseFixedUnit(seconds)),
              selected: isSelected,
              onSelected: (_) {
                onUpdate(ref, settings.copyWith(fixedPauseSeconds: seconds));
              },
            );
          }).toList(),
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
                  onUpdate(ref, settings.copyWith(pauseMultiplier: value));
                }
              },
            ),
          ],
        );
    }
  }
}
