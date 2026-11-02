// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_engine_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 测试缝：真实工厂造 MediaKitPlayerBackend，测试 override 注入 fake。

@ProviderFor(mediaBackendFactory)
final mediaBackendFactoryProvider = MediaBackendFactoryProvider._();

/// 测试缝：真实工厂造 MediaKitPlayerBackend，测试 override 注入 fake。

final class MediaBackendFactoryProvider
    extends
        $FunctionalProvider<
          MediaPlayerBackend Function(),
          MediaPlayerBackend Function(),
          MediaPlayerBackend Function()
        >
    with $Provider<MediaPlayerBackend Function()> {
  /// 测试缝：真实工厂造 MediaKitPlayerBackend，测试 override 注入 fake。
  MediaBackendFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaBackendFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaBackendFactoryHash();

  @$internal
  @override
  $ProviderElement<MediaPlayerBackend Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaPlayerBackend Function() create(Ref ref) {
    return mediaBackendFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaPlayerBackend Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaPlayerBackend Function()>(
        value,
      ),
    );
  }
}

String _$mediaBackendFactoryHash() =>
    r'2567ea2c98b41a6954ebee9854613fa1afe4f89a';

/// 测试缝：默认读全局 router，测试 override 成纯 Dart router。

@ProviderFor(mediaSessionRouter)
final mediaSessionRouterProvider = MediaSessionRouterProvider._();

/// 测试缝：默认读全局 router，测试 override 成纯 Dart router。

final class MediaSessionRouterProvider
    extends
        $FunctionalProvider<
          MediaSessionRouter,
          MediaSessionRouter,
          MediaSessionRouter
        >
    with $Provider<MediaSessionRouter> {
  /// 测试缝：默认读全局 router，测试 override 成纯 Dart router。
  MediaSessionRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaSessionRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaSessionRouterHash();

  @$internal
  @override
  $ProviderElement<MediaSessionRouter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaSessionRouter create(Ref ref) {
    return mediaSessionRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaSessionRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaSessionRouter>(value),
    );
  }
}

String _$mediaSessionRouterHash() =>
    r'95c17c25348abbebce4bd91204a6a1042263ee16';

@ProviderFor(MediaEngine)
final mediaEngineProvider = MediaEngineProvider._();

final class MediaEngineProvider
    extends $NotifierProvider<MediaEngine, MediaEngineState> {
  MediaEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaEngineHash();

  @$internal
  @override
  MediaEngine create() => MediaEngine();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaEngineState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaEngineState>(value),
    );
  }
}

String _$mediaEngineHash() => r'0f26baac0d3069b11c7e46088662c2741c1ec382';

abstract class _$MediaEngine extends $Notifier<MediaEngineState> {
  MediaEngineState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MediaEngineState, MediaEngineState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MediaEngineState, MediaEngineState>,
              MediaEngineState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
