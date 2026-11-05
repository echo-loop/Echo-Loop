// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_registry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 在线词典服务：随母语切换重建（词典 ID 由母语决定）

@ProviderFor(dictionaryService)
final dictionaryServiceProvider = DictionaryServiceProvider._();

/// 在线词典服务：随母语切换重建（词典 ID 由母语决定）

final class DictionaryServiceProvider
    extends
        $FunctionalProvider<
          DictionaryService,
          DictionaryService,
          DictionaryService
        >
    with $Provider<DictionaryService> {
  /// 在线词典服务：随母语切换重建（词典 ID 由母语决定）
  DictionaryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dictionaryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dictionaryServiceHash();

  @$internal
  @override
  $ProviderElement<DictionaryService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DictionaryService create(Ref ref) {
    return dictionaryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DictionaryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DictionaryService>(value),
    );
  }
}

String _$dictionaryServiceHash() => r'2de16940502508a3e7d0a205ff703b79cd7f5d7a';

/// 本地（在线）词典源

@ProviderFor(localDictionarySource)
final localDictionarySourceProvider = LocalDictionarySourceProvider._();

/// 本地（在线）词典源

final class LocalDictionarySourceProvider
    extends
        $FunctionalProvider<
          LocalDictionarySource,
          LocalDictionarySource,
          LocalDictionarySource
        >
    with $Provider<LocalDictionarySource> {
  /// 本地（在线）词典源
  LocalDictionarySourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localDictionarySourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localDictionarySourceHash();

  @$internal
  @override
  $ProviderElement<LocalDictionarySource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalDictionarySource create(Ref ref) {
    return localDictionarySource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalDictionarySource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalDictionarySource>(value),
    );
  }
}

String _$localDictionarySourceHash() =>
    r'd4e0f2a0ebf95a7cf774246adc7bf9d401ecf5de';

/// AI 词典源
///
/// 依赖延迟解析（lookup 时才读），避免枚举注册表即初始化数据库/网络栈。

@ProviderFor(aiDictionarySource)
final aiDictionarySourceProvider = AiDictionarySourceProvider._();

/// AI 词典源
///
/// 依赖延迟解析（lookup 时才读），避免枚举注册表即初始化数据库/网络栈。

final class AiDictionarySourceProvider
    extends
        $FunctionalProvider<
          AiDictionarySource,
          AiDictionarySource,
          AiDictionarySource
        >
    with $Provider<AiDictionarySource> {
  /// AI 词典源
  ///
  /// 依赖延迟解析（lookup 时才读），避免枚举注册表即初始化数据库/网络栈。
  AiDictionarySourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiDictionarySourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiDictionarySourceHash();

  @$internal
  @override
  $ProviderElement<AiDictionarySource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiDictionarySource create(Ref ref) {
    return aiDictionarySource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiDictionarySource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiDictionarySource>(value),
    );
  }
}

String _$aiDictionarySourceHash() =>
    r'219e794f0e8acedb4ea21898e42b6872614a52ba';

/// 网页词典源列表（由 [kWebDictConfigs] 配置生成：Cambridge / Oxford / ...）

@ProviderFor(webDictionarySources)
final webDictionarySourcesProvider = WebDictionarySourcesProvider._();

/// 网页词典源列表（由 [kWebDictConfigs] 配置生成：Cambridge / Oxford / ...）

final class WebDictionarySourcesProvider
    extends
        $FunctionalProvider<
          List<WebDictionarySource>,
          List<WebDictionarySource>,
          List<WebDictionarySource>
        >
    with $Provider<List<WebDictionarySource>> {
  /// 网页词典源列表（由 [kWebDictConfigs] 配置生成：Cambridge / Oxford / ...）
  WebDictionarySourcesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webDictionarySourcesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webDictionarySourcesHash();

  @$internal
  @override
  $ProviderElement<List<WebDictionarySource>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<WebDictionarySource> create(Ref ref) {
    return webDictionarySources(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<WebDictionarySource> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<WebDictionarySource>>(value),
    );
  }
}

String _$webDictionarySourcesHash() =>
    r'2d51291451c037ca1136580e5ed1375f3175b35c';

/// 全部数据源（顺序即默认排列/回退优先级）

@ProviderFor(dictionarySources)
final dictionarySourcesProvider = DictionarySourcesProvider._();

/// 全部数据源（顺序即默认排列/回退优先级）

final class DictionarySourcesProvider
    extends
        $FunctionalProvider<
          List<DictionarySource>,
          List<DictionarySource>,
          List<DictionarySource>
        >
    with $Provider<List<DictionarySource>> {
  /// 全部数据源（顺序即默认排列/回退优先级）
  DictionarySourcesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dictionarySourcesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dictionarySourcesHash();

  @$internal
  @override
  $ProviderElement<List<DictionarySource>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<DictionarySource> create(Ref ref) {
    return dictionarySources(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<DictionarySource> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<DictionarySource>>(value),
    );
  }
}

String _$dictionarySourcesHash() => r'11248e4d2910146de80f1a65cf9a4e23048a91a4';

/// id → source 查找表

@ProviderFor(dictionarySourcesById)
final dictionarySourcesByIdProvider = DictionarySourcesByIdProvider._();

/// id → source 查找表

final class DictionarySourcesByIdProvider
    extends
        $FunctionalProvider<
          Map<String, DictionarySource>,
          Map<String, DictionarySource>,
          Map<String, DictionarySource>
        >
    with $Provider<Map<String, DictionarySource>> {
  /// id → source 查找表
  DictionarySourcesByIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dictionarySourcesByIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dictionarySourcesByIdHash();

  @$internal
  @override
  $ProviderElement<Map<String, DictionarySource>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, DictionarySource> create(Ref ref) {
    return dictionarySourcesById(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, DictionarySource> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, DictionarySource>>(
        value,
      ),
    );
  }
}

String _$dictionarySourcesByIdHash() =>
    r'f6213e9ba90e3d004c98be7d6307aaff32d12dfd';
