/// 分析系统 Riverpod Provider 注册
///
/// 参考 [appDatabaseProvider] 的模式：在 `main()` 中提前初始化，
/// Provider 同步暴露。业务代码通过 `ref.read(analyticsServiceProvider)`
/// 获取 [AnalyticsService] 实例。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'analytics_channel.dart';
import 'analytics_service.dart';
import 'channels/log_only_channel.dart';
import 'consent_manager.dart';
import 'geo_interceptor.dart';

import 'package:firebase_analytics/firebase_analytics.dart';

import 'channels/firebase_channel.dart';
import 'channels/umeng_channel.dart';

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
/// 1. 获取地区（缓存 → geo API → locale fallback）
/// 2. 选择通道并初始化
///
/// 首次启动无缓存时调 geo API（2 秒超时），失败则 locale fallback。
Future<AnalyticsService> initAnalyticsService(
  SharedPreferences prefs, {
  required String userId,
}) async {
  final consent = ConsentManager(prefs);

  // 获取地区并选择通道
  final isChina = await _resolveIsMainlandChina(prefs);
  final channel = _createChannel(isChina);

  // 初始化通道 + 设置用户 ID
  await channel.initialize();
  await channel.setUserId(userId);

  // 非 Debug 模式下，根据通道选择控制 Firebase 采集开关
  // 选择友盟时关闭 Firebase 采集，避免 SDK 残留行为产生噪音
  if (!kDebugMode && !Platform.isMacOS) {
    await FirebaseAnalytics.instance
        .setAnalyticsCollectionEnabled(channel is FirebaseChannel);
  }

  return AnalyticsService(channel: channel, consent: consent);
}

/// 获取地区：缓存优先 → geo API → locale fallback
///
/// API 成功的结果会持久化；locale fallback 不持久化，
/// 下次启动会重新尝试 API。
Future<bool> _resolveIsMainlandChina(SharedPreferences prefs) async {
  // 1. 有缓存直接用
  final cached = prefs.getString(geoCountryKey);
  if (cached != null) return cached == 'CN';

  // 2. 无缓存：调 geo API
  try {
    final response = await Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
    )).get('$apiBaseUrl/api/v1/user/geo');
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

/// 根据地区选择分析通道
AnalyticsChannel _createChannel(bool isChina) {
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
