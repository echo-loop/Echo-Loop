/// 完成类对话框共享视觉部件
///
/// 步骤完成（StepCompleteDialog）与自由练习完成（FreePlayCompleteDialog）共用
/// 同一套「成就卡」视觉：顶部英雄区（柔和色带 + 圆形勾选徽章 + 居中标题/副标题）
/// 与高亮统计 chip。抽到此处统一维护，避免两份重复、保证观感一致。
library;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../theme/app_theme.dart';
import '../common/dot_lottie_decoder.dart';

/// 单条完成统计项
///
/// [value] 高亮显示的数字（如 "9"），[label] 下方的短标签（如 "句子"）。
typedef CompletionStat = ({String value, String label});

const _doneCheckAnimationAsset = 'assets/animation/done-check.lottie';

/// 完成对话框顶部英雄区
///
/// 柔和色带背景上居中放置完成动画（强化「完成」瞬间）、
/// 居中标题与可选副标题（如步骤进度）。
/// 全部走 [ColorScheme]，亮/暗/AMOLED 自适应。
class CompletionHeroHeader extends StatelessWidget {
  /// 主标题
  final String title;

  /// 副标题（可选，如步骤进度文案）
  final String? subtitle;

  const CompletionHeroHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    // 完成态用语义绿，强化「成功」感；深色（AMOLED）下降低色带不透明度柔和浮起
    final headerBg = isLight
        ? AppTheme.successContainer
        : AppTheme.successColor.withValues(alpha: 0.22);

    return Container(
      width: double.infinity,
      color: headerBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 完成动画循环播放，持续强化完成状态。
          Lottie.asset(
            _doneCheckAnimationAsset,
            key: const Key('completion-dialog-done-check'),
            decoder: decodeDotLottieAnimation,
            repeat: true,
            animate: true,
            width: 160,
            height: 160,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: AppSpacing.s),
          // 标题（居中）
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          // 副标题（居中）
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 统计 chip 行
///
/// 每项一张高亮卡片均分宽度，数字大、品牌蓝。
class CompletionStatsRow extends StatelessWidget {
  /// 统计项列表（至少一项）
  final List<CompletionStat> stats;

  const CompletionStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) children.add(const SizedBox(width: AppSpacing.s));
      children.add(Expanded(child: _StatChip(stat: stats[i])));
    }
    return Row(children: children);
  }
}

/// 单个统计 chip：上方大号品牌蓝数字，下方灰色标签
class _StatChip extends StatelessWidget {
  /// 统计项数据
  final CompletionStat stat;

  const _StatChip({required this.stat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.m,
        horizontal: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        // 深色（纯黑）下加 1px 描边区分卡片边界，与 cardTheme 暗色约定一致
        border: isLight ? null : Border.all(color: cs.outlineVariant, width: 1),
      ),
      // 合并朗读为「9 句子」，避免数字和标签被拆成两次
      child: Semantics(
        label: '${stat.value} ${stat.label}',
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stat.value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                stat.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
