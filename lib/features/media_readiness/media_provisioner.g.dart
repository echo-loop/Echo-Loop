// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_provisioner.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mediaEnsurer)
final mediaEnsurerProvider = MediaEnsurerProvider._();

final class MediaEnsurerProvider
    extends $FunctionalProvider<MediaEnsurer, MediaEnsurer, MediaEnsurer>
    with $Provider<MediaEnsurer> {
  MediaEnsurerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaEnsurerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaEnsurerHash();

  @$internal
  @override
  $ProviderElement<MediaEnsurer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaEnsurer create(Ref ref) {
    return mediaEnsurer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaEnsurer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaEnsurer>(value),
    );
  }
}

String _$mediaEnsurerHash() => r'ddd80f710e0a64406624bbece565e246a3d8f8ed';
