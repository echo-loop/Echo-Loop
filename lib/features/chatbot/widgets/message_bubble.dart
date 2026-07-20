/// 单条聊天气泡。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../models/chat_message.dart';
import '../models/chat_role.dart';
import 'selectable_assistant_markdown.dart';

/// 操作栏 SVG 图标资源路径（复刻 ChatGPT 线条风格）。
const String _iconCopy = 'assets/icon/chat/copy.svg';
const String _iconCheck = 'assets/icon/chat/check.svg';
const String _iconEdit = 'assets/icon/chat/edit.svg';
const String _iconRegenerate = 'assets/icon/chat/regenerate.svg';

/// 引用指向图标（右转箭头 SVG），与引用条统一。
const String _iconQuote = 'assets/icon/chat/arrow-right-turn.svg';

/// 单条气泡：user 右对齐纯文本气泡；assistant 左对齐 MarkdownMessage。
/// - streaming 且 content 为空 → 显示「思考中」动画指示（三点跳动）；
/// - error → 气泡内 inline 重试入口（onRetry）；
/// - quotaBlocked → 气泡内 inline 升级入口（onUpgrade → openPaywall）；
/// - assistant done 态气泡下方常驻操作栏：复制 + 重新生成（左下）；
/// - user 消息无常驻操作栏，长按（桌面右键）弹菜单：复制 + 编辑（编辑打开独立编辑页）；
///   带追问引用时气泡上方显示「↳ + 灰字」引用行；
/// - assistant 内容为可选中 markdown（SelectionArea）：长按起选区、拖拽手柄自由选中
///   任意连续文本（含行内代码），选区上方弹出「复制 / 问 AI」操作条。
///
/// 颜色全部取 Theme/colorScheme（暗色模式适配），禁止硬编码色值。
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onUpgrade,
    this.onCopy,
    this.onEdit,
    this.onRegenerate,
    this.onFollowUp,
  });

  final ChatMessage message;
  final VoidCallback? onRetry; // 仅 error 态用
  final VoidCallback? onUpgrade; // 仅 quotaBlocked 态用
  final void Function(String content)? onCopy;
  final VoidCallback? onEdit; // 仅 user done 态用
  final VoidCallback? onRegenerate; // 仅 assistant done 态用
  final void Function(String selectedText)? onFollowUp; // 仅 assistant 选区追问用

  bool get _isUser => message.role == ChatRole.user;

  /// 是否显示气泡下方常驻操作栏：仅 assistant 的 done 且内容非空。
  ///
  /// user 消息不显示常驻操作栏，复制/编辑改为长按弹菜单（[_showMenu]）。
  bool get _showActions =>
      !_isUser &&
      message.status == ChatMessageStatus.done &&
      message.content.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align = _isUser ? Alignment.centerRight : Alignment.centerLeft;
    // ChatGPT 风格：user 浅灰圆角气泡，assistant 无背景纯文本满宽。
    final textColor = scheme.onSurface;
    final width = MediaQuery.sizeOf(context).width;

    return Align(
      alignment: align,
      child: Column(
        crossAxisAlignment: _isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // user 追问：气泡上方显示「↳ + 灰字」引用行（assistant 无引用）。
          if (_isUser && (message.quote?.isNotEmpty ?? false))
            _buildQuoteReference(context, width),
          GestureDetector(
            // user：长按（桌面右键）唤出复制/编辑菜单；
            // assistant：不挂外层长按菜单——长按交给内部 SelectionArea 起选区。
            onLongPressStart: (!_isUser || message.content.isEmpty)
                ? null
                : (details) => _showMenu(context, details.globalPosition),
            onSecondaryTapDown: (!_isUser || message.content.isEmpty)
                ? null
                : (details) => _showMenu(context, details.globalPosition),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              padding: _isUser
                  ? const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    )
                  : EdgeInsets.zero,
              constraints: BoxConstraints(
                maxWidth: _isUser ? width * 0.8 : width,
              ),
              decoration: _isUser
                  ? BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppSpacing.l),
                    )
                  : null,
              child: _buildContent(context, textColor),
            ),
          ),
          if (_showActions) _buildActions(context),
        ],
      ),
    );
  }

  /// user 追问引用行（气泡上方）：↳ 图标紧贴引用文字，整体右对齐（maxLines 2）。
  ///
  /// 宽度约束同气泡（[width] * 0.8）：短内容时「↳ + 文字」贴右成组，长内容时
  /// 文字在图标右侧换行，最多两行、超出省略。
  Widget _buildQuoteReference(BuildContext context, double width) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 2),
      child: SizedBox(
        width: width * 0.8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          // 图标中线对齐文字中线。
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              _iconQuote,
              width: 15,
              height: 15,
              // 图标与文字统一弱化色。
              colorFilter: ColorFilter.mode(muted, BlendMode.srcIn),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                message.quote!,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// assistant 气泡下方常驻操作栏：复制 + 重新生成。
  /// 图标为复刻 ChatGPT 线条风格的 SVG（[_iconCopy] 等），随主题着色。
  Widget _buildActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CopyActionIcon(
            tooltip: l10n.chatCopy,
            color: color,
            onCopy: onCopy == null ? null : () => onCopy!(message.content),
          ),
          const SizedBox(width: AppSpacing.xs),
          _actionIcon(
            asset: _iconRegenerate,
            tooltip: l10n.chatRegenerate,
            color: color,
            onTap: onRegenerate,
          ),
        ],
      ),
    );
  }

  /// 单个操作图标（SVG + 紧凑点击区 + tooltip）。
  Widget _actionIcon({
    required String asset,
    required String tooltip,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.s),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: SvgPicture.asset(
            asset,
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  /// 依据状态与角色渲染气泡主体。
  Widget _buildContent(BuildContext context, Color textColor) {
    if (_isUser) {
      return Text(message.content, style: TextStyle(color: textColor));
    }
    // assistant：streaming 且空 → 思考中动画。
    if (message.status == ChatMessageStatus.streaming &&
        message.content.isEmpty) {
      return _ThinkingIndicator(color: textColor);
    }
    // AI 回答 markdown：官方 SelectionArea 方案，支持长按/拖拽自由选中任意连续文本
    // （含行内代码 `code`），选区上方弹出「复制 / 问 AI」操作条。
    final markdown = SelectableAssistantMarkdown(
      data: message.content,
      style: TextStyle(color: textColor),
      onFollowUp: onFollowUp,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        markdown,
        if (message.status == ChatMessageStatus.error)
          _inlineAction(
            context,
            icon: Icons.refresh,
            label: AppLocalizations.of(context)!.chatErrorGenerate,
            onTap: onRetry,
          ),
        if (message.status == ChatMessageStatus.quotaBlocked)
          _inlineAction(
            context,
            icon: Icons.workspace_premium_outlined,
            label: AppLocalizations.of(context)!.chatUpgrade,
            onTap: onUpgrade,
          ),
      ],
    );
  }

  /// 气泡内 inline 操作按钮（重试 / 升级）。
  Widget _inlineAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.error),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 操作菜单（iOS 风格：文案 + 右侧图标）。触摸端长按、桌面端右键触发，
  /// [globalPosition] 为触发点全局坐标。
  ///
  /// - user：复制 + 编辑（编辑走 [onEdit] → 打开独立编辑页）；
  /// - assistant：复制。
  Future<void> _showMenu(BuildContext context, Offset globalPosition) async {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.onSurface;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlay.size.width - globalPosition.dx,
      overlay.size.height - globalPosition.dy,
    );
    final selected = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: _menuRow(l10n.chatCopy, _iconCopy, color),
        ),
        if (_isUser)
          PopupMenuItem<String>(
            value: 'edit',
            child: _menuRow(l10n.chatEdit, _iconEdit, color),
          ),
      ],
    );
    if (selected == 'copy') onCopy?.call(message.content);
    if (selected == 'edit') onEdit?.call();
  }

  /// 长按菜单单行：左文案、右图标。
  Widget _menuRow(String label, String asset, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        const SizedBox(width: AppSpacing.xl),
        SvgPicture.asset(
          asset,
          width: 18,
          height: 18,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ],
    );
  }
}

/// 「思考中」三点跳动指示。
class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator({required this.color});
  final Color color;

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.chatThinking,
      child: SizedBox(
        height: 16,
        width: 36,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // 三点相位错开，形成波动。
                final t = (_controller.value + i / 3) % 1.0;
                final opacity = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: opacity.clamp(0.3, 1.0),
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: widget.color,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

/// 复制操作图标：点击后复制内容并短暂切换为对号（✓），数秒后恢复复制图标。
///
/// 业界标准的「复制成功」反馈：即时视觉确认，无需额外 toast。
class _CopyActionIcon extends StatefulWidget {
  const _CopyActionIcon({
    required this.tooltip,
    required this.color,
    required this.onCopy,
  });

  final String tooltip;
  final Color color;
  final VoidCallback? onCopy;

  @override
  State<_CopyActionIcon> createState() => _CopyActionIconState();
}

class _CopyActionIconState extends State<_CopyActionIcon> {
  /// 对号显示时长：足够用户看清、又不长期滞留。
  static const Duration _revertDelay = Duration(seconds: 2);

  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 触发复制回调并进入「已复制」态，[_revertDelay] 后自动恢复。
  void _handleTap() {
    widget.onCopy?.call();
    _timer?.cancel();
    setState(() => _copied = true);
    _timer = Timer(_revertDelay, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 已复制态用主题主色的对号，强化成功语义；否则用常规操作色。
    final scheme = Theme.of(context).colorScheme;
    final color = _copied ? scheme.primary : widget.color;
    return Tooltip(
      message: widget.tooltip,
      child: InkWell(
        onTap: widget.onCopy == null ? null : _handleTap,
        borderRadius: BorderRadius.circular(AppSpacing.s),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: SvgPicture.asset(
            _copied ? _iconCheck : _iconCopy,
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
