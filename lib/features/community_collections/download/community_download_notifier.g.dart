// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_download_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 社区合集媒体和字幕下载调度器。
///
/// 状态按条目（audioItemId）保存：不同条目可以同时下载，超出并发的由下载队列排队；
/// 同一条目重复请求不会建第二个任务。

@ProviderFor(CommunityDownload)
final communityDownloadProvider = CommunityDownloadProvider._();

/// 社区合集媒体和字幕下载调度器。
///
/// 状态按条目（audioItemId）保存：不同条目可以同时下载，超出并发的由下载队列排队；
/// 同一条目重复请求不会建第二个任务。
final class CommunityDownloadProvider
    extends
        $NotifierProvider<CommunityDownload, Map<String, DownloadProgress>> {
  /// 社区合集媒体和字幕下载调度器。
  ///
  /// 状态按条目（audioItemId）保存：不同条目可以同时下载，超出并发的由下载队列排队；
  /// 同一条目重复请求不会建第二个任务。
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
  Override overrideWithValue(Map<String, DownloadProgress> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, DownloadProgress>>(
        value,
      ),
    );
  }
}

String _$communityDownloadHash() => r'59bdb46141ca9272b5456ac650bfb8da5a205d3c';

/// 社区合集媒体和字幕下载调度器。
///
/// 状态按条目（audioItemId）保存：不同条目可以同时下载，超出并发的由下载队列排队；
/// 同一条目重复请求不会建第二个任务。

abstract class _$CommunityDownload
    extends $Notifier<Map<String, DownloadProgress>> {
  Map<String, DownloadProgress> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<String, DownloadProgress>,
              Map<String, DownloadProgress>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, DownloadProgress>,
                Map<String, DownloadProgress>
              >,
              Map<String, DownloadProgress>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
