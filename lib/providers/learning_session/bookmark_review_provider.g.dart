// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark_review_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BookmarkReview)
final bookmarkReviewProvider = BookmarkReviewProvider._();

final class BookmarkReviewProvider
    extends $NotifierProvider<BookmarkReview, BookmarkReviewState> {
  BookmarkReviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarkReviewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarkReviewHash();

  @$internal
  @override
  BookmarkReview create() => BookmarkReview();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookmarkReviewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookmarkReviewState>(value),
    );
  }
}

String _$bookmarkReviewHash() => r'a579026d9def14ff8145ef03be2f077f00be44a6';

abstract class _$BookmarkReview extends $Notifier<BookmarkReviewState> {
  BookmarkReviewState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BookmarkReviewState, BookmarkReviewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BookmarkReviewState, BookmarkReviewState>,
              BookmarkReviewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
