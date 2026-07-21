// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$podcastSearchServiceHash() =>
    r'f40cec9944de44c6f06acd98541577f7c2933786';

/// 播客搜索客户端。
///
/// Copied from [podcastSearchService].
@ProviderFor(podcastSearchService)
final podcastSearchServiceProvider =
    AutoDisposeProvider<PodcastSearchService>.internal(
      podcastSearchService,
      name: r'podcastSearchServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$podcastSearchServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PodcastSearchServiceRef = AutoDisposeProviderRef<PodcastSearchService>;
String _$podcastSearchResultsHash() =>
    r'55471597f5e50880715f2649e2d653c3d83a5247';

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

/// 按关键词搜索播客；[term] 为空返回空列表。
///
/// Copied from [podcastSearchResults].
@ProviderFor(podcastSearchResults)
const podcastSearchResultsProvider = PodcastSearchResultsFamily();

/// 按关键词搜索播客；[term] 为空返回空列表。
///
/// Copied from [podcastSearchResults].
class PodcastSearchResultsFamily
    extends Family<AsyncValue<List<PodcastSearchResult>>> {
  /// 按关键词搜索播客；[term] 为空返回空列表。
  ///
  /// Copied from [podcastSearchResults].
  const PodcastSearchResultsFamily();

  /// 按关键词搜索播客；[term] 为空返回空列表。
  ///
  /// Copied from [podcastSearchResults].
  PodcastSearchResultsProvider call(String term) {
    return PodcastSearchResultsProvider(term);
  }

  @override
  PodcastSearchResultsProvider getProviderOverride(
    covariant PodcastSearchResultsProvider provider,
  ) {
    return call(provider.term);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'podcastSearchResultsProvider';
}

/// 按关键词搜索播客；[term] 为空返回空列表。
///
/// Copied from [podcastSearchResults].
class PodcastSearchResultsProvider
    extends AutoDisposeFutureProvider<List<PodcastSearchResult>> {
  /// 按关键词搜索播客；[term] 为空返回空列表。
  ///
  /// Copied from [podcastSearchResults].
  PodcastSearchResultsProvider(String term)
    : this._internal(
        (ref) => podcastSearchResults(ref as PodcastSearchResultsRef, term),
        from: podcastSearchResultsProvider,
        name: r'podcastSearchResultsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$podcastSearchResultsHash,
        dependencies: PodcastSearchResultsFamily._dependencies,
        allTransitiveDependencies:
            PodcastSearchResultsFamily._allTransitiveDependencies,
        term: term,
      );

  PodcastSearchResultsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.term,
  }) : super.internal();

  final String term;

  @override
  Override overrideWith(
    FutureOr<List<PodcastSearchResult>> Function(
      PodcastSearchResultsRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PodcastSearchResultsProvider._internal(
        (ref) => create(ref as PodcastSearchResultsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        term: term,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<PodcastSearchResult>> createElement() {
    return _PodcastSearchResultsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PodcastSearchResultsProvider && other.term == term;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, term.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PodcastSearchResultsRef
    on AutoDisposeFutureProviderRef<List<PodcastSearchResult>> {
  /// The parameter `term` of this provider.
  String get term;
}

class _PodcastSearchResultsProviderElement
    extends AutoDisposeFutureProviderElement<List<PodcastSearchResult>>
    with PodcastSearchResultsRef {
  _PodcastSearchResultsProviderElement(super.provider);

  @override
  String get term => (origin as PodcastSearchResultsProvider).term;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
