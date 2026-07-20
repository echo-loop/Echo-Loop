/// 全屏聊天页壳（第二载体，与 sheet 共用同一 ChatView）。
library;

import 'package:flutter/material.dart';

import '../models/chatbot_config.dart';
import '../widgets/chat_header_actions.dart';
import '../widgets/chat_view.dart';

/// 全屏聊天页壳。走嵌套子路由（§7.17）时由入口以 config 作 extra push。
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.config});

  final ChatbotConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 与 ChatView / composer 同底色（scheme.surface）：全屏页背景不再是纯黑，
      // 与近黑底栏无接缝，明暗两套一致（对齐 sheet 载体）。
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(config.title),
        actions: [ChatHeaderActions(config: config)],
      ),
      // 键盘避让由 Scaffold.resizeToAvoidBottomInset 处理，与 sheet 行为一致。
      body: SafeArea(child: ChatView(config: config)),
    );
  }
}
