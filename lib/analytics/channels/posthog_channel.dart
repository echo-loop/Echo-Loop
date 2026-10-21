/// PostHog 上报通道
///
/// 直接通过 HTTP 上报，不依赖 GMS，中国大陆和境外均可使用。
///
/// **初始化路径**：
/// - iOS：在 `AppDelegate.application(_:didFinishLaunchingWithOptions:)` 中由 Swift 侧
///   `setupPostHogNative()` 完成 SDK setup（含 sessionReplay=true）。Info.plist 设置
///   `com.posthog.posthog.AUTO_INIT=false` 关闭插件自动 init，避免插件先用默认配置
///   抢跑（PostHog iOS SDK 二次 setup 是 no-op，会让 sessionReplay 失效）。
/// - macOS：通过 Info.plist `com.posthog.posthog.API_KEY` 等 meta-data 由插件
///   `register(with:)` 阶段自动初始化。macOS 不支持 Session Replay。
/// - Android：原生侧不预初始化，此处 `Posthog().setup(config)` 是首次也是唯一一次 init。
///
/// 因此本类 `initialize()` 中的 `setup(config)` 在 iOS 上是 no-op（SDK 已就绪），
/// 但保留以兼容 Android 路径。
library;

import 'package:posthog_flutter/posthog_flutter.dart';

import '../analytics_channel.dart';
import '../posthog_event_policy.dart';

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
  Future<void> initialize() async {
    final config = PostHogConfig(_apiKey)
      ..host = _host
      ..flushAt = 5
      ..flushInterval = const Duration(seconds: 3)
      // 保留 SDK 的 Application Opened；该配置同时会产生 Backgrounded，SDK
      // 5.23.1 没有提供按生命周期事件分别开关，Backgrounded 需在 PostHog 端过滤。
      ..captureApplicationLifecycleEvents = true
      ..personProfiles = PostHogPersonProfiles.always
      ..sessionReplay = true
      ..sessionReplayConfig.maskAllTexts = false
      ..sessionReplayConfig.maskAllImages = false
      ..debug = true;
    await Posthog().setup(config);
  }

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    if (!PostHogEventPolicy.shouldCapture(name)) return;
    await Posthog().capture(eventName: name, properties: parameters);
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

  @override
  Future<void> setUserProperties(Map<String, String?> properties) {
    return Posthog().setPersonProperties(
      userPropertiesToSet: properties.map(
        (key, value) => MapEntry(key, value ?? ''),
      ),
    );
  }

  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {
    // PostHog SDK 5.x 的 register 一次只接受一个 key/value，循环写入即可。
    for (final entry in properties.entries) {
      await Posthog().register(entry.key, entry.value);
    }
  }

  @override
  Future<void> unregisterSuperProperty(String name) {
    return Posthog().unregister(name);
  }
}
