import 'package:clock/clock.dart';

/// 向前推进时间的回调，单位为相对于真实时间的偏移量。
typedef ClockAdvancer = void Function(Duration by);

/// 在真实时间基础上可手动前跳的 package:clock 时钟。
///
/// 学习时长由 `clock.stopwatch()` 计量。这类用例还要等待真实数据库写入完成，
/// 无法放进 fakeAsync；用手动偏移代替真实 sleep，既保留真实异步又不必等待。
Future<T> runWithSkewedClock<T>(
  Future<T> Function(ClockAdvancer advance) body,
) {
  var skew = Duration.zero;
  return withClock(Clock(() => DateTime.now().add(skew)), () {
    return body((by) {
      skew += by;
    });
  });
}
