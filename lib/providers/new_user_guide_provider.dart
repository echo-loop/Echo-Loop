import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_logger.dart';

/// 页面级引导流程的运行状态。
///
/// 只记录当前正在展示的 flow id，step 推进完全交给 showcaseview 驱动。
/// 每个 flow 是否已看过由 [GuideRegistry] 单独持久化。
class GuideControllerState {
  final String? activeFlowId;
  final int resetGeneration;

  const GuideControllerState({this.activeFlowId, this.resetGeneration = 0});

  bool get isActive => activeFlowId != null;
}

/// 引导持久化注册表。
///
/// 每个 flow 独立保存 seen 状态；关闭或完成一个 flow 不会影响其它 flow。
class GuideRegistry {
  GuideRegistry({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async =>
      _prefs ?? SharedPreferences.getInstance();

  String keyFor(String flowId) => 'guide_v1_${flowId}_seen';

  Future<bool> isSeen(String flowId) async {
    final prefs = await _preferences;
    final seen = prefs.getBool(keyFor(flowId)) ?? false;
    AppLogger.log('Guide', 'registry isSeen flow=$flowId seen=$seen');
    return seen;
  }

  Future<void> markSeen(String flowId) async {
    final prefs = await _preferences;
    await prefs.setBool(keyFor(flowId), true);
    AppLogger.log('Guide', 'registry markSeen flow=$flowId');
  }

  Future<void> reset(String flowId) async {
    final prefs = await _preferences;
    await prefs.remove(keyFor(flowId));
    AppLogger.log('Guide', 'registry reset flow=$flowId');
  }
}

final guideRegistryProvider = Provider<GuideRegistry>((ref) {
  return GuideRegistry();
});

/// 是否"首次启动"。
///
/// 在 `main()` 启动时读取 SharedPreferences 的 `first_launch_done` 哨兵 key：
/// 不存在即为首次启动，随即写入 true。后续启动该 key 已存在，值为 false。
/// 通过 `ProviderScope` 的 `overrides` 注入实际值，未 override 时抛出以便
/// 尽早发现 wiring 缺失。
final isFirstLaunchProvider = Provider<bool>((ref) {
  throw UnimplementedError('isFirstLaunchProvider must be overridden in main()');
});

/// 当前版本的新用户引导 flow id。
///
/// [active] 是当前真正被 screen 使用的 flow id。
/// [legacy] 仅用于重置时清掉旧版本遗留在 SharedPreferences 中的 key，
/// 没有任何 screen 仍在引用，新增 flow 时不要往里加。
/// [all] 用于设置页"重置引导"一键清空，合并 active + legacy。
abstract final class GuideFlowIds {
  static const mainShellVisitLibrary = 'main_shell_visit_library';
  static const libraryCreateCollection = 'library_create_collection';
  static const libraryCollectionList = 'library_collection_list';
  static const collectionDetailUpload = 'collection_detail_upload';
  static const collectionDetailAudioList = 'collection_detail_audio_list';
  static const learningPlanNoTranscript = 'learning_plan_no_transcript';
  static const learningPlanWithTranscript = 'learning_plan_with_transcript';
  static const subtitleSheetTranscription = 'subtitle_sheet_transcription';
  static const studyTasksOverview = 'study_tasks_overview';
  static const studyStatsStreak = 'study_stats_streak';
  static const favoritesSentencesReview = 'favorites_sentences_review';
  static const favoritesVocabularyReview = 'favorites_vocabulary_review';
  static const intensiveListenCantUnderstand =
      'intensive_listen_cant_understand';
  static const sentenceAnnotationTour = 'sentence_annotation_tour';

  static const active = [
    mainShellVisitLibrary,
    libraryCreateCollection,
    libraryCollectionList,
    collectionDetailUpload,
    collectionDetailAudioList,
    learningPlanNoTranscript,
    learningPlanWithTranscript,
    subtitleSheetTranscription,
    studyTasksOverview,
    studyStatsStreak,
    favoritesSentencesReview,
    favoritesVocabularyReview,
    intensiveListenCantUnderstand,
    sentenceAnnotationTour,
  ];

  static const legacy = [
    'library',
    'collection_detail',
    'library_examples',
    'collection_detail_example_audio',
  ];

  static const all = [...active, ...legacy];
}

final guideControllerProvider =
    NotifierProvider<GuideController, GuideControllerState>(
      GuideController.new,
    );

/// 页面级引导控制器。
///
/// 只负责"当前哪个 flow 在跑 + 已看持久化"。
/// 步骤推进由 showcaseview 自己驱动（startShowCase 传入 key 列表，
/// 用户点 tooltip 的 next/barrier 由 showcaseview 内部 advance）。
/// 整段 flow 结束时通过 [GuideShowcaseBus] 回调触发 [completeActiveFlow]。
class GuideController extends Notifier<GuideControllerState> {
  @override
  GuideControllerState build() => const GuideControllerState();

  /// 若 [flowId] 尚未 seen 且当前无活动 flow，则切到 active。
  ///
  /// 返回值：true 表示占用成功可以启动 showcase；false 表示跳过。
  Future<bool> startFlow(String flowId) async {
    if (state.isActive) {
      final sameFlow = state.activeFlowId == flowId;
      AppLogger.log(
        'Guide',
        'start skipped flow=$flowId reason=activeFlow '
            'active=${state.activeFlowId} sameFlow=$sameFlow',
      );
      return sameFlow;
    }
    final registry = ref.read(guideRegistryProvider);
    if (await registry.isSeen(flowId)) {
      AppLogger.log('Guide', 'start skipped flow=$flowId reason=seen');
      return false;
    }
    state = GuideControllerState(
      activeFlowId: flowId,
      resetGeneration: state.resetGeneration,
    );
    AppLogger.log('Guide', 'start flow=$flowId');
    return true;
  }

  /// 当前活动 flow 结束：markSeen 并清空 active。
  Future<void> completeActiveFlow() async {
    final flowId = state.activeFlowId;
    if (flowId == null) {
      AppLogger.log('Guide', 'complete ignored reason=noActiveFlow');
      return;
    }
    await ref.read(guideRegistryProvider).markSeen(flowId);
    state = GuideControllerState(resetGeneration: state.resetGeneration);
    AppLogger.log('Guide', 'complete flow=$flowId');
  }

  Future<void> resetFlows(List<String> flowIds) async {
    final registry = ref.read(guideRegistryProvider);
    for (final flowId in flowIds) {
      await registry.reset(flowId);
    }
    state = GuideControllerState(resetGeneration: state.resetGeneration + 1);
    AppLogger.log(
      'Guide',
      'resetFlows flows=${flowIds.join(",")} '
          'resetGeneration=${state.resetGeneration}',
    );
  }
}

/// 把 showcaseview 全局 `onFinish` / `onDismiss` 桥接到我们的 controller。
///
/// [ShowcaseView.register] 的回调只能在 app 启动时设置一次且不可变，
/// 所以用一个静态 bus：Host 启动 flow 前注册 callback，整段 showcase 结束
/// 后触发，由 callback 调 [GuideController.completeActiveFlow]。
abstract final class GuideShowcaseBus {
  static VoidCallback? _onEnd;

  /// 由 Host 在启动 showcase 前调用，设置 flow 结束后要跑的回调。
  static void setOnEnd(VoidCallback? cb) {
    _onEnd = cb;
  }

  /// 由 `ShowcaseView.register` 的 `onFinish` / `onDismiss` 触发。
  /// 触发一次后自动清空，避免重复调用。
  static void fireEnd() {
    final cb = _onEnd;
    _onEnd = null;
    cb?.call();
  }
}
