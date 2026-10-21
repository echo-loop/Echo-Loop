/// Mock Provider 集合
///
/// 用 Riverpod overrideWith 模式创建测试用 Notifier，
/// 避免真实 I/O（SharedPreferences、文件系统、just_audio）。
///
/// 公共 Notifier/DAO 替身已抽到 shared/，本文件仅保留 widget test 特化部分。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/analytics/analytics_channel.dart';
import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/consent_manager.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:echo_loop/features/usage/usage_counters.dart';
import 'package:echo_loop/features/usage/usage_event.dart';
import 'package:echo_loop/features/usage/usage_providers.dart';
import 'package:echo_loop/features/usage/usage_tracker.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/providers/app_update_provider.dart';
import 'package:echo_loop/providers/dictionary_provider.dart';
import 'package:echo_loop/providers/notification_permission_provider.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/providers/retell_recording_controller_provider.dart';
import 'package:echo_loop/providers/speech/speech_recording_controller.dart';
import 'package:echo_loop/providers/local_transcription_task_provider.dart';
import 'package:echo_loop/providers/transcription_task_provider.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/app_update_info.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/services/notification_permission_service.dart';
import 'package:echo_loop/services/study_time_service.dart';
import 'package:echo_loop/services/transcription_api_client.dart';
import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';

// 共享替身
import 'shared/fake_notifiers.dart';
import 'shared/fake_daos.dart';
export 'shared/fake_notifiers.dart';
export 'shared/fake_daos.dart';
export 'shared/test_fixtures.dart';

// ========== 向后兼容的 Test* 别名 ==========
// 这些 thin wrapper 保持旧的 Test* 类名，避免改动所有调用方。
// 实现全部在 shared/ 的 Fake* 类中。

class TestAppSettings extends FakeAppSettings {
  TestAppSettings([super.initialState = const AppSettingsState()]);
}

class TestAudioLibrary extends FakeAudioLibrary {
  TestAudioLibrary([super.initialState = const AudioLibraryState()]);
}

class TestCollectionList extends FakeCollectionList {
  TestCollectionList([super.initialState = const CollectionState()]);
}

class TestTagList extends FakeTagList {
  TestTagList([super.initialState = const TagState()]);
}

class TestListeningPractice extends FakeListeningPractice {
  TestListeningPractice([super.initialState = const ListeningPracticeState()]);
}

class TestLearningProgressNotifier extends FakeLearningProgressNotifier {
  TestLearningProgressNotifier([
    super.initialState = const LearningProgressState(),
  ]);
}

class TestLearningSession extends FakeLearningSession {
  TestLearningSession([super.initialState = const LearningSessionState()]);
}

class TestBlindListenPlayer extends FakeBlindListenPlayer {
  TestBlindListenPlayer([super.initialState = const BlindListenPlayerState()]);
}

class TestIntensiveListenPlayer extends FakeIntensiveListenPlayer {
  TestIntensiveListenPlayer([
    super.initialState = const IntensiveListenState(),
    super.testSentences = const [],
  ]);
}

class TestRetellPlayer extends FakeRetellPlayer {
  TestRetellPlayer([
    super.initialState = const RetellPlayerState(),
    super.testParagraphs = const [],
    super.testKeywords = const {},
  ]);
}

class TestReviewDifficultPractice extends FakeReviewDifficultPractice {
  TestReviewDifficultPractice([
    super.initialState = const ReviewDifficultPracticeState(),
    super.testSentences = const [],
  ]);
}

class TestAudioEngine extends FakeAudioEngine {
  TestAudioEngine({
    super.initialState = const AudioEngineState(),
    super.isPlaying = false,
  });
}

class TestForegroundAudioEngine extends FakeForegroundAudioEngine {
  TestForegroundAudioEngine({
    super.initialState = const AudioEngineState(),
    super.isPlaying = false,
  });
}

class TestDailyStudyTime extends FakeDailyStudyTime {}

class TestOfflineAsrSettings extends FakeOfflineAsrSettings {
  TestOfflineAsrSettings([OfflineAsrSettingsState? initialState])
    : super(
        initialState ??
            OfflineAsrSettingsState(
              enabled: true,
              backend: AsrBackend.platform,
              engineReady: true,
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

// ========== 测试用分析服务 ==========

/// 测试用 AnalyticsChannel — 不做任何操作
class NoOpAnalyticsChannel implements AnalyticsChannel {
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

/// 创建测试用 AnalyticsService（no-op，不会访问网络或持久化）
///
/// 调用前必须确保已执行 SharedPreferences.setMockInitialValues({})
Future<AnalyticsService> createTestAnalyticsService() async {
  final prefs = await SharedPreferences.getInstance();
  return AnalyticsService(
    channel: NoOpAnalyticsChannel(),
    consent: ConsentManager(prefs),
  );
}

/// 同步创建测试用 AnalyticsService（使用 no-op consent）
AnalyticsService createTestAnalyticsServiceSync() {
  return AnalyticsService(
    channel: NoOpAnalyticsChannel(),
    consent: _NoOpConsentManager(),
  );
}

class _NoOpConsentManager extends ConsentManager {
  _NoOpConsentManager() : super(_DummySharedPreferences());

  @override
  bool get hasConsented => true;
}

class _DummySharedPreferences implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 返回 analyticsServiceProvider 的 override
Override analyticsOverride() {
  return analyticsServiceProvider.overrideWithValue(
    createTestAnalyticsServiceSync(),
  );
}

/// 固定权益态（默认 Pro）的 SubscriptionController 替身。
///
/// 让已登录用户在 widget 测试中视为「已解锁」，从而绕过 AI 功能的额度闸 /
/// Paywall（额度闸本身由订阅模块单测覆盖）。不传 [state] 即为 Pro。
class _FixedSubscriptionController extends SubscriptionController {
  _FixedSubscriptionController(this._state);
  final EntitlementState _state;
  @override
  EntitlementState build() => _state;
}

/// 返回把订阅权益固定为 [pro] 的 override（默认 Pro，已解锁全部付费能力）。
Override subscriptionEntitlementOverride({bool pro = true}) {
  return subscriptionControllerProvider.overrideWith(
    () => _FixedSubscriptionController(
      pro
          ? const EntitlementState(
              status: EntitlementStatus.premium,
              entitlement: Entitlement(isPremium: true),
            )
          : const EntitlementState.free(),
    ),
  );
}

/// 返回 usageTrackerProvider 的 override。
///
/// 大多数 widget 测试只关心业务流程，不需要真实写入 SharedPreferences。
Override usageOverride() {
  return usageTrackerProvider.overrideWithValue(_NoOpUsageTracker());
}

class _NoOpUsageTracker implements UsageTracker {
  @override
  UsageCounters loadCounters() => const UsageCounters();

  @override
  Future<void> record(
    UsageEvent event, {
    Map<String, Object>? analyticsParams,
  }) async {}

  @override
  Future<void> resetForTests() async {}
}

// ========== 通知权限 ==========

class _FakeNotificationPermissionService extends Mock
    implements NotificationPermissionService {}

/// 通知权限锚点 noop override
Override notificationPermissionOverride() {
  final fake = _FakeNotificationPermissionService();
  when(() => fake.maybeTriggerPrompt()).thenAnswer((_) async {});
  when(() => fake.onUserAcceptedPrompt()).thenAnswer((_) async => true);
  when(() => fake.onUserDismissedPrompt()).thenAnswer((_) async {});
  return notificationPermissionServiceProvider.overrideWithValue(fake);
}

// ========== 词典 ==========

/// 返回 dictionaryProvider 的 override
Override dictionaryOverride({
  DictionaryStatus status = DictionaryStatus.downloaded,
  String nativeLanguage = 'zh',
}) {
  return dictionaryProvider.overrideWith(
    () => _TestDictionary(
      DictionaryState(status: status, nativeLanguage: nativeLanguage),
    ),
  );
}

class _TestDictionary extends Dictionary {
  final DictionaryState _initialState;
  _TestDictionary(this._initialState);

  @override
  DictionaryState build() => _initialState;

  @override
  Future<void> retryDownload() async {}
}

// ========== 学习设置 ==========

/// 返回学习设置 Provider 系列的 override 列表
List<Override> learningSettingsOverrides({
  bool autoSkipRetell = false,
  bool autoShowAiExplanation = true,
  bool autoShowAiAnalysis = true,
  bool autoShowAiTranslation = true,
  bool autoShowAiSenseGroups = false,
  bool autoPlayRetellRecordingAfterCompletion = false,
  bool listenAndRepeatRatingEnabled = true,
  bool retellRatingEnabled = true,
  bool retellAutoPlaybackPromptShown = false,
  bool pdfExportReminderShown = false,
  SharedPreferences? prefs,
}) {
  return [
    initialLearningSettingsProvider.overrideWithValue(
      LearningSettings(
        autoSkipRetell: autoSkipRetell,
        autoShowAiExplanation: autoShowAiExplanation,
        autoShowAiAnalysis: autoShowAiAnalysis,
        autoShowAiTranslation: autoShowAiTranslation,
        autoShowAiSenseGroups: autoShowAiSenseGroups,
        autoPlayRetellRecordingAfterCompletion:
            autoPlayRetellRecordingAfterCompletion,
        listenAndRepeatRatingEnabled: listenAndRepeatRatingEnabled,
        retellRatingEnabled: retellRatingEnabled,
        retellAutoPlaybackPromptShown: retellAutoPlaybackPromptShown,
        pdfExportReminderShown: pdfExportReminderShown,
      ),
    ),
    if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
  ];
}

// ========== AppUpdate ==========

/// 测试用 AppUpdate — 不访问网络和 SharedPreferences
class TestAppUpdate extends AppUpdate {
  @override
  AppUpdateState build() => const AppUpdateInitial();

  @override
  Future<AppUpdateResult> manualCheck() async {
    return const AppUpdateResult(type: AppUpdateType.none);
  }

  @override
  Future<void> dismiss() async {
    state = const AppUpdateDismissed();
  }
}

// ========== TranscriptionTaskManager ==========

/// 测试用 TranscriptionTaskManager — 不执行真实转录
class TestTranscriptionTaskManager extends TranscriptionTaskManager {
  final Map<String, TranscriptionTaskState> _initialState;

  TestTranscriptionTaskManager([this._initialState = const {}]);

  @override
  Map<String, TranscriptionTaskState> build() => Map.of(_initialState);

  @override
  Future<void> startTranscription(
    AudioItem audioItem,
    String language, {
    required String accessToken,
    bool autoMergeShortSentences = true,
  }) async {}

  @override
  void cancelTranscription(String audioId) {
    state = Map.of(state)..remove(audioId);
  }

  @override
  void clearState(String audioId) {
    state = Map.of(state)..remove(audioId);
  }
}

/// 测试用 LocalTranscriptionTaskManager — build 返回注入的固定状态，
/// 副作用方法置空，便于渲染进度/终态视图。
class TestLocalTranscriptionTaskManager extends LocalTranscriptionTaskManager {
  final Map<String, LocalTranscriptionState> _initialState;

  TestLocalTranscriptionTaskManager([this._initialState = const {}]);

  @override
  Map<String, LocalTranscriptionState> build() => Map.of(_initialState);

  @override
  Future<void> startLocalTranscription(
    AudioItem audioItem, {
    required AsrModelInfo model,
    bool autoMergeShortSentences = true,
  }) async {}

  @override
  void cancelTranscription(String audioId) {
    state = Map.of(state)..remove(audioId);
  }

  @override
  void clearState(String audioId) {
    state = Map.of(state)..remove(audioId);
  }
}

// ========== SpeechRecordingController ==========

/// 测试用 SpeechRecordingController — 不依赖平台通道
class TestSpeechRecordingController extends SpeechRecordingController {
  void Function(Duration duration)? recordingCompletionHandler;

  final SpeechRecordingPhase initialPhase;
  final SpeechPracticeAttempt? initialAttempt;

  TestSpeechRecordingController({
    this.initialPhase = SpeechRecordingPhase.idle,
    this.initialAttempt,
  });

  @override
  SpeechRecordingState build() =>
      SpeechRecordingState(phase: initialPhase, currentAttempt: initialAttempt);

  @override
  Future<void> startRecording({
    required String promptId,
    required String referenceText,
    Duration? referenceDuration,
  }) async {}

  @override
  Future<void> stopAndEvaluate({required String referenceText}) async {}

  @override
  Future<void> cancelActiveRecording() async {}

  @override
  Future<void> clearRecording() async {
    state = const SpeechRecordingState();
  }

  @override
  Future<void> fullReset() async {
    state = const SpeechRecordingState();
  }

  @override
  Future<void> deleteRecording(String filePath) async {}

  @override
  void setRecordingCompletionHandler(
    void Function(Duration duration)? handler,
  ) {
    recordingCompletionHandler = handler;
  }

  void emitRecordingCompleted(Duration duration) {
    recordingCompletionHandler?.call(duration);
  }
}

// ========== RetellRecordingController ==========

/// 测试用 RetellRecordingController — 不依赖平台通道
class TestRetellRecordingController extends RetellRecordingController {
  final RetellRecordingState _initialState;
  void Function(Duration duration)? recordingCompletionHandler;

  TestRetellRecordingController([
    this._initialState = const RetellRecordingState(),
  ]);

  @override
  RetellRecordingState build() => _initialState;

  @override
  void setRecordingCompletionHandler(
    void Function(Duration duration)? handler,
  ) {
    recordingCompletionHandler = handler;
  }

  @override
  Future<void> startRecording({
    required String promptId,
    required String referenceText,
    Duration? referenceDuration,
  }) async {
    state = state.copyWith(
      phase: RetellRecordingPhase.recording,
      promptId: promptId,
      awaitingSpeechTimedOut: false,
    );
  }

  @override
  Future<void> stopAndEvaluate({required String referenceText}) async {
    state = state.copyWith(phase: RetellRecordingPhase.processing);
    state = state.copyWith(
      phase: RetellRecordingPhase.idle,
      currentAttempt: SpeechPracticeAttempt(
        promptId: state.promptId ?? '',
        status: SpeechPracticeAttemptStatus.passed,
        score: 0.8,
      ),
      clearPromptId: true,
    );
  }

  @override
  Future<void> cancelActiveRecording() async {
    state = state.copyWith(
      phase: RetellRecordingPhase.idle,
      clearPromptId: true,
    );
  }

  @override
  Future<void> clearRecording() async {
    state = state.copyWith(
      clearCurrentAttempt: true,
      clearLiveTranscript: true,
      clearPromptId: true,
      phase: RetellRecordingPhase.idle,
      awaitingSpeechTimedOut: false,
    );
  }

  @override
  Future<void> fullReset() async {
    state = const RetellRecordingState();
  }

  /// 直接设置 state（测试辅助方法）
  void setState(RetellRecordingState newState) => state = newState;

  /// 模拟底层录音服务完成一次有效录音。
  void emitRecordingCompleted(Duration duration) {
    recordingCompletionHandler?.call(duration);
  }
}

// ========== TranscriptionApiClient ==========

/// 测试用 TranscriptionApiClient Provider 值
TranscriptionApiClient createTestTranscriptionApiClient() {
  return TranscriptionApiClient(baseUrl: 'https://test.local');
}

// ========== studyTimeOverrides ==========

/// 返回录音控制器 + study time 的 override 列表
List<Override> studyTimeOverrides({
  StudyTimeService? studyTimeService,
  TestSpeechRecordingController Function()? speechControllerFactory,
}) {
  return [
    studyTimeServiceProvider.overrideWithValue(
      studyTimeService ?? FakeStudyTimeService(),
    ),
    speechRecordingControllerProvider.overrideWith(
      speechControllerFactory ?? TestSpeechRecordingController.new,
    ),
    retellRecordingControllerProvider.overrideWith(
      TestRetellRecordingController.new,
    ),
    offlineAsrOverride(),
  ];
}

// ========== offlineAsrOverride ==========

/// 返回 offlineAsrSettingsProvider 的 override（默认开启且就绪）
Override offlineAsrOverride({
  bool enabled = true,
  AsrBackend backend = AsrBackend.platform,
  bool engineReady = true,
}) {
  const testModel = AsrModelInfo(
    id: 'test-model',
    displayName: 'Test Model',
    type: AsrModelType.moonshine,
  );
  return offlineAsrSettingsProvider.overrideWith(
    () => FakeOfflineAsrSettings(
      OfflineAsrSettingsState(
        enabled: enabled,
        backend: backend,
        engineReady: engineReady,
        recommendedModel: testModel,
      ),
    ),
  );
}

// ============================================================
// Stubbed Mock Helpers
// ============================================================

class _StubbedMockCacheDao extends Mock implements SentenceAiCacheDao {}

/// 创建已 stub getByHash 的 SentenceAiCacheDao mock
///
/// getByHash 返回 Future.value(null)（无缓存命中）。
/// 其他方法按需在调用方额外 stub。
SentenceAiCacheDao createStubbedMockCacheDao() {
  final mock = _StubbedMockCacheDao();
  when(() => mock.getByHash(any(), any())).thenAnswer((_) async => null);
  return mock;
}
