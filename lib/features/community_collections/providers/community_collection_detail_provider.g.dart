// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_collection_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$communityCollectionFilesHash() =>
    r'3718b2d0e8411ec1f8141bdca8dfb2006a7225f6';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$CommunityCollectionFiles
    extends
        BuildlessAutoDisposeAsyncNotifier<
          CommunityCollectionPagedState<CommunityCollectionFile>
        > {
  late final String collectionId;

  FutureOr<CommunityCollectionPagedState<CommunityCollectionFile>> build(
    String collectionId,
  );
}

/// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。
///
/// Copied from [CommunityCollectionFiles].
@ProviderFor(CommunityCollectionFiles)
const communityCollectionFilesProvider = CommunityCollectionFilesFamily();

/// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。
///
/// Copied from [CommunityCollectionFiles].
class CommunityCollectionFilesFamily
    extends
        Family<
          AsyncValue<CommunityCollectionPagedState<CommunityCollectionFile>>
        > {
  /// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。
  ///
  /// Copied from [CommunityCollectionFiles].
  const CommunityCollectionFilesFamily();

  /// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。
  ///
  /// Copied from [CommunityCollectionFiles].
  CommunityCollectionFilesProvider call(String collectionId) {
    return CommunityCollectionFilesProvider(collectionId);
  }

  @override
  CommunityCollectionFilesProvider getProviderOverride(
    covariant CommunityCollectionFilesProvider provider,
  ) {
    return call(provider.collectionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'communityCollectionFilesProvider';
}

/// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。
///
/// Copied from [CommunityCollectionFiles].
class CommunityCollectionFilesProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          CommunityCollectionFiles,
          CommunityCollectionPagedState<CommunityCollectionFile>
        > {
  /// 单个社区合集文件的分页状态；详情页只在滚动接近底部时加载下一页。
  ///
  /// Copied from [CommunityCollectionFiles].
  CommunityCollectionFilesProvider(String collectionId)
    : this._internal(
        () => CommunityCollectionFiles()..collectionId = collectionId,
        from: communityCollectionFilesProvider,
        name: r'communityCollectionFilesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$communityCollectionFilesHash,
        dependencies: CommunityCollectionFilesFamily._dependencies,
        allTransitiveDependencies:
            CommunityCollectionFilesFamily._allTransitiveDependencies,
        collectionId: collectionId,
      );

  CommunityCollectionFilesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.collectionId,
  }) : super.internal();

  final String collectionId;

  @override
  FutureOr<CommunityCollectionPagedState<CommunityCollectionFile>>
  runNotifierBuild(covariant CommunityCollectionFiles notifier) {
    return notifier.build(collectionId);
  }

  @override
  Override overrideWith(CommunityCollectionFiles Function() create) {
    return ProviderOverride(
      origin: this,
      override: CommunityCollectionFilesProvider._internal(
        () => create()..collectionId = collectionId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        collectionId: collectionId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    CommunityCollectionFiles,
    CommunityCollectionPagedState<CommunityCollectionFile>
  >
  createElement() {
    return _CommunityCollectionFilesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CommunityCollectionFilesProvider &&
        other.collectionId == collectionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, collectionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CommunityCollectionFilesRef
    on
        AutoDisposeAsyncNotifierProviderRef<
          CommunityCollectionPagedState<CommunityCollectionFile>
        > {
  /// The parameter `collectionId` of this provider.
  String get collectionId;
}

class _CommunityCollectionFilesProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          CommunityCollectionFiles,
          CommunityCollectionPagedState<CommunityCollectionFile>
        >
    with CommunityCollectionFilesRef {
  _CommunityCollectionFilesProviderElement(super.provider);

  @override
  String get collectionId =>
      (origin as CommunityCollectionFilesProvider).collectionId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
