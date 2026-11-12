// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_text_prefs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SubtitleTextPrefsNotifier)
final subtitleTextPrefsProvider = SubtitleTextPrefsNotifierProvider._();

final class SubtitleTextPrefsNotifierProvider
    extends $NotifierProvider<SubtitleTextPrefsNotifier, SubtitleTextPrefs> {
  SubtitleTextPrefsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subtitleTextPrefsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subtitleTextPrefsNotifierHash();

  @$internal
  @override
  SubtitleTextPrefsNotifier create() => SubtitleTextPrefsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubtitleTextPrefs value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubtitleTextPrefs>(value),
    );
  }
}

String _$subtitleTextPrefsNotifierHash() =>
    r'c6e96e3f492abd6950e23d1cde34599a88af05c6';

abstract class _$SubtitleTextPrefsNotifier
    extends $Notifier<SubtitleTextPrefs> {
  SubtitleTextPrefs build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SubtitleTextPrefs, SubtitleTextPrefs>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SubtitleTextPrefs, SubtitleTextPrefs>,
              SubtitleTextPrefs,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
