// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_api_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ChatApi 单例（keepAlive）。
///
/// kChatbotUseFakeApi=true（仅 debug 联调用）时返回假实现；否则构造真实网络客户端。

@ProviderFor(chatApiClient)
final chatApiClientProvider = ChatApiClientProvider._();

/// ChatApi 单例（keepAlive）。
///
/// kChatbotUseFakeApi=true（仅 debug 联调用）时返回假实现；否则构造真实网络客户端。

final class ChatApiClientProvider
    extends $FunctionalProvider<ChatApi, ChatApi, ChatApi>
    with $Provider<ChatApi> {
  /// ChatApi 单例（keepAlive）。
  ///
  /// kChatbotUseFakeApi=true（仅 debug 联调用）时返回假实现；否则构造真实网络客户端。
  ChatApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatApiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatApiClientHash();

  @$internal
  @override
  $ProviderElement<ChatApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatApi create(Ref ref) {
    return chatApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatApi>(value),
    );
  }
}

String _$chatApiClientHash() => r'dd1611b8b601913cb8bda794aea0fb01fb89e404';
