// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_community_collections_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 获取公开社区合集的分页状态；页面只在滚动接近底部时加载下一页。

@ProviderFor(DiscoverCommunityCollections)
final discoverCommunityCollectionsProvider =
    DiscoverCommunityCollectionsProvider._();

/// 获取公开社区合集的分页状态；页面只在滚动接近底部时加载下一页。
final class DiscoverCommunityCollectionsProvider
    extends
        $AsyncNotifierProvider<
          DiscoverCommunityCollections,
          CommunityCollectionPagedState<PublicCollectionCatalogEntry>
        > {
  /// 获取公开社区合集的分页状态；页面只在滚动接近底部时加载下一页。
  DiscoverCommunityCollectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverCommunityCollectionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoverCommunityCollectionsHash();

  @$internal
  @override
  DiscoverCommunityCollections create() => DiscoverCommunityCollections();
}

String _$discoverCommunityCollectionsHash() =>
    r'f985247ed1381de5e592007c0eb686b02a36784d';

/// 获取公开社区合集的分页状态；页面只在滚动接近底部时加载下一页。

abstract class _$DiscoverCommunityCollections
    extends
        $AsyncNotifier<
          CommunityCollectionPagedState<PublicCollectionCatalogEntry>
        > {
  FutureOr<CommunityCollectionPagedState<PublicCollectionCatalogEntry>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<
                CommunityCollectionPagedState<PublicCollectionCatalogEntry>
              >,
              CommunityCollectionPagedState<PublicCollectionCatalogEntry>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<
                  CommunityCollectionPagedState<PublicCollectionCatalogEntry>
                >,
                CommunityCollectionPagedState<PublicCollectionCatalogEntry>
              >,
              AsyncValue<
                CommunityCollectionPagedState<PublicCollectionCatalogEntry>
              >,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
