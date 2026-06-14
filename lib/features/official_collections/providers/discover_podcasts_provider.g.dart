// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_podcasts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$discoverPodcastsHash() => r'e4bf8420956ece74457643a40e18b9e4904e53b5';

/// Discover 页的精选 Podcast 列表。
///
/// 与官方合集共用同一份 catalog 缓存；返回 null 表示 catalog 尚未初始化，
/// 返回空 list 表示已初始化但后端暂无精选 Podcast。
///
/// Copied from [discoverPodcasts].
@ProviderFor(discoverPodcasts)
final discoverPodcastsProvider = Provider<List<CatalogPodcast>?>.internal(
  discoverPodcasts,
  name: r'discoverPodcastsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$discoverPodcastsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DiscoverPodcastsRef = ProviderRef<List<CatalogPodcast>?>;
String _$podcastCatalogDetailHash() =>
    r'10027b32632e83941aebad0184a079566edf76c7';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 从 catalog 缓存中按 id 查找单个精选 Podcast。
///
/// Copied from [podcastCatalogDetail].
@ProviderFor(podcastCatalogDetail)
const podcastCatalogDetailProvider = PodcastCatalogDetailFamily();

/// 从 catalog 缓存中按 id 查找单个精选 Podcast。
///
/// Copied from [podcastCatalogDetail].
class PodcastCatalogDetailFamily extends Family<CatalogPodcast?> {
  /// 从 catalog 缓存中按 id 查找单个精选 Podcast。
  ///
  /// Copied from [podcastCatalogDetail].
  const PodcastCatalogDetailFamily();

  /// 从 catalog 缓存中按 id 查找单个精选 Podcast。
  ///
  /// Copied from [podcastCatalogDetail].
  PodcastCatalogDetailProvider call(String podcastId) {
    return PodcastCatalogDetailProvider(podcastId);
  }

  @override
  PodcastCatalogDetailProvider getProviderOverride(
    covariant PodcastCatalogDetailProvider provider,
  ) {
    return call(provider.podcastId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'podcastCatalogDetailProvider';
}

/// 从 catalog 缓存中按 id 查找单个精选 Podcast。
///
/// Copied from [podcastCatalogDetail].
class PodcastCatalogDetailProvider extends Provider<CatalogPodcast?> {
  /// 从 catalog 缓存中按 id 查找单个精选 Podcast。
  ///
  /// Copied from [podcastCatalogDetail].
  PodcastCatalogDetailProvider(String podcastId)
    : this._internal(
        (ref) =>
            podcastCatalogDetail(ref as PodcastCatalogDetailRef, podcastId),
        from: podcastCatalogDetailProvider,
        name: r'podcastCatalogDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$podcastCatalogDetailHash,
        dependencies: PodcastCatalogDetailFamily._dependencies,
        allTransitiveDependencies:
            PodcastCatalogDetailFamily._allTransitiveDependencies,
        podcastId: podcastId,
      );

  PodcastCatalogDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.podcastId,
  }) : super.internal();

  final String podcastId;

  @override
  Override overrideWith(
    CatalogPodcast? Function(PodcastCatalogDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PodcastCatalogDetailProvider._internal(
        (ref) => create(ref as PodcastCatalogDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        podcastId: podcastId,
      ),
    );
  }

  @override
  ProviderElement<CatalogPodcast?> createElement() {
    return _PodcastCatalogDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PodcastCatalogDetailProvider &&
        other.podcastId == podcastId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, podcastId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PodcastCatalogDetailRef on ProviderRef<CatalogPodcast?> {
  /// The parameter `podcastId` of this provider.
  String get podcastId;
}

class _PodcastCatalogDetailProviderElement
    extends ProviderElement<CatalogPodcast?>
    with PodcastCatalogDetailRef {
  _PodcastCatalogDetailProviderElement(super.provider);

  @override
  String get podcastId => (origin as PodcastCatalogDetailProvider).podcastId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
