// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(communitySyncService)
final communitySyncServiceProvider = CommunitySyncServiceProvider._();

final class CommunitySyncServiceProvider
    extends
        $FunctionalProvider<
          CommunitySyncService,
          CommunitySyncService,
          CommunitySyncService
        >
    with $Provider<CommunitySyncService> {
  CommunitySyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'communitySyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$communitySyncServiceHash();

  @$internal
  @override
  $ProviderElement<CommunitySyncService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CommunitySyncService create(Ref ref) {
    return communitySyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommunitySyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommunitySyncService>(value),
    );
  }
}

String _$communitySyncServiceHash() =>
    r'19947d28db33af15ecbd32b89146b073ad679d1d';
