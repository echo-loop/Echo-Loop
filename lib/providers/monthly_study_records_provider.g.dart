// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_study_records_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 查询指定月份的每日学习记录
///
/// 返回 `Map<int, MonthDayRecord>`，key 为日期（1~31），
/// 无记录的日期不在 map 中。

@ProviderFor(monthlyStudyRecords)
final monthlyStudyRecordsProvider = MonthlyStudyRecordsFamily._();

/// 查询指定月份的每日学习记录
///
/// 返回 `Map<int, MonthDayRecord>`，key 为日期（1~31），
/// 无记录的日期不在 map 中。

final class MonthlyStudyRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, MonthDayRecord>>,
          Map<int, MonthDayRecord>,
          FutureOr<Map<int, MonthDayRecord>>
        >
    with
        $FutureModifier<Map<int, MonthDayRecord>>,
        $FutureProvider<Map<int, MonthDayRecord>> {
  /// 查询指定月份的每日学习记录
  ///
  /// 返回 `Map<int, MonthDayRecord>`，key 为日期（1~31），
  /// 无记录的日期不在 map 中。
  MonthlyStudyRecordsProvider._({
    required MonthlyStudyRecordsFamily super.from,
    required (int, int) super.argument,
  }) : super(
         retry: null,
         name: r'monthlyStudyRecordsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monthlyStudyRecordsHash();

  @override
  String toString() {
    return r'monthlyStudyRecordsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Map<int, MonthDayRecord>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, MonthDayRecord>> create(Ref ref) {
    final argument = this.argument as (int, int);
    return monthlyStudyRecords(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthlyStudyRecordsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monthlyStudyRecordsHash() =>
    r'3b05a4e497835f71794d7ac4580ab82aee563e26';

/// 查询指定月份的每日学习记录
///
/// 返回 `Map<int, MonthDayRecord>`，key 为日期（1~31），
/// 无记录的日期不在 map 中。

final class MonthlyStudyRecordsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<int, MonthDayRecord>>,
          (int, int)
        > {
  MonthlyStudyRecordsFamily._()
    : super(
        retry: null,
        name: r'monthlyStudyRecordsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 查询指定月份的每日学习记录
  ///
  /// 返回 `Map<int, MonthDayRecord>`，key 为日期（1~31），
  /// 无记录的日期不在 map 中。

  MonthlyStudyRecordsProvider call(int year, int month) =>
      MonthlyStudyRecordsProvider._(argument: (year, month), from: this);

  @override
  String toString() => r'monthlyStudyRecordsProvider';
}
