// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listen_and_repeat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 跟读会话控制器

@ProviderFor(ListenAndRepeatController)
final listenAndRepeatControllerProvider = ListenAndRepeatControllerProvider._();

/// 跟读会话控制器
final class ListenAndRepeatControllerProvider
    extends
        $NotifierProvider<
          ListenAndRepeatController,
          ListenAndRepeatSessionState
        > {
  /// 跟读会话控制器
  ListenAndRepeatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listenAndRepeatControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listenAndRepeatControllerHash();

  @$internal
  @override
  ListenAndRepeatController create() => ListenAndRepeatController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ListenAndRepeatSessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ListenAndRepeatSessionState>(value),
    );
  }
}

String _$listenAndRepeatControllerHash() =>
    r'b8cfbb0a69980a1f0d03cbc47c5bf55adcb076f1';

/// 跟读会话控制器

abstract class _$ListenAndRepeatController
    extends $Notifier<ListenAndRepeatSessionState> {
  ListenAndRepeatSessionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<ListenAndRepeatSessionState, ListenAndRepeatSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ListenAndRepeatSessionState,
                ListenAndRepeatSessionState
              >,
              ListenAndRepeatSessionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
