// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_difficult_practice_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reviewDifficultPracticeHash() =>
    r'a64c07a54ce79072c059a6136371163d6e9fdc79';

/// 难句补练 Provider
///
/// 组合 SentencePlaybackEngine 实现盲听→自动推进的逐句训练循环。
/// 用户可偷看字幕或进入标注模式（听不懂），交互与精听一致。
///
/// Copied from [ReviewDifficultPractice].
@ProviderFor(ReviewDifficultPractice)
final reviewDifficultPracticeProvider =
    NotifierProvider<
      ReviewDifficultPractice,
      ReviewDifficultPracticeState
    >.internal(
      ReviewDifficultPractice.new,
      name: r'reviewDifficultPracticeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$reviewDifficultPracticeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReviewDifficultPractice = Notifier<ReviewDifficultPracticeState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
