// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listen_and_repeat_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 跟读设置 Provider

@ProviderFor(ListenAndRepeatSettings)
final listenAndRepeatSettingsProvider = ListenAndRepeatSettingsProvider._();

/// 跟读设置 Provider
final class ListenAndRepeatSettingsProvider
    extends
        $NotifierProvider<ListenAndRepeatSettings, IntensiveListenSettings> {
  /// 跟读设置 Provider
  ListenAndRepeatSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listenAndRepeatSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listenAndRepeatSettingsHash();

  @$internal
  @override
  ListenAndRepeatSettings create() => ListenAndRepeatSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IntensiveListenSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IntensiveListenSettings>(value),
    );
  }
}

String _$listenAndRepeatSettingsHash() =>
    r'b05544d8de3bc2458b9c386de3f19aaeae1aede4';

/// 跟读设置 Provider

abstract class _$ListenAndRepeatSettings
    extends $Notifier<IntensiveListenSettings> {
  IntensiveListenSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<IntensiveListenSettings, IntensiveListenSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<IntensiveListenSettings, IntensiveListenSettings>,
              IntensiveListenSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
