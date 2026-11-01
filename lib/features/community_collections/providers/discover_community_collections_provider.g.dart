// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_community_collections_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$discoverCommunityCollectionsHash() =>
    r'b5c2652dc5510e4f21ced2b46f685cb35437b132';

/// 获取公开社区合集的分页状态；页面只在滚动接近底部时加载下一页。
///
/// Copied from [DiscoverCommunityCollections].
@ProviderFor(DiscoverCommunityCollections)
final discoverCommunityCollectionsProvider =
    AsyncNotifierProvider<
      DiscoverCommunityCollections,
      CommunityCollectionPagedState<PublicCollectionCatalogEntry>
    >.internal(
      DiscoverCommunityCollections.new,
      name: r'discoverCommunityCollectionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$discoverCommunityCollectionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DiscoverCommunityCollections =
    AsyncNotifier<CommunityCollectionPagedState<PublicCollectionCatalogEntry>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
