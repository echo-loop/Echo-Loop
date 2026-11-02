// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_list_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AudioListSettings)
final audioListSettingsProvider = AudioListSettingsProvider._();

final class AudioListSettingsProvider
    extends $NotifierProvider<AudioListSettings, AudioListSettingsState> {
  AudioListSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioListSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioListSettingsHash();

  @$internal
  @override
  AudioListSettings create() => AudioListSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioListSettingsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioListSettingsState>(value),
    );
  }
}

String _$audioListSettingsHash() => r'4d4bf1da22dc866b006ebc9db7fa474360549213';

abstract class _$AudioListSettings extends $Notifier<AudioListSettingsState> {
  AudioListSettingsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AudioListSettingsState, AudioListSettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AudioListSettingsState, AudioListSettingsState>,
              AudioListSettingsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
