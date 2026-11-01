// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_readiness_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localMediaFileExistsHash() =>
    r'05324f23aed5d8273f3ae97931a3783bfea404f4';

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

/// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
///
/// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
/// 否则计划页会在就绪与校验中之间来回切换。
///
/// Copied from [localMediaFileExists].
@ProviderFor(localMediaFileExists)
const localMediaFileExistsProvider = LocalMediaFileExistsFamily();

/// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
///
/// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
/// 否则计划页会在就绪与校验中之间来回切换。
///
/// Copied from [localMediaFileExists].
class LocalMediaFileExistsFamily extends Family<AsyncValue<bool>> {
  /// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
  ///
  /// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
  /// 否则计划页会在就绪与校验中之间来回切换。
  ///
  /// Copied from [localMediaFileExists].
  const LocalMediaFileExistsFamily();

  /// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
  ///
  /// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
  /// 否则计划页会在就绪与校验中之间来回切换。
  ///
  /// Copied from [localMediaFileExists].
  LocalMediaFileExistsProvider call(String audioItemId) {
    return LocalMediaFileExistsProvider(audioItemId);
  }

  @override
  LocalMediaFileExistsProvider getProviderOverride(
    covariant LocalMediaFileExistsProvider provider,
  ) {
    return call(provider.audioItemId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'localMediaFileExistsProvider';
}

/// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
///
/// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
/// 否则计划页会在就绪与校验中之间来回切换。
///
/// Copied from [localMediaFileExists].
class LocalMediaFileExistsProvider extends AutoDisposeFutureProvider<bool> {
  /// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
  ///
  /// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
  /// 否则计划页会在就绪与校验中之间来回切换。
  ///
  /// Copied from [localMediaFileExists].
  LocalMediaFileExistsProvider(String audioItemId)
    : this._internal(
        (ref) =>
            localMediaFileExists(ref as LocalMediaFileExistsRef, audioItemId),
        from: localMediaFileExistsProvider,
        name: r'localMediaFileExistsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$localMediaFileExistsHash,
        dependencies: LocalMediaFileExistsFamily._dependencies,
        allTransitiveDependencies:
            LocalMediaFileExistsFamily._allTransitiveDependencies,
        audioItemId: audioItemId,
      );

  LocalMediaFileExistsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.audioItemId,
  }) : super.internal();

  final String audioItemId;

  @override
  Override overrideWith(
    FutureOr<bool> Function(LocalMediaFileExistsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LocalMediaFileExistsProvider._internal(
        (ref) => create(ref as LocalMediaFileExistsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        audioItemId: audioItemId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _LocalMediaFileExistsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalMediaFileExistsProvider &&
        other.audioItemId == audioItemId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, audioItemId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LocalMediaFileExistsRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `audioItemId` of this provider.
  String get audioItemId;
}

class _LocalMediaFileExistsProviderElement
    extends AutoDisposeFutureProviderElement<bool>
    with LocalMediaFileExistsRef {
  _LocalMediaFileExistsProviderElement(super.provider);

  @override
  String get audioItemId =>
      (origin as LocalMediaFileExistsProvider).audioItemId;
}

String _$mediaReadinessHash() => r'4669444dd5e39da98826a74c1b08dbd0bb24f288';

/// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。
///
/// Copied from [mediaReadiness].
@ProviderFor(mediaReadiness)
const mediaReadinessProvider = MediaReadinessFamily();

/// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。
///
/// Copied from [mediaReadiness].
class MediaReadinessFamily extends Family<MediaReadiness> {
  /// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。
  ///
  /// Copied from [mediaReadiness].
  const MediaReadinessFamily();

  /// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。
  ///
  /// Copied from [mediaReadiness].
  MediaReadinessProvider call(String audioItemId) {
    return MediaReadinessProvider(audioItemId);
  }

  @override
  MediaReadinessProvider getProviderOverride(
    covariant MediaReadinessProvider provider,
  ) {
    return call(provider.audioItemId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'mediaReadinessProvider';
}

/// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。
///
/// Copied from [mediaReadiness].
class MediaReadinessProvider extends AutoDisposeProvider<MediaReadiness> {
  /// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。
  ///
  /// Copied from [mediaReadiness].
  MediaReadinessProvider(String audioItemId)
    : this._internal(
        (ref) => mediaReadiness(ref as MediaReadinessRef, audioItemId),
        from: mediaReadinessProvider,
        name: r'mediaReadinessProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$mediaReadinessHash,
        dependencies: MediaReadinessFamily._dependencies,
        allTransitiveDependencies:
            MediaReadinessFamily._allTransitiveDependencies,
        audioItemId: audioItemId,
      );

  MediaReadinessProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.audioItemId,
  }) : super.internal();

  final String audioItemId;

  @override
  Override overrideWith(
    MediaReadiness Function(MediaReadinessRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MediaReadinessProvider._internal(
        (ref) => create(ref as MediaReadinessRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        audioItemId: audioItemId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<MediaReadiness> createElement() {
    return _MediaReadinessProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaReadinessProvider && other.audioItemId == audioItemId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, audioItemId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MediaReadinessRef on AutoDisposeProviderRef<MediaReadiness> {
  /// The parameter `audioItemId` of this provider.
  String get audioItemId;
}

class _MediaReadinessProviderElement
    extends AutoDisposeProviderElement<MediaReadiness>
    with MediaReadinessRef {
  _MediaReadinessProviderElement(super.provider);

  @override
  String get audioItemId => (origin as MediaReadinessProvider).audioItemId;
}

String _$mediaDownloadSnapshotHash() =>
    r'1b56bf10a2c0d8cf301d0e07faac7244cf15eadb';

/// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。
///
/// Copied from [mediaDownloadSnapshot].
@ProviderFor(mediaDownloadSnapshot)
const mediaDownloadSnapshotProvider = MediaDownloadSnapshotFamily();

/// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。
///
/// Copied from [mediaDownloadSnapshot].
class MediaDownloadSnapshotFamily extends Family<MediaDownloadSnapshot?> {
  /// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。
  ///
  /// Copied from [mediaDownloadSnapshot].
  const MediaDownloadSnapshotFamily();

  /// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。
  ///
  /// Copied from [mediaDownloadSnapshot].
  MediaDownloadSnapshotProvider call(String audioItemId) {
    return MediaDownloadSnapshotProvider(audioItemId);
  }

  @override
  MediaDownloadSnapshotProvider getProviderOverride(
    covariant MediaDownloadSnapshotProvider provider,
  ) {
    return call(provider.audioItemId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'mediaDownloadSnapshotProvider';
}

/// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。
///
/// Copied from [mediaDownloadSnapshot].
class MediaDownloadSnapshotProvider
    extends AutoDisposeProvider<MediaDownloadSnapshot?> {
  /// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。
  ///
  /// Copied from [mediaDownloadSnapshot].
  MediaDownloadSnapshotProvider(String audioItemId)
    : this._internal(
        (ref) =>
            mediaDownloadSnapshot(ref as MediaDownloadSnapshotRef, audioItemId),
        from: mediaDownloadSnapshotProvider,
        name: r'mediaDownloadSnapshotProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$mediaDownloadSnapshotHash,
        dependencies: MediaDownloadSnapshotFamily._dependencies,
        allTransitiveDependencies:
            MediaDownloadSnapshotFamily._allTransitiveDependencies,
        audioItemId: audioItemId,
      );

  MediaDownloadSnapshotProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.audioItemId,
  }) : super.internal();

  final String audioItemId;

  @override
  Override overrideWith(
    MediaDownloadSnapshot? Function(MediaDownloadSnapshotRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MediaDownloadSnapshotProvider._internal(
        (ref) => create(ref as MediaDownloadSnapshotRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        audioItemId: audioItemId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<MediaDownloadSnapshot?> createElement() {
    return _MediaDownloadSnapshotProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaDownloadSnapshotProvider &&
        other.audioItemId == audioItemId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, audioItemId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MediaDownloadSnapshotRef
    on AutoDisposeProviderRef<MediaDownloadSnapshot?> {
  /// The parameter `audioItemId` of this provider.
  String get audioItemId;
}

class _MediaDownloadSnapshotProviderElement
    extends AutoDisposeProviderElement<MediaDownloadSnapshot?>
    with MediaDownloadSnapshotRef {
  _MediaDownloadSnapshotProviderElement(super.provider);

  @override
  String get audioItemId =>
      (origin as MediaDownloadSnapshotProvider).audioItemId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
