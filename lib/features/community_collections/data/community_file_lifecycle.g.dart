// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_file_lifecycle.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(communityFileLifecycleService)
final communityFileLifecycleServiceProvider =
    CommunityFileLifecycleServiceProvider._();

final class CommunityFileLifecycleServiceProvider
    extends
        $FunctionalProvider<
          CommunityFileLifecycleService,
          CommunityFileLifecycleService,
          CommunityFileLifecycleService
        >
    with $Provider<CommunityFileLifecycleService> {
  CommunityFileLifecycleServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'communityFileLifecycleServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$communityFileLifecycleServiceHash();

  @$internal
  @override
  $ProviderElement<CommunityFileLifecycleService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CommunityFileLifecycleService create(Ref ref) {
    return communityFileLifecycleService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommunityFileLifecycleService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommunityFileLifecycleService>(
        value,
      ),
    );
  }
}

String _$communityFileLifecycleServiceHash() =>
    r'a2b88f05eaead75c7080ca8e58216572134ba9a7';
