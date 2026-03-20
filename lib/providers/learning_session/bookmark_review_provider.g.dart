// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark_review_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bookmarkReviewHash() => r'd324102b4b01bed122bac9a73547b2f776cc5075';

/// 收藏复习 Provider
///
/// 复用 [ReviewDifficultPracticeState] 作为状态类。
/// 内部维护 [List<BookmarkSentence>] 用于跨音频播放。
///
/// Copied from [BookmarkReview].
@ProviderFor(BookmarkReview)
final bookmarkReviewProvider =
    NotifierProvider<BookmarkReview, ReviewDifficultPracticeState>.internal(
      BookmarkReview.new,
      name: r'bookmarkReviewProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$bookmarkReviewHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BookmarkReview = Notifier<ReviewDifficultPracticeState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
