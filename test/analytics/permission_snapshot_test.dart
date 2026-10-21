import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/analytics/analytics_channel.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/consent_manager.dart';
import 'package:echo_loop/analytics/models/event_names.dart';
import 'package:echo_loop/analytics/permission_snapshot.dart';

/// 不出错的伪 probe：返回固定值。
class _FakeProbe implements PermissionProbe {
  final String microphone;
  final String speech;
  final String notification;

  const _FakeProbe({
    required this.microphone,
    required this.speech,
    required this.notification,
  });

  @override
  Future<({String microphone, String speech})>
  readSpeechAndMicrophoneStatus() async =>
      (microphone: microphone, speech: speech);

  @override
  Future<String> readNotificationStatus() async => notification;
}

/// readSpeechAndMicrophoneStatus 抛错的 probe，用于验证容错。
class _ThrowingSpeechProbe implements PermissionProbe {
  final String notification;
  const _ThrowingSpeechProbe({required this.notification});

  @override
  Future<({String microphone, String speech})>
  readSpeechAndMicrophoneStatus() async {
    throw Exception('boom');
  }

  @override
  Future<String> readNotificationStatus() async => notification;
}

/// 记录所有调用的 channel，给 reportPermissionSnapshot 测试用。
class _RecordingChannel implements AnalyticsChannel {
  final List<({String name, Map<String, Object>? params})> events = [];
  final List<({String name, String? value})> userProperties = [];
  final List<Map<String, Object>> superPropertiesCalls = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    events.add((name: name, params: parameters));
  }

  @override
  Future<void> setUserId(String? id) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {
    userProperties.add((name: name, value: value));
  }

  @override
  Future<void> setUserProperties(Map<String, String?> properties) async {
    for (final entry in properties.entries) {
      await setUserProperty(entry.key, entry.value);
    }
  }

  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {
    superPropertiesCalls.add(properties);
  }

  @override
  Future<void> unregisterSuperProperty(String name) async {}
}

/// readNotificationStatus 抛错的 probe，用于验证容错。
class _ThrowingNotificationProbe implements PermissionProbe {
  final String microphone;
  final String speech;
  const _ThrowingNotificationProbe({
    required this.microphone,
    required this.speech,
  });

  @override
  Future<({String microphone, String speech})>
  readSpeechAndMicrophoneStatus() async =>
      (microphone: microphone, speech: speech);

  @override
  Future<String> readNotificationStatus() async {
    throw Exception('boom');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionSnapshot.toEventParams', () {
    test('字段映射到 EventParams 常量 key', () {
      const snap = PermissionSnapshot(
        microphone: PermissionSnapshot.statusGranted,
        speech: PermissionSnapshot.statusDenied,
        notification: PermissionSnapshot.statusNotDetermined,
        network: PermissionSnapshot.statusNotApplicable,
      );

      final params = snap.toEventParams();
      expect(params, {
        EventParams.microphoneStatus: PermissionSnapshot.statusGranted,
        EventParams.speechStatus: PermissionSnapshot.statusDenied,
        EventParams.notificationStatus: PermissionSnapshot.statusNotDetermined,
        EventParams.networkStatus: PermissionSnapshot.statusNotApplicable,
      });
    });

    test('所有 value 都是 String，符合 PostHog property 类型约束', () {
      const snap = PermissionSnapshot(
        microphone: PermissionSnapshot.statusUnknown,
        speech: PermissionSnapshot.statusUnknown,
        notification: PermissionSnapshot.statusUnknown,
        network: PermissionSnapshot.statusUnknown,
      );
      final params = snap.toEventParams();
      for (final v in params.values) {
        expect(v, isA<String>());
      }
    });
  });

  group('PermissionSnapshot.mapNetworkSpStatus', () {
    test('非 iOS 平台一律 not_applicable', () {
      expect(
        PermissionSnapshot.mapNetworkSpStatus(true, isIOSPlatform: false),
        PermissionSnapshot.statusNotApplicable,
      );
      expect(
        PermissionSnapshot.mapNetworkSpStatus(false, isIOSPlatform: false),
        PermissionSnapshot.statusNotApplicable,
      );
      expect(
        PermissionSnapshot.mapNetworkSpStatus(null, isIOSPlatform: false),
        PermissionSnapshot.statusNotApplicable,
      );
    });

    test('iOS 上：曾成功过 → granted', () {
      expect(
        PermissionSnapshot.mapNetworkSpStatus(true, isIOSPlatform: true),
        PermissionSnapshot.statusGranted,
      );
    });

    test('iOS 上：SP 缺失 → notDetermined（不引入假 denied）', () {
      expect(
        PermissionSnapshot.mapNetworkSpStatus(null, isIOSPlatform: true),
        PermissionSnapshot.statusNotDetermined,
      );
    });

    test('iOS 上：false 也按 notDetermined 处理（保留语义余地）', () {
      expect(
        PermissionSnapshot.mapNetworkSpStatus(false, isIOSPlatform: true),
        PermissionSnapshot.statusNotDetermined,
      );
    });
  });

  group('PermissionSnapshot.capture (注入 probe)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('happy path：probe 返回值原样填充，network 按平台映射', () async {
      final prefs = await SharedPreferences.getInstance();
      final snap = await PermissionSnapshot.capture(
        prefs,
        probe: const _FakeProbe(
          microphone: PermissionSnapshot.statusGranted,
          speech: PermissionSnapshot.statusGranted,
          notification: PermissionSnapshot.statusDenied,
        ),
      );
      expect(snap.microphone, PermissionSnapshot.statusGranted);
      expect(snap.speech, PermissionSnapshot.statusGranted);
      expect(snap.notification, PermissionSnapshot.statusDenied);
      // 测试在 macOS host 上跑，network 一律 not_applicable
      expect(snap.network, PermissionSnapshot.statusNotApplicable);
    });

    test('mic/speech probe 抛错时，两项均回退为 unknown，notification 不受影响', () async {
      final prefs = await SharedPreferences.getInstance();
      final snap = await PermissionSnapshot.capture(
        prefs,
        probe: const _ThrowingSpeechProbe(
          notification: PermissionSnapshot.statusGranted,
        ),
      );
      expect(snap.microphone, PermissionSnapshot.statusUnknown);
      expect(snap.speech, PermissionSnapshot.statusUnknown);
      expect(snap.notification, PermissionSnapshot.statusGranted);
    });

    test('notification probe 抛错时，仅 notification 回退为 unknown', () async {
      final prefs = await SharedPreferences.getInstance();
      final snap = await PermissionSnapshot.capture(
        prefs,
        probe: const _ThrowingNotificationProbe(
          microphone: PermissionSnapshot.statusGranted,
          speech: PermissionSnapshot.statusDenied,
        ),
      );
      expect(snap.microphone, PermissionSnapshot.statusGranted);
      expect(snap.speech, PermissionSnapshot.statusDenied);
      expect(snap.notification, PermissionSnapshot.statusUnknown);
    });

    test('SP 中 network 为 true 时，仍因测试 host 非 iOS 返回 not_applicable', () async {
      SharedPreferences.setMockInitialValues({
        PermissionSnapshot.spKeyNetworkOk: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final snap = await PermissionSnapshot.capture(
        prefs,
        probe: const _FakeProbe(
          microphone: PermissionSnapshot.statusGranted,
          speech: PermissionSnapshot.statusGranted,
          notification: PermissionSnapshot.statusGranted,
        ),
      );
      expect(snap.network, PermissionSnapshot.statusNotApplicable);
    });
  });

  group('PermissionSnapshotReporting.reportPermissionSnapshot', () {
    late _RecordingChannel channel;
    late SharedPreferences prefs;
    late ConsentManager consent;
    late AnalyticsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      channel = _RecordingChannel();
      consent = ConsentManager(prefs);
      service = AnalyticsService(channel: channel, consent: consent);
    });

    test('三路写入：super properties + 4 个 person property + 1 个事件', () async {
      const snapshot = PermissionSnapshot(
        microphone: PermissionSnapshot.statusGranted,
        speech: PermissionSnapshot.statusGranted,
        notification: PermissionSnapshot.statusDenied,
        network: PermissionSnapshot.statusNotApplicable,
      );

      await service.reportPermissionSnapshot(snapshot, prefs);

      // super properties 一次性写入 4 类
      expect(channel.superPropertiesCalls, hasLength(1));
      expect(channel.superPropertiesCalls.first, snapshot.toEventParams());

      // 4 个 person property（每类一次）
      expect(channel.userProperties, hasLength(4));
      final byKey = {for (final e in channel.userProperties) e.name: e.value};
      expect(byKey[EventParams.microphoneStatus], snapshot.microphone);
      expect(byKey[EventParams.speechStatus], snapshot.speech);
      expect(byKey[EventParams.notificationStatus], snapshot.notification);
      expect(byKey[EventParams.networkStatus], snapshot.network);

      // 1 个 app_permission_snapshot 事件，参数和 snapshot 一致
      expect(channel.events, hasLength(1));
      expect(channel.events.first.name, Events.appPermissionSnapshot);
      expect(channel.events.first.params, snapshot.toEventParams());
    });

    test('用户未同意时三路全部静默丢弃', () async {
      await consent.revokeConsent();

      const snapshot = PermissionSnapshot(
        microphone: PermissionSnapshot.statusGranted,
        speech: PermissionSnapshot.statusGranted,
        notification: PermissionSnapshot.statusGranted,
        network: PermissionSnapshot.statusGranted,
      );
      await service.reportPermissionSnapshot(snapshot, prefs);

      expect(channel.superPropertiesCalls, isEmpty);
      expect(channel.userProperties, isEmpty);
      expect(channel.events, isEmpty);
    });

    test('权限未变化时不重复上报', () async {
      const snapshot = PermissionSnapshot(
        microphone: PermissionSnapshot.statusGranted,
        speech: PermissionSnapshot.statusGranted,
        notification: PermissionSnapshot.statusDenied,
        network: PermissionSnapshot.statusNotApplicable,
      );
      await service.reportPermissionSnapshot(snapshot, prefs);
      await service.reportPermissionSnapshot(snapshot, prefs);
      expect(channel.events, hasLength(1));
      expect(channel.superPropertiesCalls, hasLength(1));
      expect(channel.userProperties, hasLength(4));
    });
  });

  group('PermissionSnapshot 状态字符串常量', () {
    test('值不重复，符合命名约定', () {
      const all = [
        PermissionSnapshot.statusGranted,
        PermissionSnapshot.statusDenied,
        PermissionSnapshot.statusNotDetermined,
        PermissionSnapshot.statusRestricted,
        PermissionSnapshot.statusUnknown,
        PermissionSnapshot.statusNotApplicable,
      ];
      expect(all.toSet().length, all.length);
      for (final s in all) {
        expect(s, isNotEmpty);
      }
    });
  });
}
