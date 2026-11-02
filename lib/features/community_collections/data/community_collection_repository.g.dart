// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_collection_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(communityCollectionRepository)
final communityCollectionRepositoryProvider =
    CommunityCollectionRepositoryProvider._();

final class CommunityCollectionRepositoryProvider
    extends
        $FunctionalProvider<
          CommunityCollectionRepository,
          CommunityCollectionRepository,
          CommunityCollectionRepository
        >
    with $Provider<CommunityCollectionRepository> {
  CommunityCollectionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'communityCollectionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$communityCollectionRepositoryHash();

  @$internal
  @override
  $ProviderElement<CommunityCollectionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CommunityCollectionRepository create(Ref ref) {
    return communityCollectionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommunityCollectionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommunityCollectionRepository>(
        value,
      ),
    );
  }
}

String _$communityCollectionRepositoryHash() =>
    r'30e7c00a38a9f6583acc7bc935fc10f3973029cc';
