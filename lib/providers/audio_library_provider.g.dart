// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_library_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AudioLibrary)
final audioLibraryProvider = AudioLibraryProvider._();

final class AudioLibraryProvider
    extends $NotifierProvider<AudioLibrary, AudioLibraryState> {
  AudioLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioLibraryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioLibraryHash();

  @$internal
  @override
  AudioLibrary create() => AudioLibrary();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioLibraryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioLibraryState>(value),
    );
  }
}

String _$audioLibraryHash() => r'9f7bf6291ca20251e014aef7b083a6345ca19465';

abstract class _$AudioLibrary extends $Notifier<AudioLibraryState> {
  AudioLibraryState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AudioLibraryState, AudioLibraryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AudioLibraryState, AudioLibraryState>,
              AudioLibraryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
