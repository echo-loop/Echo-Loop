import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/analytics/analytics_observer.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/analytics_channel.dart';
import 'package:echo_loop/analytics/consent_manager.dart';
import 'package:echo_loop/analytics/models/event_names.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记录所有事件的测试通道
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

void main() {
  late _RecordingChannel channel;
  late AnalyticsService service;
  late AnalyticsObserver observer;

  setUp(() async {
    AppLogger.instance.clear();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    channel = _RecordingChannel();
    service = AnalyticsService(
      channel: channel,
      consent: ConsentManager(prefs),
    );
    observer = AnalyticsObserver(service);
  });

  group('AnalyticsObserver', () {
    test('didPush 上报 screen_view 事件', () {
      final route = MaterialPageRoute(
        settings: const RouteSettings(name: '/study'),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(route, null);

      expect(channel.events, hasLength(1));
      expect(channel.events.first.name, Events.screenView);
      expect(channel.events.first.params?[EventParams.screenName], 'study');
    });

    test('didPush 记录 previousScreen', () {
      final route1 = MaterialPageRoute(
        settings: const RouteSettings(name: '/study'),
        builder: (_) => const SizedBox(),
      );
      final route2 = MaterialPageRoute(
        settings: const RouteSettings(name: '/favorites'),
        builder: (_) => const SizedBox(),
      );

      observer.didPush(route1, null);
      observer.didPush(route2, route1);

      expect(channel.events, hasLength(2));
      expect(channel.events[1].params?[EventParams.previousScreen], 'study');
    });

    test('didPop 上报回退目标页面的 screen_view', () {
      final route1 = MaterialPageRoute(
        settings: const RouteSettings(name: '/study'),
        builder: (_) => const SizedBox(),
      );
      final route2 = MaterialPageRoute(
        settings: const RouteSettings(name: '/favorites'),
        builder: (_) => const SizedBox(),
      );

      observer.didPush(route1, null);
      observer.didPush(route2, route1);
      channel.events.clear();

      observer.didPop(route2, route1);

      expect(channel.events, hasLength(1));
      expect(channel.events.first.params?[EventParams.screenName], 'study');
    });

    test('didPush/didPop 打印 Navigator 动作诊断日志', () {
      final route1 = MaterialPageRoute(
        settings: const RouteSettings(name: '/study'),
        builder: (_) => const SizedBox(),
      );
      final route2 = MaterialPageRoute(
        settings: const RouteSettings(name: '/favorites'),
        builder: (_) => const SizedBox(),
      );

      observer.didPush(route1, null);
      observer.didPush(route2, route1);
      observer.didPop(route2, route1);

      final lines = AppLogger.instance.entries.map((e) => e.toString());
      expect(
        lines,
        contains(contains('[Navigation] didPush route=/study previous=(null)')),
      );
      expect(
        lines,
        contains(
          contains('[Navigation] didPop route=/favorites previous=/study'),
        ),
      );
    });

    test('忽略 root 路由 /', () {
      final route = MaterialPageRoute(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(route, null);

      expect(channel.events, isEmpty);
    });

    test('从深层路径提取最后一个非参数段', () {
      final route = MaterialPageRoute(
        settings: const RouteSettings(
          name:
              '/collections/550e8400-e29b-41d4-a716-446655440000/blind-listen',
        ),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(route, null);

      expect(
        channel.events.first.params?[EventParams.screenName],
        'blind-listen',
      );
    });

    test('纯数字路径段被视为参数', () {
      final route = MaterialPageRoute(
        settings: const RouteSettings(name: '/items/12345/detail'),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(route, null);

      expect(channel.events.first.params?[EventParams.screenName], 'detail');
    });

    test('GoRouter 模板参数 :collectionId 被过滤', () {
      final route = MaterialPageRoute(
        settings: const RouteSettings(name: '/collections/:collectionId'),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(route, null);

      expect(
        channel.events.first.params?[EventParams.screenName],
        'collections',
      );
    });

    test('纯参数路由名（如 :collectionId）被忽略', () {
      final route = MaterialPageRoute(
        settings: const RouteSettings(name: ':collectionId'),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(route, null);

      expect(channel.events, isEmpty);
    });

    test('GoRouter 模板参数 + 静态段混合路径', () {
      final route = MaterialPageRoute(
        settings: const RouteSettings(
          name: '/collections/:collectionId/:audioId/plan',
        ),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(route, null);

      expect(channel.events.first.params?[EventParams.screenName], 'plan');
    });
  });
}
