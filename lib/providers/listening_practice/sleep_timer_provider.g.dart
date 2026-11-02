// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_timer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 自由播放器的睡眠定时器（定时停止）。
///
/// 一次性运行态，与循环/倍速等持久化偏好物理隔离。autoDispose：仅在 Free Player
/// 页面（AppBar 按钮监听）期间存活，离开页面按钮卸载即销毁、自动取消计时——天然
/// 实现「离开页面即取消」与「一次性」语义。
///
/// 采用**墙钟**倒计时：记录目标结束时刻 [_endTime]，[Timer.periodic] 每秒按
/// `endTime - now` 重算剩余，归零时调用 [ListeningPractice.pause] 暂停（可续播）。
/// App 切后台被挂起后回前台，下一 tick 仍按墙钟对齐，无漂移。
///
/// 防竞态（见 CLAUDE.md 2.5 / 7.1）：每次 start/cancel 递增 [_generation]，
/// periodic 回调闭包捕获当时的 generation，不匹配即丢弃，避免被替换的旧计时器误触发。

@ProviderFor(SleepTimer)
final sleepTimerProvider = SleepTimerProvider._();

/// 自由播放器的睡眠定时器（定时停止）。
///
/// 一次性运行态，与循环/倍速等持久化偏好物理隔离。autoDispose：仅在 Free Player
/// 页面（AppBar 按钮监听）期间存活，离开页面按钮卸载即销毁、自动取消计时——天然
/// 实现「离开页面即取消」与「一次性」语义。
///
/// 采用**墙钟**倒计时：记录目标结束时刻 [_endTime]，[Timer.periodic] 每秒按
/// `endTime - now` 重算剩余，归零时调用 [ListeningPractice.pause] 暂停（可续播）。
/// App 切后台被挂起后回前台，下一 tick 仍按墙钟对齐，无漂移。
///
/// 防竞态（见 CLAUDE.md 2.5 / 7.1）：每次 start/cancel 递增 [_generation]，
/// periodic 回调闭包捕获当时的 generation，不匹配即丢弃，避免被替换的旧计时器误触发。
final class SleepTimerProvider
    extends $NotifierProvider<SleepTimer, SleepTimerState> {
  /// 自由播放器的睡眠定时器（定时停止）。
  ///
  /// 一次性运行态，与循环/倍速等持久化偏好物理隔离。autoDispose：仅在 Free Player
  /// 页面（AppBar 按钮监听）期间存活，离开页面按钮卸载即销毁、自动取消计时——天然
  /// 实现「离开页面即取消」与「一次性」语义。
  ///
  /// 采用**墙钟**倒计时：记录目标结束时刻 [_endTime]，[Timer.periodic] 每秒按
  /// `endTime - now` 重算剩余，归零时调用 [ListeningPractice.pause] 暂停（可续播）。
  /// App 切后台被挂起后回前台，下一 tick 仍按墙钟对齐，无漂移。
  ///
  /// 防竞态（见 CLAUDE.md 2.5 / 7.1）：每次 start/cancel 递增 [_generation]，
  /// periodic 回调闭包捕获当时的 generation，不匹配即丢弃，避免被替换的旧计时器误触发。
  SleepTimerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepTimerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepTimerHash();

  @$internal
  @override
  SleepTimer create() => SleepTimer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SleepTimerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SleepTimerState>(value),
    );
  }
}

String _$sleepTimerHash() => r'89301be0a9b317627114c765cb77949e8328fda1';

/// 自由播放器的睡眠定时器（定时停止）。
///
/// 一次性运行态，与循环/倍速等持久化偏好物理隔离。autoDispose：仅在 Free Player
/// 页面（AppBar 按钮监听）期间存活，离开页面按钮卸载即销毁、自动取消计时——天然
/// 实现「离开页面即取消」与「一次性」语义。
///
/// 采用**墙钟**倒计时：记录目标结束时刻 [_endTime]，[Timer.periodic] 每秒按
/// `endTime - now` 重算剩余，归零时调用 [ListeningPractice.pause] 暂停（可续播）。
/// App 切后台被挂起后回前台，下一 tick 仍按墙钟对齐，无漂移。
///
/// 防竞态（见 CLAUDE.md 2.5 / 7.1）：每次 start/cancel 递增 [_generation]，
/// periodic 回调闭包捕获当时的 generation，不匹配即丢弃，避免被替换的旧计时器误触发。

abstract class _$SleepTimer extends $Notifier<SleepTimerState> {
  SleepTimerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SleepTimerState, SleepTimerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SleepTimerState, SleepTimerState>,
              SleepTimerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
