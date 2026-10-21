import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/analytics/analytics_channel.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/consent_manager.dart';
import 'package:echo_loop/analytics/models/event_names.dart';

/// 记录所有调用的 Mock Channel
class MockChannel implements AnalyticsChannel {
  final List<({String name, Map<String, Object>? params})> events = [];
  final List<String?> userIds = [];
  final List<({String name, String? value})> userProperties = [];
  final List<Map<String, Object>> superPropertiesCalls = [];
  final List<String> unregisteredSuperProperties = [];

  /// 测试时把它设为 true，下一次 [registerSuperProperties] 抛错；
  /// 验证 [AnalyticsService] 是否吞掉异常。
  bool throwOnRegister = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    events.add((name: name, params: parameters));
  }

  @override
  Future<void> setUserId(String? id) async {
    userIds.add(id);
  }

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
    if (throwOnRegister) throw StateError('register failed');
    superPropertiesCalls.add(properties);
  }

  @override
  Future<void> unregisterSuperProperty(String name) async {
    unregisteredSuperProperties.add(name);
  }
}

void main() {
  group('AnalyticsService', () {
    late MockChannel channel;
    late SharedPreferences prefs;
    late ConsentManager consent;
    late AnalyticsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      channel = MockChannel();
      consent = ConsentManager(prefs);
      service = AnalyticsService(channel: channel, consent: consent);
    });

    test('track 转发事件到 channel', () async {
      await service.track(Events.learningStart, {
        EventParams.audioId: 'audio-123',
      });

      expect(channel.events, hasLength(1));
      expect(channel.events.first.name, Events.learningStart);
      expect(channel.events.first.params?[EventParams.audioId], 'audio-123');
    });

    test('track 无参数时传 null', () async {
      await service.track(Events.collectionCreate);

      expect(channel.events, hasLength(1));
      expect(channel.events.first.name, Events.collectionCreate);
      expect(channel.events.first.params, isNull);
    });

    test('用户未同意时 track 静默丢弃', () async {
      await consent.revokeConsent();

      await service.track(Events.collectionCreate);
      await service.track(Events.learningStart, {EventParams.audioId: '123'});

      expect(channel.events, isEmpty);
    });

    test('用户未同意时 setUserId 静默丢弃', () async {
      await consent.revokeConsent();

      await service.setUserId('user-123');

      expect(channel.userIds, isEmpty);
    });

    test('用户未同意时 setUserProperty 静默丢弃', () async {
      await consent.revokeConsent();

      await service.setUserProperty('locale', 'zh');

      expect(channel.userProperties, isEmpty);
    });

    test('撤回同意后停止采集，重新同意后恢复', () async {
      // 同意状态：事件正常
      await service.track(Events.collectionCreate);
      expect(channel.events, hasLength(1));

      // 撤回同意：事件丢弃
      await consent.revokeConsent();
      await service.track(Events.learningStart);
      expect(channel.events, hasLength(1)); // 没有新增

      // 重新同意：事件恢复
      await consent.grantConsent();
      await service.track(Events.learningEnd);
      expect(channel.events, hasLength(2));
    });

    test('setUserId 转发到 channel', () async {
      await service.setUserId('anonymous-uuid-123');

      expect(channel.userIds, hasLength(1));
      expect(channel.userIds.first, 'anonymous-uuid-123');
    });

    test('setUserProperty 转发到 channel', () async {
      await service.setUserProperty('app_locale', 'zh');

      expect(channel.userProperties, hasLength(1));
      expect(channel.userProperties.first.name, 'app_locale');
      expect(channel.userProperties.first.value, 'zh');
    });

    test('安装来源用户属性转发到 channel', () async {
      await service.setUserProperty(UserProperties.installSource, 'play');

      expect(channel.userProperties, hasLength(1));
      expect(channel.userProperties.first.name, 'install_source');
      expect(channel.userProperties.first.value, 'play');
    });

    test('registerSuperProperties 转发到 channel', () async {
      await service.registerSuperProperties({
        'notification_status': 'granted',
        'network_status': 'not_applicable',
      });

      expect(channel.superPropertiesCalls, hasLength(1));
      expect(channel.superPropertiesCalls.first, {
        'notification_status': 'granted',
        'network_status': 'not_applicable',
      });
    });

    test('用户未同意时 registerSuperProperties 静默丢弃', () async {
      await consent.revokeConsent();

      await service.registerSuperProperties({'notification_status': 'granted'});

      expect(channel.superPropertiesCalls, isEmpty);
    });

    test('channel 抛错时 registerSuperProperties 静默吞掉，不传播', () async {
      channel.throwOnRegister = true;

      // 不应抛
      await service.registerSuperProperties({'k': 'v'});

      expect(channel.superPropertiesCalls, isEmpty); // 抛错时不会写入
    });

    test('unregisterSuperProperty 转发到 channel', () async {
      await service.unregisterSuperProperty('supabase_user_id');

      expect(channel.unregisteredSuperProperties, ['supabase_user_id']);
    });
  });
}
