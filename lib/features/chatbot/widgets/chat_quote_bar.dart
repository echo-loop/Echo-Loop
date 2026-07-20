/// 追问引用条：输入框上方显示被引用文本 + 快捷指令 chips。
///
/// 用户点「追问」后出现：展示选中文本（可关闭），并提供一排常用快捷指令
/// （详细解释 / 翻译 / 举个例子），点击即以该指令带引用发送；用户也可直接在
/// 输入框输入问题（引用同样随发送带上）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// 引用指向图标（右转箭头 SVG）。
const String _iconQuote = 'assets/icon/chat/arrow-right-turn.svg';

/// 追问引用条（纯展示 + 回调，不含业务）。
///
/// - [quote]：被引用的原文；
/// - [isStreaming]：流式生成中 → chips 禁用；
/// - [onClose]：关闭引用条（清除待发引用）；
/// - [onCommand]：点某个快捷指令，回调该指令文案（作为发送内容）。
class ChatQuoteBar extends StatelessWidget {
  const ChatQuoteBar({
    super.key,
    required this.quote,
    required this.isStreaming,
    required this.onClose,
    required this.onCommand,
  });

  final String quote;
  final bool isStreaming;
  final VoidCallback onClose;
  final void Function(String command) onCommand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 引用区底色回到原样（亮=浅中性灰 0xFFF3F4F6，暗=略深一档灰）。
    final quoteBg = isDark
        ? scheme.surfaceContainerHighest
        : const Color(0xFFF3F4F6);
    // 外边框：与输入框同色、同弱化透明度，衔接成完整卡片轮廓（暗色不描边）。引用区
    // 底边与下方输入框顶边同位重叠 → 天然一条 1px 细线，平滑过度、无缝相连。
    final cardBorder = isDark
        ? Colors.transparent
        : scheme.outlineVariant.withValues(alpha: 0.35);
    final commands = [
      l10n.chatFollowUpExplain,
      l10n.chatFollowUpTranslate,
      l10n.chatFollowUpExample,
    ];
    // 与输入框同宽（左右留 AppSpacing.m），圆角卡片，读作输入区上方的同族卡片。
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.m,
        right: AppSpacing.m,
        top: AppSpacing.s,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: quoteBg,
          // 只保留上方两角圆角，底部平直，与下方输入框无缝衔接成同一块。
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.l),
          ),
          // 均匀外框衔接输入框轮廓（非均匀 border 与 borderRadius 冲突会断言崩溃）。
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQuoteRow(context, scheme, l10n),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.xs,
              children: [
                for (final c in commands) _buildCommandChip(context, scheme, c),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 引用行：左侧引用图标 + 引用文本（maxLines 2）+ 右侧关闭按钮。
  Widget _buildQuoteRow(
    BuildContext context,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    // 图标与文字统一弱化色，且垂直居中对齐（图标中线对齐文字中线）。
    final muted = scheme.onSurfaceVariant.withValues(alpha: 0.6);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          _iconQuote,
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(muted, BlendMode.srcIn),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            quote,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(context).copyWith(color: muted),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(AppSpacing.s),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.close,
              size: 16,
              color: scheme.onSurfaceVariant,
              semanticLabel: l10n.chatQuoteRemove,
            ),
          ),
        ),
      ],
    );
  }

  /// 快捷指令 chip：点击即以该指令发送；流式中禁用。
  Widget _buildCommandChip(
    BuildContext context,
    ColorScheme scheme,
    String label,
  ) {
    final enabled = !isStreaming;
    final fg = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.35);
    return Material(
      color: scheme.surface,
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => onCommand(label) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            label,
            style: AppTextStyles.caption(context).copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}
