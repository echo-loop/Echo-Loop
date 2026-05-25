/// 中国大陆移动端上报通道（友盟）
///
/// 封装 `umeng_common_sdk` 包。仅在 iOS/Android + 中国大陆时使用，
/// macOS 始终走 [FirebaseChannel]（友盟不支持 macOS）。
///
/// 友盟 App Key 通过 [initialize] 传入，需在友盟后台注册获取。
library;

import 'package:umeng_common_sdk/umeng_common_sdk.dart';

import '../analytics_channel.dart';

/// 友盟 Analytics 上报通道
class UmengChannel implements AnalyticsChannel {
  /// 友盟 iOS App Key（在友盟后台获取）
  static const _iosAppKey = ''; // TODO: 填入友盟 iOS App Key

  /// 友盟 Android App Key
  static const _androidAppKey = ''; // TODO: 填入友盟 Android App Key

  /// Key 是否已配置（未配置时 initialize 会抛异常，由上层 fallback）
  static bool get isConfigured =>
      _iosAppKey.isNotEmpty || _androidAppKey.isNotEmpty;

  /// 渠道标识
  static const _channel = 'flutter';

  @override
  String get name => 'Umeng';

  @override
  Future<void> initialize() async {
    await UmengCommonSdk.initCommon(_androidAppKey, _iosAppKey, _channel);
    // 手动页面采集模式，由 AnalyticsService 控制 screen_view 事件
    UmengCommonSdk.setPageCollectionModeManual();
  }

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    // 友盟 onEvent 要求 Map<String, dynamic>
    UmengCommonSdk.onEvent(
      name,
      parameters?.map((k, v) => MapEntry(k, v)) ?? {},
    );
  }

  @override
  Future<void> setUserId(String? id) async {
    if (id != null) {
      UmengCommonSdk.onProfileSignIn(id);
    } else {
      UmengCommonSdk.onProfileSignOff();
    }
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    // 友盟无独立的 user property API，通过自定义事件模拟
    if (value != null) {
      UmengCommonSdk.onEvent('user_property_set', {
        'property_name': name,
        'property_value': value,
      });
    }
  }

  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {
    // 友盟没有 super properties 概念；no-op。
    // 国内分群仍由 [setUserProperty] 转发的 user_property_set 事件兜底。
  }
}
