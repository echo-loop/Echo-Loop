// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_readiness_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
///
/// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
/// 否则计划页会在就绪与校验中之间来回切换。

@ProviderFor(localMediaFileExists)
final localMediaFileExistsProvider = LocalMediaFileExistsFamily._();

/// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
///
/// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
/// 否则计划页会在就绪与校验中之间来回切换。

final class LocalMediaFileExistsProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
  ///
  /// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
  /// 否则计划页会在就绪与校验中之间来回切换。
  LocalMediaFileExistsProvider._({
    required LocalMediaFileExistsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'localMediaFileExistsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$localMediaFileExistsHash();

  @override
  String toString() {
    return r'localMediaFileExistsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return localMediaFileExists(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalMediaFileExistsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$localMediaFileExistsHash() =>
    r'05324f23aed5d8273f3ae97931a3783bfea404f4';

/// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
///
/// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
/// 否则计划页会在就绪与校验中之间来回切换。

final class LocalMediaFileExistsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  LocalMediaFileExistsFamily._()
    : super(
        retry: null,
        name: r'localMediaFileExistsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
  ///
  /// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
  /// 否则计划页会在就绪与校验中之间来回切换。

  LocalMediaFileExistsProvider call(String audioItemId) =>
      LocalMediaFileExistsProvider._(argument: audioItemId, from: this);

  @override
  String toString() => r'localMediaFileExistsProvider';
}

/// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。

@ProviderFor(mediaReadiness)
final mediaReadinessProvider = MediaReadinessFamily._();

/// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。

final class MediaReadinessProvider
    extends $FunctionalProvider<MediaReadiness, MediaReadiness, MediaReadiness>
    with $Provider<MediaReadiness> {
  /// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。
  MediaReadinessProvider._({
    required MediaReadinessFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mediaReadinessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaReadinessHash();

  @override
  String toString() {
    return r'mediaReadinessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<MediaReadiness> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaReadiness create(Ref ref) {
    final argument = this.argument as String;
    return mediaReadiness(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaReadiness value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaReadiness>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MediaReadinessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaReadinessHash() => r'f416bedc0d4c0406ad8fc68d11de13035fee3912';

/// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。

final class MediaReadinessFamily extends $Family
    with $FunctionalFamilyOverride<MediaReadiness, String> {
  MediaReadinessFamily._()
    : super(
        retry: null,
        name: r'mediaReadinessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。

  MediaReadinessProvider call(String audioItemId) =>
      MediaReadinessProvider._(argument: audioItemId, from: this);

  @override
  String toString() => r'mediaReadinessProvider';
}

/// 列表行是否显示"排队中"；与计划页使用同一判断。

@ProviderFor(mediaDownloadQueued)
final mediaDownloadQueuedProvider = MediaDownloadQueuedFamily._();

/// 列表行是否显示"排队中"；与计划页使用同一判断。

final class MediaDownloadQueuedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// 列表行是否显示"排队中"；与计划页使用同一判断。
  MediaDownloadQueuedProvider._({
    required MediaDownloadQueuedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mediaDownloadQueuedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaDownloadQueuedHash();

  @override
  String toString() {
    return r'mediaDownloadQueuedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return mediaDownloadQueued(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MediaDownloadQueuedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaDownloadQueuedHash() =>
    r'645d9ae5b35a3dadcff9c3861773854fa0c789d2';

/// 列表行是否显示"排队中"；与计划页使用同一判断。

final class MediaDownloadQueuedFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  MediaDownloadQueuedFamily._()
    : super(
        retry: null,
        name: r'mediaDownloadQueuedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 列表行是否显示"排队中"；与计划页使用同一判断。

  MediaDownloadQueuedProvider call(String audioItemId) =>
      MediaDownloadQueuedProvider._(argument: audioItemId, from: this);

  @override
  String toString() => r'mediaDownloadQueuedProvider';
}

/// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。

@ProviderFor(mediaDownloadSnapshot)
final mediaDownloadSnapshotProvider = MediaDownloadSnapshotFamily._();

/// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。

final class MediaDownloadSnapshotProvider
    extends
        $FunctionalProvider<
          MediaDownloadSnapshot?,
          MediaDownloadSnapshot?,
          MediaDownloadSnapshot?
        >
    with $Provider<MediaDownloadSnapshot?> {
  /// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。
  MediaDownloadSnapshotProvider._({
    required MediaDownloadSnapshotFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mediaDownloadSnapshotProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaDownloadSnapshotHash();

  @override
  String toString() {
    return r'mediaDownloadSnapshotProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<MediaDownloadSnapshot?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaDownloadSnapshot? create(Ref ref) {
    final argument = this.argument as String;
    return mediaDownloadSnapshot(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaDownloadSnapshot? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaDownloadSnapshot?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MediaDownloadSnapshotProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaDownloadSnapshotHash() =>
    r'3428b885660f71b347631e1118eb1c1f8a6194ac';

/// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。

final class MediaDownloadSnapshotFamily extends $Family
    with $FunctionalFamilyOverride<MediaDownloadSnapshot?, String> {
  MediaDownloadSnapshotFamily._()
    : super(
        retry: null,
        name: r'mediaDownloadSnapshotProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。

  MediaDownloadSnapshotProvider call(String audioItemId) =>
      MediaDownloadSnapshotProvider._(argument: audioItemId, from: this);

  @override
  String toString() => r'mediaDownloadSnapshotProvider';
}
