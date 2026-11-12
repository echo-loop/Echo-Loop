/// 段落内容可见性菜单
///
/// 目前用于段落复述页面的文本可见性切换。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/retell_settings.dart';

/// 段落内容可见性菜单
class ParagraphVisibilityControls extends StatelessWidget {
  final RetellDisplayMode selectedMode;
  final ValueChanged<RetellDisplayMode> onChanged;

  /// 看译文模式：三档为「隐藏 / 译文 / 原文」。
  ///
  /// 译文复用 [RetellDisplayMode.keywordsOnly]（提示档）：复述阶段系统自动切到
  /// 提示档时，看英文显示可见词，看译文显示译文。
  final bool isTranslationPrompt;

  const ParagraphVisibilityControls({
    super.key,
    required this.selectedMode,
    required this.onChanged,
    this.isTranslationPrompt = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hideSegment = ButtonSegment(
      value: RetellDisplayMode.hideAll,
      label: _ParagraphVisibilitySegmentLabel(
        text: isTranslationPrompt
            ? l10n.retellDisplayHide
            : l10n.retellDisplayHideAll,
      ),
    );
    return SegmentedButton<RetellDisplayMode>(
      showSelectedIcon: false,
      // 看译文文案仅两个字，默认内边距下按钮偏窄不好点，加宽横向内边距。
      style: isTranslationPrompt
          ? SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24),
            )
          : null,
      segments: isTranslationPrompt
          ? [
              hideSegment,
              ButtonSegment(
                value: RetellDisplayMode.keywordsOnly,
                label: _ParagraphVisibilitySegmentLabel(
                  text: l10n.retellDisplayTranslation,
                ),
              ),
              ButtonSegment(
                value: RetellDisplayMode.showAll,
                label: _ParagraphVisibilitySegmentLabel(
                  text: l10n.retellDisplayOriginal,
                ),
              ),
            ]
          : [
              hideSegment,
              ButtonSegment(
                value: RetellDisplayMode.keywordsOnly,
                label: _ParagraphVisibilitySegmentLabel(
                  text: l10n.retellDisplayKeywordsOnly,
                ),
              ),
              ButtonSegment(
                value: RetellDisplayMode.showAll,
                label: _ParagraphVisibilitySegmentLabel(
                  text: l10n.retellDisplayShowAll,
                ),
              ),
            ],
      selected: {selectedMode},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}

class _ParagraphVisibilitySegmentLabel extends StatelessWidget {
  final String text;

  const _ParagraphVisibilitySegmentLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}
