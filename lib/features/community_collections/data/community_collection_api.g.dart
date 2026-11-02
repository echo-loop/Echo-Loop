// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_collection_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(communityCollectionApi)
final communityCollectionApiProvider = CommunityCollectionApiProvider._();

final class CommunityCollectionApiProvider
    extends
        $FunctionalProvider<
          CommunityCollectionApi,
          CommunityCollectionApi,
          CommunityCollectionApi
        >
    with $Provider<CommunityCollectionApi> {
  CommunityCollectionApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'communityCollectionApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$communityCollectionApiHash();

  @$internal
  @override
  $ProviderElement<CommunityCollectionApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CommunityCollectionApi create(Ref ref) {
    return communityCollectionApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommunityCollectionApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommunityCollectionApi>(value),
    );
  }
}

String _$communityCollectionApiHash() =>
    r'e5f23cbfe54d075ed04c28d52db3581e866baabb';
