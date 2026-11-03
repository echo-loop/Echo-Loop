// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_import_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(audioImportService)
final audioImportServiceProvider = AudioImportServiceProvider._();

final class AudioImportServiceProvider
    extends
        $FunctionalProvider<
          AudioImportService,
          AudioImportService,
          AudioImportService
        >
    with $Provider<AudioImportService> {
  AudioImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioImportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioImportServiceHash();

  @$internal
  @override
  $ProviderElement<AudioImportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioImportService create(Ref ref) {
    return audioImportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioImportService>(value),
    );
  }
}

String _$audioImportServiceHash() =>
    r'e2f957e79a4bc80d64725177faa6e97b20c6faec';

@ProviderFor(AudioImportController)
final audioImportControllerProvider = AudioImportControllerProvider._();

final class AudioImportControllerProvider
    extends $NotifierProvider<AudioImportController, AudioImportState> {
  AudioImportControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioImportControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioImportControllerHash();

  @$internal
  @override
  AudioImportController create() => AudioImportController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioImportState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioImportState>(value),
    );
  }
}

String _$audioImportControllerHash() =>
    r'17da01d2d262dc8a298c2049098c870441eb79f5';

abstract class _$AudioImportController extends $Notifier<AudioImportState> {
  AudioImportState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AudioImportState, AudioImportState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AudioImportState, AudioImportState>,
              AudioImportState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Podcast 单集懒下载控制器。
///
/// 与 [AudioImportController]（从链接导入）**完全独立**：两条流程各自持有状态，
/// 一方的下载失败不会污染另一方的 UI（避免播客下载失败后，打开「从链接导入」
/// 误显下载失败提示）。复用同一套 [AudioImportState] 模型类。
// keepAlive：同 AudioImportController，离开页面后下载继续。

@ProviderFor(PodcastDownloadController)
final podcastDownloadControllerProvider = PodcastDownloadControllerProvider._();

/// Podcast 单集懒下载控制器。
///
/// 与 [AudioImportController]（从链接导入）**完全独立**：两条流程各自持有状态，
/// 一方的下载失败不会污染另一方的 UI（避免播客下载失败后，打开「从链接导入」
/// 误显下载失败提示）。复用同一套 [AudioImportState] 模型类。
// keepAlive：同 AudioImportController，离开页面后下载继续。
final class PodcastDownloadControllerProvider
    extends
        $NotifierProvider<
          PodcastDownloadController,
          Map<String, AudioImportState>
        > {
  /// Podcast 单集懒下载控制器。
  ///
  /// 与 [AudioImportController]（从链接导入）**完全独立**：两条流程各自持有状态，
  /// 一方的下载失败不会污染另一方的 UI（避免播客下载失败后，打开「从链接导入」
  /// 误显下载失败提示）。复用同一套 [AudioImportState] 模型类。
  // keepAlive：同 AudioImportController，离开页面后下载继续。
  PodcastDownloadControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'podcastDownloadControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$podcastDownloadControllerHash();

  @$internal
  @override
  PodcastDownloadController create() => PodcastDownloadController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, AudioImportState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, AudioImportState>>(
        value,
      ),
    );
  }
}

String _$podcastDownloadControllerHash() =>
    r'62f2a02a4129f020df4baf5d42794befc0e8ab69';

/// Podcast 单集懒下载控制器。
///
/// 与 [AudioImportController]（从链接导入）**完全独立**：两条流程各自持有状态，
/// 一方的下载失败不会污染另一方的 UI（避免播客下载失败后，打开「从链接导入」
/// 误显下载失败提示）。复用同一套 [AudioImportState] 模型类。
// keepAlive：同 AudioImportController，离开页面后下载继续。

abstract class _$PodcastDownloadController
    extends $Notifier<Map<String, AudioImportState>> {
  Map<String, AudioImportState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<String, AudioImportState>,
              Map<String, AudioImportState>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, AudioImportState>,
                Map<String, AudioImportState>
              >,
              Map<String, AudioImportState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
