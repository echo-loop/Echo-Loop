// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'featured_podcast_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(featuredPodcastService)
final featuredPodcastServiceProvider = FeaturedPodcastServiceProvider._();

final class FeaturedPodcastServiceProvider
    extends
        $FunctionalProvider<
          FeaturedPodcastService,
          FeaturedPodcastService,
          FeaturedPodcastService
        >
    with $Provider<FeaturedPodcastService> {
  FeaturedPodcastServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featuredPodcastServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featuredPodcastServiceHash();

  @$internal
  @override
  $ProviderElement<FeaturedPodcastService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FeaturedPodcastService create(Ref ref) {
    return featuredPodcastService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeaturedPodcastService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeaturedPodcastService>(value),
    );
  }
}

String _$featuredPodcastServiceHash() =>
    r'f140f1f0a9e694033200cc0f6afd5990c7c55277';
