// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(podcastRepository)
final podcastRepositoryProvider = PodcastRepositoryProvider._();

final class PodcastRepositoryProvider
    extends
        $FunctionalProvider<
          PodcastRepository,
          PodcastRepository,
          PodcastRepository
        >
    with $Provider<PodcastRepository> {
  PodcastRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'podcastRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$podcastRepositoryHash();

  @$internal
  @override
  $ProviderElement<PodcastRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PodcastRepository create(Ref ref) {
    return podcastRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PodcastRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PodcastRepository>(value),
    );
  }
}

String _$podcastRepositoryHash() => r'445741831465e39b0c799b79f7c013e1770ea798';
