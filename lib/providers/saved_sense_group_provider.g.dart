// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_sense_group_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$isSenseGroupSavedHash() => r'e77fa7348d30e595bf44133eb7e8289413c3d508';

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

/// 监听单个意群是否已收藏
///
/// Copied from [isSenseGroupSaved].
@ProviderFor(isSenseGroupSaved)
const isSenseGroupSavedProvider = IsSenseGroupSavedFamily();

/// 监听单个意群是否已收藏
///
/// Copied from [isSenseGroupSaved].
class IsSenseGroupSavedFamily extends Family<AsyncValue<bool>> {
  /// 监听单个意群是否已收藏
  ///
  /// Copied from [isSenseGroupSaved].
  const IsSenseGroupSavedFamily();

  /// 监听单个意群是否已收藏
  ///
  /// Copied from [isSenseGroupSaved].
  IsSenseGroupSavedProvider call(String phraseText) {
    return IsSenseGroupSavedProvider(phraseText);
  }

  @override
  IsSenseGroupSavedProvider getProviderOverride(
    covariant IsSenseGroupSavedProvider provider,
  ) {
    return call(provider.phraseText);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isSenseGroupSavedProvider';
}

/// 监听单个意群是否已收藏
///
/// Copied from [isSenseGroupSaved].
class IsSenseGroupSavedProvider extends AutoDisposeStreamProvider<bool> {
  /// 监听单个意群是否已收藏
  ///
  /// Copied from [isSenseGroupSaved].
  IsSenseGroupSavedProvider(String phraseText)
    : this._internal(
        (ref) => isSenseGroupSaved(ref as IsSenseGroupSavedRef, phraseText),
        from: isSenseGroupSavedProvider,
        name: r'isSenseGroupSavedProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$isSenseGroupSavedHash,
        dependencies: IsSenseGroupSavedFamily._dependencies,
        allTransitiveDependencies:
            IsSenseGroupSavedFamily._allTransitiveDependencies,
        phraseText: phraseText,
      );

  IsSenseGroupSavedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.phraseText,
  }) : super.internal();

  final String phraseText;

  @override
  Override overrideWith(
    Stream<bool> Function(IsSenseGroupSavedRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IsSenseGroupSavedProvider._internal(
        (ref) => create(ref as IsSenseGroupSavedRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        phraseText: phraseText,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<bool> createElement() {
    return _IsSenseGroupSavedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsSenseGroupSavedProvider && other.phraseText == phraseText;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, phraseText.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IsSenseGroupSavedRef on AutoDisposeStreamProviderRef<bool> {
  /// The parameter `phraseText` of this provider.
  String get phraseText;
}

class _IsSenseGroupSavedProviderElement
    extends AutoDisposeStreamProviderElement<bool>
    with IsSenseGroupSavedRef {
  _IsSenseGroupSavedProviderElement(super.provider);

  @override
  String get phraseText => (origin as IsSenseGroupSavedProvider).phraseText;
}

String _$savedSenseGroupListHash() =>
    r'222bfc6bb5bb1cb9990e6f226ae0fd0cd1fb092a';

/// 收藏意群列表 Provider（流式）
///
/// 监听所有收藏意群的变化，按收藏时间倒序。
///
/// Copied from [SavedSenseGroupList].
@ProviderFor(SavedSenseGroupList)
final savedSenseGroupListProvider =
    StreamNotifierProvider<SavedSenseGroupList, List<SavedSenseGroup>>.internal(
      SavedSenseGroupList.new,
      name: r'savedSenseGroupListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$savedSenseGroupListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SavedSenseGroupList = StreamNotifier<List<SavedSenseGroup>>;
String _$savedSenseGroupTextsHash() =>
    r'57b3e78bfea821f3dade82451dc1725d0c1ce22a';

/// 监听已收藏意群的归一化文本集合（用于 badge 染色）
///
/// Copied from [SavedSenseGroupTexts].
@ProviderFor(SavedSenseGroupTexts)
final savedSenseGroupTextsProvider =
    StreamNotifierProvider<SavedSenseGroupTexts, Set<String>>.internal(
      SavedSenseGroupTexts.new,
      name: r'savedSenseGroupTextsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$savedSenseGroupTextsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SavedSenseGroupTexts = StreamNotifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
