// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_statistics_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReviewStatisticsNotifier)
final reviewStatisticsProvider = ReviewStatisticsNotifierProvider._();

final class ReviewStatisticsNotifierProvider
    extends $AsyncNotifierProvider<ReviewStatisticsNotifier, ReviewStatistics> {
  ReviewStatisticsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reviewStatisticsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reviewStatisticsNotifierHash();

  @$internal
  @override
  ReviewStatisticsNotifier create() => ReviewStatisticsNotifier();
}

String _$reviewStatisticsNotifierHash() =>
    r'156bf95798451cd3f095e2789e2b20cd7440825f';

abstract class _$ReviewStatisticsNotifier
    extends $AsyncNotifier<ReviewStatistics> {
  FutureOr<ReviewStatistics> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ReviewStatistics>, ReviewStatistics>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReviewStatistics>, ReviewStatistics>,
              AsyncValue<ReviewStatistics>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
