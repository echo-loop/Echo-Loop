// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_preview_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$podcastPreviewDioHash() => r'd8157347c67dc475ff8a48aa09ff8e383fc1becd';

/// See also [podcastPreviewDio].
@ProviderFor(podcastPreviewDio)
final podcastPreviewDioProvider = Provider<Dio>.internal(
  podcastPreviewDio,
  name: r'podcastPreviewDioProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$podcastPreviewDioHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PodcastPreviewDioRef = ProviderRef<Dio>;
String _$podcastPreviewServiceHash() =>
    r'210ca30412d93b2b7114e967a28c229c4ee304be';

/// See also [podcastPreviewService].
@ProviderFor(podcastPreviewService)
final podcastPreviewServiceProvider = Provider<PodcastPreviewService>.internal(
  podcastPreviewService,
  name: r'podcastPreviewServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$podcastPreviewServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PodcastPreviewServiceRef = ProviderRef<PodcastPreviewService>;
String _$podcastPreviewHash() => r'102dfad34486133b51ae29ef392db6a039e21013';

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

/// 拉取单个精选 Podcast 的 RSS 预览。
///
/// Copied from [podcastPreview].
@ProviderFor(podcastPreview)
const podcastPreviewProvider = PodcastPreviewFamily();

/// 拉取单个精选 Podcast 的 RSS 预览。
///
/// Copied from [podcastPreview].
class PodcastPreviewFamily extends Family<AsyncValue<PodcastPreviewData>> {
  /// 拉取单个精选 Podcast 的 RSS 预览。
  ///
  /// Copied from [podcastPreview].
  const PodcastPreviewFamily();

  /// 拉取单个精选 Podcast 的 RSS 预览。
  ///
  /// Copied from [podcastPreview].
  PodcastPreviewProvider call(String podcastId) {
    return PodcastPreviewProvider(podcastId);
  }

  @override
  PodcastPreviewProvider getProviderOverride(
    covariant PodcastPreviewProvider provider,
  ) {
    return call(provider.podcastId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'podcastPreviewProvider';
}

/// 拉取单个精选 Podcast 的 RSS 预览。
///
/// Copied from [podcastPreview].
class PodcastPreviewProvider
    extends AutoDisposeFutureProvider<PodcastPreviewData> {
  /// 拉取单个精选 Podcast 的 RSS 预览。
  ///
  /// Copied from [podcastPreview].
  PodcastPreviewProvider(String podcastId)
    : this._internal(
        (ref) => podcastPreview(ref as PodcastPreviewRef, podcastId),
        from: podcastPreviewProvider,
        name: r'podcastPreviewProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$podcastPreviewHash,
        dependencies: PodcastPreviewFamily._dependencies,
        allTransitiveDependencies:
            PodcastPreviewFamily._allTransitiveDependencies,
        podcastId: podcastId,
      );

  PodcastPreviewProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.podcastId,
  }) : super.internal();

  final String podcastId;

  @override
  Override overrideWith(
    FutureOr<PodcastPreviewData> Function(PodcastPreviewRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PodcastPreviewProvider._internal(
        (ref) => create(ref as PodcastPreviewRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        podcastId: podcastId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<PodcastPreviewData> createElement() {
    return _PodcastPreviewProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PodcastPreviewProvider && other.podcastId == podcastId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, podcastId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PodcastPreviewRef on AutoDisposeFutureProviderRef<PodcastPreviewData> {
  /// The parameter `podcastId` of this provider.
  String get podcastId;
}

class _PodcastPreviewProviderElement
    extends AutoDisposeFutureProviderElement<PodcastPreviewData>
    with PodcastPreviewRef {
  _PodcastPreviewProviderElement(super.provider);

  @override
  String get podcastId => (origin as PodcastPreviewProvider).podcastId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
