// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'featured_podcasts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 管理精选 Podcast 的缓存恢复、页面刷新和游标分页。

@ProviderFor(FeaturedPodcasts)
final featuredPodcastsProvider = FeaturedPodcastsProvider._();

/// 管理精选 Podcast 的缓存恢复、页面刷新和游标分页。
final class FeaturedPodcastsProvider
    extends
        $AsyncNotifierProvider<
          FeaturedPodcasts,
          FeaturedPodcastDiscoveryState
        > {
  /// 管理精选 Podcast 的缓存恢复、页面刷新和游标分页。
  FeaturedPodcastsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featuredPodcastsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featuredPodcastsHash();

  @$internal
  @override
  FeaturedPodcasts create() => FeaturedPodcasts();
}

String _$featuredPodcastsHash() => r'f978129361e0297339edbd90c9a7c1c702e04258';

/// 管理精选 Podcast 的缓存恢复、页面刷新和游标分页。

abstract class _$FeaturedPodcasts
    extends $AsyncNotifier<FeaturedPodcastDiscoveryState> {
  FutureOr<FeaturedPodcastDiscoveryState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<FeaturedPodcastDiscoveryState>,
              FeaturedPodcastDiscoveryState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<FeaturedPodcastDiscoveryState>,
                FeaturedPodcastDiscoveryState
              >,
              AsyncValue<FeaturedPodcastDiscoveryState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
