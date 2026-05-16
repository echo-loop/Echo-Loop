import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/audio_event_params.dart';
import '../analytics/models/event_names.dart';
import '../database/enums.dart';
import '../database/providers.dart';
import '../database/app_database.dart' as db;
import '../models/learning_progress.dart';
import '../services/app_logger.dart';
import 'learning_plan_provider.dart';
import 'learning_settings_provider.dart';
import 'time_provider.dart';

part 'learning_progress_provider.g.dart';

/// 学习进度状态
///
/// 使用 Map 存储所有音频的学习进度，支持 O(1) 查找。
class LearningProgressState {
  /// 按音频 ID 索引的进度 Map
  final Map<String, LearningProgress> progressMap;

  /// 每个音频已完成的子步骤集合（key 格式 `'stage.key:subStage.key'`）。
  ///
  /// 真实「完成」事实的内存索引（启动时从 `stage_completions` 表加载，
  /// `completeCurrentSubStage` 同步更新）。UI 和进度计算用此判定子步骤
  /// 是否真做过，而不是用 `stage.index < currentStage.index` 推导。
  /// 跳过的子步骤永远不会出现在此集合内。
  final Map<String, Set<String>> completionsByAudio;

  /// 是否正在加载
  final bool isLoading;

  const LearningProgressState({
    this.progressMap = const {},
    this.completionsByAudio = const {},
    this.isLoading = false,
  });

  LearningProgressState copyWith({
    Map<String, LearningProgress>? progressMap,
    Map<String, Set<String>>? completionsByAudio,
    bool? isLoading,
  }) {
    return LearningProgressState(
      progressMap: progressMap ?? this.progressMap,
      completionsByAudio: completionsByAudio ?? this.completionsByAudio,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// 指定音频的完成集合（不存在返回空集合）。
  Set<String> completionsFor(String audioItemId) =>
      completionsByAudio[audioItemId] ?? const {};
}

/// 学习进度管理 Provider
///
/// 管理所有音频的学习进度，提供加载、创建、推进、设置难度等操作。
/// 推进子步骤时同时写入 stage_completions 历史记录。
@Riverpod(keepAlive: true)
class LearningProgressNotifier extends _$LearningProgressNotifier {
  @override
  LearningProgressState build() {
    // 监听设置变化：自动跳过复述 false→true 时，对所有进度跑一次自动跳过扫描。
    // plan 现在是静态的，本身不会变；唯一的"reconcile"触发点是 autoSkipRetell。
    ref.listen<LearningSettings>(learningSettingsProvider, (prev, next) {
      final prevOn = prev?.autoSkipRetell ?? false;
      if (!prevOn && next.autoSkipRetell) {
        unawaited(_autoSkipScanAllProgress());
      }
    });

    // 初始态标记为 loading：用于区分"尚未加载"与"加载完为空"。
    // loadAll() 读完 DB 后会把 isLoading 置回 false，此后才可用于判断
    // "用户真的没有学习进度"（例如新装首启的引导 gate）。
    return const LearningProgressState(isLoading: true);
  }

  /// 自动跳过复述全局开关 false→true 时，对所有进度跑一次扫描，
  /// 把当前停在复述子阶段的位置批量推进（与用户在每条音频上手动跳过同效）。
  Future<void> _autoSkipScanAllProgress() async {
    final ids = state.progressMap.keys.toList(growable: false);
    for (final id in ids) {
      try {
        await _autoSkipRetellIfEnabled(id);
      } catch (e) {
        AppLogger.log('LearningProgress', 'auto-skip scan failed for $id: $e');
      }
    }
  }

  /// 自动跳过复述钩子：推进结束后调用，自动连续跳过复述类子阶段。
  ///
  /// 设计：完成 / 手动跳过结束后调一次；若 [autoSkipRetell] 开启且新位置仍
  /// 是复述类，则循环调内部 `_doSkipCore` 直到跳出复述区或进度完成。
  /// 循环以 substage 数为上界，先写 skippedSubStageKeys 再推进位置，
  /// 无死循环风险。
  Future<void> _autoSkipRetellIfEnabled(String audioItemId) async {
    final settings = ref.read(learningSettingsProvider);
    if (!settings.autoSkipRetell) return;
    var safety = 0;
    while (safety++ < 100) {
      final p = state.progressMap[audioItemId];
      if (p == null || p.isCompleted) return;
      if (!isRetellSubStage(p.currentSubStage)) return;
      final ok = await _doSkipCore(audioItemId, source: 'auto');
      if (!ok) return; // 早返回（如已 completed 该 key、review 锁等）
    }
    AppLogger.log(
      'LearningProgress',
      '_autoSkipRetellIfEnabled safety break for $audioItemId',
    );
  }

  /// 启动时加载所有学习进度
  ///
  /// 失败时会：
  ///   1. 记录日志；
  ///   2. 把 `isLoading` 重置为 false，避免永久卡在加载态；
  ///   3. rethrow，让上层调用方（有 BuildContext）负责给用户反馈（snackbar 等）。
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final dao = ref.read(learningProgressDaoProvider);
      final stageCompletionDao = ref.read(stageCompletionDaoProvider);
      final rows = await dao.getAll();
      final completions = await stageCompletionDao.getCompletionKeysByAudio();

      final map = <String, LearningProgress>{
        for (final row in rows) row.audioItemId: _fromDbRow(row),
      };

      state = LearningProgressState(
        progressMap: map,
        completionsByAudio: completions,
        isLoading: false,
      );
    } catch (e, st) {
      AppLogger.log('LearningProgress', 'loadAll failed: $e\n$st');
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// O(1) 查找指定音频的学习进度
  LearningProgress? getByAudioId(String audioItemId) {
    return state.progressMap[audioItemId];
  }

  /// 获取指定音频的最新学习进度
  ///
  /// 优先返回数据库中的最新记录，并在内存态缺失或落后时回填 state。
  Future<LearningProgress?> getLatestByAudioId(String audioItemId) async {
    final dao = ref.read(learningProgressDaoProvider);
    final row = await dao.getByAudioId(audioItemId);
    if (row == null) {
      return state.progressMap[audioItemId];
    }

    final latest = _fromDbRow(row);
    final current = state.progressMap[audioItemId];
    if (current != latest) {
      final newMap = Map<String, LearningProgress>.from(state.progressMap);
      newMap[audioItemId] = latest;
      state = state.copyWith(progressMap: newMap);
    }
    return latest;
  }

  /// 获取指定音频的最新学习进度；若不存在则创建默认进度。
  ///
  /// 进入播放器前统一调用该方法，避免命中陈旧内存态。
  Future<LearningProgress> getLatestOrEnsureProgress(String audioItemId) async {
    final latest = await getLatestByAudioId(audioItemId);
    if (latest != null) return latest;
    return ensureProgress(audioItemId);
  }

  /// 确保音频有学习进度记录（首次打开时自动创建）
  Future<LearningProgress> ensureProgress(String audioItemId) async {
    final existing = state.progressMap[audioItemId];
    if (existing != null) return existing;

    final dao = ref.read(learningProgressDaoProvider);
    final row = await dao.getByAudioId(audioItemId);
    if (row != null) {
      final persisted = _fromDbRow(row);
      final newMap = Map<String, LearningProgress>.from(state.progressMap);
      newMap[audioItemId] = persisted;
      state = state.copyWith(progressMap: newMap);
      return persisted;
    }

    // 持久化时间始终用真实时间
    final now = DateTime.now();
    final progress = LearningProgress(
      audioItemId: audioItemId,
      currentStageStartedAt: now,
      updatedAt: now,
    );

    await dao.upsert(
      db.LearningProgressesCompanion(
        audioItemId: Value(audioItemId),
        currentStage: Value(LearningStage.firstLearn.key),
        currentSubStage: Value(SubStageType.blindListen.key),
        difficulty: const Value(2),
        firstLearnCompletedAt: const Value(null),
        lastStageCompletedAt: const Value(null),
        currentStageStartedAt: Value(now),
        totalStudyDurationMs: const Value(0),
        updatedAt: Value(now),
      ),
    );

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress;
    state = state.copyWith(progressMap: newMap);

    return progress;
  }

  /// 完成当前子步骤，自动推进到下一步
  ///
  /// 通过 [learningPlanProvider] 读取计划：以 `plan.subStagesFor(stage)`
  /// 为推进序列。同阶段内推进 → planned 列表下一项；推进到下一大阶段时
  /// 跳过 planned 为空的阶段。
  ///
  /// 写入 stage_completions（真实完成事件，用户已做完此步）+ 累加耗时。
  Future<void> completeCurrentSubStage(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null || progress.isCompleted) return;
    final checkNow = ref.read(nowProvider)();
    if (progress.isReviewLockedAt(checkNow)) return;

    // 持久化时间始终用真实时间，避免 debug 偏移导致复习链断裂
    final now = DateTime.now();

    final plan = ref.read(learningPlanProvider);
    final stage = progress.currentStage;
    final planned = plan.subStagesFor(stage);
    final currentIdx = planned.indexOf(progress.currentSubStage);

    final durationMs = progress.currentStageStartedAt != null
        ? now.difference(progress.currentStageStartedAt!).inMilliseconds
        : 0;

    // 写入 stage_completions（用户真做完此步）
    final stageCompletionDao = ref.read(stageCompletionDaoProvider);
    await stageCompletionDao.insertRecord(
      db.StageCompletionsCompanion(
        audioItemId: Value(audioItemId),
        stage: Value(progress.currentStage.key),
        subStage: Value(progress.currentSubStage.key),
        completedAt: Value(now),
        durationMs: Value(durationMs),
      ),
    );

    // 同步更新内存完成集合（真实历史）
    final completionKey =
        '${progress.currentStage.key}:${progress.currentSubStage.key}';
    final updatedCompletions =
        Map<String, Set<String>>.from(state.completionsByAudio);
    updatedCompletions[audioItemId] = {
      ...?updatedCompletions[audioItemId],
      completionKey,
    };
    state = state.copyWith(completionsByAudio: updatedCompletions);

    final newTotalDuration = progress.totalStudyDurationMs + durationMs;

    // 完成当前子步骤时，清除该步骤对应的断点索引
    final completedSubStage = progress.currentSubStage;
    final clearBlindListen = completedSubStage == SubStageType.blindListen;
    final clearIntensive = completedSubStage == SubStageType.intensiveListen;
    final clearShadowing = completedSubStage == SubStageType.listenAndRepeat;
    final clearDifficult =
        completedSubStage == SubStageType.reviewDifficultPractice;
    final clearRetell = isRetellSubStage(completedSubStage);

    LearningProgress updated;
    bool advancedToNextStage;

    // 互斥：写 completion 时清除 skippedSubStageKeys 中对应 key（若存在）。
    // 用户先跳过、后又从自由练习真做完同一子步骤时，状态从「跳过」回收为 ✅。
    final Set<String>? clearedSkippedKeys =
        progress.skippedSubStageKeys.contains(completionKey)
            ? (progress.skippedSubStageKeys.toSet()..remove(completionKey))
            : null;

    if (currentIdx >= 0 && currentIdx + 1 < planned.length) {
      // 同阶段内推进子步骤
      updated = progress.copyWith(
        currentSubStage: planned[currentIdx + 1],
        currentStageStartedAt: now,
        totalStudyDurationMs: newTotalDuration,
        updatedAt: now,
        clearBlindListenParagraphIndex: clearBlindListen,
        clearIntensiveListenSentenceIndex: clearIntensive,
        clearShadowingSentenceIndex: clearShadowing,
        clearDifficultPracticeSentenceIndex: clearDifficult,
        clearRetellParagraphIndex: clearRetell,
        skippedSubStageKeys: clearedSkippedKeys,
      );
      advancedToNextStage = false;
    } else {
      // 进入下一个大阶段：planned 为空的阶段直接跳过
      var nextStage = LearningStage.values[stage.index + 1];
      while (nextStage != LearningStage.completed &&
          plan.subStagesFor(nextStage).isEmpty) {
        nextStage = LearningStage.values[nextStage.index + 1];
      }
      final nextPlanned = plan.subStagesFor(nextStage);
      updated = progress.copyWith(
        currentStage: nextStage,
        currentSubStage: nextPlanned.isNotEmpty
            ? nextPlanned.first
            : SubStageType.blindListen,
        lastStageCompletedAt: now,
        currentStageStartedAt: now,
        totalStudyDurationMs: newTotalDuration,
        updatedAt: now,
        firstLearnCompletedAt: stage == LearningStage.firstLearn
            ? now
            : progress.firstLearnCompletedAt,
        clearBlindListenParagraphIndex: clearBlindListen,
        clearIntensiveListenSentenceIndex: clearIntensive,
        clearShadowingSentenceIndex: clearShadowing,
        clearDifficultPracticeSentenceIndex: clearDifficult,
        clearRetellParagraphIndex: clearRetell,
        skippedSubStageKeys: clearedSkippedKeys,
      );
      advancedToNextStage = true;
    }

    await _persistProgress(updated);

    // 埋点：阶段推进（最后一个子步骤完成时触发）
    if (advancedToNextStage) {
      final analytics = ref.read(analyticsServiceProvider);
      final nextStage = updated.currentStage;
      final audioParams = ref.audioEventParams(audioItemId);
      analytics.track(Events.stageAdvance, {
        ...audioParams,
        EventParams.fromStage: stage.name,
        EventParams.toStage: nextStage.name,
      });
      if (stage == LearningStage.firstLearn) {
        analytics.track(Events.firstLearnComplete, {
          ...audioParams,
          EventParams.totalDurationMs: newTotalDuration,
        });
      }
    }

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);

    // 完成后若新位置仍是复述类 + 自动跳过开启 → 连续推进
    await _autoSkipRetellIfEnabled(audioItemId);
  }

  /// 用户跳过当前子阶段（手动按钮 / 自动跳过策略）。
  ///
  /// - **不**写 stage_completions
  /// - 把 `'stage.key:subStage.key'` 加入 [LearningProgress.skippedSubStageKeys] 并持久化
  /// - 推进 currentSubStage（同阶段下一项 / 跨阶段跳空阶段，逻辑同 [completeCurrentSubStage]）
  /// - 清断点索引
  /// - 互斥：若该 key 已在 completed → 早返回（理论上不会触发）
  /// - 推进后调 [_autoSkipRetellIfEnabled]（连续吃掉相邻复述位置）
  Future<void> skipCurrentSubStage(String audioItemId) async {
    final ok = await _doSkipCore(audioItemId, source: 'manual');
    if (ok) await _autoSkipRetellIfEnabled(audioItemId);
  }

  /// [skipCurrentSubStage] / [_autoSkipRetellIfEnabled] 共用的 skip 实现内核。
  /// 返回 true 表示成功跳过并推进；false 表示因 guard（如 reviewLock / 已完成
  /// / 已跳过该 key）早返回。
  Future<bool> _doSkipCore(
    String audioItemId, {
    required String source,
  }) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null || progress.isCompleted) return false;
    final checkNow = ref.read(nowProvider)();
    if (progress.isReviewLockedAt(checkNow)) return false;

    final stage = progress.currentStage;
    final subStage = progress.currentSubStage;
    final key = '${stage.key}:${subStage.key}';

    // 互斥：已完成的子步骤不再标记为跳过
    final completedSet = state.completionsByAudio[audioItemId] ?? const {};
    if (completedSet.contains(key)) return false;

    // 已在跳过集合且推进位置一致 → 已经处理过，幂等返回
    if (progress.skippedSubStageKeys.contains(key)) return false;

    final now = DateTime.now();
    final plan = ref.read(learningPlanProvider);
    final planned = plan.subStagesFor(stage);
    final currentIdx = planned.indexOf(subStage);

    // 断点清除：跳过时同样要清断点，避免残留状态指向已离开的子阶段
    final clearBlindListen = subStage == SubStageType.blindListen;
    final clearIntensive = subStage == SubStageType.intensiveListen;
    final clearShadowing = subStage == SubStageType.listenAndRepeat;
    final clearDifficult = subStage == SubStageType.reviewDifficultPractice;
    final clearRetell = isRetellSubStage(subStage);

    final newSkipped = {...progress.skippedSubStageKeys, key};

    LearningProgress updated;
    if (currentIdx >= 0 && currentIdx + 1 < planned.length) {
      // 同阶段内推进
      updated = progress.copyWith(
        currentSubStage: planned[currentIdx + 1],
        currentStageStartedAt: now,
        updatedAt: now,
        clearBlindListenParagraphIndex: clearBlindListen,
        clearIntensiveListenSentenceIndex: clearIntensive,
        clearShadowingSentenceIndex: clearShadowing,
        clearDifficultPracticeSentenceIndex: clearDifficult,
        clearRetellParagraphIndex: clearRetell,
        skippedSubStageKeys: newSkipped,
      );
    } else {
      // 跨阶段：跳到下一个非空 planned 阶段
      var nextStage = LearningStage.values[stage.index + 1];
      while (nextStage != LearningStage.completed &&
          plan.subStagesFor(nextStage).isEmpty) {
        nextStage = LearningStage.values[nextStage.index + 1];
      }
      final nextPlanned = plan.subStagesFor(nextStage);
      updated = progress.copyWith(
        currentStage: nextStage,
        currentSubStage: nextPlanned.isNotEmpty
            ? nextPlanned.first
            : SubStageType.blindListen,
        lastStageCompletedAt: now,
        currentStageStartedAt: now,
        updatedAt: now,
        firstLearnCompletedAt: stage == LearningStage.firstLearn
            ? now
            : progress.firstLearnCompletedAt,
        clearBlindListenParagraphIndex: clearBlindListen,
        clearIntensiveListenSentenceIndex: clearIntensive,
        clearShadowingSentenceIndex: clearShadowing,
        clearDifficultPracticeSentenceIndex: clearDifficult,
        clearRetellParagraphIndex: clearRetell,
        skippedSubStageKeys: newSkipped,
      );
    }

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);

    ref.read(analyticsServiceProvider).track(Events.retellSkipped, {
      EventParams.audioId: audioItemId,
      EventParams.stage: stage.name,
      EventParams.subStage: subStage.name,
      EventParams.source: source,
    });
    return true;
  }

  /// 设置难度等级
  Future<void> setDifficulty(
    String audioItemId,
    DifficultyLevel difficulty,
  ) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      difficulty: difficulty,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    ref.read(analyticsServiceProvider).track(Events.blindListenDifficultySet, {
      ...ref.audioEventParams(audioItemId),
      EventParams.difficulty: difficulty.name,
    });

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 增加盲听完成遍数并持久化
  Future<void> incrementBlindListenPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      blindListenPassCount: progress.blindListenPassCount + 1,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }



  /// 精听完成时递增总遍数（+1）
  Future<void> incrementIntensiveListenPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      intensiveListenPassCount: (progress.intensiveListenPassCount ?? 0) + 1,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 跟读完成时递增总遍数（+1）
  Future<void> incrementShadowingPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      shadowingPassCount: (progress.shadowingPassCount ?? 0) + 1,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 幂等记录一次「子步骤完成」事件。
  ///
  /// 用途：用户从过去阶段的「跳过」复述卡片进入自由练习并完成时，把该
  /// (stage, subStage) 写入 `stage_completions` 表 + 同步更新
  /// [LearningProgressState.completionsByAudio]，让 UI 把卡片从「灰色未完成」
  /// 切到 ✅。已记录过的子步骤直接跳过（不重复写表、不增加分子）。
  ///
  /// 不推进 `currentStage` / `currentSubStage`，与 [completeCurrentSubStage]
  /// 路径互补：自由练习的"补做"语义不应影响线性学习流程。
  Future<void> recordCompletionIfNew(
    String audioItemId,
    LearningStage stage,
    SubStageType subStage,
  ) async {
    final key = '${stage.key}:${subStage.key}';
    final currentSet = state.completionsByAudio[audioItemId] ?? const {};
    if (currentSet.contains(key)) return;

    final stageCompletionDao = ref.read(stageCompletionDaoProvider);
    await stageCompletionDao.insertRecord(
      db.StageCompletionsCompanion(
        audioItemId: Value(audioItemId),
        stage: Value(stage.key),
        subStage: Value(subStage.key),
        completedAt: Value(DateTime.now()),
        durationMs: const Value(0), // 自由练习"补做"不计入耗时
      ),
    );

    final updated = Map<String, Set<String>>.from(state.completionsByAudio);
    updated[audioItemId] = {...currentSet, key};
    state = state.copyWith(completionsByAudio: updated);

    // 互斥：若该 (stage, subStage) 之前被标记为跳过，回收为已完成。
    // 触发场景：用户在简报弹窗点了跳过，之后从自由练习入口又做完了这一步。
    final progress = state.progressMap[audioItemId];
    if (progress != null && progress.skippedSubStageKeys.contains(key)) {
      final newSkipped = progress.skippedSubStageKeys.toSet()..remove(key);
      final updatedProgress = progress.copyWith(
        skippedSubStageKeys: newSkipped,
        updatedAt: DateTime.now(),
      );
      await _persistProgress(updatedProgress);
      final newMap = Map<String, LearningProgress>.from(state.progressMap);
      newMap[audioItemId] = updatedProgress;
      state = state.copyWith(progressMap: newMap);
    }
  }

  /// 删除指定音频的学习进度（音频删除时调用）
  Future<void> deleteProgress(String audioItemId) async {
    final dao = ref.read(learningProgressDaoProvider);
    await dao.deleteByAudioId(audioItemId);

    // stage_completions 会被外键级联删除

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap.remove(audioItemId);
    final newCompletions = Map<String, Set<String>>.from(
      state.completionsByAudio,
    );
    newCompletions.remove(audioItemId);
    state = state.copyWith(
      progressMap: newMap,
      completionsByAudio: newCompletions,
    );
  }

  /// 保存跟读断点句子索引
  Future<void> saveShadowingSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    final progress = await ensureProgress(audioItemId);
    final now = DateTime.now();

    LearningProgress updated;
    if (isFreePlay) {
      updated = progress.copyWith(
        freePlayShadowingSentenceIndex: sentenceIndex,
        clearFreePlayShadowingSentenceIndex: sentenceIndex == null,
        freePlayBreakpointSavedAt: now,
        updatedAt: now,
      );
    } else {
      updated = progress.copyWith(
        shadowingSentenceIndex: sentenceIndex,
        clearShadowingSentenceIndex: sentenceIndex == null,
        newLearningBreakpointSavedAt: now,
        updatedAt: now,
      );
    }

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 保存难句补练断点句子索引
  Future<void> saveDifficultPracticeSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    final progress = await ensureProgress(audioItemId);
    final now = DateTime.now();

    LearningProgress updated;
    if (isFreePlay) {
      updated = progress.copyWith(
        freePlayDifficultPracticeSentenceIndex: sentenceIndex,
        clearFreePlayDifficultPracticeSentenceIndex: sentenceIndex == null,
        freePlayBreakpointSavedAt: now,
        updatedAt: now,
      );
    } else {
      updated = progress.copyWith(
        difficultPracticeSentenceIndex: sentenceIndex,
        clearDifficultPracticeSentenceIndex: sentenceIndex == null,
        newLearningBreakpointSavedAt: now,
        updatedAt: now,
      );
    }

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 保存复述断点段落索引
  /// 保存盲听断点段落索引（双轨：新学习 / 自由练习）
  Future<void> saveBlindListenParagraphIndex(
    String audioItemId,
    int? paragraphIndex, {
    required bool isFreePlay,
  }) async {
    final progress = await ensureProgress(audioItemId);
    final now = DateTime.now();

    LearningProgress updated;
    if (isFreePlay) {
      updated = progress.copyWith(
        freePlayBlindListenParagraphIndex: paragraphIndex,
        clearFreePlayBlindListenParagraphIndex: paragraphIndex == null,
        freePlayBreakpointSavedAt: now,
        updatedAt: now,
      );
    } else {
      updated = progress.copyWith(
        blindListenParagraphIndex: paragraphIndex,
        clearBlindListenParagraphIndex: paragraphIndex == null,
        newLearningBreakpointSavedAt: now,
        updatedAt: now,
      );
    }

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 保存复述断点段落索引（双轨：新学习 / 自由练习）
  Future<void> saveRetellParagraphIndex(
    String audioItemId,
    int? paragraphIndex, {
    required bool isFreePlay,
  }) async {
    final progress = await ensureProgress(audioItemId);
    final now = DateTime.now();

    LearningProgress updated;
    if (isFreePlay) {
      updated = progress.copyWith(
        freePlayRetellParagraphIndex: paragraphIndex,
        clearFreePlayRetellParagraphIndex: paragraphIndex == null,
        freePlayBreakpointSavedAt: now,
        updatedAt: now,
      );
    } else {
      updated = progress.copyWith(
        retellParagraphIndex: paragraphIndex,
        clearRetellParagraphIndex: paragraphIndex == null,
        newLearningBreakpointSavedAt: now,
        updatedAt: now,
      );
    }

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 复述完成时递增总遍数（+1）
  Future<void> incrementRetellPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      retellPassCount: (progress.retellPassCount ?? 0) + 1,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 保存精听断点句子索引
  Future<void> saveIntensiveListenSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    final progress = await ensureProgress(audioItemId);
    final now = DateTime.now();

    LearningProgress updated;
    if (isFreePlay) {
      updated = progress.copyWith(
        freePlayIntensiveListenSentenceIndex: sentenceIndex,
        clearFreePlayIntensiveListenSentenceIndex: sentenceIndex == null,
        freePlayBreakpointSavedAt: now,
        updatedAt: now,
      );
    } else {
      updated = progress.copyWith(
        intensiveListenSentenceIndex: sentenceIndex,
        clearIntensiveListenSentenceIndex: sentenceIndex == null,
        newLearningBreakpointSavedAt: now,
        updatedAt: now,
      );
    }

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 将进度持久化到数据库
  Future<void> _persistProgress(LearningProgress progress) async {
    final dao = ref.read(learningProgressDaoProvider);
    await dao.upsert(
      db.LearningProgressesCompanion(
        audioItemId: Value(progress.audioItemId),
        currentStage: Value(progress.currentStage.key),
        currentSubStage: Value(progress.currentSubStage.key),
        difficulty: Value(progress.difficulty.value),
        firstLearnCompletedAt: Value(progress.firstLearnCompletedAt),
        lastStageCompletedAt: Value(progress.lastStageCompletedAt),
        currentStageStartedAt: Value(progress.currentStageStartedAt),
        totalStudyDurationMs: Value(progress.totalStudyDurationMs),
        blindListenPassCount: Value(progress.blindListenPassCount),
        intensiveListenDifficultCount: Value(
          progress.intensiveListenDifficultCount,
        ),
        intensiveListenPassCount: Value(progress.intensiveListenPassCount),
        shadowingPassCount: Value(progress.shadowingPassCount),
        blindListenParagraphIndex: Value(progress.blindListenParagraphIndex),
        freePlayBlindListenParagraphIndex: Value(
          progress.freePlayBlindListenParagraphIndex,
        ),
        intensiveListenSentenceIndex: Value(
          progress.intensiveListenSentenceIndex,
        ),
        shadowingSentenceIndex: Value(progress.shadowingSentenceIndex),
        difficultPracticeSentenceIndex: Value(
          progress.difficultPracticeSentenceIndex,
        ),
        retellParagraphIndex: Value(progress.retellParagraphIndex),
        retellPassCount: Value(progress.retellPassCount),
        freePlayIntensiveListenSentenceIndex: Value(
          progress.freePlayIntensiveListenSentenceIndex,
        ),
        freePlayShadowingSentenceIndex: Value(
          progress.freePlayShadowingSentenceIndex,
        ),
        freePlayDifficultPracticeSentenceIndex: Value(
          progress.freePlayDifficultPracticeSentenceIndex,
        ),
        freePlayRetellParagraphIndex: Value(
          progress.freePlayRetellParagraphIndex,
        ),
        newLearningBreakpointSavedAt: Value(
          progress.newLearningBreakpointSavedAt,
        ),
        freePlayBreakpointSavedAt: Value(progress.freePlayBreakpointSavedAt),
        updatedAt: Value(progress.updatedAt),
        skippedSubStages: Value(_encodeSkippedKeys(progress.skippedSubStageKeys)),
      ),
    );
  }

  /// 序列化跳过集合：以 ',' 拼接；空集合 → 空字符串。
  static String _encodeSkippedKeys(Set<String> keys) =>
      keys.isEmpty ? '' : keys.join(',');

  /// 反序列化跳过集合；兼容历史 NULL / 空串。
  static Set<String> _decodeSkippedKeys(String raw) {
    if (raw.isEmpty) return const {};
    return raw.split(',').where((e) => e.isNotEmpty).toSet();
  }

  /// 从数据库行转换为模型
  LearningProgress _fromDbRow(db.LearningProgressesData row) {
    final stage = LearningStage.fromKey(row.currentStage);
    final normalizedSubStage = _normalizeSubStageForStage(
      stage: stage,
      rawSubStageKey: row.currentSubStage,
    );

    return LearningProgress(
      audioItemId: row.audioItemId,
      currentStage: stage,
      currentSubStage: normalizedSubStage,
      difficulty: DifficultyLevel.fromValue(row.difficulty),
      firstLearnCompletedAt: row.firstLearnCompletedAt,
      lastStageCompletedAt: row.lastStageCompletedAt,
      currentStageStartedAt: row.currentStageStartedAt,
      totalStudyDurationMs: row.totalStudyDurationMs,
      blindListenPassCount: row.blindListenPassCount,
      intensiveListenDifficultCount: row.intensiveListenDifficultCount,
      intensiveListenPassCount: row.intensiveListenPassCount,
      shadowingPassCount: row.shadowingPassCount,
      blindListenParagraphIndex: row.blindListenParagraphIndex,
      intensiveListenSentenceIndex: row.intensiveListenSentenceIndex,
      shadowingSentenceIndex: row.shadowingSentenceIndex,
      difficultPracticeSentenceIndex: row.difficultPracticeSentenceIndex,
      retellParagraphIndex: row.retellParagraphIndex,
      retellPassCount: row.retellPassCount,
      freePlayBlindListenParagraphIndex: row.freePlayBlindListenParagraphIndex,
      freePlayIntensiveListenSentenceIndex:
          row.freePlayIntensiveListenSentenceIndex,
      freePlayShadowingSentenceIndex: row.freePlayShadowingSentenceIndex,
      freePlayDifficultPracticeSentenceIndex:
          row.freePlayDifficultPracticeSentenceIndex,
      freePlayRetellParagraphIndex: row.freePlayRetellParagraphIndex,
      newLearningBreakpointSavedAt: row.newLearningBreakpointSavedAt,
      freePlayBreakpointSavedAt: row.freePlayBreakpointSavedAt,
      updatedAt: row.updatedAt,
      skippedSubStageKeys: _decodeSkippedKeys(row.skippedSubStages),
    );
  }

  /// 复习阶段兼容旧子步骤键，避免枚举扩展后旧数据无法推进。
  ///
  /// 兼容规则：
  /// - 首次学习阶段：保留原有子步骤；
  /// - review0：旧 blindListen/listenAndRepeat/retell 都归一到难句补练或段落复述；
  /// - 中间轮：旧 listenAndRepeat -> 难句补练，旧 retell -> 段落复述；
  /// - 末轮 review28：旧 retell -> 全文复述。
  SubStageType _normalizeSubStageForStage({
    required LearningStage stage,
    required String rawSubStageKey,
  }) {
    final raw = SubStageType.fromKey(rawSubStageKey);
    if (stage == LearningStage.firstLearn || stage == LearningStage.completed) {
      return raw;
    }

    if (stage == LearningStage.review0) {
      return switch (raw) {
        SubStageType.reviewDifficultPractice =>
          SubStageType.reviewDifficultPractice,
        SubStageType.reviewRetellParagraph =>
          SubStageType.reviewRetellParagraph,
        SubStageType.reviewRetellSummary => SubStageType.reviewRetellParagraph,
        SubStageType.retell => SubStageType.reviewRetellParagraph,
        _ => SubStageType.reviewDifficultPractice,
      };
    }

    if (stage == LearningStage.review28) {
      return switch (raw) {
        SubStageType.reviewDifficultPractice =>
          SubStageType.reviewDifficultPractice,
        SubStageType.reviewRetellSummary => SubStageType.reviewRetellSummary,
        SubStageType.reviewRetellParagraph => SubStageType.reviewRetellSummary,
        SubStageType.listenAndRepeat => SubStageType.reviewDifficultPractice,
        SubStageType.retell => SubStageType.reviewRetellSummary,
        _ => SubStageType.blindListen,
      };
    }

    return switch (raw) {
      SubStageType.reviewDifficultPractice =>
        SubStageType.reviewDifficultPractice,
      SubStageType.reviewRetellParagraph => SubStageType.reviewRetellParagraph,
      SubStageType.reviewRetellSummary => SubStageType.reviewRetellParagraph,
      SubStageType.listenAndRepeat => SubStageType.reviewDifficultPractice,
      SubStageType.retell => SubStageType.reviewRetellParagraph,
      _ => SubStageType.blindListen,
    };
  }
}
