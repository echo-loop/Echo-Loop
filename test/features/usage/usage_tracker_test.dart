import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/analytics/analytics_channel.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/consent_manager.dart';
import 'package:echo_loop/analytics/models/event_names.dart';
import 'package:echo_loop/features/usage/usage_counter_store.dart';
import 'package:echo_loop/features/usage/usage_counters.dart';
import 'package:echo_loop/features/usage/usage_event.dart';
import 'package:echo_loop/features/usage/usage_storage_keys.dart';
import 'package:echo_loop/features/usage/usage_tracker.dart';

class _RecordingChannel implements AnalyticsChannel {
  final List<({String name, Map<String, Object>? params})> events = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    events.add((name: name, params: parameters));
  }

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

class _FailingUsageCounterStore extends UsageCounterStore {
  _FailingUsageCounterStore() : super.memory();

  @override
  UsageCounters loadCounters() {
    throw StateError('local counter unavailable');
  }
}

void main() {
  group('UsageCounters', () {
    test('increment 更新对应计数字段', () {
      final counters = const UsageCounters()
          .increment(UsageEvent.audioUpload)
          .increment(UsageEvent.translationTapped)
          .increment(UsageEvent.translationTapped)
          .increment(UsageEvent.bookmarkSentenceSaved);

      expect(counters.audioUploadCount, 1);
      expect(counters.translationTapCount, 2);
      expect(counters.bookmarkSentenceSaveCount, 1);
      expect(counters.analysisTapCount, 0);
    });

    test('increment 更新 AI 成功计数（独立于点击计数）', () {
      final counters = const UsageCounters()
          .increment(UsageEvent.translationSucceeded)
          .increment(UsageEvent.translationSucceeded)
          .increment(UsageEvent.analysisSucceeded)
          .increment(UsageEvent.senseGroupSucceeded)
          .increment(UsageEvent.aiWordAnalysisSucceeded)
          .increment(UsageEvent.aiWordAnalysisSucceeded);

      expect(counters.translationSuccessCount, 2);
      expect(counters.analysisSuccessCount, 1);
      expect(counters.senseGroupSuccessCount, 1);
      expect(counters.aiWordAnalysisSuccessCount, 2);
      // 成功计数不影响点击计数
      expect(counters.translationTapCount, 0);
      expect(counters.analysisTapCount, 0);
      expect(counters.senseGroupTapCount, 0);
    });

    test('旧存档缺少新成功计数字段时回落为 0', () {
      // 模拟新增字段前写入的 JSON（不含 *SuccessCount）
      final legacyJson = <String, Object?>{
        'translationTapCount': 3,
        'analysisTapCount': 2,
      };

      final restored = UsageCounters.fromJson(legacyJson);

      expect(restored.translationTapCount, 3);
      expect(restored.analysisTapCount, 2);
      expect(restored.translationSuccessCount, 0);
      expect(restored.analysisSuccessCount, 0);
      expect(restored.senseGroupSuccessCount, 0);
      expect(restored.aiWordAnalysisSuccessCount, 0);
    });

    test('JSON roundtrip 保留所有计数', () {
      final counters = const UsageCounters(
        audioUploadCount: 2,
        subtitleUploadCount: 3,
        aiTranscriptionStartedCount: 4,
        aiTranscriptionCompletedCount: 5,
        subStageCompletedCount: 6,
        translationTapCount: 7,
        analysisTapCount: 8,
        senseGroupTapCount: 9,
        translationSuccessCount: 19,
        analysisSuccessCount: 20,
        senseGroupSuccessCount: 21,
        aiWordAnalysisSuccessCount: 22,
        bookmarkSentenceReviewCompleteCount: 10,
        flashcardReviewCompleteCount: 11,
        bookmarkSentenceSaveCount: 12,
        wordSaveCount: 13,
        recordingCompleteCount: 14,
        studyTaskTapCount: 15,
        firstLearnCompleteCount: 16,
        bookmarkReviewButtonTapCount: 17,
        flashcardButtonTapCount: 18,
      );

      final restored = UsageCounters.fromJson(counters.toJson());

      expect(restored.toJson(), counters.toJson());
    });
  });

  group('UsageTracker', () {
    late SharedPreferences prefs;
    late _RecordingChannel channel;
    late ConsentManager consent;
    late UsageTracker tracker;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      channel = _RecordingChannel();
      consent = ConsentManager(prefs);
      tracker = UsageTracker(
        store: UsageCounterStore(prefs),
        analytics: AnalyticsService(channel: channel, consent: consent),
      );
    });

    test('record 先写本地计数再上报 analytics', () async {
      await tracker.record(
        UsageEvent.translationTapped,
        analyticsParams: {EventParams.audioId: 'audio-1'},
      );

      expect(tracker.loadCounters().translationTapCount, 1);
      expect(channel.events, hasLength(1));
      expect(channel.events.single.name, Events.translationRequested);
      expect(channel.events.single.params?[EventParams.audioId], 'audio-1');
    });

    test('analytics consent 关闭时本地仍计数', () async {
      await consent.revokeConsent();

      await tracker.record(UsageEvent.analysisTapped);

      expect(tracker.loadCounters().analysisTapCount, 1);
      expect(channel.events, isEmpty);
    });

    test('本地计数失败不阻断 analytics 上报', () async {
      final safeTracker = UsageTracker(
        store: _FailingUsageCounterStore(),
        analytics: AnalyticsService(channel: channel, consent: consent),
      );

      await safeTracker.record(
        UsageEvent.senseGroupTapped,
        analyticsParams: {EventParams.audioId: 'audio-2'},
      );

      expect(channel.events, hasLength(1));
      expect(channel.events.single.name, Events.senseGroupRequested);
      expect(channel.events.single.params?[EventParams.audioId], 'audio-2');
    });

    test('计数持久化到 usage_ 前缀 key', () async {
      await tracker.record(UsageEvent.audioUpload);

      expect(UsageStorageKeys.counters, startsWith(UsageStorageKeys.prefix));
      expect(
        UsageStorageKeys.lastRecordedAtMs,
        startsWith(UsageStorageKeys.prefix),
      );
      expect(prefs.getString(UsageStorageKeys.counters), isNotNull);
      expect(prefs.getInt(UsageStorageKeys.lastRecordedAtMs), isNotNull);
    });

    test('resetForTests 只清理 usage_ 前缀 key', () async {
      await prefs.setString('unrelated_key', 'keep');
      await tracker.record(UsageEvent.wordSaved);

      await tracker.resetForTests();

      expect(prefs.getString('unrelated_key'), 'keep');
      expect(prefs.getString(UsageStorageKeys.counters), isNull);
      expect(prefs.getInt(UsageStorageKeys.lastRecordedAtMs), isNull);
    });
  });
}
