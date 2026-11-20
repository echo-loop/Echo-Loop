/// 可控倒计时控制器
///
/// 支持暂停/恢复/加速，替代 Timer + Future.delayed 的简单倒计时。
/// 倒计时结束时 [start] 返回的 Future 自动 complete。
///
/// **UI 不通过此控制器获取 remaining**：[CountdownRing] 自带 AnimationController
/// 驱动进度动画，本控制器仅负责流程计时和完成通知。
///
/// 使用场景：精听/跟读/复述/难句补练的句间/遍间停顿。
library;

import 'dart:async';

/// 可控倒计时控制器
class CountdownController {
  Timer? _timer;
  Completer<void>? _completer;

  /// 总时长
  Duration _total = Duration.zero;

  /// 暂停前已累积的有效时间
  Duration _accumulated = Duration.zero;

  /// 当前运行段的起始时间
  DateTime? _runStart;

  /// 速度倍率（1.0=正常，10.0=快进）
  double _speed = 1.0;

  /// 是否暂停中
  bool _paused = false;

  /// 是否有活跃的倒计时
  bool get isActive => _timer != null;

  /// 是否暂停中
  bool get isPaused => _paused;

  /// 当前速度倍率
  double get speed => _speed;

  /// 当前剩余时间（供 engine 在 resume 等场景读取）
  Duration get remaining {
    if (!isActive) return Duration.zero;
    final totalElapsed =
        _accumulated +
        (_paused || _runStart == null
            ? Duration.zero
            : _scale(DateTime.now().difference(_runStart!), _speed));
    final rem = _total - totalElapsed;
    return rem < Duration.zero ? Duration.zero : rem;
  }

  /// 启动倒计时，返回在倒计时结束或取消时 complete 的 Future
  ///
  /// [total] 倒计时总时长
  Future<void> start(Duration total) {
    cancel();
    _total = total;
    _accumulated = Duration.zero;
    _runStart = DateTime.now();
    _speed = 1.0;
    _paused = false;
    _completer = Completer<void>();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());

    return _completer!.future;
  }

  /// 暂停倒计时
  void pause() {
    if (_paused || _runStart == null || !isActive) return;
    _saveCurrentRun();
    _paused = true;
  }

  /// 恢复倒计时
  void resume() {
    if (!_paused || !isActive) return;
    _runStart = DateTime.now();
    _paused = false;
  }

  /// 设置速度倍率（切换时保存当前进度）
  void setSpeed(double speed) {
    if (!isActive) return;
    if (!_paused) {
      _saveCurrentRun();
      _runStart = DateTime.now();
    }
    _speed = speed;
  }

  /// 快进目标时长
  static const _fastForwardTargetMs = 1000.0;

  /// 快进：动态计算速度，让剩余时间在 ~1 秒内走完
  ///
  /// 返回实际设置的速度倍率，供 UI 同步动画。
  /// 最低 2x，避免剩余时间本身就很短时无效果。
  double fastForward() {
    final rem = remaining;
    final remMs = rem.inMilliseconds.toDouble();
    final speed = (remMs / _fastForwardTargetMs).clamp(2.0, 100.0);
    setSpeed(speed);
    return speed;
  }

  /// 取消倒计时（会 complete 返回的 Future，但不触发 onTick）
  void cancel() {
    _timer?.cancel();
    _timer = null;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete();
    }
    _completer = null;
    _paused = false;
    _speed = 1.0;
    _runStart = null;
    _accumulated = Duration.zero;
  }

  /// 每 100ms 触发一次，仅用于完成检测
  void _tick() {
    if (_paused || _runStart == null) return;

    final currentRun = DateTime.now().difference(_runStart!);
    final scaledCurrent = _scale(currentRun, _speed);
    final totalElapsed = _accumulated + scaledCurrent;

    if (totalElapsed >= _total) {
      _timer?.cancel();
      _timer = null;
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete();
      }
      _completer = null;
    }
  }

  /// 保存当前运行段的已累积时间
  void _saveCurrentRun() {
    if (_runStart == null) return;
    final currentRun = DateTime.now().difference(_runStart!);
    _accumulated += _scale(currentRun, _speed);
  }

  /// 缩放 Duration
  static Duration _scale(Duration d, double factor) {
    return Duration(microseconds: (d.inMicroseconds * factor).round());
  }
}
