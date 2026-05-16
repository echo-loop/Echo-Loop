// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'official_download_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$officialDownloadHash() => r'0f72332d714e5c0a8267428456dfd4dee89c701c';

/// 全局官方合集音频下载调度器。
///
/// MVP 并发约束：同一时刻最多 1 个任务。新请求到来时若已有任务在跑，
/// 返回 [StartResult.busy]，UI 层给 snackbar 提示而不启动新任务。
///
/// 防竞态：每次 start 递增 `_sessionId`，所有异步回调（progress / result）
/// 都 check 当前 sessionId 是否过期。遵循项目 ADR-3 约束。
///
/// Copied from [OfficialDownload].
@ProviderFor(OfficialDownload)
final officialDownloadProvider =
    NotifierProvider<OfficialDownload, DownloadProgress>.internal(
      OfficialDownload.new,
      name: r'officialDownloadProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$officialDownloadHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OfficialDownload = Notifier<DownloadProgress>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
