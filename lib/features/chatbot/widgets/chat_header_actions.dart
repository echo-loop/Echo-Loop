/// 载体 header 共用操作：清空对话 / 重新生成。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../models/chat_role.dart';
import '../models/chatbot_config.dart';
import '../providers/chat_session_controller.dart';

/// new-chat 图标资源路径。
const String _iconNewChat = 'assets/icon/chat/new-chat.svg';

/// 新建会话按钮：清空在途与历史，回到初始态（复用 controller.clear）。
///
/// 非流式时可用；流式中禁用（避免误触打断在途回答）。空会话时点击是无害 no-op，
/// 保持按钮可见即可，不再灰置以免被误认为「没显示」。
class ChatNewChatButton extends ConsumerWidget {
  const ChatNewChatButton({super.key, required this.config});

  final ChatbotConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = chatSessionControllerProvider(config);
    final notifier = ref.read(provider.notifier);

    // 仅 select 需要的派生位，避免流式帧触发本组件重建。
    final isStreaming = ref.watch(provider.select((s) => s.isStreaming));
    final scheme = Theme.of(context).colorScheme;
    // 跟随主题：可用态用 onSurface，禁用态用低透明度，深浅主题都可见。
    final color = isStreaming
        ? scheme.onSurface.withValues(alpha: 0.38)
        : scheme.onSurface;

    return IconButton(
      tooltip: l10n.chatNewChat,
      onPressed: isStreaming ? null : notifier.clear,
      icon: SvgPicture.asset(
        _iconNewChat,
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

/// 溢出菜单：清空对话（clear）+ 重新生成末轮（retry）。
///
/// 供 bottom sheet header 与全屏页 AppBar 共用。菜单项按状态启用：
/// - 清空：有消息且非流式时可用；
/// - 重新生成：存在 user 消息且非流式时可用（复用 controller.retry 走同一闸门）。
class ChatHeaderActions extends ConsumerWidget {
  const ChatHeaderActions({super.key, required this.config});

  final ChatbotConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = chatSessionControllerProvider(config);
    final notifier = ref.read(provider.notifier);

    // 仅 select 需要的派生位，避免流式帧触发本组件重建。
    final canAct = ref.watch(
      provider.select(
        (s) => !s.isStreaming && s.messages.any((m) => m.role == ChatRole.user),
      ),
    );
    final hasMessages = ref.watch(
      provider.select((s) => s.messages.isNotEmpty),
    );

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'clear') notifier.clear();
        if (value == 'regenerate') notifier.retry();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'regenerate',
          enabled: canAct,
          child: Row(
            children: [
              const Icon(Icons.refresh, size: 18),
              const SizedBox(width: 8),
              Text(l10n.chatRegenerate),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'clear',
          enabled: hasMessages && canAct,
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18),
              const SizedBox(width: 8),
              Text(l10n.chatClear),
            ],
          ),
        ),
      ],
    );
  }
}
