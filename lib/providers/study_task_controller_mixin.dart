/// 学习任务 Controller Mixin
///
/// 所有学习模式（盲听/精听/跟读/复述/补练）的 Controller 共享逻辑：
/// - 学习计时（Stopwatch + 周期保存 + App 前后台暂停/恢复）
/// - LP 监听暂停/恢复
/// - 音频加载
/// - Analytics 上报
/// - 输出词数统计
/// - 词形统计刷新
/// - 书签同步
library;

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../analytics/analytics_providers.dart';
import '../analytics/audio_event_params.dart';
import '../analytics/models/event_names.dart';
import '../models/study_stage.dart';
import '../database/providers.dart';
import '../services/app_logger.dart';
import '../services/learned_vocabulary_tracker.dart';
import '../services/study_event_recorder.dart';
// 该 mixin 唯一消费者是难句跟读（录音类任务），故引擎统一用前台引擎
// （不接 audio_service、不上锁屏）。见 PLAN.md ADR-7。
import 'audio_engine/foreground_audio_engine_provider.dart';
import 'daily_study_time_provider.dart';
import 'study_stats_provider.dart';
import 'learned_vocabulary_tracker_provider.dart';
import 'listening_practice/listening_practice_provider.dart';
import 'speech/speech_recording_controller.dart';

/// 学习任务 Controller Mixin
///
/// 使用方式：
/// ```dart
/// @Riverpod(keepAlive: true)
/// class ListenAndRepeatController extends _$ListenAndRepeatController
///     with StudyTaskControllerMixin {
///   @override
///   Ref get studyTaskRef => ref;
/// }
/// ```
mixin StudyTaskControllerMixin {
  // ========== 内部状态 ==========

  final Stopwatch _studyStopwatch = Stopwatch();
  Timer? _periodicSaveTimer;
  AppLifecycleListener? _lifecycleListener;
  StudyEventRecorder? _recorder;
  bool _isSaving = false;
  String? _studyAudioItemId;
  StudyStage? _studyStage;
  bool _studyIsFreePlay = false;

  static const _maxSessionSeconds = 5 * 60;

  // ========== 公开方法 ==========

  /// 初始化学习任务（进入学习模式时调用）
  Future<void> initStudyTask(
    Ref ref, {
    required String audioItemId,
    required StudyStage stage,
    required bool isFreePlay,
  }) async {
    _studyAudioItemId = audioItemId;
    _studyStage = stage;
    _studyIsFreePlay = isFreePlay;

    // 启动计时
    _studyStopwatch.reset();
    _studyStopwatch.start();
    _schedulePeriodicSave(ref);

    // App 生命周期监听
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (s) => _onAppLifecycleChanged(ref, s),
    );

    // 暂停 LP 监听
    ref.read(listeningPracticeProvider.notifier).suspendListeners();

    // 确保音频加载
    await _ensureAudioLoaded(ref, audioItemId);

    // 创建学习事件记录器并注入底层
    LearnedVocabularyTracker? vocabTracker;
    try {
      vocabTracker = ref.read(learnedVocabularyTrackerProvider);
    } catch (e) {
      AppLogger.log('StudyTask', '⚠ vocabTracker 不可用: $e');
    }
    _recorder = StudyEventRecorder(
      studyTimeService: ref.read(studyTimeServiceProvider),
      vocabTracker: vocabTracker,
      stage: stage,
    );
    ref.read(foregroundAudioEngineProvider.notifier).setRecorder(_recorder);
    ref.read(speechRecordingControllerProvider.notifier).setRecorder(_recorder);

    // 上报 analytics
    ref.read(analyticsServiceProvider).track(Events.learningStart, {
      ...ref.audioEventParams(audioItemId),
      EventParams.stage: stage.name,
      EventParams.isFreePractice: isFreePlay ? 1 : 0,
    });

    AppLogger.log('StudyTask', '初始化: $audioItemId, stage=$stage');
  }

  /// 结束学习任务（退出学习模式时调用）
  Future<void> disposeStudyTask(Ref ref) async {
    // 上报 session_end
    ref.read(analyticsServiceProvider).track(Events.learningEnd, {
      ...ref.audioEventParams(_studyAudioItemId),
      if (_studyStage != null) EventParams.stage: _studyStage!.name,
      EventParams.durationMs: _studyStopwatch.elapsedMilliseconds,
      EventParams.isFreePractice: _studyIsFreePlay ? 1 : 0,
    });

    // 保存学习时长
    _stopPeriodicSaveTimer();
    await _saveStudyTime(ref);

    // 清除 AudioEngine clip
    await ref.read(foregroundAudioEngineProvider.notifier).clearClip();

    // 恢复 LP 监听 + 同步书签
    final practice = ref.read(listeningPracticeProvider.notifier);
    practice.resumeListeners();
    practice.syncBookmarks();

    // 停止播放
    await ref.read(foregroundAudioEngineProvider.notifier).stop();

    // 刷新词形统计
    await _flushVocabulary(ref);

    // 刷新统计 UI
    ref.invalidate(dailyStudyTimeProvider);
    ref.read(studyStatsNotifierProvider.notifier).refresh();

    // 清理 recorder 注入
    ref.read(foregroundAudioEngineProvider.notifier).setRecorder(null);
    ref.read(speechRecordingControllerProvider.notifier).setRecorder(null);
    _recorder = null;

    // 清理
    _lifecycleListener?.dispose();
    _lifecycleListener = null;

    AppLogger.log('StudyTask', '结束: $_studyAudioItemId');
  }

  /// 暂停学习计时
  void pauseStudyTimer() {
    _studyStopwatch.stop();
    _stopPeriodicSaveTimer();
  }

  /// 添加输出词数
  void addOutputWords(Ref ref, int count) {
    if (count > 0) {
      ref.read(studyTimeServiceProvider).addOutputWords(count);
    }
  }

  // ========== 内部方法 ==========

  void _onAppLifecycleChanged(Ref ref, AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden) {
      _studyStopwatch.stop();
      _stopPeriodicSaveTimer();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (!_studyStopwatch.isRunning) {
        _studyStopwatch.start();
        _schedulePeriodicSave(ref);
      }
    }
  }

  Future<void> _saveStudyTime(Ref ref) async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      if (!_studyStopwatch.isRunning &&
          _studyStopwatch.elapsed == Duration.zero) {
        return;
      }
      _studyStopwatch.stop();
      final seconds = _studyStopwatch.elapsed.inSeconds.clamp(
        0,
        _maxSessionSeconds,
      );
      _studyStopwatch.reset();
      if (seconds > 0) {
        await ref
            .read(studyTimeServiceProvider)
            .addStudyTime(seconds, stage: _studyStage);
      }
    } finally {
      _isSaving = false;
    }
  }

  void _schedulePeriodicSave(Ref ref) {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = Timer(
      const Duration(seconds: _maxSessionSeconds),
      () async {
        if (_isSaving) return;
        await _saveStudyTime(ref);
        _studyStopwatch.start();
        _schedulePeriodicSave(ref);
      },
    );
  }

  void _stopPeriodicSaveTimer() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = null;
  }

  /// 确保音频引擎已加载目标音频
  Future<void> _ensureAudioLoaded(Ref ref, String audioItemId) async {
    final engineState = ref.read(foregroundAudioEngineProvider);
    if (engineState.currentAudioId == audioItemId && !engineState.isLoading) {
      return;
    }
    final lp = ref.read(listeningPracticeProvider);
    final audioItem = lp.currentAudioItem;
    if (audioItem != null && audioItem.id == audioItemId) {
      await ref
          .read(foregroundAudioEngineProvider.notifier)
          .loadAudio(audioItem, lp.settings.playbackSpeed);
    }
  }

  Future<void> _flushVocabulary(Ref ref) async {
    try {
      final tracker = ref.read(learnedVocabularyTrackerProvider);
      await tracker.flush();
    } on Exception catch (e) {
      AppLogger.log('StudyTask', '⚠ vocabTracker flush 失败: $e');
    }
  }
}
