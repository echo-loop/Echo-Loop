/// 通用聊天视图（载体无关纯组件，双载体共用）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/sign_in_required_dialog.dart';
import '../../subscription/widgets/feature_gate.dart';
import '../models/chatbot_config.dart';
import '../providers/chat_session_controller.dart';
import '../screens/chat_edit_screen.dart';
import 'chat_composer.dart';
import 'chat_gate_banner.dart';
import 'chat_quote_bar.dart';
import 'context_chip.dart';
import 'message_list.dart';

/// 通用聊天视图：可嵌 bottom sheet 或全屏页 body。无 Scaffold。
///
/// 结构：Column[ 可选 ContextChip, Expanded(ChatMessageList), ChatGateBanner, ChatComposer ]
/// 键盘避让：外层用 Padding(MediaQuery.viewInsetsOf) —— 由载体负责，本组件不含。
///
/// 性能：**不 watch 整个 state**（否则每个 delta 帧全树 rebuild）——分别
///   select isStreaming（composer）与 gate（banner）；消息渲染的重建控制在
///   ChatMessageList。
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key, required this.config});

  final ChatbotConfig config;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  ChatbotConfig get config => widget.config;

  /// 待发追问引用（用户点「追问」后暂存；发送/关闭后清空，null = 无引用）。
  String? _pendingQuote;

  /// 输入框焦点（本组件创建并销毁，传给 [ChatComposer]）：点「追问」后
  /// requestFocus 弹键盘。谁创建谁销毁。
  final FocusNode _composerFocusNode = FocusNode();

  @override
  void dispose() {
    _composerFocusNode.dispose();
    super.dispose();
  }

  /// 点「追问」：暂存引用、聚焦输入框弹键盘。
  void _startFollowUp(String selectedText) {
    setState(() => _pendingQuote = selectedText);
    _composerFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final provider = chatSessionControllerProvider(config);
    final notifier = ref.read(provider.notifier);
    final l10n = AppLocalizations.of(context)!;

    final isStreaming = ref.watch(provider.select((s) => s.isStreaming));
    final gate = ref.watch(provider.select((s) => s.gate));

    final summary = config.contextSummary;

    // 整块统一底色（对标 ChatGPT：消息区 = 底栏 = scheme.surface，仅输入 pill /
    // 引用卡片保留边界）。载体（sheet / scaffold）也用 surface，明暗两套皆无接缝。
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          if (summary != null && summary.isNotEmpty)
            ChatContextChip(summary: summary),
          Expanded(
            child: ChatMessageList(
              config: config,
              onRetry: (_) => notifier.retry(),
              onUpgrade: () => openPaywall(context, ref),
              onCopy: (content) => _copy(context, l10n, content),
              onEdit: (messageId) => _handleEdit(notifier, messageId),
              onRegenerate: (messageId) => notifier.regenerate(messageId),
              onFollowUp: _startFollowUp,
            ),
          ),
          ChatGateBanner(
            gate: gate,
            onUpgrade: () => openPaywall(context, ref),
            onSignIn: () => _signIn(context, ref, l10n, notifier),
          ),
          if (_pendingQuote != null)
            ChatQuoteBar(
              quote: _pendingQuote!,
              isStreaming: isStreaming,
              onClose: () => setState(() => _pendingQuote = null),
              onCommand: (command) =>
                  _handleSend(context, ref, l10n, notifier, command),
            ),
          ChatComposer(
            placeholder: config.inputPlaceholder,
            focusNode: _composerFocusNode,
            attachedTop: _pendingQuote != null,
            isStreaming: isStreaming,
            onSend: (text) => _handleSend(context, ref, l10n, notifier, text),
            onStop: notifier.stop,
          ),
        ],
      ),
    );
  }

  /// 修改用户消息：打开独立编辑页，确认发送后才截断该轮并以新文本重发（不分叉）。
  Future<void> _handleEdit(
    ChatSessionController notifier,
    String messageId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final original = notifier.messageContent(messageId);
    if (original == null) return;
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => ChatEditScreen(initialText: original),
      ),
    );
    if (edited == null || !mounted) return; // 关闭编辑页 = 取消，不改会话
    final ok = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.chatSignInTitle,
      message: l10n.chatSignInMessage,
    );
    if (!ok || !mounted) return;
    await notifier.editAndResend(messageId, edited);
  }

  /// 发送前登录拦截（tap site）。带待发引用时随消息发送并清空引用。
  Future<void> _handleSend(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ChatSessionController notifier,
    String text,
  ) async {
    final ok = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.chatSignInTitle,
      message: l10n.chatSignInMessage,
    );
    if (!ok) return;
    final quote = _pendingQuote;
    if (quote != null && mounted) setState(() => _pendingQuote = null);
    await notifier.send(text, quote: quote);
  }

  /// 闸门 banner 的登录入口。
  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ChatSessionController notifier,
  ) async {
    await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.chatSignInTitle,
      message: l10n.chatSignInMessage,
    );
  }

  /// 复制消息内容到剪贴板并提示。
  void _copy(BuildContext context, AppLocalizations l10n, String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.chatCopied)));
  }
}
