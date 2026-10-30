/// 字幕句子的长按／右键菜单，只返回用户选择，不执行播放或收藏副作用。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'sentence_action_icons.dart';

/// 整句菜单支持的操作；收藏选项的名称由调用方当前状态决定。
enum SentenceContextAction { copy, toggleBookmark, explain }

/// 在触发位置显示整句菜单，复用应用现有文本菜单的视觉样式。
Future<SentenceContextAction?> showSentenceContextMenu({
  required BuildContext context,
  required Offset position,
  required bool isBookmarked,
  required bool canToggleBookmark,
  required bool canExplain,
}) {
  final l10n = AppLocalizations.of(context);
  final overlay = Overlay.of(context).context.findRenderObject();
  if (l10n == null || overlay is! RenderBox) return Future.value();
  final theme = Theme.of(context);

  PopupMenuItem<SentenceContextAction> item(
    SentenceContextAction action,
    String label,
    Widget icon, {
    bool enabled = true,
  }) => PopupMenuItem(
    key: ValueKey('sentence-menu-${action.name}'),
    value: action,
    enabled: enabled,
    height: 44,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [icon, const SizedBox(width: 10), Text(label)],
    ),
  );

  return showMenu<SentenceContextAction>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    ),
    elevation: 3,
    shadowColor: Colors.black.withValues(alpha: 0.15),
    surfaceTintColor: Colors.transparent,
    color: theme.colorScheme.surface,
    items: [
      item(
        SentenceContextAction.copy,
        l10n.copy,
        Icon(
          Icons.copy_rounded,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      item(
        SentenceContextAction.toggleBookmark,
        isBookmarked ? l10n.sentenceMenuUnsave : l10n.sentenceMenuSave,
        SentenceBookmarkIcon(isBookmarked: isBookmarked),
        enabled: canToggleBookmark,
      ),
      item(
        SentenceContextAction.explain,
        l10n.sentenceMenuExplain,
        const SentenceExplanationIcon(),
        enabled: canExplain,
      ),
    ],
  );
}
