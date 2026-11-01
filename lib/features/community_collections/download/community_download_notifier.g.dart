// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_download_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$communityDownloadHash() => r'd2ac79bb336469c3fd62f1d3d43bc89baf1851a7';

/// 社区合集媒体和字幕下载调度器；同一时刻只运行一个任务。
///
/// Copied from [CommunityDownload].
@ProviderFor(CommunityDownload)
final communityDownloadProvider =
    NotifierProvider<CommunityDownload, DownloadProgress>.internal(
      CommunityDownload.new,
      name: r'communityDownloadProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$communityDownloadHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CommunityDownload = Notifier<DownloadProgress>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
