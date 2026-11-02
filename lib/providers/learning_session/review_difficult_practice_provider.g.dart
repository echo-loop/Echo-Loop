// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_difficult_practice_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 难句补练 Provider

@ProviderFor(ReviewDifficultPractice)
final reviewDifficultPracticeProvider = ReviewDifficultPracticeProvider._();

/// 难句补练 Provider
final class ReviewDifficultPracticeProvider
    extends
        $NotifierProvider<
          ReviewDifficultPractice,
          ReviewDifficultPracticeState
        > {
  /// 难句补练 Provider
  ReviewDifficultPracticeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reviewDifficultPracticeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reviewDifficultPracticeHash();

  @$internal
  @override
  ReviewDifficultPractice create() => ReviewDifficultPractice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReviewDifficultPracticeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReviewDifficultPracticeState>(value),
    );
  }
}

String _$reviewDifficultPracticeHash() =>
    r'4505c79a8036ba3156f463083c31cf89745a7161';

/// 难句补练 Provider

abstract class _$ReviewDifficultPractice
    extends $Notifier<ReviewDifficultPracticeState> {
  ReviewDifficultPracticeState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<ReviewDifficultPracticeState, ReviewDifficultPracticeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ReviewDifficultPracticeState,
                ReviewDifficultPracticeState
              >,
              ReviewDifficultPracticeState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
