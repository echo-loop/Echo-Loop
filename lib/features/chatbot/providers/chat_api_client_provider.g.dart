// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_api_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatApiClientHash() => r'd62687865b98c6d110d23357427be2fdd75dabbf';

/// ChatApi 单例（keepAlive）。
///
/// kChatbotUseFakeApi=true（仅 debug 联调用）时返回假实现；否则构造真实网络客户端。
///
/// Copied from [chatApiClient].
@ProviderFor(chatApiClient)
final chatApiClientProvider = Provider<ChatApi>.internal(
  chatApiClient,
  name: r'chatApiClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatApiClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChatApiClientRef = ProviderRef<ChatApi>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
