/// 自由练习（全能播放器）循环设置浮层
///
/// 悬浮在控制栏循环图标上方的浮层（非底部 sheet），即时生效并持久化。包含两组
/// **相互独立、可同时开启**的循环：
/// - 整篇循环：整篇播完后回到开头重播，可设总遍数（含 ∞）与每遍间隔。
/// - 单句循环：每句重复若干次（含 ∞）后进下一句，可设次数与每次间隔。
///
/// 每个区块由一个主开关控制；开启后用 [AnimatedSize] 展开「重复次数 / 间隔时长」两行
/// 滑块。布局紧凑：标签、滑条、当前值同处一行。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/playback_settings.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../theme/app_theme.dart';

/// 循环设置浮层内容（气泡卡片 + 向下箭头）。
///
/// 由调用方放进 Overlay 并锚定到循环按钮上方。卡片底部带一个指向按钮的小三角
/// [caretX] 是箭头尖端相对卡片左边缘的水平位置（按按钮中心计算并夹紧在卡片内）。
class LoopSettingsPopup extends ConsumerWidget {
  const LoopSettingsPopup({super.key, this.width = 280, this.caretX = 140});

  /// 气泡宽度。
  final double width;

  /// 向下箭头尖端相对卡片左边缘的水平位置。
  final double caretX;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(
      listeningPracticeProvider.select((s) => s.settings),
    );
    final controller = ref.read(listeningPracticeProvider.notifier);

    void update(PlaybackSettings next) => controller.updateSettings(next);

    final surface = theme.colorScheme.surface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 8,
          color: surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 整篇循环
                  _LoopSection(
                    icon: Icons.repeat,
                    title: l10n.wholeTextLoop,
                    enabled: settings.loopWhole,
                    count: settings.wholeLoopCount,
                    intervalSeconds: settings.wholeInterval.inSeconds,
                    onEnabledChanged: (v) =>
                        update(settings.copyWith(loopWhole: v)),
                    onCountChanged: (v) =>
                        update(settings.copyWith(wholeLoopCount: v)),
                    onIntervalChanged: (v) => update(
                      settings.copyWith(wholeInterval: Duration(seconds: v)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  // 单句循环
                  _LoopSection(
                    icon: Icons.repeat_one,
                    title: l10n.singleSentenceLoop,
                    enabled: settings.loopSentence,
                    count: settings.sentenceLoopCount,
                    intervalSeconds: settings.sentenceInterval.inSeconds,
                    onEnabledChanged: (v) =>
                        update(settings.copyWith(loopSentence: v)),
                    onCountChanged: (v) =>
                        update(settings.copyWith(sentenceLoopCount: v)),
                    onIntervalChanged: (v) => update(
                      settings.copyWith(sentenceInterval: Duration(seconds: v)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 向下箭头：贴在卡片底边、指向循环按钮（上移 1px 盖住接缝）
        ExcludeSemantics(
          child: Transform.translate(
            offset: const Offset(0, -1),
            child: CustomPaint(
              size: Size(width, 8),
              painter: _CaretPainter(caretX: caretX, color: surface),
            ),
          ),
        ),
      ],
    );
  }
}

/// 气泡向下箭头：等腰三角，底边在上贴卡片、尖端朝下指向按钮。
class _CaretPainter extends CustomPainter {
  const _CaretPainter({required this.caretX, required this.color});

  /// 尖端相对左边缘的水平位置。
  final double caretX;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const halfWidth = 8.0;
    final x = caretX.clamp(halfWidth, size.width - halfWidth);
    final path = Path()
      ..moveTo(x - halfWidth, 0)
      ..lineTo(x + halfWidth, 0)
      ..lineTo(x, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter old) =>
      old.caretX != caretX || old.color != color;
}

/// 单组循环区块：紧凑主开关行 + 开启后展开的两行「标签 + 滑条 + 值」。
class _LoopSection extends StatelessWidget {
  const _LoopSection({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.count,
    required this.intervalSeconds,
    required this.onEnabledChanged,
    required this.onCountChanged,
    required this.onIntervalChanged,
  });

  /// 区块图标（整篇=repeat，单句=repeat_one）。
  final IconData icon;

  /// 区块标题。
  final String title;

  /// 该循环是否开启。
  final bool enabled;

  /// 重复次数模型值：`0`=∞，`1-10`=有限。
  final int count;

  /// 间隔秒数（0-10）。
  final int intervalSeconds;

  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<int> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 图标 / 标题随开关状态变色：开启高亮 primary，关闭弱化 onSurfaceVariant
    final accent = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 紧凑主开关行：整行可点切换开关
        InkWell(
          onTap: () => onEnabledChanged(!enabled),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onEnabledChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
        // 子设置：开启后展开
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: enabled
              ? Column(
                  children: [
                    // 重复次数：1-10 + ∞（末位）
                    _LabeledSliderRow(
                      label: l10n.repeatCount,
                      sliderValue: _countToSlider(count),
                      min: 1,
                      max: 11,
                      divisions: 10,
                      valueLabel: _countLabel(l10n, count),
                      onChanged: (pos) => onCountChanged(_sliderToCount(pos)),
                    ),
                    // 间隔时长：0-10 秒（值列用紧凑单位 Ns 表达，label 不带单位）
                    _LabeledSliderRow(
                      label: l10n.intervalTime,
                      sliderValue: intervalSeconds.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      valueLabel: '${intervalSeconds}s',
                      a11yLabel: '$intervalSeconds ${l10n.seconds}',
                      onChanged: (v) => onIntervalChanged(v.round()),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// 次数模型值 → 滑块位置：∞(0) 放最右端 11。
  static double _countToSlider(int count) => count == 0 ? 11 : count.toDouble();

  /// 滑块位置 → 次数模型值：11=∞(0)。
  static int _sliderToCount(double pos) => pos >= 11 ? 0 : pos.round();

  /// 次数显示文案：∞ 或「N 次」。
  static String _countLabel(AppLocalizations l10n, int count) =>
      count == 0 ? '∞' : '$count ${l10n.times}';
}

/// 紧凑的「标签 + 滑条 + 当前值」单行组件。
class _LabeledSliderRow extends StatelessWidget {
  const _LabeledSliderRow({
    required this.label,
    required this.sliderValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    this.a11yLabel,
  });

  final String label;
  final double sliderValue;
  final double min;
  final double max;
  final int divisions;

  /// 右侧及拖动气泡显示的当前值文案。
  final String valueLabel;

  /// 无障碍朗读用的完整文案（如「2 秒」）；为空时回退到 [valueLabel]。
  final String? a11yLabel;

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: sliderValue.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
              semanticFormatterCallback: (_) => a11yLabel ?? valueLabel,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            valueLabel,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
