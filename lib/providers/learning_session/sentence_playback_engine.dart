/// 句子播放引擎（公共逻辑）
///
/// 提取精听和跟读共享的播放循环逻辑：
/// - N 遍播放 + 遍间停顿
/// - 句间自动推进
/// - 倒计时 UI 更新（支持暂停/快进）
/// - sessionId 守护防止异步竞态
///
/// 各 Provider 通过组合此类实现各自的播放流程，
/// 状态更新通过回调方式传回给宿主 Provider。
library;

import 'dart:async';
import '../../models/sentence.dart';
import '../../services/study_event_recorder.dart';
import '../audio_engine/foreground_audio_engine_provider.dart';
import 'countdown_controller.dart';

/// 停顿时长计算器函数签名
///
/// 根据句子时长返回停顿时长，不同模式有不同的计算策略。
typedef PauseCalculator = Duration Function(Duration sentenceDuration);

/// 句子播放引擎
///
/// 封装 N 遍播放循环 + 遍间/句间停顿 + 倒计时 UI 更新。
/// 通过构造参数注入 AudioEngine 的获取方式，
/// 状态更新通过回调参数传回给宿主。
///
/// 可选注入 [StudyEventRecorder]，每次 playClipOnce 成功后
/// 自动调用 [StudyEventRecorder.onSentencePlayed] 记录听力统计。
class SentencePlaybackEngine {
  /// 获取前台引擎实例的工厂函数（录音/复习类任务用前台引擎，不上锁屏）
  final ForegroundAudioEngine Function() _getEngine;

  /// 学习事件记录器（可选）
  ///
  /// 注入后，[playSentenceLoop] 和 [playOnce] 每播完一遍自动记录听力时长和词数。
  final StudyEventRecorder? _recorder;

  /// 可控倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 当前播放循环的 sessionId
  int _currentSessionId = -1;

  SentencePlaybackEngine({
    required ForegroundAudioEngine Function() getEngine,
    StudyEventRecorder? recorder,
  }) : _getEngine = getEngine,
       _recorder = recorder;

  /// 当前 sessionId（供外部查询）
  int get currentSessionId => _currentSessionId;

  /// 播放句子循环：播放 [repeatCount] 遍，遍间停顿
  ///
  /// [sentence] 要播放的句子
  /// [repeatCount] 总遍数
  /// [pauseCalculator] 停顿时长计算函数
  /// [onPlayCountChanged] 每遍开始时回调（playCount 从 1 开始）
  /// [onPauseStarted] 遍间停顿开始时回调（传入停顿总时长）
  /// [onPauseEnded] 遍间停顿结束时回调
  /// [onAllPlaysCompleted] 所有遍数播完后回调
  ///
  /// 返回时表示播放完成或被中断。
  Future<void> playSentenceLoop({
    required Sentence sentence,
    required int repeatCount,
    int startPlayCount = 1,
    required PauseCalculator pauseCalculator,
    required void Function(int playCount) onPlayCountChanged,
    required void Function(Duration pauseDuration) onPauseStarted,
    required void Function() onPauseEnded,
    required Future<void> Function() onAllPlaysCompleted,
  }) async {
    final engine = _getEngine();
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;
    var playCount = startPlayCount;
    while (repeatCount == 0 || playCount <= repeatCount) {
      if (!engine.isActiveSession(sessionId)) return;

      onPlayCountChanged(playCount);

      await engine.playClipOnce(sentence, sessionId);

      if (!engine.isActiveSession(sessionId)) return;

      // 播完一遍，自动记录听力统计
      _recorder?.onSentencePlayed(sentence);

      // 遍间停顿（最后一遍不停顿）
      if (repeatCount == 0 || playCount < repeatCount) {
        final pauseDur = pauseCalculator(sentence.duration);
        onPauseStarted(pauseDur);

        await _countdown.start(pauseDur);

        if (!engine.isActiveSession(sessionId)) return;
        onPauseEnded();
      }
      playCount += 1;
    }

    // 所有遍数播完
    if (engine.isActiveSession(sessionId)) {
      await onAllPlaysCompleted();
    }
  }

  /// 执行句间停顿
  ///
  /// 停顿结束后调用 [onAdvance]。
  /// 停顿开始前会创建新 session，确保期间用户操作可中断。
  Future<void> autoAdvance({
    required Duration pauseDuration,
    required void Function(Duration pauseDuration) onPauseStarted,
    required Future<void> Function() onAdvance,
  }) async {
    final engine = _getEngine();
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;

    onPauseStarted(pauseDuration);

    await _countdown.start(pauseDuration);

    if (!engine.isActiveSession(sessionId)) return;
    await onAdvance();
  }

  /// 暂停倒计时
  void pauseCountdown() => _countdown.pause();

  /// 恢复倒计时
  void resumeCountdown() => _countdown.resume();

  /// 设置倒计时速度倍率
  void setCountdownSpeed(double speed) => _countdown.setSpeed(speed);

  /// 使当前 session 失效并暂停引擎
  void invalidateSession() {
    final engine = _getEngine();
    engine.pause();
    _currentSessionId = -1;
    _countdown.cancel();
  }

  /// 创建新 session 并返回 sessionId
  int newSession() {
    final engine = _getEngine();
    _currentSessionId = engine.newSession();
    return _currentSessionId;
  }

  /// 检查指定 sessionId 是否仍有效
  bool isActiveSession(int sessionId) {
    return _getEngine().isActiveSession(sessionId);
  }

  /// 播放单句一遍（用于标注重播等场景）
  Future<void> playOnce(Sentence sentence) async {
    final engine = _getEngine();
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;
    await engine.playClipOnce(sentence, sessionId);
    if (engine.isActiveSession(sessionId)) {
      _recorder?.onSentencePlayed(sentence);
    }
  }

  /// 清理资源
  void cleanup() {
    _countdown.cancel();
    _currentSessionId = -1;
  }
}

/// 跟读模式停顿计算：clamp(1s + 0.6×句长, 2s, 20s)
///
/// 与精听 smart 模式统一公式。
Duration listenAndRepeatPauseCalculator(Duration sentenceDuration) {
  final ms = 1000 + (sentenceDuration.inMilliseconds * 0.6).round();
  return Duration(milliseconds: ms.clamp(2000, 20000));
}

/// 根据难度等级返回目标播放遍数
///
/// 当前所有难度统一返回 3 遍（难句跟读默认三遍）。保留按难度入参的 switch
/// 结构，便于以后再按难度差异化调整遍数，无需改动调用方。
int targetPlayCountForDifficulty(int difficultyValue) {
  return switch (difficultyValue) {
    0 => 3, // veryEasy
    1 => 3, // easy
    2 => 3, // medium
    3 => 3, // hard
    4 => 3, // veryHard
    _ => 3, // 默认
  };
}
