import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sleep_timer_state.dart';
import 'media_playback_provider.dart';

/// 视频随心听的睡眠定时器。
///
/// 与音频随心听的定时器保持相同的墙钟与竞态语义，但到点时只暂停媒体播放器。页面
/// 离开时由 [MediaPlaybackScreen] 取消，避免已关闭的视频页保留后台计时任务。
final mediaSleepTimerProvider =
    NotifierProvider<MediaSleepTimer, SleepTimerState>(MediaSleepTimer.new);

class MediaSleepTimer extends Notifier<SleepTimerState> {
  Timer? _ticker;
  DateTime? _endTime;
  int _generation = 0;

  @override
  SleepTimerState build() {
    ref.onDispose(_cancelTicker);
    return const SleepTimerState();
  }

  /// 启动或重设定时器；旧计时器会因 generation 失效而不能误暂停新播放。
  void start(Duration total) {
    final generation = ++_generation;
    _cancelTicker();
    _endTime = clock.now().add(total);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick(generation);
    });
    state = SleepTimerState(remaining: total, presetMinutes: total.inMinutes);
  }

  /// 取消定时器，不改变当前播放状态。
  void cancel() {
    _generation++;
    _cancelTicker();
    // notifier 已销毁（如容器释放、宿主页面卸载）时只需停止计时器，不再写 state。
    if (!ref.mounted) return;
    state = const SleepTimerState();
  }

  void _tick(int generation) {
    if (generation != _generation) return;
    final endTime = _endTime;
    if (endTime == null) return;

    final remaining = endTime.difference(clock.now());
    if (remaining <= Duration.zero) {
      _cancelTicker();
      _generation++;
      state = const SleepTimerState();
      unawaited(ref.read(mediaPlaybackProvider.notifier).pause());
      return;
    }
    state = SleepTimerState(
      remaining: remaining,
      presetMinutes: state.presetMinutes,
    );
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
    _endTime = null;
  }
}
