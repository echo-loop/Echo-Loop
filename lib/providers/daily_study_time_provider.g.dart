// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_study_time_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 今日学习时长 Provider（秒）
///
/// 从 SQLite 读取今日累计学习秒数。
/// 每次进入/退出学习模式后刷新。

@ProviderFor(DailyStudyTime)
final dailyStudyTimeProvider = DailyStudyTimeProvider._();

/// 今日学习时长 Provider（秒）
///
/// 从 SQLite 读取今日累计学习秒数。
/// 每次进入/退出学习模式后刷新。
final class DailyStudyTimeProvider
    extends $AsyncNotifierProvider<DailyStudyTime, int> {
  /// 今日学习时长 Provider（秒）
  ///
  /// 从 SQLite 读取今日累计学习秒数。
  /// 每次进入/退出学习模式后刷新。
  DailyStudyTimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyStudyTimeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyStudyTimeHash();

  @$internal
  @override
  DailyStudyTime create() => DailyStudyTime();
}

String _$dailyStudyTimeHash() => r'722707d40228995ac80f305bef2362d22958b2a2';

/// 今日学习时长 Provider（秒）
///
/// 从 SQLite 读取今日累计学习秒数。
/// 每次进入/退出学习模式后刷新。

abstract class _$DailyStudyTime extends $AsyncNotifier<int> {
  FutureOr<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
