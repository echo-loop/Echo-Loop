/// 集成测试专用 Notifier 替身和 App 工厂
///
/// 提供所有 Provider 的测试实现，以及 [createTestApp] / [createTestAppWithAudio] 工厂函数。
/// 各测试 group 文件共享此模块，避免重复定义。
///
/// 公共 Notifier/DAO 替身已抽到 test/helpers/shared/，本文件仅保留
/// integration_test live-runner 特化部分。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/analytics/analytics_channel.dart';
import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/consent_manager.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/main.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/daily_study_time_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';
import 'package:echo_loop/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/new_user_guide_provider.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart'
    show showOfflineAsrSectionProvider, offlineAsrSettingsProvider;
import 'package:echo_loop/providers/package_info_provider.dart';
import 'package:echo_loop/providers/review_reminder_provider.dart';
import 'package:echo_loop/providers/saved_word_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:echo_loop/providers/tag_provider.dart';
import 'package:echo_loop/services/review_reminder_service.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/services/speech_practice_platform.dart';

// 共享替身
import '../../test/helpers/shared/fake_notifiers.dart';
import '../../test/helpers/shared/fake_daos.dart';
import '../../test/helpers/shared/test_fixtures.dart';
export '../../test/helpers/shared/test_fixtures.dart';

// ========== 向后兼容的 Test* 别名 ==========
// 这些 thin wrapper 保持旧的 Test* 类名，避免改动所有集成测试调用方。
// 实现全部在 shared/ 的 Fake* 类中。

class TestAppSettings extends FakeAppSettings {
  TestAppSettings() : super(const AppSettingsState());
}

class TestAudioLibrary extends FakeAudioLibrary {
  TestAudioLibrary() : super(const AudioLibraryState());
}

class TestCollectionList extends FakeCollectionList {
  TestCollectionList() : super(const CollectionState());
}

class TestTagList extends FakeTagList {
  TestTagList() : super(const TagState());
}

class TestListeningPractice extends FakeListeningPractice {
  TestListeningPractice() : super(const ListeningPracticeState());
}

class TestLearningProgressNotifier extends FakeLearningProgressNotifier {
  TestLearningProgressNotifier() : super(const LearningProgressState());
}

class TestLearningSession extends FakeLearningSession {
  TestLearningSession() : super(const LearningSessionState());
}

class TestBlindListenPlayer extends FakeBlindListenPlayer {
  TestBlindListenPlayer() : super(const BlindListenPlayerState());
}

class TestIntensiveListenPlayer extends FakeIntensiveListenPlayer {
  TestIntensiveListenPlayer() : super(const IntensiveListenState(), const []);
}

class TestRetellPlayer extends FakeRetellPlayer {
  TestRetellPlayer() : super(const RetellPlayerState(), const [], const {});
}

class TestReviewDifficultPractice extends FakeReviewDifficultPractice {
  TestReviewDifficultPractice()
    : super(const ReviewDifficultPracticeState(), const []);
}

class TestAudioEngine extends FakeAudioEngine {
  TestAudioEngine() : super();
}

class TestDailyStudyTime extends FakeDailyStudyTime {}

/// 集成测试默认关闭 ASR（与之前行为一致）
class TestOfflineAsrSettings extends FakeOfflineAsrSettings {
  TestOfflineAsrSettings()
    : super(
        OfflineAsrSettingsState(
          enabled: false,
          backend: AsrBackend.platform,
          engineReady: false,
          recommendedModel: const AsrModelInfo(
            id: 'test-model',
            displayName: 'Test Model',
            type: AsrModelType.moonshine,
          ),
        ),
      );
}

class TestStudyTimeService extends FakeStudyTimeService {}

class TestBookmarkDao extends FakeBookmarkDao {}

class TestAudioItemDao extends FakeAudioItemDao {}

class TestStageCompletionDao extends FakeStageCompletionDao {}

class TestSavedWordDao extends FakeSavedWordDao {}

// ========== Integration-test 特化 Notifier ==========

/// 测试用 SavedWordList（返回空列表，不依赖数据库）
class TestSavedWordList extends SavedWordList {
  @override
  Stream<List<SavedWord>> build() => Stream.value([]);
}

/// 测试用 StudyStatsNotifier — 返回固定空数据，避免触发 DB
class TestStudyStatsNotifier extends StudyStatsNotifier {
  @override
  Future<StudyStats> build() async => const StudyStats();

  @override
  Future<void> refresh() async {}
}

/// 测试用 SentenceAiCacheDao — 始终返回 null（无缓存）
class _TestSentenceAiCacheDao extends Fake implements SentenceAiCacheDao {
  @override
  Future<String?> getByHash(String hash, String type) async => null;

  @override
  Future<void> upsert(String hash, String type, String resultJson) async {}
}

/// 测试用 SentenceAiApiClient — 不发起真实请求
class _TestSentenceAiApiClient extends Fake implements SentenceAiApiClient {}

/// 集成测试用录音识别后端替身
class TestSpeechPracticePlatform implements SpeechPracticeBackend {
  TestSpeechPracticePlatform({
    this.permissions = const SpeechPracticePermissionState(
      microphone: SpeechPracticePermissionStatus.granted,
      speech: SpeechPracticePermissionStatus.granted,
    ),
  });

  final _controller = StreamController<SpeechPracticeEvent>.broadcast();
  SpeechPracticePermissionState permissions;
  final Map<String, String> transcriptsByPath = {};
  String? lastPromptId;
  int _counter = 0;

  @override
  bool get isSupported => true;

  @override
  Stream<SpeechPracticeEvent> get events => _controller.stream;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async =>
      permissions;

  @override
  Future<SpeechPracticePermissionState> requestPermissions({
    bool onlyMic = false,
  }) async => permissions;

  @override
  Future<void> warmup({String locale = 'en-US'}) async {}

  @override
  Future<int> getDeviceRamBytes() async => 0;

  @override
  Future<void> setRecognitionEnabled(bool enabled) async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    lastPromptId = promptId;
    _counter += 1;
    final path = '/tmp/test-recording-$_counter.caf';
    transcriptsByPath[path] = '';
    return path;
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    if (_counter == 0) return const SpeechPracticeStopResult();
    final filePath = '/tmp/test-recording-$_counter.caf';
    scheduleMicrotask(() {
      _controller.add(
        SpeechPracticeEvent(
          type: SpeechPracticeEventType.finalTranscriptReady,
          promptId: lastPromptId ?? 'prompt',
          transcript: transcriptsByPath[filePath] ?? '',
        ),
      );
    });
    return SpeechPracticeStopResult(filePath: filePath);
  }

  @override
  Future<void> cancelSession() async {
    lastPromptId = null;
  }

  @override
  Future<void> deleteRecording(String filePath) async {
    transcriptsByPath.remove(filePath);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

// ========== ReviewReminderService 测试替身 ==========

/// 空操作复习提醒服务（集成测试用）
class TestReviewReminderService implements ReviewReminderService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

// ========== safeSettle ==========

/// 集成测试用的 bounded pumpAndSettle 替身
///
/// 真实 pumpAndSettle 在 LiveTest 下默认 10min 超时；测试中 Riverpod async
/// provider / Showcase 等可能持续 schedule 帧导致 settle 不收敛。
/// 这里限定到 5 秒并吞掉 TimeoutException，避免单个测试卡 10 分钟。
Future<void> safeSettle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  } catch (_) {
    /* settle 超时容忍 */
  }
}

// ========== Analytics 初始化 ==========

/// 空操作分析通道（集成测试用）
class _NoOpChannel implements AnalyticsChannel {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}
  @override
  Future<void> setUserId(String? id) async {}
  @override
  Future<void> setUserProperty(String name, String? value) async {}
  @override
  Future<void> setUserProperties(Map<String, String?> properties) async {}
  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {}
  @override
  Future<void> unregisterSuperProperty(String name) async {}
}

/// 缓存的 SharedPreferences 实例（由 [initTestAnalytics] 初始化）
SharedPreferences? _testPrefsCache;
AnalyticsService? _testAnalyticsService;

/// 初始化测试用 AnalyticsService（须在 createTestApp 前调用一次）
Future<void> initTestAnalytics() async {
  final guideSeen = <String, Object>{
    for (final flowId in GuideFlowIds.all) 'guide_v1_${flowId}_seen': true,
  };
  SharedPreferences.setMockInitialValues(guideSeen);
  final prefs = await SharedPreferences.getInstance();
  _testPrefsCache = prefs;
  _testAnalyticsService = AnalyticsService(
    channel: _NoOpChannel(),
    consent: ConsentManager(prefs),
  );
}

// ========== Override 工厂 ==========

/// Onboarding 问卷相关的 provider 测试 override
List<Override> onboardingTestOverrides() {
  final prefs = _testPrefsCache;
  final analyticsService = _testAnalyticsService;
  if (prefs == null || analyticsService == null) {
    throw StateError(
      'initTestAnalytics() must be called before createTestApp() '
      'to initialize SharedPreferences for onboarding overrides',
    );
  }
  return [
    analyticsServiceProvider.overrideWithValue(analyticsService),
    isFirstLaunchProvider.overrideWithValue(false),
    sharedPreferencesProvider.overrideWithValue(prefs),
    initialOnboardingCompletedProvider.overrideWithValue(true),
  ];
}

/// 学习设置相关的 provider 测试 override
List<Override> learningSettingsTestOverrides({bool autoSkipRetell = false}) {
  return [
    initialLearningSettingsProvider.overrideWithValue(
      LearningSettings(autoSkipRetell: autoSkipRetell),
    ),
  ];
}

// ========== App 工厂 ==========

final _testPackageInfo = PackageInfo(
  appName: 'Echo Loop',
  packageName: 'top.echo-loop',
  version: '1.0.0',
  buildNumber: '1',
);

/// 创建集成测试用的 App，注入所有 Provider 测试替身
Widget createTestApp() {
  return ProviderScope(
    overrides: [
      ...onboardingTestOverrides(),
      ...learningSettingsTestOverrides(),
      showOfflineAsrSectionProvider.overrideWithValue(false),
      offlineAsrSettingsProvider.overrideWith(() => TestOfflineAsrSettings()),
      appSettingsProvider.overrideWith(() => TestAppSettings()),
      audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
      collectionListProvider.overrideWith(() => TestCollectionList()),
      tagListProvider.overrideWith(() => TestTagList()),
      listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
      learningProgressNotifierProvider.overrideWith(
        () => TestLearningProgressNotifier(),
      ),
      learningSessionProvider.overrideWith(() => TestLearningSession()),
      blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
      intensiveListenPlayerProvider.overrideWith(
        () => TestIntensiveListenPlayer(),
      ),
      retellPlayerProvider.overrideWith(() => TestRetellPlayer()),
      reviewDifficultPracticeProvider.overrideWith(
        () => TestReviewDifficultPractice(),
      ),
      bookmarkDaoProvider.overrideWithValue(TestBookmarkDao()),
      stageCompletionDaoProvider.overrideWithValue(TestStageCompletionDao()),
      audioItemDaoProvider.overrideWithValue(TestAudioItemDao()),
      packageInfoProvider.overrideWithValue(_testPackageInfo),
      sentenceAiNotifierProvider.overrideWithValue(
        SentenceAiNotifier(
          cacheDao: _TestSentenceAiCacheDao(),
          apiClient: _TestSentenceAiApiClient(),
        ),
      ),
      dailyStudyTimeProvider.overrideWith(() => TestDailyStudyTime()),
      studyStatsNotifierProvider.overrideWith(() => TestStudyStatsNotifier()),
      studyTimeServiceProvider.overrideWithValue(TestStudyTimeService()),
      savedWordListProvider.overrideWith(() => TestSavedWordList()),
      speechPracticeBackendProvider.overrideWithValue(
        TestSpeechPracticePlatform(),
      ),
      reviewReminderServiceProvider.overrideWithValue(
        TestReviewReminderService(),
      ),
      savedWordDaoProvider.overrideWithValue(TestSavedWordDao()),
    ],
    child: const EchoLoopApp(),
  );
}

/// 创建预置音频数据的集成测试 App
Widget createTestAppWithAudio({
  LearningProgress? progressOverride,
  AudioItem? audioItemOverride,
}) {
  final audioItem = audioItemOverride ?? createTestAudioItem();
  final collection = createTestCollection();
  final sentences = createTestSentences();
  final progress =
      progressOverride ??
      createTestLearningProgress(currentStageStartedAt: DateTime.now());

  return ProviderScope(
    overrides: [
      ...onboardingTestOverrides(),
      ...learningSettingsTestOverrides(),
      showOfflineAsrSectionProvider.overrideWithValue(false),
      offlineAsrSettingsProvider.overrideWith(() => TestOfflineAsrSettings()),
      appSettingsProvider.overrideWith(() => TestAppSettings()),
      audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
      collectionListProvider.overrideWith(() => TestCollectionList()),
      tagListProvider.overrideWith(() => TestTagList()),
      listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
      learningProgressNotifierProvider.overrideWith(
        () => TestLearningProgressNotifier(),
      ),
      learningSessionProvider.overrideWith(() => TestLearningSession()),
      blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
      intensiveListenPlayerProvider.overrideWith(
        () => TestIntensiveListenPlayer(),
      ),
      retellPlayerProvider.overrideWith(() => TestRetellPlayer()),
      reviewDifficultPracticeProvider.overrideWith(
        () => TestReviewDifficultPractice(),
      ),
      bookmarkDaoProvider.overrideWithValue(TestBookmarkDao()),
      stageCompletionDaoProvider.overrideWithValue(TestStageCompletionDao()),
      audioItemDaoProvider.overrideWithValue(TestAudioItemDao()),
      packageInfoProvider.overrideWithValue(_testPackageInfo),
      sentenceAiNotifierProvider.overrideWithValue(
        SentenceAiNotifier(
          cacheDao: _TestSentenceAiCacheDao(),
          apiClient: _TestSentenceAiApiClient(),
        ),
      ),
      dailyStudyTimeProvider.overrideWith(() => TestDailyStudyTime()),
      studyStatsNotifierProvider.overrideWith(() => TestStudyStatsNotifier()),
      studyTimeServiceProvider.overrideWithValue(TestStudyTimeService()),
      savedWordListProvider.overrideWith(() => TestSavedWordList()),
      speechPracticeBackendProvider.overrideWithValue(
        TestSpeechPracticePlatform(),
      ),
      reviewReminderServiceProvider.overrideWithValue(
        TestReviewReminderService(),
      ),
      savedWordDaoProvider.overrideWithValue(TestSavedWordDao()),
    ],
    child: _AudioPreloadWrapper(
      audioItem: audioItem,
      collection: collection,
      sentences: sentences,
      progress: progress,
    ),
  );
}

/// 预加载音频数据的 Wrapper
class _AudioPreloadWrapper extends ConsumerStatefulWidget {
  final AudioItem audioItem;
  final Collection collection;
  final List<Sentence> sentences;
  final LearningProgress progress;

  const _AudioPreloadWrapper({
    required this.audioItem,
    required this.collection,
    required this.sentences,
    required this.progress,
  });

  @override
  ConsumerState<_AudioPreloadWrapper> createState() =>
      _AudioPreloadWrapperState();
}

class _AudioPreloadWrapperState extends ConsumerState<_AudioPreloadWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadData();
    });
  }

  void _preloadData() {
    final audioLib =
        ref.read(audioLibraryProvider.notifier) as TestAudioLibrary;
    audioLib.addAudioItem(widget.audioItem);

    final collectionList =
        ref.read(collectionListProvider.notifier) as TestCollectionList;
    collectionList.state = collectionList.state.copyWith(
      rawCollections: [widget.collection],
      audioIdsMap: {
        widget.collection.id: [widget.audioItem.id],
      },
    );

    final progressNotifier =
        ref.read(learningProgressNotifierProvider.notifier)
            as TestLearningProgressNotifier;
    progressNotifier.setProgress(widget.progress);

    // 按 (currentStage, currentSubStage) 推导已完成的 sub_stage key 集合
    final progress = widget.progress;
    final completed = <String>{};
    for (final stage in LearningStage.values) {
      if (stage.index < progress.currentStage.index) {
        for (final sub in stage.allSubStages) {
          completed.add('${stage.key}:${sub.key}');
        }
      } else if (stage.index == progress.currentStage.index) {
        final subs = stage.allSubStages;
        final idx = subs.indexOf(progress.currentSubStage);
        if (idx > 0) {
          for (var i = 0; i < idx; i++) {
            completed.add('${stage.key}:${subs[i].key}');
          }
        }
      }
    }
    progressNotifier.setCompletionKeys(progress.audioItemId, completed);

    final practice =
        ref.read(listeningPracticeProvider.notifier) as TestListeningPractice;
    practice.setTestSentences(widget.sentences);

    final engine = ref.read(audioEngineProvider.notifier) as TestAudioEngine;
    engine.setTotalDuration(const Duration(seconds: 25));
  }

  @override
  Widget build(BuildContext context) {
    return const EchoLoopApp();
  }
}
