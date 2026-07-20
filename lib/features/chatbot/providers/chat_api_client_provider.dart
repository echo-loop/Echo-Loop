/// ChatApi 单例 provider。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../config/api_config.dart';
import '../../../providers/package_info_provider.dart';
import '../chatbot_flags.dart';
import '../services/chat_api_client.dart';
import '../services/fake_chat_api_client.dart';

part 'chat_api_client_provider.g.dart';

/// ChatApi 单例（keepAlive）。
///
/// kChatbotUseFakeApi=true（仅 debug 联调用）时返回假实现；否则构造真实网络客户端。
@Riverpod(keepAlive: true)
ChatApi chatApiClient(Ref ref) {
  if (kChatbotUseFakeApi) return const FakeChatApiClient();
  final client = ChatApiClient(
    baseUrl: apiBaseUrl,
    appVersion: readAppVersion(ref),
  );
  ref.onDispose(client.dispose);
  return client;
}
