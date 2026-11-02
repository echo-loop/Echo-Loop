// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_transcript_downloader.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(podcastTranscriptDownloader)
final podcastTranscriptDownloaderProvider =
    PodcastTranscriptDownloaderProvider._();

final class PodcastTranscriptDownloaderProvider
    extends
        $FunctionalProvider<
          PodcastTranscriptDownloader,
          PodcastTranscriptDownloader,
          PodcastTranscriptDownloader
        >
    with $Provider<PodcastTranscriptDownloader> {
  PodcastTranscriptDownloaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'podcastTranscriptDownloaderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$podcastTranscriptDownloaderHash();

  @$internal
  @override
  $ProviderElement<PodcastTranscriptDownloader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PodcastTranscriptDownloader create(Ref ref) {
    return podcastTranscriptDownloader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PodcastTranscriptDownloader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PodcastTranscriptDownloader>(value),
    );
  }
}

String _$podcastTranscriptDownloaderHash() =>
    r'1c45a7b0cda79d7c12a4615ec69700391d49ae46';
