/// 分析系统 Riverpod Provider 注册
///
/// 参考 [appDatabaseProvider] 的模式：在 `main()` 中提前初始化，
/// Provider 同步暴露。业务代码通过 `ref.read(analyticsServiceProvider)`
/// 获取 [AnalyticsService] 实例。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'analytics_channel.dart';
import 'analytics_service.dart';
import 'channels/firebase_channel.dart';
import 'channels/log_only_channel.dart';
import 'channels/posthog_channel.dart';
import 'channels/umeng_channel.dart';
import 'consent_manager.dart';
import 'geo_interceptor.dart';

/// 分析服务单例（在 main() 中通过 [initAnalyticsService] 初始化）
late AnalyticsService _analyticsService;

/// 初始化分析服务（在 main() 中 runApp 之前调用）
void initAnalytics(AnalyticsService service) {
  _analyticsService = service;
}

/// 分析服务 Provider（同步，与 appDatabaseProvider 模式一致）
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return _analyticsService;
});

/// 初始化分析服务
///
/// [userId] 由 [initUserIdService] 提前生成，analytics 不负责 ID 管理。
///
/// 通道选择策略：
/// - Debug 模式 → LogOnly
/// - Release 模式 → PostHog（全平台，不依赖 GMS，中国大陆可用）
/// - PostHog 未配置时 → LogOnly（需传入 POSTHOG_API_KEY dart-define）
///
/// Firebase/友盟通道保留备用，当前不启用。
Future<AnalyticsService> initAnalyticsService(
  SharedPreferences prefs, {
  required String userId,
}) async {
  final consent = ConsentManager(prefs);
  final channel = _createChannel();

  // 初始化通道 + 设置用户 ID
  await channel.initialize();
  await channel.setUserId(userId);

  // 关闭 Firebase 采集（当前使用 PostHog，避免 Firebase SDK 残留上报）
  if (!kDebugMode && !Platform.isMacOS) {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
  }

  return AnalyticsService(channel: channel, consent: consent);
}

/// 获取地区：缓存优先 → geo API → locale fallback
///
/// 当前仅供 GeoInterceptor 更新缓存使用，不再用于通道选择。
/// API 成功的结果会持久化；locale fallback 不持久化。
Future<bool> resolveIsMainlandChina(SharedPreferences prefs) async {
  // 1. 有缓存直接用
  final cached = prefs.getString(geoCountryKey);
  if (cached != null) return cached == 'CN';

  // 2. 无缓存：调 geo API
  try {
    final response = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ),
    ).get('$apiBaseUrl/api/v1/user/geo');
    final data = response.data;
    final country = data is Map ? data['country'] as String? : null;
    if (country != null && country.isNotEmpty) {
      await prefs.setString(geoCountryKey, country);
      return country == 'CN';
    }
  } catch (_) {
    // API 不可用，继续 fallback
  }

  // 3. API 失败：locale fallback（不持久化）
  return Platform.localeName.contains('CN');
}

/// 根据配置选择分析通道
///
/// 当前策略：PostHog 全平台统一上报。
/// 如需切回 Firebase/友盟，修改此函数即可。
AnalyticsChannel _createChannel() {
  if (kDebugMode) return LogOnlyChannel();
  if (PostHogChannel.isConfigured) return PostHogChannel();
  // PostHog 未配置（缺少 POSTHOG_API_KEY dart-define）时降级到日志
  return LogOnlyChannel();
}

// 以下通道备用，当前未启用
// ignore: unused_element
AnalyticsChannel _createChannelLegacy(bool isChina) {
  if (kDebugMode) return LogOnlyChannel();
  if (Platform.isAndroid) {
    if (isChina && UmengChannel.isConfigured) return UmengChannel();
    return FirebaseChannel();
  }
  if (!Platform.isMacOS && isChina && UmengChannel.isConfigured) {
    return UmengChannel();
  }
  return FirebaseChannel();
}
