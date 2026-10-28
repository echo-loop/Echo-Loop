/// 文字大小设置页（学习内容）
///
/// 布局：上方字号设置卡，下方一段预览文本。
/// 预览放在最下面，调整字号时上方控件位置不动，只有预览向下伸缩。
/// 当前只作用于字幕列表（试点），后续推广到其他学习内容。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_localizations.dart';
import '../providers/reading_text_prefs_provider.dart';
import '../theme/app_theme.dart';

/// 预览文本（学习内容本身是英文，不随界面语言切换）。
const _previewText =
    'Learning a language takes patience and a lot of practice. '
    'Listen carefully, then repeat each sentence out loud until it '
    'feels natural.';

class ReadingTextSettingsScreen extends ConsumerWidget {
  const ReadingTextSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(readingTextPrefsNotifierProvider);
    final controller = ref.read(readingTextPrefsNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.readingTextSettings)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          Card(
            child: _FontSizeControl(
              fontScale: prefs.fontScale,
              onChanged: controller.setFontScale,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          _SectionLabel(l10n.readingTextPreview),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Text(
                _previewText,
                style: prefs.applyTo(
                  theme.textTheme.bodyMedium ?? const TextStyle(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片外的小节标题。
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.s),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 字号：标题行显示当前百分比；下方「A− ── 滑块 ── A+」，两端按钮逐档（5%）调整。
class _FontSizeControl extends StatelessWidget {
  final double fontScale;
  final ValueChanged<double> onChanged;

  const _FontSizeControl({required this.fontScale, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final steps = readingFontScaleSteps;
    final index = steps.indexOf(fontScale).clamp(0, steps.length - 1);
    final lastIndex = steps.length - 1;
    final percent = '${(fontScale * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.m,
        AppSpacing.m,
        AppSpacing.xs,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.readingFontSize,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Text(
                percent,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _StepButton(
                tooltip: l10n.readingFontSizeDecrease,
                asset: 'assets/icon/text-decrease.svg',
                onPressed: index > 0 ? () => onChanged(steps[index - 1]) : null,
              ),
              Expanded(
                // 档位密（5% 一档），不画刻度点，避免滑轨上一串密集小点。
                child: SliderTheme(
                  data: SliderTheme.of(
                    context,
                  ).copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
                  child: Slider(
                    value: index.toDouble(),
                    max: lastIndex.toDouble(),
                    divisions: lastIndex,
                    onChanged: (v) => onChanged(steps[v.round()]),
                  ),
                ),
              ),
              _StepButton(
                tooltip: l10n.readingFontSizeIncrease,
                asset: 'assets/icon/text-increase.svg',
                onPressed: index < lastIndex
                    ? () => onChanged(steps[index + 1])
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 滑块两端的缩小 / 放大按钮：两侧图标同尺寸，用「A−」「A+」区分方向。
class _StepButton extends StatelessWidget {
  final String tooltip;
  final String asset;
  final VoidCallback? onPressed;

  const _StepButton({
    required this.tooltip,
    required this.asset,
    required this.onPressed,
  });

  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = onPressed == null
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : colorScheme.onSurfaceVariant;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: SvgPicture.asset(
        asset,
        width: _iconSize,
        height: _iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
