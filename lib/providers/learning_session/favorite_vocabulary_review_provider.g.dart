// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_vocabulary_review_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FavoriteVocabularyReview)
final favoriteVocabularyReviewProvider = FavoriteVocabularyReviewProvider._();

final class FavoriteVocabularyReviewProvider
    extends
        $NotifierProvider<
          FavoriteVocabularyReview,
          FavoriteVocabularyReviewState
        > {
  FavoriteVocabularyReviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoriteVocabularyReviewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoriteVocabularyReviewHash();

  @$internal
  @override
  FavoriteVocabularyReview create() => FavoriteVocabularyReview();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FavoriteVocabularyReviewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FavoriteVocabularyReviewState>(
        value,
      ),
    );
  }
}

String _$favoriteVocabularyReviewHash() =>
    r'39314fc7ebf70faa8470743be3edb9fd628afa4b';

abstract class _$FavoriteVocabularyReview
    extends $Notifier<FavoriteVocabularyReviewState> {
  FavoriteVocabularyReviewState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              FavoriteVocabularyReviewState,
              FavoriteVocabularyReviewState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                FavoriteVocabularyReviewState,
                FavoriteVocabularyReviewState
              >,
              FavoriteVocabularyReviewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
