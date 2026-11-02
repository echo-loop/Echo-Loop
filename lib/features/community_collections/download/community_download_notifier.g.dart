// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_download_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 社区合集媒体和字幕下载调度器；同一时刻只运行一个任务。

@ProviderFor(CommunityDownload)
final communityDownloadProvider = CommunityDownloadProvider._();

/// 社区合集媒体和字幕下载调度器；同一时刻只运行一个任务。
final class CommunityDownloadProvider
    extends $NotifierProvider<CommunityDownload, DownloadProgress> {
  /// 社区合集媒体和字幕下载调度器；同一时刻只运行一个任务。
  CommunityDownloadProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'communityDownloadProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$communityDownloadHash();

  @$internal
  @override
  CommunityDownload create() => CommunityDownload();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadProgress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadProgress>(value),
    );
  }
}

String _$communityDownloadHash() => r'6955a235d5fd2a047dbbea66fc9ae6723356f817';

/// 社区合集媒体和字幕下载调度器；同一时刻只运行一个任务。

abstract class _$CommunityDownload extends $Notifier<DownloadProgress> {
  DownloadProgress build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DownloadProgress, DownloadProgress>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DownloadProgress, DownloadProgress>,
              DownloadProgress,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
