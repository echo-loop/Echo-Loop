import 'dart:async';
import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/sleep_timer_state.dart';
import 'listening_practice_provider.dart';
import 'package:flutter_riverpod/misc.dart';

export '../../models/sleep_timer_state.dart'
    show SleepTimerState, sleepTimerPresets;

part 'sleep_timer_provider.g.dart';

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
@riverpod
class SleepTimer extends _$SleepTimer {
  Timer? _ticker;
  DateTime? _endTime;
  int _generation = 0;

  @override
  SleepTimerState build() {
    ref.onDispose(_cancelTicker);
    return const SleepTimerState();
  }

  /// 持有保活链接，供宿主 State 在 initState 取得、dispose 释放。
  ///
  /// 仅用于抵消「宿主被覆盖时监听暂停导致 autoDispose 销毁」，不改变离开页面时的
  /// 取消语义：宿主卸载释放链接后，无其它监听即销毁并取消计时。
  KeepAliveLink holdKeepAlive() => ref.keepAlive();

  /// 启动（或重设）定时器：[total] 后暂停播放。重设时旧计时器经 generation 作废。
  void start(Duration total) {
    final generation = ++_generation;
    _cancelTicker();
    _endTime = clock.now().add(total);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick(generation);
    });
    state = SleepTimerState(remaining: total, presetMinutes: total.inMinutes);
  }

  /// 取消定时器，恢复未激活态（不触发暂停）。
  void cancel() {
    _generation++;
    _cancelTicker();
    state = const SleepTimerState();
  }

  /// 每秒计时回调：校验 generation 后按墙钟刷新剩余，归零则暂停并清空。
  void _tick(int generation) {
    if (generation != _generation) return;
    final endTime = _endTime;
    if (endTime == null) return;

    final remaining = endTime.difference(clock.now());
    if (remaining <= Duration.zero) {
      _cancelTicker();
      _generation++;
      state = const SleepTimerState();
      // 到点暂停（幂等：手动已暂停时再调一次无副作用）。
      ref.read(listeningPracticeProvider.notifier).pause();
    } else {
      state = SleepTimerState(
        remaining: remaining,
        presetMinutes: state.presetMinutes,
      );
    }
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
    _endTime = null;
  }
}
