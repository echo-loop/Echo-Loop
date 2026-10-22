import 'dart:math' as math;

// 学习计划表页面
//
// 展示音频的完整学习流程：首次学习（4步）和复习（7步）。
// 从 LearningProgressNotifier 读取真实进度数据，
// 步骤卡片支持三态：已完成、当前、未开始。
// 导航路径：合集详情 → 学习计划表 → 播放器
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../database/enums.dart';
import '../models/practice_completion_result.dart';
import '../features/rating_prompt/domain/rating_prompt_policy.dart';
import '../features/rating_prompt/rating_prompt_providers.dart';
import '../features/rating_prompt/rating_prompt_presentation_guard.dart';
import '../models/audio_item.dart';
import '../models/learning_plan.dart';
import '../models/learning_progress.dart';
import '../models/media_learning_startup.dart';
import '../models/media_load_result.dart';
import '../models/sentence.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/audio_sentences_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/time_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../models/stage_settings_overrides.dart';
import '../providers/intensive_listen_prefs_provider.dart';
import '../providers/blind_listen_prefs_provider.dart';
import '../providers/retell_prefs_provider.dart';
import '../providers/difficult_practice_prefs_provider.dart';
import '../providers/listen_and_repeat/listen_and_repeat_controller.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/app_logger.dart';
import '../services/subtitle_parser.dart';
import '../theme/app_theme.dart';
import '../models/blind_listen_settings.dart';
import '../models/difficult_practice_settings.dart';
import '../models/intensive_listen_settings.dart'
    show PauseMode, IntensiveListenSettings;
import '../models/retell_settings.dart' show KeywordRatio, RetellSettings;
import '../models/study_stage.dart';
import '../utils/blind_listen_duration_estimator.dart';
import '../utils/paragraph_grouping.dart';
import '../utils/playback_speed_default.dart';
import '../utils/retell_duration_estimator.dart';
import '../utils/audio_item_actions.dart';
import '../utils/time_format.dart';
import '../widgets/blind_listen_paragraph_sheet.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/audio_app_bar_title.dart';
import '../widgets/intensive_listen/intensive_listen_briefing_sheet.dart';
import '../widgets/listen_and_repeat/listen_and_repeat_briefing_sheet.dart';
import '../widgets/common/paragraph_selection_sheet.dart'
    show paragraphDurationOptions;
import '../widgets/retell/retell_briefing_sheet.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/speech_permission_dialog.dart';
import '../widgets/study/study_stage_visuals.dart';
import '../widgets/guide_flow.dart';
import '../widgets/manage_subtitles_sheet.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../database/providers.dart';
import '../providers/learning_session/sentence_playback_engine.dart';

/// 学习计划复习轮次标题左侧图标。
///
/// 使用固定 SVG，避免 `🔁` emoji 在不同平台被系统字体渲染成不一致的蓝色方块。
const String _refreshIconAsset = 'assets/icon/refresh.svg';
const _durationDebugLogTag = 'MediaDuration';

/// 统一打开音频或视频盲听任务，避免首次学习与复习入口各自维护媒体分流。
///
/// 自由练习的补做目标只在媒体加载成功后写入，加载失败和取消不会提前改变学习进度语义。
Future<void> _openBlindListenPractice({
  required BuildContext context,
  required WidgetRef ref,
  required AudioItem audioItem,
  required String? collectionId,
  required List<List<Sentence>> paragraphs,
  required BlindListenSettings settings,
  required LearningStage stage,
  required String loadKey,
  bool isFreePlay = false,
  LearningStage? catchUpStage,
  SubStageType? catchUpSubStage,
}) async {
  final session = ref.read(learningSessionProvider.notifier);
  final route = AppRoutes.blindListenPlayer(collectionId, audioItem.id);
  if (!context.mounted) return;
  context.push(
    route,
    extra: MediaLearningStartup(
      loadKey: loadKey,
      showVideoLoading: audioItem.isVideo,
      load: () async {
        final result = await session.enterBlindListenMode(
          audioItem,
          paragraphs: paragraphs,
          settings: settings,
          stage: stage,
          isFreePlay: isFreePlay,
        );
        if (result == MediaLoadResult.ready &&
            catchUpStage != null &&
            catchUpSubStage != null) {
          session.setCatchUp(catchUpStage, catchUpSubStage);
        }
        return result;
      },
      cancel: session.cancelBlindListenEntry,
    ),
  );
}

/// 通过统一媒体启动链路打开音频或视频复述任务。
Future<void> _openRetellPractice({
  required BuildContext context,
  required WidgetRef ref,
  required AudioItem audioItem,
  required String? collectionId,
  required List<List<Sentence>> paragraphs,
  required String loadKey,
  bool isFreePlay = false,
  LearningStage? catchUpStage,
  SubStageType? catchUpSubStage,
}) async {
  final session = ref.read(learningSessionProvider.notifier);
  if (!context.mounted) return;
  await _pushPracticeAndWaitForTransition(
    context,
    AppRoutes.retellPlayer(collectionId, audioItem.id),
    ref: ref,
    event: RatingPromptEvent.retellCompleted,
    extra: MediaLearningStartup(
      loadKey: loadKey,
      showVideoLoading: audioItem.isVideo,
      load: () => session.enterRetellMode(
        audioItem,
        paragraphs,
        isFreePlay: isFreePlay,
        catchUpStage: catchUpStage,
        catchUpSubStage: catchUpSubStage,
      ),
      cancel: session.cancelRetellEntry,
    ),
  );
}

/// 推入练习页，等待 root 退场完成后在原计划页仍可见时检查评分资格。
Future<void> _pushPracticeAndWaitForTransition(
  BuildContext context,
  String route, {
  Object? extra,
  required WidgetRef ref,
  required RatingPromptEvent event,
}) async {
  final transition = rootRouteObserver.watchNextPop();
  final presentation = RatingPromptPresentationGuard(
    context: context,
    isRootRouteCurrent: () => transition.returnedToPreviousRoute,
  );
  try {
    final result = await context.push<PracticeCompletionResult>(
      route,
      extra: extra,
    );
    if (result == PracticeCompletionResult.completed) {
      await transition.completed;
      if (!context.mounted) return;
      await _requestRatingAfterPractice(
        ref,
        event,
        canPresent: () => presentation.canPresent,
      );
    }
  } finally {
    transition.cancel();
  }
}

/// 评分邀请失败由独立协调器处理，不改变练习完成后的导航行为。
Future<void> _requestRatingAfterPractice(
  WidgetRef ref,
  RatingPromptEvent event, {
  required bool Function() canPresent,
}) async {
  try {
    await ref
        .read(ratingPromptCoordinatorProvider)
        .maybeRequest(event, canPresent: canPresent);
  } catch (error, stackTrace) {
    AppLogger.log(
      'RatingPrompt',
      'coordinator unavailable error=$error\n$stackTrace',
    );
  }
}

/// 学习计划大阶段完成标记图标。
///
/// 使用固定 SVG，避免 `✅` emoji 在不同平台呈现不一致。
const String _checkCircleIconAsset = 'assets/icon/check-circle-3.svg';

/// 学习计划大阶段当前到期标记图标。
///
/// 使用固定 SVG，避免 `📖` emoji 在不同平台呈现不一致。
const String _calendarIconAsset = 'assets/icon/calendar-2.svg';

/// 学习计划大阶段锁定标记图标。
///
/// 使用固定 SVG，避免 `🔒` emoji 在不同平台呈现不一致。
const String _lockIconAsset = 'assets/icon/lock.svg';

/// 学习计划复习轮次提前解锁按钮图标。
const String _unlockIconAsset = 'assets/icon/unlock.svg';

/// 学习计划首次学习标题左侧图标。
const String _readingIconAsset = 'assets/icon/reading.svg';

/// 学习计划阶段标题行标题列宽。
///
/// 首次学习与各复习轮次共用固定列宽，保证状态图标、状态文案和进度计数
/// 在不同行之间垂直对齐。
const double _stageHeaderTitleColumnWidth = 132;

/// 学习计划阶段标题行中文标题列宽。
const double _stageHeaderZhTitleColumnWidth = 112;

/// 学习计划阶段标题行状态文案列最大宽度。
const double _stageHeaderStatusTextMaxWidth = 180;

/// 学习计划阶段标题行进度计数列宽。
const double _stageHeaderProgressColumnWidth = 48;

/// 实时查询指定音频的书签数量（难句数）
///
/// 使用 StreamProvider 监听 bookmarks 表变化，确保难句数实时更新。
final _bookmarkCountProvider = StreamProvider.family.autoDispose<int, String>((
  ref,
  audioItemId,
) {
  final bookmarkDao = ref.watch(bookmarkDaoProvider);
  return bookmarkDao
      .watchByAudioId(audioItemId)
      .map((bookmarks) => bookmarks.length);
});

/// 查询指定音频各复习大阶段的最终完成时间。
///
/// 学习计划页据此为已完成的大阶段显示“X 天前”一类相对完成时间。
final reviewStageCompletionTimesProvider =
    StreamProvider.family<Map<String, DateTime>, String>((ref, audioItemId) {
      final dao = ref.watch(stageCompletionDaoProvider);
      return dao.watchStageCompletedAtByAudioId(audioItemId);
    });

/// 已完成大阶段标题文案。
///
/// 使用相对时间，但显式带上“完成于 / Completed”前缀，避免误读成逾期时间。
String formatCompletedStageTimeLabel(
  BuildContext context,
  DateTime completedAt,
) {
  final ago = formatTimeAgo(context, completedAt);
  final isZh = Localizations.localeOf(context).languageCode == 'zh';
  return isZh ? '完成于$ago' : 'Completed $ago';
}

/// 逐句精听入口弹窗的「停顿下拉显示值」← 已解析设置。
///
/// 仅作下拉的 UI 显示值,不承担持久化/传输(真相源是 [intensiveListenPrefsProvider])。
BriefingPauseChoice intensivePauseChoiceFromSettings(
  IntensiveListenSettings s,
) => switch (s.pauseMode) {
  PauseMode.smart => const BriefingPauseChoice.smart(),
  PauseMode.fixed => BriefingPauseChoice.fixed(s.fixedPauseSeconds),
  PauseMode.multiplier => BriefingPauseChoice.multiplier(s.pauseMultiplier),
};

/// 生成逐句精听入口弹窗的「改完即记」回调:用户在弹窗改速度/停顿时即时写入
/// [intensiveListenPrefsProvider](与 🔧 面板同一份 store,改完即持久,无需开始练习)。
///
/// 闭包跟踪上次值,仅写**真正变化的那个字段**:既支持来回改,又不会因改一个字段而
/// 把另一个未碰过的字段(智能默认)冻结。两个入口(按计划/自由练习)共用,行为一致。
void Function(double, BriefingPauseChoice) intensivePrefsRecorder(
  IntensiveListenPrefsNotifier notifier,
  String slot,
  IntensiveListenSettings resolved,
) {
  var lastSpeed = resolved.playbackSpeed;
  var lastPause = intensivePauseChoiceFromSettings(resolved);
  return (speed, pause) {
    if (speed != lastSpeed) {
      notifier.setPlaybackSpeed(slot, speed);
      lastSpeed = speed;
    }
    if (pause != lastPause) {
      switch (pause.mode) {
        case PauseMode.smart:
          notifier.setPauseMode(slot, PauseMode.smart);
        case PauseMode.fixed:
          notifier.setPauseMode(slot, PauseMode.fixed);
          notifier.setFixedPauseSeconds(slot, pause.fixedSeconds);
        case PauseMode.multiplier:
          notifier.setPauseMode(slot, PauseMode.multiplier);
          notifier.setPauseMultiplier(slot, pause.multiplier);
      }
      lastPause = pause;
    }
  };
}

/// 盲听入口弹窗的「停顿下拉显示值」← 已解析设置。
BriefingPauseChoice blindPauseChoiceFromSettings(BlindListenSettings s) =>
    switch (s.pauseMode) {
      PauseMode.smart => const BriefingPauseChoice.smart(),
      PauseMode.fixed => BriefingPauseChoice.fixed(s.fixedPauseSeconds),
      PauseMode.multiplier => BriefingPauseChoice.multiplier(s.pauseMultiplier),
    };

/// 难句补练 / 收藏句复习 入口的「停顿下拉显示值」← 已解析设置。
BriefingPauseChoice difficultPauseChoiceFromSettings(
  DifficultPracticeSettings s,
) => switch (s.pauseMode) {
  PauseMode.smart => const BriefingPauseChoice.smart(),
  PauseMode.fixed => BriefingPauseChoice.fixed(s.fixedPauseSeconds),
  PauseMode.multiplier => BriefingPauseChoice.multiplier(s.pauseMultiplier),
};

/// 段落复述 入口的「停顿下拉显示值」← 已解析设置。
BriefingPauseChoice retellPauseChoiceFromSettings(RetellSettings s) =>
    switch (s.pauseMode) {
      PauseMode.smart => const BriefingPauseChoice.smart(),
      PauseMode.fixed => BriefingPauseChoice.fixed(s.fixedPauseSeconds),
      PauseMode.multiplier => BriefingPauseChoice.multiplier(s.pauseMultiplier),
    };

/// 复述段落入口弹窗的预填:从按槽位偏好 resolve 出 速度/停顿/可见词比例/目标段长。
({
  int seconds,
  KeywordRatio ratio,
  double speed,
  BriefingPauseChoice pause,
  RetellSettings settings,
})
retellBriefingDefaults(
  WidgetRef ref,
  String slot, {
  required double smartSpeed,
  required KeywordRatio smartRatio,
  required int smartSeconds,
}) {
  final rp = ref.read(retellPrefsProvider.notifier);
  final settings = rp.resolve(
    slot,
    smartSpeed: smartSpeed,
    smartRatio: smartRatio,
  );
  final rawSeconds = rp.resolveTargetSeconds(slot, smartSeconds: smartSeconds);
  // 目标段长须落在合法档位内,否则下拉 value 不在 items 会断言。
  final seconds = paragraphDurationOptions.contains(rawSeconds)
      ? rawSeconds
      : smartSeconds;
  return (
    seconds: seconds,
    ratio: settings.keywordRatio,
    speed: settings.playbackSpeed,
    pause: retellPauseChoiceFromSettings(settings),
    settings: settings,
  );
}

/// 盲听入口「改完即记」回调:改速度/停顿即时写按槽位偏好(跟踪上次值,仅写变化字段,
/// 支持回退到默认)。供按计划/自由练习各入口共用。
void Function(Duration, BriefingPauseChoice, double) blindPrefsRecorder(
  WidgetRef ref,
  String slot,
  BlindListenSettings defaults,
  int defaultSeconds,
) {
  final n = ref.read(blindListenPrefsProvider.notifier);
  var lastPause = blindPauseChoiceFromSettings(defaults);
  var lastSpeed = defaults.playbackSpeed;
  var lastSeconds = defaultSeconds;
  return (duration, pause, speed) {
    if (speed != lastSpeed) {
      n.setPlaybackSpeed(slot, speed);
      lastSpeed = speed;
    }
    if (pause != lastPause) {
      switch (pause.mode) {
        case PauseMode.smart:
          n.setPauseMode(slot, PauseMode.smart);
        case PauseMode.fixed:
          n.setPauseMode(slot, PauseMode.fixed);
          n.setFixedPauseSeconds(slot, pause.fixedSeconds);
        case PauseMode.multiplier:
          n.setPauseMode(slot, PauseMode.multiplier);
          n.setPauseMultiplier(slot, pause.multiplier);
      }
      lastPause = pause;
    }
    final seconds = duration.inHours >= 24 ? -1 : duration.inSeconds;
    if (seconds != lastSeconds && paragraphDurationOptions.contains(seconds)) {
      n.setTargetSeconds(slot, seconds);
      lastSeconds = seconds;
    }
  };
}

/// 难句补练入口「改完即记」回调(速度/停顿)。
void Function(double, BriefingPauseChoice) difficultPrefsRecorder(
  WidgetRef ref,
  String slot,
  DifficultPracticeSettings defaults,
) {
  final n = ref.read(difficultPracticePrefsProvider.notifier);
  var lastPause = difficultPauseChoiceFromSettings(defaults);
  var lastSpeed = defaults.playbackSpeed;
  return (speed, pause) {
    if (speed != lastSpeed) {
      n.setPlaybackSpeed(slot, speed);
      lastSpeed = speed;
    }
    if (pause != lastPause) {
      switch (pause.mode) {
        case PauseMode.smart:
          n.setPauseMode(slot, PauseMode.smart);
        case PauseMode.fixed:
          n.setPauseMode(slot, PauseMode.fixed);
          n.setFixedPauseSeconds(slot, pause.fixedSeconds);
        case PauseMode.multiplier:
          n.setPauseMode(slot, PauseMode.multiplier);
          n.setPauseMultiplier(slot, pause.multiplier);
      }
      lastPause = pause;
    }
  };
}

/// 全文复述(复习简报)「改完即记」回调(仅速度/停顿)。
void Function(double, BriefingPauseChoice) retellPauseSpeedRecorder(
  WidgetRef ref,
  String slot,
  RetellSettings defaults,
) {
  final n = ref.read(retellPrefsProvider.notifier);
  var lastPause = retellPauseChoiceFromSettings(defaults);
  var lastSpeed = defaults.playbackSpeed;
  return (speed, pause) {
    if (speed != lastSpeed) {
      n.setPlaybackSpeed(slot, speed);
      lastSpeed = speed;
    }
    if (pause != lastPause) {
      switch (pause.mode) {
        case PauseMode.smart:
          n.setPauseMode(slot, PauseMode.smart);
        case PauseMode.fixed:
          n.setPauseMode(slot, PauseMode.fixed);
          n.setFixedPauseSeconds(slot, pause.fixedSeconds);
        case PauseMode.multiplier:
          n.setPauseMode(slot, PauseMode.multiplier);
          n.setPauseMultiplier(slot, pause.multiplier);
      }
      lastPause = pause;
    }
  };
}

/// 复述入口「改完即记」回调(目标段长/停顿/可见词比例/速度)。
void Function(Duration, BriefingPauseChoice, KeywordRatio?, double)
retellPrefsRecorder(WidgetRef ref, String slot, RetellSettings defaults) {
  final n = ref.read(retellPrefsProvider.notifier);
  var lastPause = retellPauseChoiceFromSettings(defaults);
  var lastSpeed = defaults.playbackSpeed;
  var lastRatio = defaults.keywordRatio;
  int? lastSeconds;
  return (duration, pause, ratio, speed) {
    if (speed != lastSpeed) {
      n.setPlaybackSpeed(slot, speed);
      lastSpeed = speed;
    }
    if (pause != lastPause) {
      switch (pause.mode) {
        case PauseMode.smart:
          n.setPauseMode(slot, PauseMode.smart);
        case PauseMode.fixed:
          n.setPauseMode(slot, PauseMode.fixed);
          n.setFixedPauseSeconds(slot, pause.fixedSeconds);
        case PauseMode.multiplier:
          n.setPauseMode(slot, PauseMode.multiplier);
          n.setPauseMultiplier(slot, pause.multiplier);
      }
      lastPause = pause;
    }
    if (ratio != null && ratio != lastRatio) {
      n.setKeywordRatio(slot, ratio);
      lastRatio = ratio;
    }
    final seconds = duration.inHours >= 24 ? -1 : duration.inSeconds;
    if (seconds != lastSeconds && paragraphDurationOptions.contains(seconds)) {
      n.setTargetSeconds(slot, seconds);
      lastSeconds = seconds;
    }
  };
}

/// 学习计划表页面
class LearningPlanScreen extends ConsumerStatefulWidget {
  /// 合集 ID（从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  /// 是否自动启动当前学习任务
  final bool autoStart;

  const LearningPlanScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
    this.autoStart = false,
  });

  @override
  ConsumerState<LearningPlanScreen> createState() => _LearningPlanScreenState();
}

class _LearningPlanScreenState extends ConsumerState<LearningPlanScreen> {
  /// autoStart 是否已触发
  bool _autoStartTriggered = false;

  /// loadAudio 的 Future，用于在读取 sentences 前确保音频加载完成
  Future<void>? _loadAudioFuture;

  /// 首次学习区域是否展开（首次学习阶段默认展开，进入复习阶段后默认折叠）
  bool? _isFirstLearnExpanded;

  /// 各复习轮次的展开状态（key 为复习大阶段）
  final Map<LearningStage, bool> _reviewRoundExpandedMap = {};

  // Guide step keys
  final _keyFreePlay = GlobalKey();
  final _keyStartLearning = GlobalKey();
  final _keyAddSubtitle = GlobalKey();
  final _keyPauseLearning = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保学习进度记录存在
      ref
          .read(learningProgressNotifierProvider.notifier)
          .ensureProgress(widget.audioItemId);

      // 检查并加载音频数据
      final audioItem = ref
          .read(audioLibraryProvider.notifier)
          .getItemById(widget.audioItemId);
      if (audioItem == null) {
        AppLogger.log(
          _durationDebugLogTag,
          'event=plan_item_missing itemId=${widget.audioItemId}',
        );
        return;
      }
      AppLogger.log(
        _durationDebugLogTag,
        'event=plan_item_loaded trace=${audioItem.id} '
        'mediaType=${audioItem.mediaType.name} '
        'extension=${p.extension(audioItem.audioPath ?? '')} '
        'source=${audioItem.importSourceType?.name ?? 'unknown'} '
        'durationSeconds=${audioItem.totalDuration}',
      );

      // 始终调用 loadAudio：同一音频时只重新读取字幕，不重新加载音频文件
      _maybeLoadAudio(audioItem);

      // 监听字幕变化（上传/AI转录完成后重新加载字幕）。
      //
      // 字幕内容入库后，AI 转录完成不会再写 transcriptPath；学习计划页必须
      // 监听 transcriptSource / 统计字段等模型列，否则当前页内 LP 仍保留空句子，
      // 点击「开始学习」会在 sentences.isEmpty 分支静默返回。
      ref.listenManual(
        audioLibraryProvider.select(
          (s) =>
              s.audioItems.where((i) => i.id == widget.audioItemId).firstOrNull,
        ),
        (prev, next) {
          if (next == null) return;
          final transcriptChanged =
              prev?.transcriptPath != next.transcriptPath ||
              prev?.transcriptSource != next.transcriptSource ||
              prev?.transcriptLanguage != next.transcriptLanguage ||
              prev?.sentenceCount != next.sentenceCount ||
              prev?.wordCount != next.wordCount;
          if (transcriptChanged) {
            _maybeLoadAudio(next, forceTranscriptReload: true);
          }
        },
      );
    });
  }

  /// 加载音频到听力练习引擎；视频条目本期不接入播放引擎，直接跳过（仅保证页面不崩溃）。
  void _maybeLoadAudio(AudioItem item, {bool forceTranscriptReload = false}) {
    if (item.isVideo) return;
    _loadAudioFuture = ref
        .read(listeningPracticeProvider.notifier)
        .loadAudio(item, forceTranscriptReload: forceTranscriptReload);
  }

  /// 等待音频加载完成，返回 LP 状态。
  ///
  /// 如果加载后 audioItemId 不匹配（加载失败等），返回 null。
  Future<ListeningPracticeState?> _ensureAudioLoaded() async {
    await _loadAudioFuture;
    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.currentAudioItem?.id != widget.audioItemId) return null;
    return lpState;
  }

  /// 构造"跳过当前子步骤"的回调。
  ///
  /// 首次学习的第一个盲听不可跳过（[LearningProgress.canSkipCurrentSubStage]
  /// 为 false），此时返回 null，简报弹窗据此隐藏「跳过」按钮。
  VoidCallback? _buildSkipCallback() {
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    if (!(progress?.canSkipCurrentSubStage ?? false)) return null;
    return () async {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .skipCurrentSubStage(widget.audioItemId);
    };
  }

  /// 打开「随心听」播放器（泛听/预热用途，不计学习进度）。
  ///
  /// 右上角随心听胶囊与「首次学习」预热卡共用此入口，保证目的地单一来源。
  void _openFreePlay(BuildContext context) {
    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(widget.audioItemId);
    if (audioItem != null && audioItem.isVideo) {
      context.push(
        AppRoutes.mediaPlayer(widget.collectionId, widget.audioItemId),
        extra: audioItem,
      );
      return;
    }
    if (widget.collectionId != null) {
      context.push(
        AppRoutes.player(widget.collectionId!, widget.audioItemId),
        extra: audioItem,
      );
    } else {
      context.push(AppRoutes.audioPlayer(widget.audioItemId), extra: audioItem);
    }
  }

  /// 构建计划页顶栏「更多操作」菜单（随心听按钮右侧）。
  ///
  /// 承载对当前音频的重要操作：管理字幕、编辑字幕、导出音频、导出 PDF、重置进度。
  /// 与音频列表项菜单同源（复用 [showManageSubtitlesSheet]/[exportAudioItem]）。
  /// 社区音频隐藏字幕/导出写操作，仅在有字幕时保留导出 PDF；无可用项时返回 null。
  Widget? _buildPlanMenu(
    BuildContext context,
    AppLocalizations l10n,
    AudioItem audioItem,
    LearningProgress? progress,
  ) {
    final isCommunity = audioItem.remoteAudioId != null;
    final hasTranscript = audioItem.hasTranscript;
    final hasProgress = progress?.isStarted ?? false;

    final items = <PopupMenuEntry<String>>[
      if (!isCommunity)
        appPopupMenuItem(
          context,
          value: 'manageSubtitles',
          icon: const Icon(Icons.subtitles_outlined, size: 20),
          label: l10n.manageSubtitles,
        ),
      if (!isCommunity && hasTranscript)
        appPopupMenuItem(
          context,
          value: 'editSubtitles',
          icon: const Icon(Icons.edit_note, size: 20),
          label: l10n.editSubtitles,
        ),
      if (!isCommunity)
        appPopupMenuItem(
          context,
          value: 'export',
          icon: const Icon(Icons.ios_share, size: 20),
          label: audioItem.isVideo ? l10n.exportVideo : l10n.exportAudio,
        ),
      if (hasTranscript)
        appPopupMenuItem(
          context,
          value: 'exportPdf',
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
          label: l10n.exportPdf,
        ),
      // 与音频列表菜单保持一致：仅在已有实际学习进度时提供危险的重置操作。
      if (hasProgress)
        appPopupMenuItem(
          context,
          value: 'resetProgress',
          icon: Icon(
            Icons.restart_alt,
            size: 20,
            color: Theme.of(context).colorScheme.error,
          ),
          label: l10n.resetLearningProgress,
          destructive: true,
        ),
    ];

    if (items.isEmpty) return null;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s),
      child: PopupMenuButton<String>(
        key: const Key('learning_plan_more_menu'),
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        icon: const Icon(Icons.more_horiz),
        itemBuilder: (_) => items,
        onSelected: (value) {
          switch (value) {
            case 'manageSubtitles':
              showManageSubtitlesSheet(context, ref, audioItem);
            case 'editSubtitles':
              context.push(
                AppRoutes.subtitleEditor(audioItem.id),
                extra: audioItem,
              );
            case 'export':
              exportAudioItem(context, ref, audioItem);
            case 'exportPdf':
              AppRoutes.pushNested(
                context,
                AppRoutes.pdfPreviewSegment,
                extra: audioItem,
              );
            case 'resetProgress':
              _showResetProgressDialog(context, l10n, audioItem);
          }
        },
      ),
    );
  }

  /// 确认后清除当前音频的学习进度，并保留音频与字幕内容。
  Future<void> _showResetProgressDialog(
    BuildContext context,
    AppLocalizations l10n,
    AudioItem audioItem,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.resetLearningProgressConfirmTitle),
        content: Text(l10n.resetLearningProgressConfirmMessage(audioItem.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ref
        .read(learningProgressNotifierProvider.notifier)
        .resetProgress(audioItem.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.resetLearningProgressDone)));
    }
  }

  /// 处理"开始学习/继续学习"按钮点击。
  ///
  /// 首帧进入计划页时，进度可能仍在 [ensureProgress] 异步创建中；此时
  /// 必须等待并读取真实进度，不能把 null 误判为盲听入口。
  Future<void> _handleStartLearning(
    BuildContext context,
    LearningProgress? progress,
  ) async {
    final effectiveProgress =
        progress ??
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .getLatestOrEnsureProgress(widget.audioItemId);
    if (!context.mounted) return;

    final now = ref.read(nowProvider)();
    if (effectiveProgress.isReviewLockedAt(now)) return;

    if (effectiveProgress.currentStage.index >= LearningStage.review0.index &&
        effectiveProgress.currentStage.index <= LearningStage.review28.index) {
      _startReviewSubStage(context, effectiveProgress);
      return;
    }

    final currentSubStage = effectiveProgress.currentSubStage;

    if (currentSubStage == SubStageType.blindListen) {
      _startBlindListen(context, effectiveProgress);
    } else if (currentSubStage == SubStageType.intensiveListen) {
      _startIntensiveListen(context);
    } else if (currentSubStage == SubStageType.listenAndRepeat) {
      _startListenAndRepeat(context);
    } else if (currentSubStage == SubStageType.retell) {
      _startRetelling(context);
    } else {
      // 其他子步骤 → 直接导航到播放器
      _openFreePlay(context);
    }
  }

  /// 无字幕时保留学习入口的可点击反馈，明确告知用户开始学习的前置条件。
  void _showMissingTranscriptSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.noTranscriptWarning),
      ),
    );
  }

  /// 复习阶段：按 subStage 分发到真实页面。
  ///
  /// 盲听和段落复述自带段落选择弹窗，无需再展示复习简报；
  /// 其余子阶段先展示复习简报弹窗。
  Future<void> _startReviewSubStage(
    BuildContext context,
    LearningProgress progress,
  ) async {
    final subStage = progress.currentSubStage;

    // 段落复述自带时长选择弹窗，无需再展示复习简报
    if (subStage == SubStageType.reviewRetellParagraph) {
      _startReviewRetell(context, isSummary: false);
      return;
    }

    // 盲听自带段落选择弹窗，阶段名和预估时长直接显示在弹窗上
    if (subStage == SubStageType.blindListen) {
      _startReviewBlindListen(context, stage: progress.currentStage);
      return;
    }

    // 按当前难句书签数实时重算难度，难度降低后速度随之回升
    final lpState = await _ensureAudioLoaded();
    if (!context.mounted) return;
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(
          widget.audioItemId,
          lpState?.sentences.length ?? 0,
        );
    if (!context.mounted) return;

    // 预估时长
    final estimatedDuration = _estimateReviewDuration(subStage);

    final reviewStage = progress.currentStage;
    final smartSpeed = defaultPlaybackSpeedFor(liveDifficulty, reviewStage);

    // 难句补练:按槽位 typed 偏好(轮次独立)。
    if (subStage == SubStageType.reviewDifficultPractice) {
      final slot = stageSlotKey(
        StageSettingsSlots.reviewDifficultPractice,
        reviewStage,
      );
      final dp = ref.read(difficultPracticePrefsProvider.notifier);
      final defaults = dp.resolve(slot, smartSpeed: smartSpeed);
      showReviewBriefingSheet(
        context: context,
        stage: reviewStage,
        subStage: subStage,
        estimatedDuration: estimatedDuration,
        defaultPlaybackSpeed: defaults.playbackSpeed,
        defaultPause: difficultPauseChoiceFromSettings(defaults),
        onSelectionChanged: difficultPrefsRecorder(ref, slot, defaults),
        onStartPractice: (playbackSpeed, pause) {
          final settings = ref
              .read(difficultPracticePrefsProvider.notifier)
              .resolve(slot, smartSpeed: smartSpeed);
          _startReviewDifficultPractice(
            context,
            settings: settings,
            stage: reviewStage,
          );
        },
        onSkip: _buildSkipCallback(),
      );
      return;
    }

    // 全文复述(reviewRetellSummary):按槽位 typed 偏好。
    final slot = stageSlotKey(StageSettingsSlots.retell, reviewStage);
    final rp = ref.read(retellPrefsProvider.notifier);
    final smartRatio = KeywordRatio.forDifficultyAndStage(
      liveDifficulty,
      reviewStage,
    );
    final defaults = rp.resolve(
      slot,
      smartSpeed: smartSpeed,
      smartRatio: smartRatio,
    );
    showReviewBriefingSheet(
      context: context,
      stage: reviewStage,
      subStage: subStage,
      estimatedDuration: estimatedDuration,
      defaultPlaybackSpeed: defaults.playbackSpeed,
      defaultPause: retellPauseChoiceFromSettings(defaults),
      onSelectionChanged: retellPauseSpeedRecorder(ref, slot, defaults),
      onStartPractice: (playbackSpeed, pause) {
        _startReviewRetell(context, isSummary: true);
      },
      onSkip: _buildSkipCallback(),
    );
  }

  /// 预估复习子步骤时长
  Duration? _estimateReviewDuration(SubStageType subStage) {
    switch (subStage) {
      case SubStageType.blindListen:
        // 盲听 = 跳过静音开启时按字幕有效时长，否则按音频总时长
        return estimateBlindListenSessionDuration(
          sentences: ref.read(listeningPracticeProvider).sentences,
          fullAudioDuration: ref.read(audioEngineProvider).totalDuration,
          skipSilenceEnabled: ref.read(appSettingsProvider).skipSilenceEnabled,
        );
      case SubStageType.reviewDifficultPractice:
        // 难句补练 = 难句总时长 × 2（盲听 + 跟读）
        final lpState = ref.read(listeningPracticeProvider);
        final difficultDuration = lpState.sentences
            .where((s) => s.isBookmarked)
            .fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);
        if (difficultDuration == Duration.zero) return null;
        return difficultDuration * 2;
      case SubStageType.reviewRetellSummary:
        // 全文复述 = 真实播放（字幕 wall-clock）+ smart 停顿
        // 全文作为单段，pauseMultiplier=-1 走 smart 模式
        final sentences = ref.read(listeningPracticeProvider).sentences;
        if (sentences.isEmpty) return null;
        return estimateRetellSessionDuration(
          sentences: sentences,
          targetSeconds: -1,
          pauseMultiplier: -1,
        );
      default:
        return null;
    }
  }

  /// 复习盲听：弹段落选择弹窗后进入段落播放
  ///
  /// [stage] 当前复习阶段，用于在弹窗上显示阶段名和预估时长。
  Future<void> _startReviewBlindListen(
    BuildContext context, {
    required LearningStage stage,
  }) async {
    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(widget.audioItemId);
    if (audioItem == null) return;
    final lpState = audioItem.isVideo ? null : await _ensureAudioLoaded();
    if (!context.mounted) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(widget.audioItemId).future)
        : lpState?.sentences ?? const <Sentence>[];
    if (!context.mounted) return;
    if (sentences.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final estimatedDuration = estimateBlindListenSessionDuration(
      sentences: sentences,
      fullAudioDuration: ref.read(audioEngineProvider).totalDuration,
      skipSilenceEnabled: ref.read(appSettingsProvider).skipSilenceEnabled,
    );
    final estimatedText = estimatedDuration != null
        ? formatEstimatedDuration(l10n, estimatedDuration)
        : null;

    final progressForSpeed = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    // 按当前难句书签数实时重算难度，难度降低后速度随之回升
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(widget.audioItemId, sentences.length);
    if (!context.mounted) return;
    final skip = _buildSkipCallback();
    final smartSpeed = progressForSpeed != null
        ? defaultPlaybackSpeedFor(liveDifficulty, stage)
        : 1.0;
    final slot = stageSlotKey(StageSettingsSlots.blindListen, stage);
    final blindPrefs = ref.read(blindListenPrefsProvider.notifier);
    final defaults = blindPrefs.resolve(slot, smartSpeed: smartSpeed);
    final blindSeconds = blindPrefs.resolveTargetSeconds(
      slot,
      smartSeconds: -1,
    );
    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      stageLabel: reviewStageLabel(l10n, stage),
      estimatedDurationText: estimatedText,
      defaultPlaybackSpeed: defaults.playbackSpeed,
      defaultSeconds: blindSeconds,
      defaultPause: blindPauseChoiceFromSettings(defaults),
      onSelectionChanged: blindPrefsRecorder(ref, slot, defaults, blindSeconds),
      skipLabel: skip != null ? l10n.retellSkip : null,
      onSkip: skip,
      onStartPractice: (targetDuration, pause, playbackSpeed) async {
        final settings = ref
            .read(blindListenPrefsProvider.notifier)
            .resolve(slot, smartSpeed: smartSpeed);
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        await _openBlindListenPractice(
          context: context,
          ref: ref,
          audioItem: audioItem,
          collectionId: widget.collectionId,
          paragraphs: paragraphs,
          settings: settings,
          stage: stage,
          loadKey: '${audioItem.id}:blind-listen:${stage.key}:planned',
        );
      },
    );
  }

  /// 复习难句补练：进入 ReviewDifficultPracticeScreen
  ///
  /// 先检查书签数量，无难句时自动完成并跳到下一复述子阶段。
  Future<void> _startReviewDifficultPractice(
    BuildContext context, {
    DifficultPracticeSettings settings = const DifficultPracticeSettings(),
    LearningStage? stage,
  }) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      SubStageType.reviewDifficultPractice,
    );
    if (!allowed || !context.mounted) return;

    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(widget.audioItemId);
    if (audioItem == null) return;
    final lpState = audioItem.isVideo ? null : await _ensureAudioLoaded();
    if (!context.mounted) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(widget.audioItemId).future)
        : lpState?.sentences;
    if (!context.mounted || sentences == null) return;
    final l10n = AppLocalizations.of(context)!;

    if (sentences.isEmpty) {
      // 无字幕 → 跳过
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reviewDifficultPracticeNone)),
        );
      }
      return;
    }

    // 检查书签数量（难句数）
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarks = await BookmarkManager.loadBookmarks(
      widget.audioItemId,
      dao: bookmarkDao,
    );
    if (!context.mounted) return;

    if (bookmarks.isEmpty) {
      // 无难句 → 自动完成补练，推进到下一子阶段
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.reviewDifficultPracticeNone)));
      // 推进后根据新位置自动进入下一子步骤（复述 / v2 review0 的全文盲听）
      _navigateToNextReviewSubStageFromPlan(context);
      return;
    }

    final route = AppRoutes.reviewDifficultPractice(
      widget.collectionId,
      widget.audioItemId,
    );
    context.push(
      route,
      extra: MediaLearningStartup(
        loadKey:
            '${audioItem.id}:review-difficult:${stage?.key ?? 'current'}:planned',
        showVideoLoading: audioItem.isVideo,
        load: () => ref
            .read(learningSessionProvider.notifier)
            .enterReviewDifficultPracticeMode(
              audioItem,
              sentences,
              settings: settings,
              stage: stage,
            ),
        cancel: () => ref
            .read(learningSessionProvider.notifier)
            .cancelReviewDifficultPracticeEntry(),
      ),
    );
  }

  /// 自动完成难句补练后，按新的 `currentSubStage` 自动进入下一个子步骤。
  ///
  /// 处理：
  /// - v1 review0：reviewRetellParagraph → 段落复述
  /// - v2 review0：blindListen → 复习盲听
  /// - 中间轮 review1~14：blindListen / reviewRetellParagraph
  /// - 末轮 review28：blindListen / reviewRetellSummary
  /// - 跨阶段推进到 completed / firstLearn 等其它情况：不导航，回到计划页。
  void _navigateToNextReviewSubStageFromPlan(BuildContext context) {
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    if (progress == null) return;
    if (!progress.isInReviewStage) return;

    switch (progress.currentSubStage) {
      case SubStageType.blindListen:
        _startReviewBlindListen(context, stage: progress.currentStage);
      case SubStageType.reviewRetellParagraph:
        _startReviewRetell(context, isSummary: false);
      case SubStageType.reviewRetellSummary:
        _startReviewRetell(context, isSummary: true);
      default:
        // 推进后罕见落到难句补练等情况，回到计划页让用户重新选择
        break;
    }
  }

  /// 复习复述：复用 RetellPlayerScreen
  ///
  /// [isSummary] 为 true 时全文作为单个段落（reviewRetellSummary）
  Future<void> _startReviewRetell(
    BuildContext context, {
    required bool isSummary,
  }) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      isSummary
          ? SubStageType.reviewRetellSummary
          : SubStageType.reviewRetellParagraph,
    );
    if (!allowed || !context.mounted) return;

    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(widget.audioItemId);
    if (audioItem == null) return;
    final lpState = audioItem.isVideo ? null : await _ensureAudioLoaded();
    if (!context.mounted) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(widget.audioItemId).future)
        : lpState?.sentences;
    if (!context.mounted || sentences == null) return;

    if (sentences.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.intensiveListenNoSubtitle,
            ),
          ),
        );
      }
      return;
    }

    if (isSummary) {
      // reviewRetellSummary：全文作为单个段落；停顿/速度已由复习简报落入偏好,
      // enterRetellMode 内部按槽位 resolve 出完整设置。
      await _openRetellPractice(
        context: context,
        ref: ref,
        audioItem: audioItem,
        collectionId: widget.collectionId,
        paragraphs: [sentences],
        loadKey: '${audioItem.id}:retell-summary:planned',
      );
      return;
    }

    // reviewRetellParagraph：弹出简报面板让用户选择段落时长
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    final currentStage = progress?.currentStage;

    // 复习阶段显示阶段名；预估时长由 briefing sheet 内部按真实公式动态计算
    final l10n = AppLocalizations.of(context)!;
    final isReview =
        currentStage != null && currentStage != LearningStage.firstLearn;

    final effectiveStage = currentStage ?? LearningStage.firstLearn;
    // 按当前难句书签数实时重算难度，难度降低后速度/可见词比例随之调整
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(widget.audioItemId, sentences.length);
    if (!context.mounted) return;
    final smartRatio = KeywordRatio.forDifficultyAndStage(
      liveDifficulty,
      effectiveStage,
    );
    final slot = stageSlotKey(StageSettingsSlots.retell, effectiveStage);
    final prefill = retellBriefingDefaults(
      ref,
      slot,
      smartSpeed: progress != null
          ? defaultPlaybackSpeedFor(liveDifficulty, effectiveStage)
          : 1.0,
      smartRatio: smartRatio,
      smartSeconds: retellDefaultSeconds(currentStage),
    );
    showRetellBriefingSheet(
      context: context,
      sentences: sentences,
      defaultSeconds: prefill.seconds,
      stageLabel: isReview ? reviewStageLabel(l10n, currentStage) : null,
      defaultKeywordRatio: progress != null ? prefill.ratio : null,
      defaultPlaybackSpeed: prefill.speed,
      defaultPause: prefill.pause,
      onSelectionChanged: retellPrefsRecorder(ref, slot, prefill.settings),
      onStartPractice:
          (targetDuration, pause, keywordRatio, playbackSpeed) async {
            final paragraphs = groupSentencesIntoParagraphs(
              sentences,
              targetDuration,
            );
            await _openRetellPractice(
              context: context,
              ref: ref,
              audioItem: audioItem,
              collectionId: widget.collectionId,
              paragraphs: paragraphs,
              loadKey: '${audioItem.id}:retell-paragraph:planned',
            );
          },
      // 按计划学习路径才显示「跳过」按钮；自由练习路径无此回调
      onSkip: () async {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .skipCurrentSubStage(widget.audioItemId);
      },
    );
  }

  /// 进入全文盲听
  ///
  /// 先弹简报弹窗，点"开始练习"后等待音频加载，
  /// 有字幕时再弹段落选择弹窗，无字幕时直接进入极简播放。
  Future<void> _startBlindListen(
    BuildContext context,
    LearningProgress? progress,
  ) async {
    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(widget.audioItemId);
    if (audioItem == null) return;
    // 视频字幕直接从数据库读取，避免把视频送入原音频播放链路。
    final lpState = audioItem.isVideo ? null : await _ensureAudioLoaded();
    if (!context.mounted) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(widget.audioItemId).future)
        : lpState?.sentences ?? const [];

    if (sentences.isEmpty) return;

    // 按当前难句书签数实时重算难度，难度降低后速度随之回升（与难句跟读/复述一致）
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(widget.audioItemId, sentences.length);
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final estimatedDuration = estimateBlindListenSessionDuration(
      sentences: sentences,
      fullAudioDuration: ref.read(audioEngineProvider).totalDuration,
      skipSilenceEnabled: ref.read(appSettingsProvider).skipSilenceEnabled,
    );

    // 首次学习的第一个盲听不可跳过，_buildSkipCallback 在此返回 null（无跳过按钮）
    final skip = _buildSkipCallback();
    // 全文盲听属于首次学习步骤，按 firstLearn 阶段算默认速度
    const stage = LearningStage.firstLearn;
    final smartSpeed = progress != null
        ? defaultPlaybackSpeedFor(liveDifficulty, LearningStage.firstLearn)
        : 1.0;
    final slot = stageSlotKey(StageSettingsSlots.blindListen, stage);
    final blindPrefs = ref.read(blindListenPrefsProvider.notifier);
    final defaults = blindPrefs.resolve(slot, smartSpeed: smartSpeed);
    final blindSeconds = blindPrefs.resolveTargetSeconds(
      slot,
      smartSeconds: -1,
    );
    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      estimatedDurationText: estimatedDuration != null
          ? formatEstimatedDuration(l10n, estimatedDuration)
          : null,
      defaultPlaybackSpeed: defaults.playbackSpeed,
      defaultSeconds: blindSeconds,
      defaultPause: blindPauseChoiceFromSettings(defaults),
      onSelectionChanged: blindPrefsRecorder(ref, slot, defaults, blindSeconds),
      skipLabel: skip != null ? l10n.retellSkip : null,
      onSkip: skip,
      onStartPractice: (targetDuration, pause, playbackSpeed) async {
        final settings = ref
            .read(blindListenPrefsProvider.notifier)
            .resolve(slot, smartSpeed: smartSpeed);
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        await _openBlindListenPractice(
          context: context,
          ref: ref,
          audioItem: audioItem,
          collectionId: widget.collectionId,
          paragraphs: paragraphs,
          settings: settings,
          stage: stage,
          loadKey: '${audioItem.id}:blind-listen:planned',
        );
      },
    );
  }

  /// 进入逐句精听
  Future<void> _startIntensiveListen(BuildContext context) async {
    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(widget.audioItemId);
    if (audioItem == null) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(widget.audioItemId).future)
        : (await _ensureAudioLoaded())?.sentences;
    if (!context.mounted || sentences == null) return;
    final l10n = AppLocalizations.of(context)!;

    // 无字幕则提示用户上传
    if (sentences.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.intensiveListenNoSubtitle),
          content: Text(l10n.intensiveListenNoSubtitleMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    // 预估时长：每句 = 句子时长 × 2（听 + 停顿处理）
    final totalSentenceDuration = sentences.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final intensiveEstimate = totalSentenceDuration * 2;

    // 单一真相源:逐句精听仅在首学,槽位 intensiveListen:firstLearn。
    final slot = stageSlotKey(
      StageSettingsSlots.intensiveListen,
      LearningStage.firstLearn,
    );
    final prefs = ref.read(intensiveListenPrefsProvider.notifier);
    final defaults = prefs.resolve(slot, smartSpeed: 1.0);
    showIntensiveListenBriefingSheet(
      context: context,
      sentenceCount: sentences.length,
      estimatedDuration: intensiveEstimate,
      defaultPlaybackSpeed: defaults.playbackSpeed,
      defaultPause: intensivePauseChoiceFromSettings(defaults),
      // 改完即记(与 🔧 面板一致):无论是否「开始练习」、即使关闭弹窗都已持久化。
      onSelectionChanged: intensivePrefsRecorder(prefs, slot, defaults),
      onStartPractice: (playbackSpeed, pause) async {
        final session = ref.read(learningSessionProvider.notifier);
        final resolved = prefs.resolve(slot, smartSpeed: 1.0);
        if (!context.mounted) return;
        context.push(
          AppRoutes.intensiveListenPlayer(
            widget.collectionId,
            widget.audioItemId,
          ),
          extra: MediaLearningStartup(
            loadKey: '${audioItem.id}:planned',
            load: () => session.enterIntensiveListenMode(
              audioItem,
              sentences,
              settings: resolved,
              settingsSlot: slot,
            ),
            cancel: session.cancelIntensiveListenEntry,
            showVideoLoading: audioItem.isVideo,
          ),
        );
      },
      onSkip: _buildSkipCallback(),
    );
  }

  /// 进入难句跟读
  Future<void> _startListenAndRepeat(BuildContext context) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      SubStageType.listenAndRepeat,
    );
    if (!allowed || !context.mounted) return;

    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(widget.audioItemId);
    if (audioItem == null) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(widget.audioItemId).future)
        : (await _ensureAudioLoaded())?.sentences;
    if (!context.mounted || sentences == null) return;
    final l10n = AppLocalizations.of(context)!;

    if (sentences.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.intensiveListenNoSubtitle),
          content: Text(l10n.intensiveListenNoSubtitleMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final difficultIndices = await BookmarkManager.loadBookmarks(
      widget.audioItemId,
      dao: bookmarkDao,
    );
    if (!context.mounted) return;

    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    // 按当前难句书签数实时重算难度（难句跟读入口最关键：用户练熟取消收藏后
    // 比例下降 → 难度降低 → 速度回升），同时用于跟读遍数 playCount。
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(widget.audioItemId, sentences.length);
    if (!context.mounted) return;
    final playCount = targetPlayCountForDifficulty(liveDifficulty.index);

    final difficultDuration = difficultIndices.fold<Duration>(
      Duration.zero,
      (sum, idx) =>
          sum +
          (idx < sentences.length ? sentences[idx].duration : Duration.zero),
    );
    final repeatEstimate = difficultDuration * playCount * 2;

    const stage = LearningStage.firstLearn;
    final smartSpeed = progress != null
        ? defaultPlaybackSpeedFor(liveDifficulty, LearningStage.firstLearn)
        : 1.0;
    // 难句跟读与逐句精听共用 IntensiveListenPrefs store,槽位 listenAndRepeat:firstLearn。
    final slot = stageSlotKey(StageSettingsSlots.listenAndRepeat, stage);
    final prefs = ref.read(intensiveListenPrefsProvider.notifier);
    final defaults = prefs.resolve(slot, smartSpeed: smartSpeed);
    final defaultScope = prefs.listenAndRepeatScopeFor(slot);
    final fullTextDuration = sentences.fold<Duration>(
      Duration.zero,
      (sum, sentence) => sum + sentence.duration,
    );
    showListenAndRepeatBriefingSheet(
      context: context,
      difficultCount: difficultIndices.length,
      fullTextCount: sentences.length,
      playCount: playCount,
      difficultEstimatedDuration: repeatEstimate,
      fullTextEstimatedDuration: fullTextDuration * playCount * 2,
      defaultScope: defaultScope,
      defaultPlaybackSpeed: defaults.playbackSpeed,
      defaultPause: intensivePauseChoiceFromSettings(defaults),
      onSelectionChanged: intensivePrefsRecorder(prefs, slot, defaults),
      onScopeChanged: (scope) {
        prefs.setListenAndRepeatScope(slot, scope);
        ref
            .read(learningProgressNotifierProvider.notifier)
            .saveShadowingSentenceIndex(
              widget.audioItemId,
              null,
              isFreePlay: false,
            );
      },
      onStartPractice: (playbackSpeed, pause, scope) async {
        if (scope == ListenAndRepeatScope.difficultOnly &&
            difficultIndices.isEmpty) {
          await ref
              .read(learningProgressNotifierProvider.notifier)
              .completeCurrentSubStage(widget.audioItemId);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.difficultSentenceCount(0))),
          );
          return;
        }
        await _pushPracticeAndWaitForTransition(
          context,
          AppRoutes.listenAndRepeatPlayer(
            widget.collectionId,
            widget.audioItemId,
          ),
          ref: ref,
          event: RatingPromptEvent.shadowingCompleted,
          extra: MediaLearningStartup(
            loadKey: '${audioItem.id}:listen-and-repeat:planned',
            showVideoLoading: audioItem.isVideo,
            load: () => ref
                .read(listenAndRepeatControllerProvider.notifier)
                .initialize(
                  mediaItem: audioItem,
                  allSentences: sentences,
                  isFreePlay: false,
                  scope: scope,
                  smartSpeed: smartSpeed,
                  stage: stage,
                ),
            cancel: () => ref
                .read(listenAndRepeatControllerProvider.notifier)
                .cancelEntry(),
          ),
        );
      },
      onSkip: _buildSkipCallback(),
    );
  }

  /// 进入段落复述
  Future<void> _startRetelling(BuildContext context) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      SubStageType.retell,
    );
    if (!allowed || !context.mounted) return;

    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(widget.audioItemId);
    if (audioItem == null) return;
    final lpState = audioItem.isVideo ? null : await _ensureAudioLoaded();
    if (!context.mounted) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(widget.audioItemId).future)
        : lpState?.sentences;
    if (!context.mounted || sentences == null) return;
    final l10n = AppLocalizations.of(context)!;

    // 无字幕则提示
    if (sentences.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.intensiveListenNoSubtitle),
          content: Text(l10n.intensiveListenNoSubtitleMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    final progressForDefault = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    final stageForDefault =
        progressForDefault?.currentStage ?? LearningStage.firstLearn;
    // 按当前难句书签数实时重算难度，难度降低后速度/可见词比例随之调整
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(widget.audioItemId, sentences.length);
    if (!context.mounted) return;
    final hasProgress = progressForDefault != null;
    final smartRatio = KeywordRatio.forDifficultyAndStage(
      liveDifficulty,
      stageForDefault,
    );
    final slot = stageSlotKey(StageSettingsSlots.retell, stageForDefault);
    final prefill = retellBriefingDefaults(
      ref,
      slot,
      smartSpeed: hasProgress
          ? defaultPlaybackSpeedFor(liveDifficulty, stageForDefault)
          : 1.0,
      smartRatio: smartRatio,
      smartSeconds: retellDefaultSeconds(stageForDefault),
    );
    showRetellBriefingSheet(
      context: context,
      sentences: sentences,
      defaultSeconds: prefill.seconds,
      defaultKeywordRatio: hasProgress ? prefill.ratio : null,
      defaultPlaybackSpeed: prefill.speed,
      defaultPause: prefill.pause,
      onSelectionChanged: retellPrefsRecorder(ref, slot, prefill.settings),
      onStartPractice:
          (targetDuration, pause, keywordRatio, playbackSpeed) async {
            final paragraphs = groupSentencesIntoParagraphs(
              sentences,
              targetDuration,
            );

            await _openRetellPractice(
              context: context,
              ref: ref,
              audioItem: audioItem,
              collectionId: widget.collectionId,
              paragraphs: paragraphs,
              loadKey: '${audioItem.id}:retell:planned',
            );
          },
      // 按计划学习路径才显示「跳过」按钮；自由练习路径无此回调
      onSkip: () async {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .skipCurrentSubStage(widget.audioItemId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final audioItem = ref.watch(
      audioLibraryProvider.select(
        (s) =>
            s.audioItems.where((i) => i.id == widget.audioItemId).firstOrNull,
      ),
    );

    // 监听学习进度
    final progress = ref.watch(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[widget.audioItemId],
      ),
    );
    final now = ref.watch(nowProvider)();

    // audioItem 找不到时显示错误页面
    if (audioItem == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.audioFileNotFound)),
      );
    }

    // autoStart：正常渲染计划页，同时自动触发 _handleStartLearning（弹 briefing sheet）
    if (widget.autoStart && !_autoStartTriggered) {
      _autoStartTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleStartLearning(context, progress);
      });
    }

    final reviewStages = _buildReviewStages(l10n);

    // 当前音频所属的所有合集名（按合集列表顺序），用于 AppBar 副标题
    final collectionNames = ref.watch(
      collectionListProvider.select((s) {
        final ids = s.audioToCollectionsMap[widget.audioItemId] ?? const [];
        if (ids.isEmpty) return const <String>[];
        final idSet = ids.toSet();
        return s.collections
            .where((c) => idSet.contains(c.id))
            .map((c) => c.name)
            .toList(growable: false);
      }),
    );

    final hasTranscript = audioItem.hasTranscript;
    final isLockedReview = progress?.isReviewLockedAt(now) ?? false;
    final startLearningAction = !isLockedReview
        ? hasTranscript
              ? () => _handleStartLearning(context, progress)
              : () => _showMissingTranscriptSnackBar(context)
        : null;

    final stepFreePlay = GuideStep(
      key: _keyFreePlay,
      title: l10n.guidePlanFreePlayTitle,
      description: l10n.guidePlanFreePlayDescription,
    );
    final stepStartLearning = GuideStep(
      key: _keyStartLearning,
      title: l10n.guidePlanStartLearningTitle,
      description: l10n.guidePlanStartLearningDescription,
    );
    final stepAddSubtitle = GuideStep(
      key: _keyAddSubtitle,
      title: l10n.guidePlanAddSubtitleTitle,
      description: l10n.guidePlanAddSubtitleDescription,
    );
    final stepPauseLearning = GuideStep(
      key: _keyPauseLearning,
      title: l10n.guidePlanPauseLearningTitle,
      description: l10n.guidePlanPauseLearningDescription,
    );

    // 暂停学习按钮仅在已开始学习且当前未暂停时才会渲染，引导也只在此时
    // 触发；和「自由练习 / 按计划学习」flow 隔离，让用户开始学习后再看到。
    final showPauseLearningGuide =
        hasTranscript &&
        (progress?.isStarted ?? false) &&
        !(progress?.isPaused ?? false);

    final flows = <GuideFlow>[
      GuideFlow(
        flowId: GuideFlowIds.learningPlanWithTranscript,
        shouldRun: hasTranscript,
        steps: [stepFreePlay, stepStartLearning],
      ),
      GuideFlow(
        flowId: GuideFlowIds.learningPlanNoTranscript,
        shouldRun: !hasTranscript,
        steps: [stepAddSubtitle],
      ),
      GuideFlow(
        flowId: GuideFlowIds.learningPlanPauseLearning,
        shouldRun: showPauseLearningGuide,
        steps: [stepPauseLearning],
      ),
    ];

    return GuideFlowSequenceHost(
      flows: flows,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: AudioAppBarTitle(
            audioName: audioItem.name,
            collectionNames: collectionNames,
          ),
          actions: [
            GuideTarget(
              step: stepFreePlay,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s),
                child: _FreePlayAppBarButton(
                  label: l10n.freePlay,
                  onPressed: () => _openFreePlay(context),
                ),
              ),
            ),
            ?_buildPlanMenu(context, l10n, audioItem, progress),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.m),
                children: [
                  _ProgressCard(
                    l10n: l10n,
                    progress: progress,
                    audioItem: audioItem,
                    now: now,
                  ),
                  if (!hasTranscript) ...[
                    const SizedBox(height: AppSpacing.s),
                    _NoTranscriptBanner(
                      l10n: l10n,
                      audioItem: audioItem,
                      addSubtitleStep: stepAddSubtitle,
                    ),
                  ],
                  // 听前预热卡：未开始本音频且有字幕时显示，引导用户先随心听
                  // 熟悉内容。放在「首次学习」之上，作为整个学习流程的前置预热；
                  // 用户开始学习后 isStarted 变 true，卡片自动消失（按音频维度
                  // 一次性，无需新增持久化）。
                  if ((progress == null || !progress.isStarted) &&
                      hasTranscript) ...[
                    const SizedBox(height: AppSpacing.s),
                    _WarmUpCard(
                      l10n: l10n,
                      onTap: () => _openFreePlay(context),
                    ),
                    const SizedBox(height: AppSpacing.s),
                  ] else
                    const SizedBox(height: AppSpacing.l),
                  _FirstStudySection(
                    l10n: l10n,
                    progress: progress,
                    collectionId: widget.collectionId,
                    audioItemId: widget.audioItemId,
                    isExpanded: _isFirstLearnExpanded ??=
                        progress?.isCurrentStage(LearningStage.firstLearn) ??
                        true,
                    onToggle: () => setState(
                      () => _isFirstLearnExpanded =
                          !(_isFirstLearnExpanded ?? true),
                    ),
                    onStartCurrentStage: startLearningAction,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  ...List.generate(reviewStages.length, (index) {
                    final review = reviewStages[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == reviewStages.length - 1
                            ? 0
                            : AppSpacing.m,
                      ),
                      child: _ReviewRoundSection(
                        l10n: l10n,
                        progress: progress,
                        review: review,
                        now: now,
                        collectionId: widget.collectionId,
                        audioItemId: widget.audioItemId,
                        isExpanded: _isReviewRoundExpanded(
                          review.stage,
                          progress,
                        ),
                        onToggle: () =>
                            _toggleReviewRoundExpanded(review.stage),
                        onStartCurrentStage: startLearningAction,
                      ),
                    );
                  }),
                ],
              ),
            ),
            _BottomButton(
              l10n: l10n,
              progress: progress,
              audioItemId: widget.audioItemId,
              audioItemName: audioItem.name,
              startLearningStep: hasTranscript ? stepStartLearning : null,
              pauseLearningStep: showPauseLearningGuide
                  ? stepPauseLearning
                  : null,
              onPressed: startLearningAction,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建复习阶段列表（review0 ~ review28，共 7 个）
  List<_ReviewStageData> _buildReviewStages(AppLocalizations l10n) {
    return [
      _ReviewStageData(name: l10n.reviewRound0, stage: LearningStage.review0),
      _ReviewStageData(name: l10n.reviewRound1, stage: LearningStage.review1),
      _ReviewStageData(name: l10n.reviewRound2, stage: LearningStage.review2),
      _ReviewStageData(name: l10n.reviewRound4, stage: LearningStage.review4),
      _ReviewStageData(name: l10n.reviewRound7, stage: LearningStage.review7),
      _ReviewStageData(name: l10n.reviewRound14, stage: LearningStage.review14),
      _ReviewStageData(name: l10n.reviewRound28, stage: LearningStage.review28),
    ];
  }

  /// 读取复习轮次展开态（仅首次按默认规则初始化）
  ///
  /// 默认规则：
  /// - 已完成轮次：折叠
  /// - 当前进行中轮次：展开
  /// - 未来轮次：折叠
  bool _isReviewRoundExpanded(LearningStage stage, LearningProgress? progress) {
    return _reviewRoundExpandedMap.putIfAbsent(
      stage,
      () => progress?.isCurrentStage(stage) ?? false,
    );
  }

  /// 切换单个复习轮次的展开态
  void _toggleReviewRoundExpanded(LearningStage stage) {
    setState(() {
      _reviewRoundExpandedMap[stage] =
          !(_reviewRoundExpandedMap[stage] ?? false);
    });
  }
}

/// 顶部进度卡片 — 圆环进度 + 状态文字 + 逾期徽章 + 音频元信息
class _ProgressCard extends ConsumerWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;
  final AudioItem? audioItem;
  final DateTime now;

  const _ProgressCard({
    required this.l10n,
    this.progress,
    this.audioItem,
    required this.now,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // 没有 audioItem 时（理论不出现，因 progress 同源）退化到全局默认 plan。
    final plan = audioItem == null
        ? ref.watch(learningPlanProvider)
        : ref.watch(learningPlanForAudioProvider(audioItem!.id));
    final completedKeys = audioItem == null
        ? const <String>{}
        : ref
              .watch(learningProgressNotifierProvider)
              .completionsFor(audioItem!.id);
    final percent = progress?.progressPercent(plan, completedKeys) ?? 0.0;
    final percentText = '${(percent * 100).round()}%';

    final isInProgress = _isInProgress();
    final overdueText = _getOverdueText();
    // 第一行徽章：进行中显示 In Progress，否则显示逾期
    final badgeText = isInProgress ? l10n.learningInProgress : overdueText;
    final badgeIsError = !isInProgress && overdueText != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            // 左侧：圆环进度
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                painter: _ProgressRingPainter(
                  progress: percent,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  progressColor: theme.colorScheme.primary,
                ),
                child: Center(
                  child: Text(
                    percentText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            // 右侧：三行信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第一行：大阶段 + 逾期徽章
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _getStageText(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: AppSpacing.s),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: badgeIsError
                                ? theme.colorScheme.error.withValues(alpha: 0.1)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: badgeIsError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: badgeIsError
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // 第二行：子阶段
                  if (_getSubStageText() case final subStage?) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subStage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  // 第三行：音频元信息
                  if (audioItem != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _buildAudioInfo(theme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建音频元信息行
  Widget _buildAudioInfo(ThemeData theme) {
    final item = audioItem!;
    final chips = <Widget>[];

    // 内容异常警告（损坏 / 静音）放在首位，最醒目。
    final contentWarningLabel = _contentWarningLabel(item.contentStatus);
    if (contentWarningLabel != null) {
      chips.add(_buildContentWarningChip(theme, contentWarningLabel));
    }
    if (item.totalDuration > 0) {
      chips.add(
        _InfoChip(
          icon: Icons.timer_outlined,
          label: SubtitleParser.formatDuration(
            Duration(seconds: item.totalDuration),
          ),
          theme: theme,
        ),
      );
    }
    if (item.sentenceCount > 0) {
      chips.add(
        _InfoChip(
          icon: Icons.format_list_numbered,
          label: l10n.sentenceCountLabel(item.sentenceCount),
          theme: theme,
        ),
      );
    }
    if (item.wordCount > 0) {
      chips.add(
        _InfoChip(
          icon: Icons.text_fields,
          label: l10n.wordCountLabel(item.wordCount),
          theme: theme,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }

  /// 内容异常警告徽章，与音频列表项的警告徽章风格一致。
  Widget _buildContentWarningChip(ThemeData theme, String label) {
    final color = theme.colorScheme.error;
    return Container(
      key: const Key('learning_plan_content_warning_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  String? _contentWarningLabel(AudioContentStatus? status) {
    return switch (status) {
      AudioContentStatus.damaged => l10n.audioContentDamagedWarning,
      AudioContentStatus.silent => l10n.audioContentSilentWarning,
      AudioContentStatus.ok || null => null,
    };
  }

  /// 第一行：大阶段文字
  String _getStageText() {
    if (progress == null || !progress!.isStarted) {
      return l10n.learningPlanNotStarted;
    }
    if (progress!.isCompleted) {
      return l10n.learningCompleted;
    }
    return reviewStageLabel(l10n, progress!.currentStage);
  }

  /// 第二行：子阶段文字（未开始/已完成时返回 null）
  String? _getSubStageText() {
    if (progress == null || !progress!.isStarted || progress!.isCompleted) {
      return null;
    }
    final subStageName = switch (progress!.currentSubStage) {
      SubStageType.blindListen => l10n.stepBlindListening,
      SubStageType.intensiveListen => l10n.stepIntensiveListening,
      SubStageType.listenAndRepeat => l10n.stepShadowing,
      SubStageType.retell => l10n.stepRetelling,
      SubStageType.reviewDifficultPractice => l10n.reviewDifficultPracticeTitle,
      SubStageType.reviewRetellParagraph => l10n.stepRetelling,
      SubStageType.reviewRetellSummary => l10n.stepRetelling,
    };
    return subStageName;
  }

  /// 是否正在学习中（当前阶段已完成至少 1 个子阶段）
  bool _isInProgress() {
    if (progress == null || !progress!.isStarted || progress!.isCompleted) {
      return false;
    }
    return progress!.currentSubStageIndex > 0;
  }

  /// 获取逾期文案（未逾期返回 null）
  String? _getOverdueText() {
    if (progress == null || !progress!.isReviewOverdueAt(now)) return null;
    final overdue = progress!.overdueDurationAt(now);
    if (overdue == null || overdue.inDays > 7) return l10n.reviewDue;
    if (overdue.inDays > 0) return l10n.overdueDays(overdue.inDays);
    final hours = overdue.inHours.clamp(1, 999);
    return l10n.overdueHours(hours);
  }
}

/// 学习计划页 AppBar 的「自由练习」入口。
///
/// 这里不用普通文字按钮，而是做成轻量 CTA 胶囊，提升可发现性，
/// 同时控制横向占用，避免在移动端把标题进一步挤压。
class _FreePlayAppBarButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _FreePlayAppBarButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = colorScheme.primaryContainer.withValues(
      alpha: isDark ? 0.34 : 0.72,
    );
    final borderColor = colorScheme.primary.withValues(
      alpha: isDark ? 0.18 : 0.24,
    );
    final iconColor = colorScheme.primary;
    final labelColor = colorScheme.onPrimaryContainer;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: colorScheme.primary.withValues(alpha: 0.12),
        child: InkWell(
          key: const Key('learning_plan_free_play_button'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: surfaceColor,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.headphones_rounded, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 圆环进度绘制器
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  _ProgressRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 6.0;

    // 背景圆环
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度圆弧
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 学习计划阶段标题行。
///
/// 固定关键列宽，避免某一行缺少状态文案时影响后续进度计数和展开箭头的列对齐。
class _StageHeaderRow extends StatelessWidget {
  final String keyPrefix;
  final Widget leadingIcon;
  final String title;
  final Color? titleColor;
  final Widget statusIcon;
  final String? statusText;
  final Color statusTextColor;
  final String progressText;
  final Color progressColor;
  final bool isExpanded;
  final VoidCallback onTap;

  const _StageHeaderRow({
    required this.keyPrefix,
    required this.leadingIcon,
    required this.title,
    this.titleColor,
    required this.statusIcon,
    this.statusText,
    required this.statusTextColor,
    required this.progressText,
    required this.progressColor,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final titleColumnWidth = isZh
        ? _stageHeaderZhTitleColumnWidth
        : _stageHeaderTitleColumnWidth;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const horizontalGaps =
                AppSpacing.s +
                AppSpacing.xs +
                AppSpacing.s +
                AppSpacing.s +
                AppSpacing.xs;
            final fixedWidth =
                20 +
                titleColumnWidth +
                18 +
                _stageHeaderProgressColumnWidth +
                24 +
                horizontalGaps;
            final statusTextWidth = math
                .max(0, constraints.maxWidth - fixedWidth)
                .clamp(0, _stageHeaderStatusTextMaxWidth)
                .toDouble();

            return Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(child: leadingIcon),
                ),
                const SizedBox(width: AppSpacing.s),
                SizedBox(
                  key: Key('${keyPrefix}_title_column'),
                  width: titleColumnWidth,
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  key: Key('${keyPrefix}_status_icon_column'),
                  width: 18,
                  height: 18,
                  child: Center(child: statusIcon),
                ),
                const SizedBox(width: AppSpacing.s),
                SizedBox(
                  key: Key('${keyPrefix}_status_text_column'),
                  width: statusTextWidth,
                  child: Text(
                    statusText ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: AppSpacing.s),
                SizedBox(
                  key: Key('${keyPrefix}_progress_column'),
                  width: _stageHeaderProgressColumnWidth,
                  child: Text(
                    progressText,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: progressColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  key: Key('${keyPrefix}_expand_column'),
                  width: 24,
                  child: AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 首次学习区域 — 默认展开，显示 4 个步骤
///
/// 已完成的盲听步骤支持点击进入自由练习模式。
class _FirstStudySection extends ConsumerWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;

  /// 合集 ID（导航用，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID（导航用）
  final String audioItemId;

  /// 是否展开
  final bool isExpanded;

  /// 折叠/展开切换回调
  final VoidCallback onToggle;

  /// 点击当前进行中步骤的回调（效果同底部「开始学习」），不可启动时为 null
  final VoidCallback? onStartCurrentStage;

  const _FirstStudySection({
    required this.l10n,
    this.progress,
    required this.collectionId,
    required this.audioItemId,
    required this.isExpanded,
    required this.onToggle,
    this.onStartCurrentStage,
  });

  /// 使用统计与任务卡片共用的阶段展示定义，仅补充首次学习描述。
  _StepData _stepDataForStage(StudyStage stage, String description) {
    final visual = studyStageVisual(stage, l10n);
    return _StepData(
      icon: visual.icon,
      iconColor: visual.iconColor,
      name: visual.name,
      description: description,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(learningPlanForAudioProvider(audioItemId));
    final stageCompletedAtMap =
        ref
            .watch(reviewStageCompletionTimesProvider(audioItemId))
            .valueOrNull ??
        const <String, DateTime>{};
    final completedKeys = ref
        .watch(learningProgressNotifierProvider)
        .completionsFor(audioItemId);
    final completedCount =
        progress?.completedFirstStudySteps(plan, completedKeys) ?? 0;
    final firstLearnStage = LearningStage.firstLearn;
    final isFirstLearnCompleted =
        progress?.isStageCompleted(LearningStage.firstLearn) ?? false;
    final firstLearnCompletedAt =
        stageCompletedAtMap[LearningStage.firstLearn.key] ??
        progress?.firstLearnCompletedAt;
    final firstLearnStatusText =
        isFirstLearnCompleted && firstLearnCompletedAt != null
        ? formatCompletedStageTimeLabel(context, firstLearnCompletedAt)
        : null;

    /// 子步骤的 UI 数据映射
    final stepDataMap = {
      SubStageType.blindListen: _stepDataForStage(
        StudyStage.blindListen,
        l10n.stepBlindListeningDesc,
      ),
      SubStageType.intensiveListen: _stepDataForStage(
        StudyStage.intensiveListen,
        l10n.stepIntensiveListeningDesc,
      ),
      SubStageType.listenAndRepeat: _stepDataForStage(
        StudyStage.listenAndRepeat,
        l10n.stepShadowingDesc,
      ),
      SubStageType.retell: _stepDataForStage(
        StudyStage.retell,
        l10n.stepRetellingDesc,
      ),
    };

    // 迭代顺序 = 当前 plan 顺序 + 历史外延项（已完成或已跳过但不在当前 plan 内）。
    // firstLearn 没有 plan 变体，但 helper 统一处理便于复用。
    final subStages = _orderedSubStagesForDisplay(
      plan: plan,
      stage: firstLearnStage,
      completedKeys: completedKeys,
      skippedKeys: progress?.skippedSubStageKeys ?? const {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行（可点击展开/折叠）
        _StageHeaderRow(
          keyPrefix: 'learning_plan_stage_first_learn',
          leadingIcon: SvgPicture.asset(
            _readingIconAsset,
            width: 20,
            height: 20,
          ),
          title: l10n.firstStudy,
          titleColor: isFirstLearnCompleted ? Colors.green : null,
          statusIcon: isFirstLearnCompleted
              ? SvgPicture.asset(
                  _checkCircleIconAsset,
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    Colors.green,
                    BlendMode.srcIn,
                  ),
                )
              : progress?.isCurrentStage(LearningStage.firstLearn) ?? false
              ? SvgPicture.asset(_calendarIconAsset, width: 18, height: 18)
              : SvgPicture.asset(
                  _lockIconAsset,
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.onSurfaceVariant,
                    BlendMode.srcIn,
                  ),
                ),
          statusText: firstLearnStatusText,
          statusTextColor: Colors.green,
          progressText: l10n.stepProgress(completedCount, subStages.length),
          progressColor: isFirstLearnCompleted
              ? Colors.green
              : theme.colorScheme.onSurfaceVariant,
          isExpanded: isExpanded,
          onTap: onToggle,
        ),
        // 展开的步骤列表（无动画，直接切换）
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.s),
          Column(
            children: List.generate(subStages.length, (index) {
              final subStage = subStages[index];
              final stepData = stepDataMap[subStage]!;
              final isCompleted =
                  progress?.isSubStageCompleted(
                    firstLearnStage,
                    subStage,
                    completedKeys,
                  ) ??
                  false;
              final isCurrent =
                  progress?.isCurrentSubStage(firstLearnStage, subStage) ??
                  false;
              final isSkipped =
                  progress?.isSubStageSkipped(firstLearnStage, subStage) ??
                  false;

              // 各步骤显示完成统计
              String? subtitle;
              if (subStage == SubStageType.blindListen) {
                // 盲听：仅显示已听遍数（难度在逐句精听完成时自动判定，盲听不再展示）
                final passCount = progress?.blindListenPassCount ?? 0;
                if (passCount > 0) {
                  subtitle = l10n.blindListenPassInfo(passCount);
                }
              } else if (subStage == SubStageType.intensiveListen) {
                // 精听：仅当前或已完成步骤显示统计
                if (isCompleted || isCurrent) {
                  subtitle = _buildIntensiveListenSubtitle(ref, l10n);
                }
              } else if (subStage == SubStageType.listenAndRepeat) {
                // 跟读：统一显示难句数量和已练习遍数，零难句也保留练习记录。
                if (isCompleted || isCurrent) {
                  subtitle = _buildShadowingSubtitle(ref, l10n);
                }
              } else if (subStage == SubStageType.retell) {
                // 复述：仅当前或已完成步骤显示统计
                if (isCompleted || isCurrent) {
                  subtitle = _buildRetellSubtitle(l10n);
                }
              }

              // 已完成、已跳过（含当前阶段内跳过）或过去阶段的步骤都支持点击进入自由练习。
              // （跳过的步骤用户随时可补做，不必等大阶段推进）
              final isPast =
                  progress != null &&
                  firstLearnStage.index < progress!.currentStage.index;
              final canFreePlay = isCompleted || isSkipped || isPast;
              VoidCallback? onTap;
              if (canFreePlay && subStage == SubStageType.blindListen) {
                onTap = () => _startFreePlayBlindListen(context, ref);
              } else if (canFreePlay &&
                  subStage == SubStageType.intensiveListen) {
                onTap = () => _startFreePlayIntensiveListen(context, ref);
              } else if (canFreePlay &&
                  subStage == SubStageType.listenAndRepeat) {
                onTap = () => _startFreePlayListenAndRepeat(context, ref);
              } else if (canFreePlay && subStage == SubStageType.retell) {
                onTap = () => _startFreePlayRetell(context, ref);
              }

              // 当前进行中的步骤：点击等同底部「开始学习」
              if (isCurrent) {
                onTap = onStartCurrentStage;
              }

              return _StepCard(
                stepNumber: index + 1,
                icon: stepData.icon,
                iconColor: stepData.iconColor,
                name: stepData.name,
                description: stepData.description,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                isSkipped: isSkipped,
                isFirst: index == 0,
                isLast: index == subStages.length - 1,
                subtitle: subtitle,
                onTap: onTap,
              );
            }),
          ),
        ],
      ],
    );
  }

  /// 构建精听卡片副标题（实时难句数 + 总完成遍数）
  String? _buildIntensiveListenSubtitle(WidgetRef ref, AppLocalizations l10n) {
    final parts = <String>[];

    // 实时查询书签数量（难句数）
    final bookmarkCount =
        ref.watch(_bookmarkCountProvider(audioItemId)).valueOrNull ?? 0;
    if (bookmarkCount > 0) {
      parts.add(l10n.difficultSentenceCount(bookmarkCount));
    }

    // 精听总完成遍数
    if (progress?.intensiveListenPassCount case final count? when count > 0) {
      parts.add(l10n.intensiveListenPassInfo(count));
    }

    return parts.isNotEmpty ? parts.join(' · ') : null;
  }

  /// 构建跟读卡片副标题（实时难句数 + 总完成遍数）
  String? _buildShadowingSubtitle(WidgetRef ref, AppLocalizations l10n) {
    final parts = <String>[];

    // 实时查询书签数量（难句数）
    final bookmarkCount =
        ref.watch(_bookmarkCountProvider(audioItemId)).valueOrNull ?? 0;
    parts.add(l10n.listenAndRepeatBriefingDifficultCount(bookmarkCount));

    // 跟读总完成遍数
    if (progress?.shadowingPassCount case final count? when count > 0) {
      parts.add(l10n.shadowingPassInfo(count));
    }

    return parts.isNotEmpty ? parts.join(' · ') : null;
  }

  /// 进入自由练习盲听模式
  Future<void> _startFreePlayBlindListen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(audioItemId);
    if (audioItem == null) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(audioItemId).future)
        : ref.read(listeningPracticeProvider).sentences;
    if (sentences.isEmpty) return;

    // 按当前难句书签数实时重算难度，难度降低后速度随之回升（与难句跟读/复述一致）
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(audioItemId, sentences.length);
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final estimatedDuration = estimateBlindListenSessionDuration(
      sentences: sentences,
      fullAudioDuration: ref.read(audioEngineProvider).totalDuration,
      skipSilenceEnabled: ref.read(appSettingsProvider).skipSilenceEnabled,
    );

    // 全文盲听属于首次学习步骤,按 firstLearn 算默认速度;与按计划共用同一槽位偏好。
    const stage = LearningStage.firstLearn;
    final smartSpeed = progress != null
        ? defaultPlaybackSpeedFor(liveDifficulty, stage)
        : 1.0;
    final slot = stageSlotKey(StageSettingsSlots.blindListen, stage);
    final blindPrefs = ref.read(blindListenPrefsProvider.notifier);
    final defaults = blindPrefs.resolve(slot, smartSpeed: smartSpeed);
    final blindSeconds = blindPrefs.resolveTargetSeconds(
      slot,
      smartSeconds: -1,
    );
    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      estimatedDurationText: estimatedDuration != null
          ? formatEstimatedDuration(l10n, estimatedDuration)
          : null,
      defaultPlaybackSpeed: defaults.playbackSpeed,
      defaultSeconds: blindSeconds,
      defaultPause: blindPauseChoiceFromSettings(defaults),
      onSelectionChanged: blindPrefsRecorder(ref, slot, defaults, blindSeconds),
      onStartPractice: (targetDuration, pause, playbackSpeed) async {
        final settings = ref
            .read(blindListenPrefsProvider.notifier)
            .resolve(slot, smartSpeed: smartSpeed);
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        await _openBlindListenPractice(
          context: context,
          ref: ref,
          audioItem: audioItem,
          collectionId: collectionId,
          paragraphs: paragraphs,
          settings: settings,
          stage: stage,
          loadKey: '${audioItem.id}:blind-listen:free-play',
          isFreePlay: true,
          catchUpStage: LearningStage.firstLearn,
          catchUpSubStage: SubStageType.blindListen,
        );
      },
    );
  }

  /// 进入自由练习精听模式（与按计划学习一致：先弹 briefing 含速度下拉）
  Future<void> _startFreePlayIntensiveListen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(audioItemId);
    if (audioItem == null) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(audioItemId).future)
        : ref.read(listeningPracticeProvider).sentences;
    if (sentences.isEmpty || !context.mounted) return;

    // 预估时长：每句 = 句子时长 × 2（听 + 停顿处理）
    final totalSentenceDuration = sentences.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final intensiveEstimate = totalSentenceDuration * 2;

    // 与按计划入口同一份偏好真相源、同一槽位:预填、改完即记、进入设置完全一致。
    final slot = stageSlotKey(
      StageSettingsSlots.intensiveListen,
      LearningStage.firstLearn,
    );
    final prefs = ref.read(intensiveListenPrefsProvider.notifier);
    final defaults = prefs.resolve(slot, smartSpeed: 1.0);
    showIntensiveListenBriefingSheet(
      context: context,
      sentenceCount: sentences.length,
      estimatedDuration: intensiveEstimate,
      defaultPlaybackSpeed: defaults.playbackSpeed,
      defaultPause: intensivePauseChoiceFromSettings(defaults),
      onSelectionChanged: intensivePrefsRecorder(prefs, slot, defaults),
      onStartPractice: (playbackSpeed, pause) async {
        final notifier = ref.read(learningSessionProvider.notifier);
        final resolved = prefs.resolve(slot, smartSpeed: 1.0);
        if (!context.mounted) return;
        context.push(
          AppRoutes.intensiveListenPlayer(collectionId, audioItemId),
          extra: MediaLearningStartup(
            loadKey: '${audioItem.id}:free-play',
            load: () async {
              final result = await notifier.enterIntensiveListenMode(
                audioItem,
                sentences,
                isFreePlay: true,
                settings: resolved,
                settingsSlot: slot,
              );
              if (result == MediaLoadResult.ready) {
                // 补做语义：跳过的精听完成后回收为已完成。
                notifier.setCatchUp(
                  LearningStage.firstLearn,
                  SubStageType.intensiveListen,
                );
              }
              return result;
            },
            cancel: notifier.cancelIntensiveListenEntry,
            showVideoLoading: audioItem.isVideo,
          ),
        );
      },
    );
  }

  /// 进入自由练习跟读模式（与按计划学习一致：先弹 briefing 含速度下拉）
  Future<void> _startFreePlayListenAndRepeat(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      SubStageType.listenAndRepeat,
    );
    if (!allowed || !context.mounted) return;

    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(audioItemId);
    if (audioItem == null) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(audioItemId).future)
        : ref.read(listeningPracticeProvider).sentences;
    if (!context.mounted || sentences.isEmpty) return;

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final difficultIndices = await BookmarkManager.loadBookmarks(
      audioItemId,
      dao: bookmarkDao,
    );
    if (!context.mounted) return;
    // 按当前难句书签数实时重算难度（难句跟读入口最关键：用户练熟取消收藏后
    // 比例下降 → 难度降低 → 速度回升），同时用于跟读遍数 playCount。
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(audioItemId, sentences.length);
    if (!context.mounted) return;
    final playCount = targetPlayCountForDifficulty(liveDifficulty.index);
    final difficultDuration = difficultIndices.fold<Duration>(
      Duration.zero,
      (sum, idx) =>
          sum +
          (idx < sentences.length ? sentences[idx].duration : Duration.zero),
    );
    final repeatEstimate = difficultDuration * playCount * 2;

    // 难句跟读只属于"首次学习"步骤,自由练习与按计划共用同一槽位偏好。
    final smartSpeed = progress != null
        ? defaultPlaybackSpeedFor(liveDifficulty, LearningStage.firstLearn)
        : 1.0;
    final slot = stageSlotKey(
      StageSettingsSlots.listenAndRepeat,
      LearningStage.firstLearn,
    );
    final prefs = ref.read(intensiveListenPrefsProvider.notifier);
    final defaults = prefs.resolve(slot, smartSpeed: smartSpeed);
    final defaultScope = prefs.listenAndRepeatScopeFor(slot);
    final fullTextDuration = sentences.fold<Duration>(
      Duration.zero,
      (sum, sentence) => sum + sentence.duration,
    );
    showListenAndRepeatBriefingSheet(
      context: context,
      difficultCount: difficultIndices.length,
      fullTextCount: sentences.length,
      playCount: playCount,
      difficultEstimatedDuration: repeatEstimate,
      fullTextEstimatedDuration: fullTextDuration * playCount * 2,
      defaultScope: defaultScope,
      defaultPlaybackSpeed: defaults.playbackSpeed,
      defaultPause: intensivePauseChoiceFromSettings(defaults),
      onSelectionChanged: intensivePrefsRecorder(prefs, slot, defaults),
      onScopeChanged: (scope) {
        prefs.setListenAndRepeatScope(slot, scope);
        ref
            .read(learningProgressNotifierProvider.notifier)
            .saveShadowingSentenceIndex(audioItemId, null, isFreePlay: true);
      },
      onStartPractice: (playbackSpeed, pause, scope) async {
        if (scope == ListenAndRepeatScope.difficultOnly &&
            difficultIndices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.difficultSentenceCount(0))),
          );
          return;
        }
        await _pushPracticeAndWaitForTransition(
          context,
          AppRoutes.listenAndRepeatPlayer(collectionId, audioItemId),
          ref: ref,
          event: RatingPromptEvent.shadowingCompleted,
          extra: MediaLearningStartup(
            loadKey: '${audioItem.id}:listen-and-repeat:free-play',
            load: () async {
              final result = await ref
                  .read(listenAndRepeatControllerProvider.notifier)
                  .initialize(
                    mediaItem: audioItem,
                    allSentences: sentences,
                    isFreePlay: true,
                    scope: scope,
                    smartSpeed: smartSpeed,
                  );
              if (result != MediaLoadResult.ready) return result;
              ref
                  .read(learningSessionProvider.notifier)
                  .setCatchUp(
                    LearningStage.firstLearn,
                    SubStageType.listenAndRepeat,
                  );
              return result;
            },
            cancel: () => ref
                .read(listenAndRepeatControllerProvider.notifier)
                .cancelEntry(),
            showVideoLoading: audioItem.isVideo,
          ),
        );
      },
    );
  }

  /// 构建复述卡片副标题（总完成遍数）
  String? _buildRetellSubtitle(AppLocalizations l10n) {
    if (progress?.retellPassCount case final count? when count > 0) {
      return l10n.retellPassInfo(count);
    }
    return null;
  }

  /// 进入自由练习复述模式（弹 briefing sheet 选择段落时长）
  void _startFreePlayRetell(BuildContext context, WidgetRef ref) {
    _startFreePlayRetellAsync(context, ref);
  }

  /// 进入自由练习复述前先检查本地 ASR，避免步骤卡片直达绕过拦截。
  Future<void> _startFreePlayRetellAsync(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      SubStageType.retell,
    );
    if (!allowed || !context.mounted) return;

    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(audioItemId);
    if (audioItem == null) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(audioItemId).future)
        : ref.read(listeningPracticeProvider).sentences;
    if (!context.mounted || sentences.isEmpty) return;

    // 段落时长 default 按用户**当前**学习阶段算（review28 用户能驾驭长段），
    // 与 catchUpStage（始终 firstLearn，因为这是 firstLearn 子步骤的补练）解耦。
    // 可见词比例按 catchUpStage=firstLearn 算（补练 firstLearn 复述）。
    final progressForDefault = ref
        .read(learningProgressNotifierProvider)
        .progressMap[audioItemId];
    final stageForDefault =
        progressForDefault?.currentStage ?? LearningStage.firstLearn;
    // 按当前难句书签数实时重算难度，难度降低后速度/可见词比例随之调整
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(audioItemId, sentences.length);
    if (!context.mounted) return;
    // 自由练习复述属 firstLearn 补练,槽位 retell:firstLearn,与按计划共用偏好。
    final slot = stageSlotKey(
      StageSettingsSlots.retell,
      LearningStage.firstLearn,
    );
    final prefill = retellBriefingDefaults(
      ref,
      slot,
      smartSpeed: progressForDefault != null
          ? defaultPlaybackSpeedFor(liveDifficulty, LearningStage.firstLearn)
          : 1.0,
      smartRatio: KeywordRatio.forDifficultyAndStage(
        liveDifficulty,
        LearningStage.firstLearn,
      ),
      smartSeconds: retellDefaultSeconds(stageForDefault),
    );
    showRetellBriefingSheet(
      context: context,
      sentences: sentences,
      defaultSeconds: prefill.seconds,
      defaultKeywordRatio: progressForDefault != null ? prefill.ratio : null,
      defaultPlaybackSpeed: prefill.speed,
      defaultPause: prefill.pause,
      onSelectionChanged: retellPrefsRecorder(ref, slot, prefill.settings),
      onStartPractice:
          (targetDuration, pause, keywordRatio, playbackSpeed) async {
            final paragraphs = groupSentencesIntoParagraphs(
              sentences,
              targetDuration,
            );

            await _openRetellPractice(
              context: context,
              ref: ref,
              audioItem: audioItem,
              collectionId: collectionId,
              paragraphs: paragraphs,
              loadKey: '${audioItem.id}:retell:free-play',
              isFreePlay: true,
              catchUpStage: LearningStage.firstLearn,
              catchUpSubStage: SubStageType.retell,
            );
          },
    );
  }
}

/// 步骤数据模型（内部使用）
class _StepData {
  final IconData icon;
  final Color? iconColor;
  final String name;
  final String description;

  const _StepData({
    required this.icon,
    this.iconColor,
    required this.name,
    required this.description,
  });
}

/// 听前预热卡（横向单行紧凑卡，置于「首次学习」之上）。
///
/// 引导用户在正式精听前先用「随心听」整篇泛听、建立内容认知。视觉上用暖奶油
/// 色填充块（区别于页面其余白底蓝调卡片）+ 内联「推荐先做」小徽章 + 右侧
/// chevron，整卡可点进入「随心听」播放器（与右上角胶囊同一目的地）。
///
/// 作为次要推荐引导，视觉权重刻意低于底部「开始学习」主按钮：取消独立大按钮、
/// 高度压缩到约一半。显隐由父级按 `!isStarted && hasTranscript` 控制，开始学习
/// 后自动消失，不计学习进度。
class _WarmUpCard extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _WarmUpCard({required this.l10n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 暖橙调配色（亮/暗双套），不读 colorScheme 以避免主题 tertiary 偏色。
    const amber = Color(0xFFFFB300);
    final bg = isDark
        ? Color.alphaBlend(
            amber.withValues(alpha: 0.12),
            theme.colorScheme.surface,
          )
        : const Color(0xFFFFF4E2);
    final border = isDark
        ? amber.withValues(alpha: 0.20)
        : const Color(0xFFF4D7A8).withValues(alpha: 0.6);
    final iconBg = amber.withValues(alpha: isDark ? 0.22 : 0.16);
    final iconFg = isDark ? const Color(0xFFFFB74D) : const Color(0xFFE8870C);
    final titleColor = isDark
        ? const Color(0xFFFFE2B8)
        : const Color(0xFF5A3A12);
    final descColor = titleColor.withValues(alpha: isDark ? 0.70 : 0.72);
    final badgeBg = isDark ? amber : const Color(0xFFF38B00);
    final badgeFg = isDark ? const Color(0xFF3A2400) : Colors.white;

    return Semantics(
      button: true,
      label:
          '${l10n.warmUpCardTitle}. ${l10n.warmUpCardSubtitle}. '
          '${l10n.warmUpCardBadge}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s + 2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.headphones_rounded,
                      size: 20,
                      color: iconFg,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                l10n.warmUpCardTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                l10n.warmUpCardBadge,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: badgeFg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.warmUpCardSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: descColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: iconFg.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个步骤卡片 — 支持三态：已完成、当前、未开始
class _StepCard extends StatelessWidget {
  final int stepNumber;
  final IconData icon;
  final Color? iconColor;
  final String name;
  final String description;
  final bool isCompleted;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;

  /// 已跳过状态：与 [isCompleted] 互斥（持久化层保证）；显示 ⏭ 灰色图标，
  /// 文案后缀「已跳过」。
  final bool isSkipped;

  /// 可选的附加信息（如"已听 X 遍"）
  final String? subtitle;

  /// 点击回调（如已完成的盲听步骤可点击进入自由练习）
  final VoidCallback? onTap;

  const _StepCard({
    required this.stepNumber,
    required this.icon,
    this.iconColor,
    required this.name,
    required this.description,
    required this.isCompleted,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    this.isSkipped = false,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间线（圆形指示器垂直居中）
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // 上方竖线（第一个卡片用透明占位）
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? (theme.brightness == Brightness.dark
                              ? Colors.transparent
                              : Colors.green.shade50)
                        : isSkipped
                        ? theme.colorScheme.surfaceContainerHighest
                        : isCurrent
                        ? null
                        : theme.colorScheme.surfaceContainerHighest,
                    border: isCompleted
                        ? Border.all(
                            color: theme.brightness == Brightness.dark
                                ? Colors.green.shade400
                                : Colors.green,
                            width: 1.5,
                          )
                        : isCurrent && !isSkipped
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: theme.brightness == Brightness.dark
                                ? Colors.green.shade300
                                : Colors.green.shade700,
                          )
                        : isSkipped
                        ? Icon(
                            Icons.remove,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          )
                        : Text(
                            '$stepNumber',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                // 下方竖线（最后一个卡片用透明占位）
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          // 右侧卡片内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s),
              child: Card(
                clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: isCompleted
                              ? (iconColor ?? theme.colorScheme.primary)
                                    .withAlpha(100)
                              : isSkipped
                              ? theme.colorScheme.outline
                              : iconColor ?? theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSkipped
                                    ? '$name · ${AppLocalizations.of(context)!.retellSkippedSuffix}'
                                    : name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted || isSkipped
                                      ? theme.colorScheme.outline
                                      : null,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isCompleted
                                      ? theme.colorScheme.outline
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  subtitle!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个复习轮次的数据模型
class _ReviewStageData {
  final String name;
  final LearningStage stage;

  const _ReviewStageData({required this.name, required this.stage});
}

/// 单个复习轮次区块（与首次学习同级）
///
/// 视觉与首次学习区块保持一致：标题行可独立折叠/展开，展开后显示子阶段。
class _ReviewRoundSection extends ConsumerWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;
  final _ReviewStageData review;
  final DateTime now;

  /// 合集 ID（导航用）
  final String? collectionId;

  /// 音频项 ID（导航用）
  final String audioItemId;
  final bool isExpanded;
  final VoidCallback onToggle;

  /// 点击当前进行中步骤的回调（效果同底部「开始学习」），不可启动时为 null
  final VoidCallback? onStartCurrentStage;

  const _ReviewRoundSection({
    required this.l10n,
    this.progress,
    required this.review,
    required this.now,
    required this.collectionId,
    required this.audioItemId,
    required this.isExpanded,
    required this.onToggle,
    this.onStartCurrentStage,
  });

  /// 使用统计与任务卡片共用的阶段展示定义，仅补充复习描述。
  _StepData _stepDataForStage(StudyStage stage, String description) {
    final visual = studyStageVisual(stage, l10n);
    return _StepData(
      icon: visual.icon,
      iconColor: visual.iconColor,
      name: visual.name,
      description: description,
    );
  }

  /// 计算本轮次「已完成」子步骤数（基于真实完成历史 [completedKeys]）。
  int _completedSubStageCount(Set<String> completedKeys) {
    int count = 0;
    for (final sub in review.stage.allSubStages) {
      if (completedKeys.contains('${review.stage.key}:${sub.key}')) count += 1;
    }
    return count;
  }

  /// 当前复习轮次时间文案（仅当前轮次显示）。
  ///
  /// 展示优先级：已有进度→"学习中" > 未到时间倒计时 > 逾期提示 > 可复习。
  String? _reviewTimingText(
    BuildContext context, {
    required Set<String> completedKeys,
  }) {
    if (progress == null) return null;
    if (!progress!.isCurrentStage(review.stage)) return null;

    // 已有进度（至少完成 1 个子阶段）→ 显示"学习中"
    if (_completedSubStageCount(completedKeys) > 0) {
      return l10n.learningInProgress;
    }

    final nextReview = progress!.nextReviewAt;
    if (nextReview == null) return null;

    // 与锁定判定同源（isReviewReadyAt 对手动解锁短路），避免手动解锁后
    // 按钮已消失、倒计时文案却仍显示的不一致。
    if (!progress!.isReviewReadyAt(now) && now.isBefore(nextReview)) {
      final diff = nextReview.difference(now);
      if (diff.inDays > 0) {
        return l10n.reviewUnlockIn(diff.inDays);
      }
      return l10n.reviewUnlockInHours(diff.inHours.clamp(1, 999));
    }

    if (progress!.isReviewOverdueAt(now)) {
      return _formatOverdueText(context, progress!.overdueDurationAt(now));
    }

    return l10n.reviewDue;
  }

  /// 逾期措辞：短期保留时间信息，长期只显示"待复习"。
  ///
  /// - 无时长 / >7天 → "待复习"
  /// - ≤7天 → "待复习 · X天前到期"
  /// - <1天 → "待复习 · X小时前到期"
  String _formatOverdueText(BuildContext context, Duration? overdue) {
    // 无时长信息或长期逾期（>7天）只显示"待复习"
    if (overdue == null || overdue.inDays > 7) {
      return l10n.reviewDue;
    }
    if (overdue.inDays > 0) {
      return l10n.overdueDays(overdue.inDays);
    }
    final hours = overdue.inHours.clamp(1, 999);
    return l10n.overdueHours(hours);
  }

  /// 复习子阶段名称与描述映射
  _StepData _subStageData(SubStageType subStage) {
    final retellSummaryVisual = studyRetellSummaryVisual(l10n);
    return switch (subStage) {
      SubStageType.blindListen => _stepDataForStage(
        StudyStage.blindListen,
        l10n.reviewBlindListenDesc,
      ),
      SubStageType.intensiveListen => _stepDataForStage(
        StudyStage.intensiveListen,
        l10n.stepIntensiveListeningDesc,
      ),
      SubStageType.listenAndRepeat => _stepDataForStage(
        StudyStage.listenAndRepeat,
        l10n.stepShadowingDesc,
      ),
      SubStageType.retell => _stepDataForStage(
        StudyStage.retell,
        l10n.stepRetellingDesc,
      ),
      SubStageType.reviewDifficultPractice => _stepDataForStage(
        StudyStage.reviewDifficultPractice,
        l10n.reviewDifficultPracticeDesc,
      ),
      SubStageType.reviewRetellParagraph => _stepDataForStage(
        StudyStage.retell,
        l10n.reviewRetellParagraphDesc,
      ),
      SubStageType.reviewRetellSummary => _StepData(
        icon: retellSummaryVisual.icon,
        iconColor: retellSummaryVisual.iconColor,
        name: retellSummaryVisual.name,
        description: l10n.reviewRetellSummaryDesc,
      ),
    };
  }

  /// 进入自由练习盲听模式（复习阶段的全文盲听）
  Future<void> _startFreePlayBlindListen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(audioItemId);
    if (audioItem == null) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(audioItemId).future)
        : ref.read(listeningPracticeProvider).sentences;
    if (!context.mounted) return;
    if (sentences.isEmpty) return;

    // 按当前难句书签数实时重算难度，难度降低后速度随之回升
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(audioItemId, sentences.length);
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final estimatedDuration = estimateBlindListenSessionDuration(
      sentences: sentences,
      fullAudioDuration: ref.read(audioEngineProvider).totalDuration,
      skipSilenceEnabled: ref.read(appSettingsProvider).skipSilenceEnabled,
    );

    final smartSpeed = progress == null
        ? 1.0
        : defaultPlaybackSpeedFor(liveDifficulty, review.stage);
    final slot = stageSlotKey(StageSettingsSlots.blindListen, review.stage);
    final blindPrefs = ref.read(blindListenPrefsProvider.notifier);
    final defaults = blindPrefs.resolve(slot, smartSpeed: smartSpeed);
    final blindSeconds = blindPrefs.resolveTargetSeconds(
      slot,
      smartSeconds: -1,
    );
    showBlindListenParagraphSheet(
      context: context,
      sentences: sentences,
      estimatedDurationText: estimatedDuration != null
          ? formatEstimatedDuration(l10n, estimatedDuration)
          : null,
      defaultPlaybackSpeed: defaults.playbackSpeed,
      defaultSeconds: blindSeconds,
      defaultPause: blindPauseChoiceFromSettings(defaults),
      onSelectionChanged: blindPrefsRecorder(ref, slot, defaults, blindSeconds),
      onStartPractice: (targetDuration, pause, playbackSpeed) async {
        final settings = ref
            .read(blindListenPrefsProvider.notifier)
            .resolve(slot, smartSpeed: smartSpeed);
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        await _openBlindListenPractice(
          context: context,
          ref: ref,
          audioItem: audioItem,
          collectionId: collectionId,
          paragraphs: paragraphs,
          settings: settings,
          stage: review.stage,
          loadKey: '${audioItem.id}:blind-listen:${review.stage.key}:free-play',
          isFreePlay: true,
          catchUpStage: review.stage,
          catchUpSubStage: SubStageType.blindListen,
        );
      },
    );
  }

  /// 进入自由练习难句补练模式
  Future<void> _startFreePlayDifficultPractice(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      SubStageType.reviewDifficultPractice,
    );
    if (!allowed || !context.mounted) return;

    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(audioItemId);
    if (audioItem == null) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(audioItemId).future)
        : ref.read(listeningPracticeProvider).sentences;
    if (sentences.isEmpty || !context.mounted) return;

    // 难句补练自由练习也按"先弹 briefing 含速度下拉"流程，与按计划学习对齐。
    final difficultDuration = sentences
        .where((s) => s.isBookmarked)
        .fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);
    final estimated = difficultDuration == Duration.zero
        ? null
        : difficultDuration * 2;
    // 按当前难句书签数实时重算难度，难度降低后速度随之回升
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(audioItemId, sentences.length);
    if (!context.mounted) return;
    final smartSpeed = progress == null
        ? 1.0
        : defaultPlaybackSpeedFor(liveDifficulty, review.stage);
    final slot = stageSlotKey(
      StageSettingsSlots.reviewDifficultPractice,
      review.stage,
    );
    final dp = ref.read(difficultPracticePrefsProvider.notifier);
    final defaults = dp.resolve(slot, smartSpeed: smartSpeed);
    showReviewBriefingSheet(
      context: context,
      stage: review.stage,
      subStage: SubStageType.reviewDifficultPractice,
      estimatedDuration: estimated,
      defaultPlaybackSpeed: defaults.playbackSpeed,
      defaultPause: difficultPauseChoiceFromSettings(defaults),
      onSelectionChanged: difficultPrefsRecorder(ref, slot, defaults),
      onStartPractice: (playbackSpeed, pause) async {
        final settings = ref
            .read(difficultPracticePrefsProvider.notifier)
            .resolve(slot, smartSpeed: smartSpeed);
        context.push(
          AppRoutes.reviewDifficultPractice(collectionId, audioItemId),
          extra: MediaLearningStartup(
            loadKey:
                '${audioItem.id}:review-difficult:${review.stage.key}:free-play',
            showVideoLoading: audioItem.isVideo,
            load: () async {
              final result = await ref
                  .read(learningSessionProvider.notifier)
                  .enterReviewDifficultPracticeMode(
                    audioItem,
                    sentences,
                    isFreePlay: true,
                    settings: settings,
                    stage: review.stage,
                  );
              if (result != MediaLoadResult.ready) return result;
              ref
                  .read(learningSessionProvider.notifier)
                  .setCatchUp(
                    review.stage,
                    SubStageType.reviewDifficultPractice,
                  );
              return result;
            },
            cancel: () => ref
                .read(learningSessionProvider.notifier)
                .cancelReviewDifficultPracticeEntry(),
          ),
        );
      },
    );
  }

  /// 进入自由练习复述模式（段落复述 / 全文复述）
  Future<void> _startFreePlayRetell(
    BuildContext context,
    WidgetRef ref, {
    required bool isSummary,
  }) async {
    final allowed = await ensureSpeechReadyForSubStage(
      context,
      ref,
      isSummary
          ? SubStageType.reviewRetellSummary
          : SubStageType.reviewRetellParagraph,
    );
    if (!allowed || !context.mounted) return;

    final audioItem = ref
        .read(audioLibraryProvider.notifier)
        .getItemById(audioItemId);
    if (audioItem == null) return;
    final sentences = audioItem.isVideo
        ? await ref.read(audioSentencesProvider(audioItemId).future)
        : ref.read(listeningPracticeProvider).sentences;
    if (!context.mounted || sentences.isEmpty) return;

    final catchUpSub = isSummary
        ? SubStageType.reviewRetellSummary
        : SubStageType.reviewRetellParagraph;

    if (isSummary) {
      // 全文复述：全文作为单个段落，无需选择时长
      await _openRetellPractice(
        context: context,
        ref: ref,
        audioItem: audioItem,
        collectionId: collectionId,
        paragraphs: [sentences],
        loadKey: '${audioItem.id}:retell-summary:${review.stage.key}:free-play',
        isFreePlay: true,
        catchUpStage: review.stage,
        catchUpSubStage: catchUpSub,
      );
      return;
    }

    // 段落复述：弹出简报面板让用户选择段落时长（预估时长由 sheet 内部按真实公式动态计算）
    final progressForRetell = ref
        .read(learningProgressNotifierProvider)
        .progressMap[audioItemId];
    // 按当前难句书签数实时重算难度，难度降低后速度/可见词比例随之调整
    final liveDifficulty = await ref
        .read(learningProgressNotifierProvider.notifier)
        .refreshDifficultyFromBookmarks(audioItemId, sentences.length);
    if (!context.mounted) return;
    final slot = stageSlotKey(StageSettingsSlots.retell, review.stage);
    final prefill = retellBriefingDefaults(
      ref,
      slot,
      smartSpeed: progressForRetell != null
          ? defaultPlaybackSpeedFor(liveDifficulty, review.stage)
          : 1.0,
      smartRatio: KeywordRatio.forDifficultyAndStage(
        liveDifficulty,
        review.stage,
      ),
      smartSeconds: retellDefaultSeconds(review.stage),
    );
    showRetellBriefingSheet(
      context: context,
      sentences: sentences,
      defaultSeconds: prefill.seconds,
      defaultKeywordRatio: progressForRetell != null ? prefill.ratio : null,
      defaultPlaybackSpeed: prefill.speed,
      defaultPause: prefill.pause,
      onSelectionChanged: retellPrefsRecorder(ref, slot, prefill.settings),
      onStartPractice: (targetDuration, pause, keywordRatio, playbackSpeed) async {
        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          targetDuration,
        );
        await _openRetellPractice(
          context: context,
          ref: ref,
          audioItem: audioItem,
          collectionId: collectionId,
          paragraphs: paragraphs,
          loadKey:
              '${audioItem.id}:retell-paragraph:${review.stage.key}:free-play',
          isFreePlay: true,
          catchUpStage: review.stage,
          catchUpSubStage: catchUpSub,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(learningPlanForAudioProvider(audioItemId));
    final stageCompletedAtMap =
        ref
            .watch(reviewStageCompletionTimesProvider(audioItemId))
            .valueOrNull ??
        const <String, DateTime>{};
    final completedKeys = ref
        .watch(learningProgressNotifierProvider)
        .completionsFor(audioItemId);
    // 迭代顺序 = 当前 plan 顺序 + 历史外延项（已完成 / 已跳过但不在当前 plan 内）。
    // 例如 review28 v1 用户完成了 reviewRetellSummary 后切到 v2 不会发生（v1 用户
    // 该 stage 有 completion 仍走 v1 plan），但 helper 防御性兜底。
    final subStages = _orderedSubStagesForDisplay(
      plan: plan,
      stage: review.stage,
      completedKeys: completedKeys,
      skippedKeys: progress?.skippedSubStageKeys ?? const {},
    );
    final completedCount = _completedSubStageCount(completedKeys);
    final timingText = _reviewTimingText(context, completedKeys: completedKeys);
    final isCompleted = progress?.isStageCompleted(review.stage) ?? false;
    final isCurrent = progress?.isCurrentStage(review.stage) ?? false;
    final isFuture = !isCompleted && !isCurrent;
    final completedAt = stageCompletedAtMap[review.stage.key];
    // 标题行文案优先级：
    // 1. 已完成轮次显示相对完成时间
    // 2. 当前轮次显示真实倒计时 / 待复习 / 逾期
    // 3. 未来轮次不显示固定时间标签，避免误导为累计里程碑
    final statusText = isCompleted
        ? (completedAt == null
              ? null
              : formatCompletedStageTimeLabel(context, completedAt))
        : timingText;
    // 标题颜色：已完成→绿色，当前→默认，未来→弱化
    final titleColor = isCompleted
        ? Colors.green
        : isFuture
        ? theme.colorScheme.onSurfaceVariant
        : null;
    // 状态文案颜色：已完成→绿色，其余状态→弱化前景色。
    final statusColor = isCompleted
        ? Colors.green
        : theme.colorScheme.onSurfaceVariant;
    final reviewIconColor = isCompleted
        ? Colors.green
        : isFuture
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    // 当前轮次锁定且未暂停 → 显示可点解锁药丸（倒计时并入药丸，不再挤在标题行）
    final showUnlockPill =
        isCurrent &&
        !(progress?.isPaused ?? false) &&
        (progress?.isReviewLockedAt(now) ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          // 未开始（锁定）轮次进一步弱化，避免抢夺当前/已完成轮次的注意力
          opacity: isFuture ? 0.45 : 1.0,
          child: _StageHeaderRow(
            keyPrefix: 'learning_plan_stage_${review.stage.key}',
            leadingIcon: SvgPicture.asset(
              _refreshIconAsset,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(reviewIconColor, BlendMode.srcIn),
            ),
            title: review.name,
            titleColor: titleColor,
            statusIcon: isCompleted
                ? SvgPicture.asset(
                    _checkCircleIconAsset,
                    width: 18,
                    height: 18,
                    colorFilter: const ColorFilter.mode(
                      Colors.green,
                      BlendMode.srcIn,
                    ),
                  )
                : isCurrent
                ? SvgPicture.asset(_calendarIconAsset, width: 18, height: 18)
                : SvgPicture.asset(
                    _lockIconAsset,
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                      theme.colorScheme.onSurfaceVariant,
                      BlendMode.srcIn,
                    ),
                  ),
            // 状态文案内联到标题行：已完成显示完成时间，当前显示真实状态，
            // 未来轮次不显示固定“After X days”，但仍保留状态文案列宽。
            statusText: statusText,
            statusTextColor: statusColor,
            progressText: l10n.stepProgress(completedCount, subStages.length),
            progressColor: isCompleted
                ? Colors.green
                : theme.colorScheme.onSurfaceVariant,
            isExpanded: isExpanded,
            onTap: onToggle,
          ),
        ),
        // 当前轮次锁定且未暂停时显示「立即解锁」药丸按钮：倒计时是标题行的
        // 纯展示 label，解锁是独立按钮，两者分离避免歧义（解锁写 manualUnlockAt，
        // 不篡改完成时间，后续轮次仍按实际完成时间顺延）。
        if (showUnlockPill)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xl,
              top: AppSpacing.xs,
            ),
            child: Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => ref
                    .read(learningProgressNotifierProvider.notifier)
                    .unlockCurrentReview(audioItemId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        _unlockIconAsset,
                        width: 14,
                        height: 14,
                        colorFilter: ColorFilter.mode(
                          theme.colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.unlockReviewNow,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.s),
          Column(
            children: List.generate(subStages.length, (index) {
              final subStage = subStages[index];
              final subStageData = _subStageData(subStage);
              final isCompleted =
                  progress?.isSubStageCompleted(
                    review.stage,
                    subStage,
                    completedKeys,
                  ) ??
                  false;
              final isCurrent =
                  progress?.isCurrentSubStage(review.stage, subStage) ?? false;
              final isSkipped =
                  progress?.isSubStageSkipped(review.stage, subStage) ?? false;

              // 难句补练步骤：显示难句数量或自动完成提示
              String? subtitle;
              if (subStage == SubStageType.reviewDifficultPractice) {
                final bookmarkCount =
                    ref
                        .watch(_bookmarkCountProvider(audioItemId))
                        .valueOrNull ??
                    0;
                if (isCompleted && bookmarkCount == 0) {
                  subtitle = l10n.autoCompletedNoDifficultReview;
                } else if (bookmarkCount > 0) {
                  subtitle = l10n.difficultSentenceCount(bookmarkCount);
                }
              }

              // 已完成、已跳过（含当前阶段内跳过）或过去阶段的子步骤都支持点击进入自由练习。
              // （跳过的步骤用户随时可补做，不必等大阶段推进）
              final isPast =
                  progress != null &&
                  review.stage.index < progress!.currentStage.index;
              final canFreePlay = isCompleted || isSkipped || isPast;
              VoidCallback? onTap;
              if (canFreePlay) {
                // 无难句自动完成的补练步骤：点击只显示提示
                final bookmarkCount =
                    ref
                        .watch(_bookmarkCountProvider(audioItemId))
                        .valueOrNull ??
                    0;
                if (subStage == SubStageType.reviewDifficultPractice &&
                    bookmarkCount == 0) {
                  onTap = () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.autoCompletedNoDifficultReview),
                      ),
                    );
                  };
                } else {
                  onTap = switch (subStage) {
                    SubStageType.blindListen => () => _startFreePlayBlindListen(
                      context,
                      ref,
                    ),
                    SubStageType.reviewDifficultPractice =>
                      () => _startFreePlayDifficultPractice(context, ref),
                    SubStageType.reviewRetellParagraph =>
                      () =>
                          _startFreePlayRetell(context, ref, isSummary: false),
                    SubStageType.reviewRetellSummary =>
                      () => _startFreePlayRetell(context, ref, isSummary: true),
                    _ => null,
                  };
                }
              }

              // 当前进行中的步骤：点击等同底部「开始学习」
              if (isCurrent) {
                onTap = onStartCurrentStage;
              }

              return _StepCard(
                stepNumber: index + 1,
                icon: subStageData.icon,
                iconColor: subStageData.iconColor,
                name: subStageData.name,
                description: subStageData.description,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                isSkipped: isSkipped,
                isFirst: index == 0,
                isLast: index == subStages.length - 1,
                subtitle: subtitle,
                onTap: onTap,
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// 音频信息行 — 显示时长、句子数、单词数
/// 单个信息标签
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// 无字幕提醒横幅 — 提示用户需要上传字幕，支持直接打开字幕管理
class _NoTranscriptBanner extends StatelessWidget {
  final AppLocalizations l10n;
  final AudioItem audioItem;
  final GuideStep addSubtitleStep;

  const _NoTranscriptBanner({
    required this.l10n,
    required this.audioItem,
    required this.addSubtitleStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.onErrorContainer,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                l10n.noTranscriptWarning,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            GuideTarget(
              step: addSubtitleStep,
              child: FilledButton.icon(
                onPressed: () => _showManageSubtitlesSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addSubtitle),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.onErrorContainer,
                  foregroundColor: theme.colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.xs,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageSubtitlesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ManageSubtitlesSheet(audioItem: audioItem),
    );
  }
}

/// 底部固定按钮 — 根据进度显示不同形态：
///
/// - 未开始：单按钮「开始学习」（[onPressed] 为 null 时禁用）。
/// - 进行中（未暂停）：Row[Expanded 1:暂停学习 | Expanded 2:继续学习]，比例 1:2。
/// - 进行中（已暂停）：单按钮「恢复学习」，点击直接恢复（不弹窗），随后 UI 自动
///   回到 Row 形态。
/// - 已学完：单按钮「重置学习进度」，点击弹窗确认后清除全部进度。
class _BottomButton extends ConsumerWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;
  final String audioItemId;
  final String audioItemName;
  final VoidCallback? onPressed;
  final GuideStep? startLearningStep;
  final GuideStep? pauseLearningStep;

  const _BottomButton({
    required this.l10n,
    required this.audioItemId,
    required this.audioItemName,
    this.progress,
    required this.onPressed,
    this.startLearningStep,
    this.pauseLearningStep,
  });

  Future<void> _confirmAndPause(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pauseLearningConfirmTitle),
        content: Text(l10n.pauseLearningConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.pauseLearning),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .pauseProgress(audioItemId);
    }
  }

  Future<void> _resume(WidgetRef ref) {
    return ref
        .read(learningProgressNotifierProvider.notifier)
        .resumeProgress(audioItemId);
  }

  /// 已学完状态：重置学习进度（与音频列表菜单的「重置学习进度」逻辑一致）
  Future<void> _confirmAndReset(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetLearningProgressConfirmTitle),
        content: Text(l10n.resetLearningProgressConfirmMessage(audioItemName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .resetProgress(audioItemId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.resetLearningProgressDone)));
      }
    }
  }

  Widget _wrap(BuildContext context, Widget body) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(top: false, child: body),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProgress = progress?.isStarted ?? false;
    final isPaused = progress?.isPaused ?? false;
    final isCompleted = progress?.isCompleted ?? false;

    // 已学完：只显示「重置学习进度」按钮，不再提供暂停/继续。
    if (isCompleted) {
      final theme = Theme.of(context);
      return _wrap(
        context,
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _confirmAndReset(context, ref),
            icon: Icon(Icons.restart_alt, color: theme.colorScheme.error),
            label: Text(
              l10n.resetLearningProgress,
              style: TextStyle(color: theme.colorScheme.error),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      );
    }

    // 暂停态：单按钮，文案合并「已暂停 · 恢复学习」，点击直接恢复。
    // 用 tonal 灰底突出当前是暂停态，与正常态的主色「继续学习」区分。
    if (hasProgress && isPaused) {
      final theme = Theme.of(context);
      return _wrap(
        context,
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () => _resume(ref),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            child: Text(
              '${l10n.pausedChipLabel} · ${l10n.resumeLearning}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    // 进行中（未暂停）：Row[暂停 | 继续] 1:2
    if (hasProgress) {
      final continueButton = FilledButton(
        onPressed: onPressed,
        child: Text(l10n.continueLearning),
      );
      final guidedContinue = startLearningStep != null
          ? GuideTarget(step: startLearningStep!, child: continueButton)
          : continueButton;
      final pauseButton = FilledButton.tonal(
        onPressed: () => _confirmAndPause(context, ref),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: Text(
          l10n.pauseLearning,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      final guidedPause = pauseLearningStep != null
          ? GuideTarget(step: pauseLearningStep!, child: pauseButton)
          : pauseButton;
      return _wrap(
        context,
        Row(
          children: [
            Expanded(flex: 3, child: guidedPause),
            const SizedBox(width: AppSpacing.m),
            Expanded(flex: 5, child: guidedContinue),
          ],
        ),
      );
    }

    // 未开始：单按钮「开始学习」
    final startButton = FilledButton(
      onPressed: onPressed,
      child: Text(l10n.startLearning),
    );
    final guidedStart = startLearningStep != null
        ? GuideTarget(step: startLearningStep!, child: startButton)
        : startButton;
    return _wrap(context, SizedBox(width: double.infinity, child: guidedStart));
  }
}

/// 学习计划页子步骤显示顺序：当前 plan 顺序在前，历史外延项在后。
///
/// - [plan]：按 audio 版本派生的 plan（v1/v2）
/// - [stage]：当前渲染的大阶段
/// - [completedKeys]：该 audio 的 stage_completions 集合
/// - [skippedKeys]：该 audio 的用户跳过集合
///
/// 历史外延项 = `stage.allSubStages` ∖ plan，且属于 completed 或 skipped。
/// 用于保留 v1 已完成但 v2 已移除项（如 review28 v1→v2 中的 reviewRetellSummary）
/// 的 ✅ 历史显示。当用户走 v1 plan（该 stage 有 completion）时，
/// extras 通常为空（plan 已含历史项）。
List<SubStageType> _orderedSubStagesForDisplay({
  required LearningPlan plan,
  required LearningStage stage,
  required Set<String> completedKeys,
  required Set<String> skippedKeys,
}) {
  final planned = plan.subStagesFor(stage);
  final extras = stage.allSubStages
      .where((s) {
        if (planned.contains(s)) return false;
        final key = '${stage.key}:${s.key}';
        return completedKeys.contains(key) || skippedKeys.contains(key);
      })
      .toList(growable: false);
  return [...planned, ...extras];
}
