// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lookup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dictionaryLookupContextHash() =>
    r'43f7097e39da82a4cf96c1f62fedbbea7a1e7fa1';

/// 查词请求上下文（鉴权 + 目标语言），收敛为单一 provider 便于测试覆盖
///
/// Copied from [dictionaryLookupContext].
@ProviderFor(dictionaryLookupContext)
final dictionaryLookupContextProvider =
    AutoDisposeProvider<DictionaryLookupContext>.internal(
      dictionaryLookupContext,
      name: r'dictionaryLookupContextProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dictionaryLookupContextHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DictionaryLookupContextRef =
    AutoDisposeProviderRef<DictionaryLookupContext>;
String _$dictionarySessionSourceHash() =>
    r'7b5db5448f5049403292e651521a8bcda4f525df';

/// 会话内粘滞源：词典面板打开期间用户手动选中的源 id（null = 未手动选过）。
///
/// 同一面板会话内切词/重新选词组时，新词的查词 controller 沿用该源，
/// 不回退默认源；面板关闭时由 [DictionaryPanel] 清除，下次打开恢复默认。
/// keepAlive——family 查词 controller 是 autoDispose（切词即销毁重建），
/// 粘滞选择必须跨 controller 存活。
///
/// Copied from [DictionarySessionSource].
@ProviderFor(DictionarySessionSource)
final dictionarySessionSourceProvider =
    NotifierProvider<DictionarySessionSource, String?>.internal(
      DictionarySessionSource.new,
      name: r'dictionarySessionSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dictionarySessionSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DictionarySessionSource = Notifier<String?>;
String _$dictionaryLookupControllerHash() =>
    r'77d386c9a22105df437386e6cbc5e9f051212b6a';

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

abstract class _$DictionaryLookupController
    extends BuildlessAutoDisposeNotifier<DictionaryLookupState> {
  late final String word;

  DictionaryLookupState build(String word);
}

/// 查词会话 controller（family by word，autoDispose）
///
/// Copied from [DictionaryLookupController].
@ProviderFor(DictionaryLookupController)
const dictionaryLookupControllerProvider = DictionaryLookupControllerFamily();

/// 查词会话 controller（family by word，autoDispose）
///
/// Copied from [DictionaryLookupController].
class DictionaryLookupControllerFamily extends Family<DictionaryLookupState> {
  /// 查词会话 controller（family by word，autoDispose）
  ///
  /// Copied from [DictionaryLookupController].
  const DictionaryLookupControllerFamily();

  /// 查词会话 controller（family by word，autoDispose）
  ///
  /// Copied from [DictionaryLookupController].
  DictionaryLookupControllerProvider call(String word) {
    return DictionaryLookupControllerProvider(word);
  }

  @override
  DictionaryLookupControllerProvider getProviderOverride(
    covariant DictionaryLookupControllerProvider provider,
  ) {
    return call(provider.word);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'dictionaryLookupControllerProvider';
}

/// 查词会话 controller（family by word，autoDispose）
///
/// Copied from [DictionaryLookupController].
class DictionaryLookupControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          DictionaryLookupController,
          DictionaryLookupState
        > {
  /// 查词会话 controller（family by word，autoDispose）
  ///
  /// Copied from [DictionaryLookupController].
  DictionaryLookupControllerProvider(String word)
    : this._internal(
        () => DictionaryLookupController()..word = word,
        from: dictionaryLookupControllerProvider,
        name: r'dictionaryLookupControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$dictionaryLookupControllerHash,
        dependencies: DictionaryLookupControllerFamily._dependencies,
        allTransitiveDependencies:
            DictionaryLookupControllerFamily._allTransitiveDependencies,
        word: word,
      );

  DictionaryLookupControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.word,
  }) : super.internal();

  final String word;

  @override
  DictionaryLookupState runNotifierBuild(
    covariant DictionaryLookupController notifier,
  ) {
    return notifier.build(word);
  }

  @override
  Override overrideWith(DictionaryLookupController Function() create) {
    return ProviderOverride(
      origin: this,
      override: DictionaryLookupControllerProvider._internal(
        () => create()..word = word,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        word: word,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    DictionaryLookupController,
    DictionaryLookupState
  >
  createElement() {
    return _DictionaryLookupControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DictionaryLookupControllerProvider && other.word == word;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, word.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DictionaryLookupControllerRef
    on AutoDisposeNotifierProviderRef<DictionaryLookupState> {
  /// The parameter `word` of this provider.
  String get word;
}

class _DictionaryLookupControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          DictionaryLookupController,
          DictionaryLookupState
        >
    with DictionaryLookupControllerRef {
  _DictionaryLookupControllerProviderElement(super.provider);

  @override
  String get word => (origin as DictionaryLookupControllerProvider).word;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
