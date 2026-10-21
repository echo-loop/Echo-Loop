/// 全球/默认上报通道（Firebase Analytics）
///
/// 封装 `firebase_analytics` 包。Firebase 在 `main()` 中通过
/// `Firebase.initializeApp()` 初始化，此 Channel 只负责启用采集和转发事件。
///
/// 中国大陆移动端使用 [UmengChannel]，此时 Firebase 采集会被
/// `setAnalyticsCollectionEnabled(false)` 关闭。
library;

import 'package:firebase_analytics/firebase_analytics.dart';

import '../analytics_channel.dart';

/// Firebase Analytics 上报通道
class FirebaseChannel implements AnalyticsChannel {
  late final FirebaseAnalytics _analytics;

  @override
  Future<void> initialize() async {
    _analytics = FirebaseAnalytics.instance;
    await _analytics.setAnalyticsCollectionEnabled(true);
  }

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> setUserId(String? id) {
    return _analytics.setUserId(id: id);
  }

  @override
  Future<void> setUserProperty(String name, String? value) {
    return _analytics.setUserProperty(name: name, value: value);
  }

  @override
  Future<void> setUserProperties(Map<String, String?> properties) async {
    for (final entry in properties.entries) {
      await setUserProperty(entry.key, entry.value);
    }
  }

  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {
    // Firebase Analytics 没有 super properties 概念；no-op。
    // 调用方需要事件级冻结属性时应在 PostHog 通道生效，Firebase 通道下相关
    // 维度只能落到 user property（[setUserProperty]）。
  }

  @override
  Future<void> unregisterSuperProperty(String name) async {
    // Firebase Analytics 没有 super properties 概念；no-op。
  }
}
