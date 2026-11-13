import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/learning_progress_colors.dart';
import '../domain/account_usage.dart';
import '../providers/account_usage_provider.dart';

/// 账户用量页：以进度条展示本月各功能的已用比例。
///
/// 只展示百分比，不展示原始 used/limit，避免把后端的计量单位细节暴露给用户。
class AccountUsageScreen extends ConsumerWidget {
  const AccountUsageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final usageAsync = ref.watch(accountUsageProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.usageTitle)),
      body: SafeArea(
        child: usageAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _UsageLoadError(
            onRetry: () => ref.invalidate(accountUsageProvider),
          ),
          data: (usage) => usage == null
              ? const SizedBox.shrink()
              : _UsageContent(usage: usage),
        ),
      ),
    );
  }
}

class _UsageLoadError extends StatelessWidget {
  const _UsageLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: TextButton(onPressed: onRetry, child: Text(l10n.usageLoadFailed)),
    );
  }
}

class _UsageContent extends StatelessWidget {
  const _UsageContent({required this.usage});

  final AccountUsage usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final featureRows = <Widget>[];
    for (final feature in UsageFeature.values) {
      final featureUsage = usage.features[feature];
      if (featureUsage == null) continue;
      if (featureRows.isNotEmpty) {
        featureRows.add(const SizedBox(height: AppSpacing.m));
      }
      featureRows.add(
        _UsageFeatureRow(
          label: _featureLabel(l10n, feature),
          usage: featureUsage,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            _UsageSummaryCard(usage: usage),
            const SizedBox(height: AppSpacing.l),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: featureRows,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _featureLabel(AppLocalizations l10n, UsageFeature feature) {
    return switch (feature) {
      UsageFeature.dictionary => l10n.usageFeatureDictionary,
      UsageFeature.translate => l10n.usageFeatureTranslate,
      UsageFeature.analyze => l10n.usageFeatureAnalyze,
      UsageFeature.senseGroups => l10n.usageFeatureSenseGroups,
      UsageFeature.transcription => l10n.usageFeatureTranscription,
      UsageFeature.chat => l10n.usageFeatureChat,
      UsageFeature.retellReview => l10n.usageFeatureRetellReview,
      UsageFeature.tts => l10n.usageFeatureTts,
    };
  }
}

/// 套餐、计费周期与重置时间。
///
/// 层级：套餐名最醒目，周期次之，重置时间作为补充信息弱化。
class _UsageSummaryCard extends StatelessWidget {
  const _UsageSummaryCard({required this.usage});

  final AccountUsage usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final planLabel = switch (usage.plan) {
      'free' => l10n.usagePlanFree,
      'paid' => l10n.premiumTitle,
      _ => usage.plan,
    };
    final monthLabel = DateFormat.yMMMM(locale).format(usage.periodStart);
    final resetDate = DateFormat.MMMd(locale).format(usage.resetAt.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              planLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.usageMonthlyQuota(monthLabel),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.usageResetsOn(resetDate),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个功能的用量行，一行排布：名称 · 进度条 · 百分比。
///
/// 名称与数值列固定宽度，使各行进度条的起点与终点对齐。
/// 不限量没有进度条，只显示弱化的文字。
/// 颜色随用量递进：常规时数值弱化、进度条用主题蓝 → 接近额度变橙 → 已用完变错误色。
class _UsageFeatureRow extends StatelessWidget {
  const _UsageFeatureRow({required this.label, required this.usage});

  /// 进度条达到该百分比时切换为提醒色。
  static const _nearLimitPercent = 80;
  static const _labelWidth = 128.0;
  static const _valueWidth = 64.0;

  final String label;
  final FeatureUsage usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = learningProgressPalette(theme.brightness);
    final percent = usage.percent;
    final mutedColor = scheme.onSurfaceVariant;

    // 用完时同样显示 100%，只用颜色表达状态。
    final String valueLabel;
    final Color valueColor;
    final FontWeight valueWeight;
    final Color barColor;
    if (percent == null) {
      valueLabel = l10n.usageUnlimited;
      valueColor = mutedColor;
      valueWeight = FontWeight.w400;
      barColor = palette.active;
    } else if (usage.isExhausted) {
      valueLabel = l10n.usagePercentLabel(percent.toString());
      valueColor = scheme.error;
      valueWeight = FontWeight.w600;
      barColor = scheme.error;
    } else if (percent >= _nearLimitPercent) {
      valueLabel = l10n.usagePercentLabel(percent.toString());
      valueColor = _nearLimitColor(theme.brightness);
      valueWeight = FontWeight.w600;
      barColor = valueColor;
    } else {
      valueLabel = l10n.usagePercentLabel(percent.toString());
      valueColor = mutedColor;
      valueWeight = FontWeight.w500;
      barColor = palette.active;
    }

    // 合并为一个语义节点，读屏时读出「名称 + 百分比」。
    // 不设置 LinearProgressIndicator 的 semanticsValue：Flutter 会把它当作数值解析，
    // 百分比为 100 时也会触发断言。
    return MergeSemantics(
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            // 英文长标签允许换行到两行，避免被省略号遮住语义。
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: percent == null
                ? const SizedBox.shrink()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 4,
                      color: barColor,
                      backgroundColor: palette.track,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.s),
          SizedBox(
            width: _valueWidth,
            child: Text(
              valueLabel,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: valueColor,
                fontWeight: valueWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _nearLimitColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? Colors.orange.shade300
        : Colors.orange.shade800;
  }
}
