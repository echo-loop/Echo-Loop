import 'dart:async';

import 'package:echo_loop/analytics/analytics_channel.dart';
import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/consent_manager.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('根 scope 首次读取固定的 analytics service', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = AnalyticsService(
      channel: _RecordingChannel(),
      consent: ConsentManager(prefs),
    );
    final container = ProviderContainer(
      overrides: [analyticsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    expect(container.read(analyticsServiceProvider), same(service));
    expect(container.read(analyticsServiceProvider), same(service));
  });

  test('初始化 channel 不等待或注册匿名 ID', () async {
    final prefs = await SharedPreferences.getInstance();
    final channel = _RecordingChannel();

    final service = await initAnalyticsService(
      prefs,
      channelFactory: () => channel,
    );

    await service.track('startup_probe', {'source': 'test'});

    expect(channel.events, hasLength(1));
    expect(channel.events.single.name, 'startup_probe');
    expect(channel.events.single.parameters, {'source': 'test'});
    expect(channel.initializeCalls, 1);
    expect(channel.superProperties, isEmpty);
  });

  test('channel 初始化失败时降级为 LogOnly', () async {
    final prefs = await SharedPreferences.getInstance();
    AppLogger.instance.clear();

    final service = await initializeAnalyticsWithFallback(
      prefs,
      channelFactory: _FailingChannel.new,
    );

    await service.track('fallback_probe', {'source': 'test'});

    expect(
      AppLogger.instance.entries.any(
        (entry) =>
            entry.tag == 'Analytics' &&
            entry.message == 'Event: fallback_probe {source=test}',
      ),
      isTrue,
    );
  });

  test('延迟匿名 ID 完成后才注册 super property', () async {
    final prefs = await SharedPreferences.getInstance();
    final channel = _RecordingChannel();
    final service = AnalyticsService(
      channel: channel,
      consent: ConsentManager(prefs),
    );
    final idReady = Completer<String>();
    final registration = idReady.future.then(
      (id) => service.registerSuperProperties({'app_anonymous_id': id}),
    );

    expect(channel.superProperties, isEmpty);
    idReady.complete('anon-123');
    await registration;

    expect(channel.superProperties, {'app_anonymous_id': 'anon-123'});
  });
}

class _RecordingChannel implements AnalyticsChannel {
  var initializeCalls = 0;
  final superProperties = <String, Object>{};
  final events = <({String name, Map<String, Object>? parameters})>[];

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {
    superProperties.addAll(properties);
  }

  @override
  Future<void> setUserId(String? id) async {}

  @override
  Future<void> setUserProperties(Map<String, String?> properties) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}

  @override
  Future<void> unregisterSuperProperty(String name) async {}
}

class _FailingChannel extends _RecordingChannel {
  @override
  Future<void> initialize() => Future<void>.error(StateError('setup failed'));
}
