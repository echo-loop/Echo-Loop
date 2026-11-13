/// 收藏复习共用设置面板。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/favorite_review_settings.dart';
import '../../providers/bookmark_review_settings_provider.dart';
import '../../providers/favorite_review_settings_provider.dart';
import '../../theme/app_theme.dart';
import '../common/settings_sheet_scaffold.dart';

enum FavoriteReviewSettingsTask { sentence, vocabulary, favorites }

/// 收藏复习设置面板。
///
/// 设置项直接监听全局 Provider，与其它学习任务设置弹窗保持一致，
/// 使每次更新都能立即反映到当前控件。
class BookmarkReviewSettingsSheet extends ConsumerStatefulWidget {
  const BookmarkReviewSettingsSheet({super.key, required this.task});

  final FavoriteReviewSettingsTask task;

  @override
  ConsumerState<BookmarkReviewSettingsSheet> createState() =>
      _BookmarkReviewSettingsSheetState();
}

class _BookmarkReviewSettingsSheetState
    extends ConsumerState<BookmarkReviewSettingsSheet> {
  /// 折叠区展开态本地跟踪，仅用于控制标题栏置灰，不涉及业务状态。
  late bool _sentenceExpanded =
      widget.task == FavoriteReviewSettingsTask.sentence;
  late bool _vocabularyExpanded =
      widget.task == FavoriteReviewSettingsTask.vocabulary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(favoriteReviewSettingsProvider);
    final notifier = ref.read(favoriteReviewSettingsProvider.notifier);
    final sentenceSettings = ref.watch(bookmarkReviewSettingsProvider);
    final sentenceNotifier = ref.read(bookmarkReviewSettingsProvider.notifier);
    return SettingsSheetScaffold(
      title: l10n.bookmarkReviewSettingsTitle,
      closeButtonKey: const Key('bookmark-review-settings-close'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 设置主体由公共骨架负责滚动，避免标题和关闭按钮离开视口。
          _SettingsGroup(
            title: l10n.bookmarkReviewOrder,
            child: _BookmarkReviewOrderSelector(
              labels: {
                FavoriteReviewOrder.smart: l10n.bookmarkReviewOrderSmart,
                FavoriteReviewOrder.dueAt: l10n.bookmarkReviewOrderDueAt,
                FavoriteReviewOrder.random: l10n.bookmarkReviewOrderRandom,
              },
              selected: settings.order,
              onSelected: (order) =>
                  notifier.update(settings.copyWith(order: order)),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          _SettingsGroup(
            child: Column(
              children: [
                _SettingsSwitch(
                  title: l10n.bookmarkReviewShowNextReviewTime,
                  value: settings.showNextReviewTime,
                  onChanged: (value) => notifier.update(
                    settings.copyWith(showNextReviewTime: value),
                  ),
                ),
                _SettingsSwitch(
                  title: l10n.favoriteReviewAutoPlayFront,
                  value: settings.autoPlayFront,
                  onChanged: (value) =>
                      notifier.update(settings.copyWith(autoPlayFront: value)),
                ),
                _SettingsSwitch(
                  title: l10n.favoriteReviewAutoPlayBack,
                  value: settings.autoPlayBack,
                  onChanged: (value) =>
                      notifier.update(settings.copyWith(autoPlayBack: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          _ReviewDetailSection(
            key: const Key('favorite-review-settings-sentence-section'),
            title: l10n.favoriteReviewSentenceSettings,
            expanded: _sentenceExpanded,
            onExpansionChanged: (expanded) =>
                setState(() => _sentenceExpanded = expanded),
            children: [
              _SettingsSwitch(
                title: l10n.autoShowAiExplanationToggle,
                value: sentenceSettings.autoShowAiExplanation,
                onChanged: (value) => sentenceNotifier.update(
                  sentenceSettings.copyWith(autoShowAiExplanation: value),
                ),
              ),
              if (sentenceSettings.autoShowAiExplanation) ...[
                _AiExplanationSubSwitch(
                  title: l10n.autoShowAiAnalysisToggle,
                  value: sentenceSettings.autoShowAiAnalysis,
                  onChanged: (value) => sentenceNotifier.update(
                    sentenceSettings.copyWith(autoShowAiAnalysis: value),
                  ),
                ),
                _AiExplanationSubSwitch(
                  title: l10n.autoShowAiTranslationToggle,
                  value: sentenceSettings.autoShowAiTranslation,
                  onChanged: (value) => sentenceNotifier.update(
                    sentenceSettings.copyWith(autoShowAiTranslation: value),
                  ),
                ),
                _AiExplanationSubSwitch(
                  title: l10n.autoShowAiSenseGroupsToggle,
                  value: sentenceSettings.autoShowAiSenseGroups,
                  onChanged: (value) => sentenceNotifier.update(
                    sentenceSettings.copyWith(autoShowAiSenseGroups: value),
                  ),
                ),
              ],
            ],
          ),
          // 仅在两个不同复习类型之间保留轻分隔，避免无边界的连续列表。
          const Divider(height: AppSpacing.l),
          _ReviewDetailSection(
            key: const Key('favorite-review-settings-vocabulary-section'),
            title: l10n.favoriteReviewVocabularySettings,
            expanded: _vocabularyExpanded,
            onExpansionChanged: (expanded) =>
                setState(() => _vocabularyExpanded = expanded),
            children: [
              _SettingsSwitch(
                title: l10n.autoShowAiExplanationToggle,
                value: settings.autoShowAiLookup,
                onChanged: (value) =>
                    notifier.update(settings.copyWith(autoShowAiLookup: value)),
              ),
              _SettingsSwitch(
                key: const Key('favorite-review-show-vocabulary-on-front'),
                title: l10n.favoriteReviewShowVocabularyOnFront,
                value: settings.showVocabularyOnFront,
                onChanged: (value) => notifier.update(
                  settings.copyWith(showVocabularyOnFront: value),
                ),
              ),
              _SettingsSwitch(
                key: const Key('favorite-review-show-word-definition-on-front'),
                title: l10n.favoriteReviewShowWordDefinitionOnFront,
                subtitle: l10n.favoriteReviewShowWordDefinitionOnFrontHint,
                value: settings.showWordDefinitionOnFront,
                onChanged: (value) => notifier.update(
                  settings.copyWith(showWordDefinitionOnFront: value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 无卡片边框的紧凑设置区；可选标题按普通设置字段呈现。
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          // “复习顺序”与开关同属普通字段，复用 ListTile 标题的正文层级。
          Text(title!, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.s),
        ],
        child,
      ],
    );
  }
}

/// 复习类型的专属设置使用原生 [ExpansionTile] 承载标题与内容，
/// 展开时不再依赖标题外的条件渲染，保持语义与可访问性一致。
class _ReviewDetailSection extends StatelessWidget {
  const _ReviewDetailSection({
    super.key,
    required this.title,
    required this.expanded,
    required this.onExpansionChanged,
    required this.children,
  });

  final String title;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      initiallyExpanded: expanded,
      onExpansionChanged: onExpansionChanged,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: theme.colorScheme.onSurfaceVariant,
      collapsedIconColor: theme.colorScheme.onSurfaceVariant,
      title: Text(title, style: AppTextStyles.sectionHeader(context)),
      children: children,
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// 标题下方的补充说明，如适用范围；为空时不占位。
  final String? subtitle;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    title: Text(title),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.7),
            ),
          ),
    value: value,
    onChanged: onChanged,
  );
}

class _AiExplanationSubSwitch extends StatelessWidget {
  const _AiExplanationSubSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.only(
      left: AppSpacing.l,
      right: AppSpacing.xs,
    ),
    title: Text(title),
    value: value,
    onChanged: onChanged,
  );
}

/// 复习顺序单选控件按当前本地化文案的实际宽度分配分段比例。
class _BookmarkReviewOrderSelector extends StatelessWidget {
  const _BookmarkReviewOrderSelector({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final Map<FavoriteReviewOrder, String> labels;
  final FavoriteReviewOrder selected;
  final ValueChanged<FavoriteReviewOrder> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final weights = _segmentWeights(
      context,
      labels.values.toList(growable: false),
      textStyle,
    );
    final colorScheme = theme.colorScheme;
    final borderColor = colorScheme.outline;

    return Semantics(
      label: AppLocalizations.of(context)!.bookmarkReviewOrder,
      child: Stack(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(
                    flex: weights[index],
                    child: _BookmarkReviewOrderSegment(
                      key: Key(
                        'bookmark-review-order-${labels.keys.elementAt(index).name}',
                      ),
                      label: labels.values.elementAt(index),
                      isSelected: selected == labels.keys.elementAt(index),
                      textStyle: textStyle,
                      dividerColor: index == 0 ? null : borderColor,
                      selectedColor: colorScheme.secondaryContainer,
                      onTap: () => onSelected(labels.keys.elementAt(index)),
                    ),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 文本宽度加统一水平内边距，保证各段随文案和字体缩放变化。
  List<int> _segmentWeights(
    BuildContext context,
    List<String> labels,
    TextStyle? textStyle,
  ) => [
    for (final label in labels)
      ((TextPainter(
                text: TextSpan(text: label, style: textStyle),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout()).width +
              48)
          .round(),
  ];
}

class _BookmarkReviewOrderSegment extends StatelessWidget {
  const _BookmarkReviewOrderSegment({
    super.key,
    required this.label,
    required this.isSelected,
    required this.textStyle,
    required this.dividerColor,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final TextStyle? textStyle;
  final Color? dividerColor;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: isSelected,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected ? selectedColor : Colors.transparent,
        border: dividerColor == null
            ? null
            : Border(left: BorderSide(color: dividerColor!)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(child: Text(label, style: textStyle, softWrap: false)),
      ),
    ),
  );
}
