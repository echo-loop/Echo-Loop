/// 词典源切换器（弹窗右上角下拉 chip）+ AI 源快捷按钮
///
/// [SourceSwitcher]：显示当前源「图标 + 名称 + ▾」，点击弹出菜单列出
/// 除 AI 外的「可见」源；菜单项含图标、名称、默认徽章、当前选中勾。
/// AI 源被提升为独立的 [AiSourceButton]（紫色，放在切换器左侧），
/// 一键直达，不再混在下拉菜单里。两者共用同一选中状态。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/dictionary/dictionary_settings_provider.dart';
import '../../providers/dictionary/visible_sources_provider.dart';
import '../../services/dictionary/dictionary_source.dart';
import 'dict_source_presentation.dart';

/// 词典源切换器
class SourceSwitcher extends ConsumerWidget {
  /// 当前选中源 id
  final String selectedId;

  /// 选择回调
  final ValueChanged<String> onSelected;

  const SourceSwitcher({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // AI 源已独立成 [AiSourceButton]，下拉菜单只保留其余源
    final visible = ref
        .watch(visibleDictionarySourcesProvider)
        .where((s) => s.id != 'ai')
        .toList(growable: false);
    final defaultId = ref.watch(
      dictionarySettingsProvider.select((s) => s.defaultSourceId),
    );
    if (visible.isEmpty) return const SizedBox.shrink();

    // chip 显示的源：当前选中（非 AI）；选中 AI 时退回默认源（再到第一个）
    final selected = visible.firstWhere(
      (s) => s.id == selectedId,
      orElse: () => visible.firstWhere(
        (s) => s.id == defaultId,
        orElse: () => visible.first,
      ),
    );
    // 选中的是下拉里的某个源时，chip 高亮（与 AI 按钮选中态对称，让用户知道当前选了哪个）
    final highlighted = selectedId != 'ai';

    final label = l10n.dictSwitcherSemantics(
      dictSourceLabel(l10n, selected.id),
    );

    // 选中 AI 时：点 chip 直接切到其显示的源（无需先展开菜单）；
    // 已在某个下拉源上时：点 chip 才展开菜单换源。
    if (!highlighted) {
      return Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelected(selected.id),
            child: _Chip(source: selected, highlighted: false),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: label,
      child: PopupMenuButton<String>(
        tooltip: '',
        position: PopupMenuPosition.under,
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final s in visible)
            PopupMenuItem<String>(
              value: s.id,
              child: _MenuRow(
                // 用真实 selectedId 判定：选中 AI（独立按钮）时菜单内无勾选
                source: s,
                isSelected: s.id == selectedId,
                isDefault: s.id == defaultId,
              ),
            ),
        ],
        child: _Chip(source: selected, highlighted: true),
      ),
    );
  }
}

/// AI 源快捷按钮（紫色 chip，提到下拉菜单外，左侧一键直达）
///
/// 仅当 AI 源「可见」（未在设置中禁用）时渲染；选中时高亮填充。
/// 与 [SourceSwitcher] 共用 [selectedId] / [onSelected]。
class AiSourceButton extends ConsumerWidget {
  /// 当前选中源 id
  final String selectedId;

  /// 选择回调
  final ValueChanged<String> onSelected;

  const AiSourceButton({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  /// AI 品牌强调色（与句子标注卡片的 AI 配色一致）
  static const Color _accent = Color(0xFFAB47BC); // Colors.purple.shade400

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final visible = ref.watch(visibleDictionarySourcesProvider);
    if (!visible.any((s) => s.id == 'ai')) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = selectedId == 'ai';
    // 未选中：与切换器一致的中性底（仅用紫色字/图标作 AI 标识）
    // 选中：覆盖一层柔和紫色底，区分但不刺眼
    final neutralBg = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      selected: isSelected,
      label: dictSourceLabel(l10n, 'ai'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSelected('ai'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accent.withValues(alpha: isDark ? 0.28 : 0.14)
                  : neutralBg,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: _accent.withValues(alpha: 0.45))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: _accent),
                const SizedBox(width: 5),
                Text(
                  'AI',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 切换器 chip 本体
class _Chip extends StatelessWidget {
  final DictionarySource source;

  /// 高亮态：当前选中的就是下拉里的这个源（加主色边框 + 主色字标识）
  final bool highlighted;

  const _Chip({required this.source, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final neutralBg = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final fg = highlighted ? primary : theme.colorScheme.onSurface;
    final fgVariant = highlighted
        ? primary
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: highlighted
            ? primary.withValues(alpha: isDark ? 0.24 : 0.10)
            : neutralBg,
        borderRadius: BorderRadius.circular(16),
        border: highlighted
            ? Border.all(color: primary.withValues(alpha: 0.45))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(source.icon, size: 16, color: fgVariant),
          const SizedBox(width: 6),
          Text(
            dictSourceLabel(l10n, source.id),
            style: theme.textTheme.titleSmall?.copyWith(color: fg),
          ),
          Icon(Icons.expand_more, size: 18, color: fgVariant),
        ],
      ),
    );
  }
}

/// 菜单项：图标 + 名称 + 默认徽章 + 选中勾
class _MenuRow extends StatelessWidget {
  final DictionarySource source;
  final bool isSelected;
  final bool isDefault;
  const _MenuRow({
    required this.source,
    required this.isSelected,
    required this.isDefault,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        // 图标用各源品牌色，与设置页列表保持一致，便于区分
        Icon(
          source.icon,
          size: 20,
          color: dictSourceColor(theme.colorScheme, source.id),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            dictSourceLabel(l10n, source.id),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (isDefault) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              l10n.dictDefaultBadge,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (isSelected)
          Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
        else
          const SizedBox(width: 18),
      ],
    );
  }
}
