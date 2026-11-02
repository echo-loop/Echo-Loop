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
        isAutoDispose: true,
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
    r'89bb3214ffdd3585eb2361a753a6562cac7725de';

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

@ProviderFor(PodcastDownloadController)
final podcastDownloadControllerProvider = PodcastDownloadControllerProvider._();

/// Podcast 单集懒下载控制器。
///
/// 与 [AudioImportController]（从链接导入）**完全独立**：两条流程各自持有状态，
/// 一方的下载失败不会污染另一方的 UI（避免播客下载失败后，打开「从链接导入」
/// 误显下载失败提示）。复用同一套 [AudioImportState] 模型类。
final class PodcastDownloadControllerProvider
    extends $NotifierProvider<PodcastDownloadController, AudioImportState> {
  /// Podcast 单集懒下载控制器。
  ///
  /// 与 [AudioImportController]（从链接导入）**完全独立**：两条流程各自持有状态，
  /// 一方的下载失败不会污染另一方的 UI（避免播客下载失败后，打开「从链接导入」
  /// 误显下载失败提示）。复用同一套 [AudioImportState] 模型类。
  PodcastDownloadControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'podcastDownloadControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$podcastDownloadControllerHash();

  @$internal
  @override
  PodcastDownloadController create() => PodcastDownloadController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioImportState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioImportState>(value),
    );
  }
}

String _$podcastDownloadControllerHash() =>
    r'c834b3a7d27fe38f1ee513ca474534d7f86af38f';

/// Podcast 单集懒下载控制器。
///
/// 与 [AudioImportController]（从链接导入）**完全独立**：两条流程各自持有状态，
/// 一方的下载失败不会污染另一方的 UI（避免播客下载失败后，打开「从链接导入」
/// 误显下载失败提示）。复用同一套 [AudioImportState] 模型类。

abstract class _$PodcastDownloadController extends $Notifier<AudioImportState> {
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
