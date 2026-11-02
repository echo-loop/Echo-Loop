// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 播客搜索客户端。

@ProviderFor(podcastSearchService)
final podcastSearchServiceProvider = PodcastSearchServiceProvider._();

/// 播客搜索客户端。

final class PodcastSearchServiceProvider
    extends
        $FunctionalProvider<
          PodcastSearchService,
          PodcastSearchService,
          PodcastSearchService
        >
    with $Provider<PodcastSearchService> {
  /// 播客搜索客户端。
  PodcastSearchServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'podcastSearchServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$podcastSearchServiceHash();

  @$internal
  @override
  $ProviderElement<PodcastSearchService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PodcastSearchService create(Ref ref) {
    return podcastSearchService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PodcastSearchService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PodcastSearchService>(value),
    );
  }
}

String _$podcastSearchServiceHash() =>
    r'f40cec9944de44c6f06acd98541577f7c2933786';

/// 按关键词搜索播客；[term] 为空返回空列表。

@ProviderFor(podcastSearchResults)
final podcastSearchResultsProvider = PodcastSearchResultsFamily._();

/// 按关键词搜索播客；[term] 为空返回空列表。

final class PodcastSearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PodcastSearchResult>>,
          List<PodcastSearchResult>,
          FutureOr<List<PodcastSearchResult>>
        >
    with
        $FutureModifier<List<PodcastSearchResult>>,
        $FutureProvider<List<PodcastSearchResult>> {
  /// 按关键词搜索播客；[term] 为空返回空列表。
  PodcastSearchResultsProvider._({
    required PodcastSearchResultsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'podcastSearchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$podcastSearchResultsHash();

  @override
  String toString() {
    return r'podcastSearchResultsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<PodcastSearchResult>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PodcastSearchResult>> create(Ref ref) {
    final argument = this.argument as String;
    return podcastSearchResults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PodcastSearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$podcastSearchResultsHash() =>
    r'55471597f5e50880715f2649e2d653c3d83a5247';

/// 按关键词搜索播客；[term] 为空返回空列表。

final class PodcastSearchResultsFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<List<PodcastSearchResult>>, String> {
  PodcastSearchResultsFamily._()
    : super(
        retry: null,
        name: r'podcastSearchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 按关键词搜索播客；[term] 为空返回空列表。

  PodcastSearchResultsProvider call(String term) =>
      PodcastSearchResultsProvider._(argument: term, from: this);

  @override
  String toString() => r'podcastSearchResultsProvider';
}
