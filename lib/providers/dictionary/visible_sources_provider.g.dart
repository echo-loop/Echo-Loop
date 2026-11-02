// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visible_sources_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 设置过滤后的可见源列表（顺序沿用注册表）

@ProviderFor(visibleDictionarySources)
final visibleDictionarySourcesProvider = VisibleDictionarySourcesProvider._();

/// 设置过滤后的可见源列表（顺序沿用注册表）

final class VisibleDictionarySourcesProvider
    extends
        $FunctionalProvider<
          List<DictionarySource>,
          List<DictionarySource>,
          List<DictionarySource>
        >
    with $Provider<List<DictionarySource>> {
  /// 设置过滤后的可见源列表（顺序沿用注册表）
  VisibleDictionarySourcesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'visibleDictionarySourcesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$visibleDictionarySourcesHash();

  @$internal
  @override
  $ProviderElement<List<DictionarySource>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<DictionarySource> create(Ref ref) {
    return visibleDictionarySources(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<DictionarySource> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<DictionarySource>>(value),
    );
  }
}

String _$visibleDictionarySourcesHash() =>
    r'fbb899f4a118b1491651fd7d41e86d91626ba3d8';

/// 生效的默认源 id（默认源不可见时回退到第一个可见源）

@ProviderFor(resolvedDefaultSourceId)
final resolvedDefaultSourceIdProvider = ResolvedDefaultSourceIdProvider._();

/// 生效的默认源 id（默认源不可见时回退到第一个可见源）

final class ResolvedDefaultSourceIdProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// 生效的默认源 id（默认源不可见时回退到第一个可见源）
  ResolvedDefaultSourceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resolvedDefaultSourceIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resolvedDefaultSourceIdHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return resolvedDefaultSourceId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$resolvedDefaultSourceIdHash() =>
    r'555560588ed9f77b67c20c483e3a66bd4015171a';
