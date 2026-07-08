/// App 版本更新检查服务
///
/// iOS 通过 App Store Lookup API（`itunes.apple.com/lookup`）查询当前
/// App Store 实际可下载的版本，确保审核期间不会误提示 iOS 用户更新。
/// 其他平台从远程静态 JSON（`version.json`）获取版本信息。
/// 使用独立 Dio 实例（不复用 AI API 的 Dio），失败时返回 null 并写日志。
library;

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../config/api_config.dart';
import '../config/app_store_config.dart';
import '../models/app_update_info.dart';
import '../utils/version_compare.dart';
import 'android_update_bridge.dart';
import 'app_logger.dart';

/// App Store Lookup API endpoint。
const _iosLookupBase = 'https://itunes.apple.com/lookup';

/// 日志 tag
const _logTag = 'AppUpdateChecker';

/// App 版本更新检查器
///
/// 版本检查 URL 基于 [apiBaseUrl]（通过 `--dart-define=API_BASE_URL` 配置），
/// 本地开发时访问 `http://localhost:3000/version.json`，
/// 生产环境访问 `https://www.echo-loop.top/version.json`。
///
/// iOS 单独走 App Store Lookup API，[bundleId] 必填。
class AppUpdateChecker {
  final Dio _dio;
  final String _url;
  final String? _bundleId;
  final AppUpdateRuntimePlatform _platform;
  final AndroidUpdateBridge _androidBridge;

  /// 使用默认配置创建检查器
  ///
  /// [bundleId] 用于 iOS App Store Lookup（其他平台忽略此参数）。
  AppUpdateChecker({String? bundleId})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
      _url = '$apiBaseUrl/version.json',
      _bundleId = bundleId,
      _platform = _currentPlatform(),
      _androidBridge = const MethodChannelAndroidUpdateBridge();

  /// 用于测试的构造函数，允许注入 Dio 实例和配置
  ///
  /// [useIosLookup] 强制走 iOS Lookup 路径（host 测试机 Platform.isIOS=false，
  /// 测试时需显式开启）。
  AppUpdateChecker.withDio(
    this._dio, {
    String url = '',
    String? bundleId,
    bool useIosLookup = false,
    AppUpdateRuntimePlatform? platform,
    AndroidUpdateBridge androidBridge =
        const MethodChannelAndroidUpdateBridge(),
  }) : _url = url,
       _bundleId = bundleId,
       _platform =
           platform ??
           (useIosLookup
               ? AppUpdateRuntimePlatform.ios
               : AppUpdateRuntimePlatform.other),
       _androidBridge = androidBridge;

  /// 检查远程版本信息
  ///
  /// iOS：查 App Store Lookup API（返回 App Store 实际可下载版本）。
  /// 其他平台：拉取远程 version.json。
  /// 失败时返回 null（网络错误、JSON 解析失败等均静默处理）。
  /// [country] 指定 App Store 区域（如 `cn` / `us`），决定 Lookup API 返回
  /// 哪个区域的 releaseNotes 本地化文案。仅 iOS 路径使用，为 null 时不传。
  Future<AppUpdateInfo?> check({String? country}) async {
    if (_platform == AppUpdateRuntimePlatform.ios) {
      return _checkIos(country: country);
    }
    if (_platform == AppUpdateRuntimePlatform.android) {
      return _checkAndroid();
    }
    return _checkVersionJson();
  }

  /// iOS：App Store Lookup 提供真实可下载版本，version.json 提供最低可用版本。
  Future<AppUpdateInfo?> _checkIos({String? country}) async {
    final lookup = await _checkIosLookup(country: country);
    if (lookup == null) return null;

    final manifest = await _checkVersionJson();
    // 只认 platforms.ios.minimumVersion；顶层 minimumVersion 仅供旧版本 App 兼容，
    // 新版本一律忽略，避免为旧版而设的顶层 min 误触发 iOS 强制更新。
    final configuredMinimum = manifest?.platforms.ios.minimumVersion;
    final effectiveMinimum =
        configuredMinimum == null ||
            compareVersions(configuredMinimum, lookup.latestVersion) > 0
        ? '0.0.0'
        : configuredMinimum;

    return AppUpdateInfo(
      latestVersion: lookup.latestVersion,
      minimumVersion: effectiveMinimum,
      releaseNotes: lookup.releaseNotes.isNotEmpty
          ? lookup.releaseNotes
          : manifest?.releaseNotes ?? const {},
      downloadUrl: lookup.downloadUrl,
      platforms: manifest?.platforms ?? const AppUpdatePlatforms(),
      channel: AppUpdateChannel.iosAppStore,
    );
  }

  /// Android：按安装来源选择 Google Play 或 APK 渠道。
  Future<AppUpdateInfo?> _checkAndroid() async {
    final manifest = await _checkVersionJson();
    if (manifest == null) return null;

    final installer = await _androidBridge.installerPackageName();
    AppLogger.log(_logTag, 'android installer=${installer ?? "(null)"}');

    if (installer == 'com.android.vending') {
      return AppUpdateInfo(
        latestVersion: manifest.latestVersion,
        // 只认渠道级 minimumVersion；顶层仅供旧版本 App 兼容，新版本忽略。
        minimumVersion:
            manifest.platforms.android.googlePlay.minimumVersion ?? '0.0.0',
        releaseNotes: manifest.releaseNotes,
        downloadUrl: _googlePlayDownloadUrl(manifest),
        platforms: manifest.platforms,
        channel: AppUpdateChannel.androidGooglePlay,
      );
    }

    final latest =
        manifest.platforms.android.apk.latestVersion ?? manifest.latestVersion;
    // 只认渠道级 minimumVersion；顶层仅供旧版本 App 兼容，新版本忽略。
    final minimum = manifest.platforms.android.apk.minimumVersion ?? '0.0.0';
    final apkUrl = _apkDownloadUrl(manifest);
    return AppUpdateInfo(
      latestVersion: latest,
      minimumVersion: minimum,
      releaseNotes: manifest.releaseNotes,
      downloadUrl: {
        ...manifest.downloadUrl,
        if (apkUrl != null) 'android': apkUrl,
        if (apkUrl != null) 'androidApk': apkUrl,
      },
      platforms: manifest.platforms,
      channel: AppUpdateChannel.androidApk,
    );
  }

  /// iOS：从 App Store Lookup API 解析版本信息
  ///
  /// Lookup API 返回的 `version` 字段总是 App Store 当前可下载的版本，
  /// 不会包含审核中的 build，因此天然解决"提示有但下载不到"的问题。
  /// Lookup API 不提供 minimumVersion，回退为 `0.0.0`（不触发强制更新）。
  Future<AppUpdateInfo?> _checkIosLookup({String? country}) async {
    final bundleId = _bundleId;
    if (bundleId == null || bundleId.isEmpty) {
      AppLogger.log(_logTag, 'iOS lookup skipped: empty bundleId');
      return null;
    }
    AppLogger.log(
      _logTag,
      'iOS lookup start: bundleId=$bundleId country=${country ?? "(default)"}',
    );
    try {
      // iTunes Lookup 返回 Content-Type: text/javascript，Dio 默认 JSON
      // transformer 不识别该 MIME，会把 body 当作 String 透传。这里强制
      // ResponseType.plain 后用 jsonDecode 自行解析，避免 String 被错误地
      // 当成 Map 触发类型转换异常 → 静默 catch → "检查失败"。
      final response = await _dio.get<String>(
        _iosLookupBase,
        queryParameters: {
          'bundleId': bundleId,
          if (country != null && country.isNotEmpty) 'country': country,
        },
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      // 打印实际访问的 Lookup URL（含 country 查询参数）、HTTP 状态码与
      // body 字节数，便于排查「查错区 / 返回空 / 被限流」等问题。
      final bodyBytes = body == null ? 0 : utf8.encode(body).length;
      AppLogger.log(
        _logTag,
        'iOS lookup response: url=${response.realUri} '
        'status=${response.statusCode} bodyBytes=$bodyBytes',
      );
      if (body == null || body.isEmpty) {
        AppLogger.log(_logTag, 'iOS lookup empty body');
        return null;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        AppLogger.log(
          _logTag,
          'iOS lookup unexpected top-level: ${decoded.runtimeType}',
        );
        return null;
      }
      final results = decoded['results'];
      if (results is! List || results.isEmpty) {
        AppLogger.log(_logTag, 'iOS lookup empty results');
        return null;
      }
      final entry = results.first;
      if (entry is! Map) {
        AppLogger.log(
          _logTag,
          'iOS lookup unexpected entry: ${entry.runtimeType}',
        );
        return null;
      }
      final version = entry['version'];
      if (version is! String || version.isEmpty) {
        AppLogger.log(_logTag, 'iOS lookup missing/invalid version');
        return null;
      }
      final trackUrl = entry['trackViewUrl'];
      final releaseNotes = entry['releaseNotes'];
      final downloadUrl = trackUrl is String && trackUrl.isNotEmpty
          ? trackUrl
          : appStoreProductUri.toString();
      final notes = releaseNotes is String && releaseNotes.isNotEmpty
          ? {'en': releaseNotes, 'zh': releaseNotes}
          : <String, String>{};
      AppLogger.log(_logTag, 'iOS lookup done: version=$version');
      return AppUpdateInfo(
        latestVersion: version,
        minimumVersion: '0.0.0',
        releaseNotes: notes,
        downloadUrl: {'ios': downloadUrl, 'fallback': downloadUrl},
        channel: AppUpdateChannel.iosAppStore,
      );
    } catch (e) {
      AppLogger.log(_logTag, 'iOS lookup failed: $e');
      return null;
    }
  }

  /// 非 iOS 平台：拉取远程 version.json
  Future<AppUpdateInfo?> _checkVersionJson() async {
    AppLogger.log(_logTag, 'version.json start: url=$_url');
    try {
      final response = await _dio.get<Map<String, dynamic>>(_url);
      final data = response.data;
      if (data == null) {
        AppLogger.log(_logTag, 'version.json empty body');
        return null;
      }
      final info = AppUpdateInfo.fromJson(data);
      AppLogger.log(
        _logTag,
        'version.json done: latest=${info.latestVersion} min=${info.minimumVersion}',
      );
      return info;
    } catch (e) {
      AppLogger.log(_logTag, 'version.json failed: $e');
      return null;
    }
  }

  /// 释放资源
  void dispose() => _dio.close();

  Map<String, String> _googlePlayDownloadUrl(AppUpdateInfo manifest) {
    const packageName = 'app.echoloop';
    final storeUrl =
        manifest.platforms.android.googlePlay.storeUrl ??
        'market://details?id=$packageName';
    final fallbackUrl =
        manifest.platforms.android.googlePlay.fallbackUrl ??
        'https://play.google.com/store/apps/details?id=$packageName';
    return {
      ...manifest.downloadUrl,
      'android': storeUrl,
      'fallback': fallbackUrl,
    };
  }

  String? _apkDownloadUrl(AppUpdateInfo manifest) {
    return manifest.platforms.android.apk.downloadUrl ??
        manifest.downloadUrl['androidApk'] ??
        manifest.downloadUrl['android'];
  }
}

/// 运行平台，用于测试注入。
enum AppUpdateRuntimePlatform { ios, android, other }

AppUpdateRuntimePlatform _currentPlatform() {
  if (kIsWeb) return AppUpdateRuntimePlatform.other;
  if (Platform.isIOS) return AppUpdateRuntimePlatform.ios;
  if (Platform.isAndroid) return AppUpdateRuntimePlatform.android;
  return AppUpdateRuntimePlatform.other;
}
