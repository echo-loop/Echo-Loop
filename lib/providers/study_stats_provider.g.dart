// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 学习统计 Provider
///
/// 聚合 streak、今日时长、本周时长、7 天每日时长。

@ProviderFor(StudyStatsNotifier)
final studyStatsProvider = StudyStatsNotifierProvider._();

/// 学习统计 Provider
///
/// 聚合 streak、今日时长、本周时长、7 天每日时长。
final class StudyStatsNotifierProvider
    extends $AsyncNotifierProvider<StudyStatsNotifier, StudyStats> {
  /// 学习统计 Provider
  ///
  /// 聚合 streak、今日时长、本周时长、7 天每日时长。
  StudyStatsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studyStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studyStatsNotifierHash();

  @$internal
  @override
  StudyStatsNotifier create() => StudyStatsNotifier();
}

String _$studyStatsNotifierHash() =>
    r'10eff22265d975cc3c259eb7cf54d92e838e27ee';

/// 学习统计 Provider
///
/// 聚合 streak、今日时长、本周时长、7 天每日时长。

abstract class _$StudyStatsNotifier extends $AsyncNotifier<StudyStats> {
  FutureOr<StudyStats> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<StudyStats>, StudyStats>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<StudyStats>, StudyStats>,
              AsyncValue<StudyStats>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
