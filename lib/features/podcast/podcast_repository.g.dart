// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 播客仓库由 app 作用域持有：它持有 [Ref] 并在后台刷新（订阅启动刷新、回前台刷新）
/// 的异步 continuation 中继续读取 provider，不能因无人监听而被 autoDispose。

@ProviderFor(podcastRepository)
final podcastRepositoryProvider = PodcastRepositoryProvider._();

/// 播客仓库由 app 作用域持有：它持有 [Ref] 并在后台刷新（订阅启动刷新、回前台刷新）
/// 的异步 continuation 中继续读取 provider，不能因无人监听而被 autoDispose。

final class PodcastRepositoryProvider
    extends
        $FunctionalProvider<
          PodcastRepository,
          PodcastRepository,
          PodcastRepository
        >
    with $Provider<PodcastRepository> {
  /// 播客仓库由 app 作用域持有：它持有 [Ref] 并在后台刷新（订阅启动刷新、回前台刷新）
  /// 的异步 continuation 中继续读取 provider，不能因无人监听而被 autoDispose。
  PodcastRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'podcastRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$podcastRepositoryHash();

  @$internal
  @override
  $ProviderElement<PodcastRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PodcastRepository create(Ref ref) {
    return podcastRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PodcastRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PodcastRepository>(value),
    );
  }
}

String _$podcastRepositoryHash() => r'e0984a4ede3fe8002bdfd759d27b3a2b4f8ae480';
