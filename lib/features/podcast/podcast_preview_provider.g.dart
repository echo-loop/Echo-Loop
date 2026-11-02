// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_preview_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(podcastPreviewDio)
final podcastPreviewDioProvider = PodcastPreviewDioProvider._();

final class PodcastPreviewDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  PodcastPreviewDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'podcastPreviewDioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$podcastPreviewDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return podcastPreviewDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$podcastPreviewDioHash() => r'd8157347c67dc475ff8a48aa09ff8e383fc1becd';

@ProviderFor(podcastPreviewService)
final podcastPreviewServiceProvider = PodcastPreviewServiceProvider._();

final class PodcastPreviewServiceProvider
    extends
        $FunctionalProvider<
          PodcastPreviewService,
          PodcastPreviewService,
          PodcastPreviewService
        >
    with $Provider<PodcastPreviewService> {
  PodcastPreviewServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'podcastPreviewServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$podcastPreviewServiceHash();

  @$internal
  @override
  $ProviderElement<PodcastPreviewService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PodcastPreviewService create(Ref ref) {
    return podcastPreviewService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PodcastPreviewService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PodcastPreviewService>(value),
    );
  }
}

String _$podcastPreviewServiceHash() =>
    r'210ca30412d93b2b7114e967a28c229c4ee304be';

/// 由订阅输入 URL 拉取单个 Podcast 的 RSS 预览。
///
/// [inputUrl] 为 RSS 或 Apple Podcasts 链接，同时用作 family key，
/// 天然按来源缓存并防竞态。

@ProviderFor(podcastPreview)
final podcastPreviewProvider = PodcastPreviewFamily._();

/// 由订阅输入 URL 拉取单个 Podcast 的 RSS 预览。
///
/// [inputUrl] 为 RSS 或 Apple Podcasts 链接，同时用作 family key，
/// 天然按来源缓存并防竞态。

final class PodcastPreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<PodcastPreviewData>,
          PodcastPreviewData,
          FutureOr<PodcastPreviewData>
        >
    with
        $FutureModifier<PodcastPreviewData>,
        $FutureProvider<PodcastPreviewData> {
  /// 由订阅输入 URL 拉取单个 Podcast 的 RSS 预览。
  ///
  /// [inputUrl] 为 RSS 或 Apple Podcasts 链接，同时用作 family key，
  /// 天然按来源缓存并防竞态。
  PodcastPreviewProvider._({
    required PodcastPreviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'podcastPreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$podcastPreviewHash();

  @override
  String toString() {
    return r'podcastPreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PodcastPreviewData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PodcastPreviewData> create(Ref ref) {
    final argument = this.argument as String;
    return podcastPreview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PodcastPreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$podcastPreviewHash() => r'da4544329963232118faedcadcfadc7904702d0d';

/// 由订阅输入 URL 拉取单个 Podcast 的 RSS 预览。
///
/// [inputUrl] 为 RSS 或 Apple Podcasts 链接，同时用作 family key，
/// 天然按来源缓存并防竞态。

final class PodcastPreviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PodcastPreviewData>, String> {
  PodcastPreviewFamily._()
    : super(
        retry: null,
        name: r'podcastPreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 由订阅输入 URL 拉取单个 Podcast 的 RSS 预览。
  ///
  /// [inputUrl] 为 RSS 或 Apple Podcasts 链接，同时用作 family key，
  /// 天然按来源缓存并防竞态。

  PodcastPreviewProvider call(String inputUrl) =>
      PodcastPreviewProvider._(argument: inputUrl, from: this);

  @override
  String toString() => r'podcastPreviewProvider';
}
