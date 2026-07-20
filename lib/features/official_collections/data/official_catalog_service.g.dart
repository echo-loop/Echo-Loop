// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'official_catalog_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$officialCatalogServiceHash() =>
    r'6b8e671bf0c0e43b17972701131f6f835e100c44';

/// catalog service Provider（keepAlive；进程内单例）。
///
/// Copied from [officialCatalogService].
@ProviderFor(officialCatalogService)
final officialCatalogServiceProvider =
    Provider<OfficialCatalogService>.internal(
      officialCatalogService,
      name: r'officialCatalogServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$officialCatalogServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OfficialCatalogServiceRef = ProviderRef<OfficialCatalogService>;
String _$cachedCatalogHash() => r'11568e5cc9462212abf6a437fa8d46008cc07cc5';

/// catalog 内存快照 provider。
///
/// 只读 service.cached；不直接持有数据。service 通过
/// `ref.invalidate(officialCatalogServiceProvider)` 触发重 build。
/// 注意：实际场景中我们也通过更直接的方式让 watcher 更新 — 见 sync service。
///
/// Copied from [cachedCatalog].
@ProviderFor(cachedCatalog)
final cachedCatalogProvider = Provider<CatalogSnapshot?>.internal(
  cachedCatalog,
  name: r'cachedCatalogProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cachedCatalogHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CachedCatalogRef = ProviderRef<CatalogSnapshot?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
