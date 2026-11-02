// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_collection_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。

@ProviderFor(CommunityCollectionFiles)
final communityCollectionFilesProvider = CommunityCollectionFilesFamily._();

/// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。
final class CommunityCollectionFilesProvider
    extends
        $AsyncNotifierProvider<
          CommunityCollectionFiles,
          CommunityCollectionPagedState<CommunityCollectionFile>
        > {
  /// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。
  CommunityCollectionFilesProvider._({
    required CommunityCollectionFilesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'communityCollectionFilesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$communityCollectionFilesHash();

  @override
  String toString() {
    return r'communityCollectionFilesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CommunityCollectionFiles create() => CommunityCollectionFiles();

  @override
  bool operator ==(Object other) {
    return other is CommunityCollectionFilesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$communityCollectionFilesHash() =>
    r'63681381cda2c8823c84e8a00e4db08ca94b8ece';

/// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。

final class CommunityCollectionFilesFamily extends $Family
    with
        $ClassFamilyOverride<
          CommunityCollectionFiles,
          AsyncValue<CommunityCollectionPagedState<CommunityCollectionFile>>,
          CommunityCollectionPagedState<CommunityCollectionFile>,
          FutureOr<CommunityCollectionPagedState<CommunityCollectionFile>>,
          String
        > {
  CommunityCollectionFilesFamily._()
    : super(
        retry: null,
        name: r'communityCollectionFilesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。

  CommunityCollectionFilesProvider call(String collectionId) =>
      CommunityCollectionFilesProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'communityCollectionFilesProvider';
}

/// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。

abstract class _$CommunityCollectionFiles
    extends
        $AsyncNotifier<CommunityCollectionPagedState<CommunityCollectionFile>> {
  late final _$args = ref.$arg as String;
  String get collectionId => _$args;

  FutureOr<CommunityCollectionPagedState<CommunityCollectionFile>> build(
    String collectionId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<
                CommunityCollectionPagedState<CommunityCollectionFile>
              >,
              CommunityCollectionPagedState<CommunityCollectionFile>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<
                  CommunityCollectionPagedState<CommunityCollectionFile>
                >,
                CommunityCollectionPagedState<CommunityCollectionFile>
              >,
              AsyncValue<
                CommunityCollectionPagedState<CommunityCollectionFile>
              >,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
