// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$studyStatsNotifierHash() =>
    r'0922e22015e9fae4f7be9c2eddb287717db86997';

/// 学习统计 Provider
///
/// 聚合 streak、今日时长、本周时长、7 天每日时长。
///
/// Copied from [StudyStatsNotifier].
@ProviderFor(StudyStatsNotifier)
final studyStatsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<StudyStatsNotifier, StudyStats>.internal(
      StudyStatsNotifier.new,
      name: r'studyStatsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$studyStatsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$StudyStatsNotifier = AutoDisposeAsyncNotifier<StudyStats>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
