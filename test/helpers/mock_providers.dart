/// Mock Provider 集合
///
/// 用 Riverpod overrideWith 模式创建测试用 Notifier，
/// 避免真实 I/O（SharedPreferences、文件系统、just_audio）。
///
/// 公共 Notifier/DAO 替身已抽到 shared/，本文件仅保留 widget test 特化部分。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/analytics/analytics_channel.dart';
import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/consent_manager.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/providers/app_update_provider.dart';
import 'package:echo_loop/providers/dictionary_provider.dart';
import 'package:echo_loop/providers/notification_permission_provider.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/providers/retell_recording_controller_provider.dart';
import 'package:echo_loop/providers/speech/speech_recording_controller.dart';
import 'package:echo_loop/providers/transcription_task_provider.dart';
import 'package:echo_loop/services/asr/offline_asr_engine.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/app_update_info.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/services/notification_permission_service.dart';
import 'package:echo_loop/services/study_event_recorder.dart';
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
  TestAppSettings([AppSettingsState initialState = const AppSettingsState()])
    : super(initialState);
}

class TestAudioLibrary extends FakeAudioLibrary {
  TestAudioLibrary([AudioLibraryState initialState = const AudioLibraryState()])
    : super(initialState);
}

class TestCollectionList extends FakeCollectionList {
  TestCollectionList([CollectionState initialState = const CollectionState()])
    : super(initialState);
}

class TestTagList extends FakeTagList {
  TestTagList([TagState initialState = const TagState()]) : super(initialState);
}

class TestListeningPractice extends FakeListeningPractice {
  TestListeningPractice([
    ListeningPracticeState initialState = const ListeningPracticeState(),
  ]) : super(initialState);
}

class TestLearningProgressNotifier extends FakeLearningProgressNotifier {
  TestLearningProgressNotifier([
    LearningProgressState initialState = const LearningProgressState(),
  ]) : super(initialState);
}

class TestLearningSession extends FakeLearningSession {
  TestLearningSession([
    LearningSessionState initialState = const LearningSessionState(),
  ]) : super(initialState);
}

class TestBlindListenPlayer extends FakeBlindListenPlayer {
  TestBlindListenPlayer([
    BlindListenPlayerState initialState = const BlindListenPlayerState(),
  ]) : super(initialState);
}

class TestIntensiveListenPlayer extends FakeIntensiveListenPlayer {
  TestIntensiveListenPlayer([
    IntensiveListenState initialState = const IntensiveListenState(),
    List<Sentence> testSentences = const [],
  ]) : super(initialState, testSentences);
}

class TestRetellPlayer extends FakeRetellPlayer {
  TestRetellPlayer([
    RetellPlayerState initialState = const RetellPlayerState(),
    List<List<Sentence>> testParagraphs = const [],
    Map<int, Set<int>> testKeywords = const {},
  ]) : super(initialState, testParagraphs, testKeywords);
}

class TestReviewDifficultPractice extends FakeReviewDifficultPractice {
  TestReviewDifficultPractice([
    ReviewDifficultPracticeState initialState =
        const ReviewDifficultPracticeState(),
    List<Sentence> testSentences = const [],
  ]) : super(initialState, testSentences);
}

class TestAudioEngine extends FakeAudioEngine {
  TestAudioEngine({
    AudioEngineState initialState = const AudioEngineState(),
    bool isPlaying = false,
  }) : super(initialState: initialState, isPlaying: isPlaying);
}

class TestFlashcardNotifier extends FakeFlashcardNotifier {}

class TestDailyStudyTime extends FakeDailyStudyTime {}

class TestOfflineAsrSettings extends FakeOfflineAsrSettings {
  TestOfflineAsrSettings([
    OfflineAsrSettingsState initialState = const OfflineAsrSettingsState(
      enabled: true,
      backend: AsrBackend.platform,
      engineReady: true,
      recommendedModel: AsrModelInfo(
        id: 'test-model',
        displayName: 'Test Model',
        type: AsrModelType.moonshine,
      ),
    ),
  ]) : super(initialState);
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
  String get name => 'NoOp';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}

  @override
  Future<void> setUserId(String? id) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}

  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {}
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
  SharedPreferences? prefs,
}) {
  return [
    initialLearningSettingsProvider.overrideWithValue(
      LearningSettings(autoSkipRetell: autoSkipRetell),
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
  Future<void> startTranscription(AudioItem audioItem, String language) async {}

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
  final SpeechRecordingPhase initialPhase;

  TestSpeechRecordingController({
    this.initialPhase = SpeechRecordingPhase.idle,
  });

  @override
  SpeechRecordingState build() => SpeechRecordingState(phase: initialPhase);

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
  void setRecorder(StudyEventRecorder? recorder) {}
}

// ========== RetellRecordingController ==========

/// 测试用 RetellRecordingController — 不依赖平台通道
class TestRetellRecordingController extends RetellRecordingController {
  final RetellRecordingState _initialState;

  TestRetellRecordingController([
    this._initialState = const RetellRecordingState(),
  ]);

  @override
  RetellRecordingState build() => _initialState;

  @override
  void setRecorder(StudyEventRecorder? recorder) {}

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
}

// ========== TranscriptionApiClient ==========

/// 测试用 TranscriptionApiClient Provider 值
TranscriptionApiClient createTestTranscriptionApiClient() {
  return TranscriptionApiClient(baseUrl: 'https://test.local');
}

// ========== studyTimeOverrides ==========

/// 返回录音控制器 + study time 的 override 列表
List<Override> studyTimeOverrides() {
  return [
    studyTimeServiceProvider.overrideWithValue(FakeStudyTimeService()),
    speechRecordingControllerProvider.overrideWith(
      TestSpeechRecordingController.new,
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
