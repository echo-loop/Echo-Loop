// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_engine_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mediaBackendFactoryHash() =>
    r'2567ea2c98b41a6954ebee9854613fa1afe4f89a';

/// 测试缝：真实工厂造 MediaKitPlayerBackend，测试 override 注入 fake。
///
/// Copied from [mediaBackendFactory].
@ProviderFor(mediaBackendFactory)
final mediaBackendFactoryProvider =
    Provider<MediaPlayerBackend Function()>.internal(
      mediaBackendFactory,
      name: r'mediaBackendFactoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$mediaBackendFactoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MediaBackendFactoryRef = ProviderRef<MediaPlayerBackend Function()>;
String _$mediaSessionRouterHash() =>
    r'95c17c25348abbebce4bd91204a6a1042263ee16';

/// 测试缝：默认读全局 router，测试 override 成纯 Dart router。
///
/// Copied from [mediaSessionRouter].
@ProviderFor(mediaSessionRouter)
final mediaSessionRouterProvider = Provider<MediaSessionRouter>.internal(
  mediaSessionRouter,
  name: r'mediaSessionRouterProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mediaSessionRouterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MediaSessionRouterRef = ProviderRef<MediaSessionRouter>;
String _$mediaEngineHash() => r'ea4578e2df475795dfd93d6ac99e24efc21a2731';

/// See also [MediaEngine].
@ProviderFor(MediaEngine)
final mediaEngineProvider =
    NotifierProvider<MediaEngine, MediaEngineState>.internal(
      MediaEngine.new,
      name: r'mediaEngineProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$mediaEngineHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MediaEngine = Notifier<MediaEngineState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
