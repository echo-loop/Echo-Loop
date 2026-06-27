/// 学习/复习任务后台播放 + 锁屏控制接入 Mixin
///
/// 把 Free Player 已验证的「三层后台播放」机制通用化给学习计划任务（盲听/精听/
/// 难句补练）与复习任务（收藏句复习/闪卡音频段）。封装三件事：
/// 1. 注册/清空锁屏控制回调（播放/暂停/上一句·上一段/下一句·下一段）；
/// 2. 维护**逻辑播放态**（停顿倒计时期间仍为 true，使锁屏图标显示「播放中」）；
/// 3. 后台静音保活（仅 iOS）——停顿期间保持音频会话活跃，让 Dart 倒计时在后台推进。
///
/// 使用方式：
/// ```dart
/// @Riverpod(keepAlive: true)
/// class BlindListenPlayer extends _$BlindListenPlayer
///     with StudyBackgroundPlaybackMixin {
///   @override
///   Ref get bgRef => ref;
/// }
/// ```
///
/// 关键约定：
/// - [setSessionActive] 的入参是「会话是否处于活跃自动推进」（播放中或停顿倒计时中），
///   **不是**单帧的 isPlaying；停顿期间必须保持 true，否则保活会被频繁关停、后台断流。
/// - 离开页面（disposePlayer）或进入录音子模式时必须调 [unbindLockScreen]，把全局
///   回调槽清空、逻辑播放态恢复 null、停保活，避免陈旧任务捕获锁屏按钮。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio_engine/audio_engine_provider.dart';

/// 学习/复习任务后台播放接入能力。
mixin StudyBackgroundPlaybackMixin {
  /// 由具体 Notifier 提供：`Ref get bgRef => ref;`。
  Ref get bgRef;

  AudioEngine get _bgEngine => bgRef.read(audioEngineProvider.notifier);

  /// 注册锁屏控制回调。
  ///
  /// [onPlay]/[onPause] 路由到任务自身的续播/暂停业务逻辑（而非裸驱动播放器），
  /// 修复「播完后锁屏播放无反应」。句子/段落类任务额外传 [onNext]/[onPrevious]
  /// 启用锁屏上一句·上一段/下一句·下一段；不传则锁屏不显示切换按钮。
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    Future<void> Function()? onNext,
    Future<void> Function()? onPrevious,
  }) {
    final engine = _bgEngine;
    engine.setTransportHandlers(onPlay: onPlay, onPause: onPause);
    engine.setSkipHandlers(onPrevious: onPrevious, onNext: onNext);
    // 学习/复习任务为句子/段落语义，不用相对 seek 切句，确保清空避免残留。
    engine.setSeekHandlers(onRewind: null, onFastForward: null);
  }

  /// 设置会话是否处于活跃自动推进。
  ///
  /// [active] = 播放中或停顿倒计时中。true 时锁屏图标显示「播放中」并启动静音保活；
  /// false（暂停/停止/完成/进入录音前台）时恢复并停保活。
  void setSessionActive(bool active) {
    final engine = _bgEngine;
    engine.setLogicalPlaying(active);
    if (active) {
      unawaited(engine.startKeepAlive());
    } else {
      unawaited(engine.stopKeepAlive());
    }
  }

  /// 清空锁屏控制 + 恢复读裸 player + 停保活。
  ///
  /// 离开任务页或进入录音子模式调用。逻辑播放态恢复 null 后，handler 回退读裸
  /// [AudioPlayer.playing]，Free Player 等其它场景行为不受影响。
  void unbindLockScreen() {
    final engine = _bgEngine;
    engine.setTransportHandlers(onPlay: null, onPause: null);
    engine.setSkipHandlers(onPrevious: null, onNext: null);
    engine.setSeekHandlers(onRewind: null, onFastForward: null);
    engine.setLogicalPlaying(null);
    unawaited(engine.stopKeepAlive());
  }
}
