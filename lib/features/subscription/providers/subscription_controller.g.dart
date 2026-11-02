// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SubscriptionController)
final subscriptionControllerProvider = SubscriptionControllerProvider._();

final class SubscriptionControllerProvider
    extends $NotifierProvider<SubscriptionController, EntitlementState> {
  SubscriptionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionControllerHash();

  @$internal
  @override
  SubscriptionController create() => SubscriptionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntitlementState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntitlementState>(value),
    );
  }
}

String _$subscriptionControllerHash() =>
    r'bb6fd108bed6e826febd0d2b0fb57363f4b0d474';

abstract class _$SubscriptionController extends $Notifier<EntitlementState> {
  EntitlementState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EntitlementState, EntitlementState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EntitlementState, EntitlementState>,
              EntitlementState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
