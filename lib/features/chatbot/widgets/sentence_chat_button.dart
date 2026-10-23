/// 句子级 AI 助手入口按钮（AppBar action）。
///
/// 各页面和文本选区共用的入口：统一解析字幕上下文、生成会话配置并打开聊天面板。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/audio_sentences_provider.dart';
import '../../remote_config/remote_config.dart';
import '../../remote_config/remote_config_providers.dart';
import '../chatbot_flags.dart';
import '../chatbot_sheet.dart';
import '../models/chatbot_config.dart';
import '../sentence_passage.dart';

/// AI 聊天入口显示规则：编译期开关负责硬停，远程开关负责运行期全球隐藏。
bool shouldShowAiChatAssistantEntry({
  required bool chatbotEnabled,
  required bool remoteEnabled,
}) {
  return chatbotEnabled && remoteEnabled;
}

/// 构造句子级聊天配置；AppBar 与文本选区入口必须复用同一会话身份。
ChatbotConfig sentenceChatbotConfig(
  BuildContext context,
  SentenceChatTarget target, {
  String? passage,
}) {
  final l10n = AppLocalizations.of(context)!;
  final targetText = target.text.trim();
  final trimmedPassage = passage?.trim();
  final normalizedPassage = trimmedPassage == null || trimmedPassage.isEmpty
      ? null
      : trimmedPassage;
  return ChatbotConfig(
    // 来源和目标共同确定会话，保证同一材料跨页面复用且不同来源互相隔离。
    sessionId:
        'sentence:${jsonEncode([target.audioItemId, target.sentenceIndex, targetText, normalizedPassage])}',
    endpoint: '/api/v1/stream/chat/sentence',
    context: {
      'sentence': targetText,
      if (normalizedPassage != null) 'passage': normalizedPassage,
    },
    title: l10n.chatSentenceTitle,
    inputPlaceholder: l10n.chatInputPlaceholder,
    contextSummary: targetText,
  );
}

/// 打开句子级 AI Sheet；[initialQuote] 只进入引用待发送区，不自动提问。
Future<void> showSentenceChatbotSheet({
  required BuildContext context,
  required WidgetRef ref,
  required SentenceChatTarget target,
  String? initialQuote,
}) async {
  final passage = await resolveSentencePassage(
    target: target,
    loadSentences: (audioItemId) =>
        ref.read(audioSentencesProvider(audioItemId).future),
  );
  if (!context.mounted) return;

  await showChatbotSheet(
    context: context,
    config: sentenceChatbotConfig(context, target, passage: passage),
    initialQuote: initialQuote,
  );
}

/// 句子 AI 助手入口按钮。
///
/// 开关关闭或聊天目标为空（句子未就绪）时自隐藏（渲染空 widget），
/// 调用方无需判空。点击时先执行 [onBeforeOpen]（任务页用来暂停自动推进，
/// 语义同各页设置按钮），再以 bottom sheet 打开 chatbot。
class SentenceChatButton extends ConsumerWidget {
  /// 聊天目标及其可选原文来源。
  final SentenceChatTarget target;

  /// 打开面板前回调（可选）：任务页在此暂停自动推进/等待用户。
  final VoidCallback? onBeforeOpen;

  const SentenceChatButton({
    super.key,
    required this.target,
    this.onBeforeOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 发布开关：编译期开关保留硬停能力，remote config 支持全球动态隐藏入口。
    final show = shouldShowAiChatAssistantEntry(
      chatbotEnabled: kChatbotEnabled,
      remoteEnabled: ref.watch(
        remoteFeatureEnabledProvider(RemoteFeature.aiChatAssistant),
      ),
    );
    if (!show || target.text.isEmpty) return const SizedBox.shrink();

    return IconButton(
      // 渐变多色图标，保留原始配色不做 colorFilter 染色。
      icon: SvgPicture.asset(
        'assets/icon/chat/use-ai-chat.svg',
        width: 24,
        height: 24,
      ),
      tooltip: AppLocalizations.of(context)!.chatOpenTooltip,
      onPressed: () {
        onBeforeOpen?.call();
        showSentenceChatbotSheet(context: context, ref: ref, target: target);
      },
    );
  }
}
