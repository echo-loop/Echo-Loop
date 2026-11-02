// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_text_prefs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReadingTextPrefsNotifier)
final readingTextPrefsProvider = ReadingTextPrefsNotifierProvider._();

final class ReadingTextPrefsNotifierProvider
    extends $NotifierProvider<ReadingTextPrefsNotifier, ReadingTextPrefs> {
  ReadingTextPrefsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readingTextPrefsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readingTextPrefsNotifierHash();

  @$internal
  @override
  ReadingTextPrefsNotifier create() => ReadingTextPrefsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReadingTextPrefs value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReadingTextPrefs>(value),
    );
  }
}

String _$readingTextPrefsNotifierHash() =>
    r'9e287b585db960092391045d50c80837b4c4c419';

abstract class _$ReadingTextPrefsNotifier extends $Notifier<ReadingTextPrefs> {
  ReadingTextPrefs build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReadingTextPrefs, ReadingTextPrefs>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReadingTextPrefs, ReadingTextPrefs>,
              ReadingTextPrefs,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
