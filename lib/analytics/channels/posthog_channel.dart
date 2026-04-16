/// PostHog 上报通道
///
/// 直接通过 HTTP 上报，不依赖 GMS，中国大陆和境外均可使用。
/// API Key 和 Host 通过 dart-define 注入：
///   --dart-define="POSTHOG_API_KEY=phc_xxx"
///   --dart-define="POSTHOG_HOST=https://your-posthog-host"
library;

import 'package:posthog_flutter/posthog_flutter.dart';

import '../analytics_channel.dart';

/// PostHog 分析上报通道
class PostHogChannel implements AnalyticsChannel {
  static const _apiKey = String.fromEnvironment(
    'POSTHOG_API_KEY',
    defaultValue: 'phc_s2ZWTJV3n57Tcz16OYZailIJroIUJhWEXmHMothJ5MZ',
  );
  static const _host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  /// 始终已配置（内置默认 API Key）
  static bool get isConfigured => true;

  @override
  String get name => 'PostHog';

  @override
  Future<void> initialize() async {
    final config = PostHogConfig(_apiKey)..host = _host;
    await Posthog().setup(config);
  }

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) {
    return Posthog().capture(eventName: name, properties: parameters);
  }

  @override
  Future<void> setUserId(String? id) {
    if (id == null) return Posthog().reset();
    return Posthog().identify(userId: id);
  }

  @override
  Future<void> setUserProperty(String name, String? value) {
    return Posthog().setPersonProperties(
      userPropertiesToSet: {name: value ?? ''},
    );
  }
}
