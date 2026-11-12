/// 字幕文字设置页（学习内容）
///
/// 布局：上方一张设置卡（字号、粗细），下方一段预览文本（原文 + 译文）。
/// 预览放在最下面，调整上方控件时位置不动，只有预览向下伸缩。
/// 作用范围与 [SubtitleTextPrefs] 一致，覆盖所有学习正文。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/subtitle_text_prefs_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/sentence_translation_text.dart';

/// 预览文本（学习内容本身是英文，不随界面语言切换）。
const _previewText =
    'Learning a language takes patience and a lot of practice. '
    'Listen carefully, then repeat each sentence out loud until it '
    'feels natural.';

/// 预览译文，按母语取值（键与 [supportedNativeLanguages] 一致）。
/// 译文跟随母语而非应用语言：应用界面语言可能被设成要学习的语言。
const _previewTranslations = <String, String>{
  'zh-CN': '学习语言需要耐心和大量练习。认真听，然后大声跟读每一句，直到说得自然为止。',
  'zh-TW': '學習語言需要耐心和大量練習。認真聽，然後大聲跟讀每一句，直到說得自然為止。',
};

/// 母语缺失对应译文时的回退语言（与 [AppSettingsState.nativeLanguage] 默认值一致）。
const _fallbackNativeLanguage = 'zh-CN';

class SubtitleTextSettingsScreen extends ConsumerWidget {
  const SubtitleTextSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(subtitleTextPrefsProvider);
    final controller = ref.read(subtitleTextPrefsProvider.notifier);
    final theme = Theme.of(context);
    final nativeLanguage = ref.watch(
      appSettingsProvider.select((settings) => settings.nativeLanguage),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subtitleTextSettings)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          Card(
            child: Column(
              children: [
                _FontSizeControl(
                  fontSizePercent: prefs.fontSizePercent,
                  onChanged: controller.setFontSizePercent,
                ),
                const Divider(
                  height: 1,
                  indent: AppSpacing.m,
                  endIndent: AppSpacing.m,
                ),
                _FontWeightControl(
                  percent: prefs.fontWeightPercent,
                  onChanged: controller.setFontWeightPercent,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          _SectionLabel(l10n.subtitleTextPreview),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: _buildPreview(prefs, theme, nativeLanguage),
            ),
          ),
        ],
      ),
    );
  }

  /// 原文与译文：原文样式与字幕列表一致，译文沿用列表内的次级样式。
  Widget _buildPreview(
    SubtitleTextPrefs prefs,
    ThemeData theme,
    String nativeLanguage,
  ) {
    final textStyle = prefs.applyTo(
      theme.textTheme.bodyLarge?.copyWith(
            height: subtitleBodyLineHeight,
            letterSpacing: 0,
          ) ??
          const TextStyle(),
    );
    final translation =
        _previewTranslations[nativeLanguage] ??
        _previewTranslations[_fallbackNativeLanguage]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_previewText, style: textStyle),
        const SizedBox(height: AppSpacing.s),
        Text(
          translation,
          style: SentenceTranslationText.secondaryStyle(theme, textStyle),
        ),
      ],
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

/// 字号与粗细两个控件共用的内边距。
const _controlPadding = EdgeInsets.fromLTRB(
  AppSpacing.m,
  AppSpacing.m,
  AppSpacing.m,
  AppSpacing.xs,
);

/// 两端按钮与中间字形的边长。
const _iconSize = 24.0;

/// 字号：标题行显示当前百分比；下方「A− ── 滑块 ── A+」，两端按钮逐档（5%）调整。
class _FontSizeControl extends StatelessWidget {
  final int fontSizePercent;
  final ValueChanged<int> onChanged;

  const _FontSizeControl({
    required this.fontSizePercent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final steps = subtitleFontSizePercentSteps;
    final index = steps.indexOf(fontSizePercent).clamp(0, steps.length - 1);
    final percent = '$fontSizePercent%';

    return Padding(
      padding: _controlPadding,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.subtitleFontSize,
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
          _StepSliderRow(
            index: index,
            lastIndex: steps.length - 1,
            onIndexChanged: (next) => onChanged(steps[next]),
            decreaseTooltip: l10n.subtitleFontSizeDecrease,
            increaseTooltip: l10n.subtitleFontSizeIncrease,
            decreaseIconBuilder: (color) =>
                _svgIcon('assets/icon/text-decrease.svg', color),
            increaseIconBuilder: (color) =>
                _svgIcon('assets/icon/text-increase.svg', color),
          ),
        ],
      ),
    );
  }
}

/// 粗细：标题行显示当前百分比（100% 即默认字重 w400）；下方「A ── 滑块 ── A」，左细右粗，两端按钮逐档（5%）调整。
class _FontWeightControl extends StatelessWidget {
  final int percent;
  final ValueChanged<int> onChanged;

  const _FontWeightControl({required this.percent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final steps = subtitleFontWeightPercentSteps;
    final index = steps.indexOf(percent).clamp(0, steps.length - 1);

    // 字形盒固定为图标边长：正文行高 1.5 会把按钮撑大，高亮圆也随之变大。
    Widget glyph(FontWeight glyphWeight, Color color) => SizedBox.square(
      dimension: _iconSize,
      child: Center(
        child: Text(
          'A',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: _iconSize,
            height: 1,
            fontWeight: glyphWeight,
            color: color,
          ),
        ),
      ),
    );

    return Padding(
      padding: _controlPadding,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.subtitleFontWeight,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Text(
                '$percent%',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          _StepSliderRow(
            index: index,
            lastIndex: steps.length - 1,
            onIndexChanged: (next) => onChanged(steps[next]),
            decreaseTooltip: l10n.subtitleFontWeightDecrease,
            increaseTooltip: l10n.subtitleFontWeightIncrease,
            decreaseIconBuilder: (color) => glyph(FontWeight.w200, color),
            increaseIconBuilder: (color) => glyph(FontWeight.w800, color),
          ),
        ],
      ),
    );
  }
}

/// 字号与粗细共用的「两端按钮 + 滑块」一行：两端按钮逐档调整，中间滑块与档位一一对应。
/// 两侧按钮与滑轨布局完全相同，保证两个控件的滑轨长度与起止位置一致。
class _StepSliderRow extends StatelessWidget {
  /// 当前档位下标。
  final int index;

  /// 最大档位下标。
  final int lastIndex;

  /// 用户选中新档位（下标）时回调。
  final ValueChanged<int> onIndexChanged;

  final String decreaseTooltip;
  final String increaseTooltip;
  final Widget Function(Color color) decreaseIconBuilder;
  final Widget Function(Color color) increaseIconBuilder;

  const _StepSliderRow({
    required this.index,
    required this.lastIndex,
    required this.onIndexChanged,
    required this.decreaseTooltip,
    required this.increaseTooltip,
    required this.decreaseIconBuilder,
    required this.increaseIconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepButton(
          tooltip: decreaseTooltip,
          onPressed: index > 0 ? () => onIndexChanged(index - 1) : null,
          iconBuilder: decreaseIconBuilder,
        ),
        Expanded(
          // 档位密，不画刻度点，避免滑轨上一串密集小点。
          child: SliderTheme(
            // 轨道与滑块做细：档位多，默认的粗轨道和大圆点会显得笨重。
            data: SliderTheme.of(context).copyWith(
              tickMarkShape: SliderTickMarkShape.noTickMark,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: index.toDouble(),
              max: lastIndex.toDouble(),
              divisions: lastIndex,
              onChanged: (v) => onIndexChanged(v.round()),
            ),
          ),
        ),
        _StepButton(
          tooltip: increaseTooltip,
          onPressed: index < lastIndex ? () => onIndexChanged(index + 1) : null,
          iconBuilder: increaseIconBuilder,
        ),
      ],
    );
  }
}

/// 滑块两端的逐档按钮；不可用时整体变灰。
class _StepButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget Function(Color color) iconBuilder;

  const _StepButton({
    required this.tooltip,
    required this.onPressed,
    required this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = onPressed == null
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : colorScheme.onSurfaceVariant;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      // 悬停 / 按下的高亮统一为圆形，与 Material 默认的圆角方形区分开。
      style: IconButton.styleFrom(shape: const CircleBorder()),
      icon: iconBuilder(color),
    );
  }
}

Widget _svgIcon(String asset, Color color) => SvgPicture.asset(
  asset,
  width: _iconSize,
  height: _iconSize,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
);
