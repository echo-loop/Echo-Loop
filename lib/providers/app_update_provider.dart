/// App 版本更新状态管理
///
/// 使用 Riverpod 管理版本更新检查流程：
/// - 冷启动 / 回到前台时后台静默检查（无时间节流）
/// - 支持手动检查（绕过忽略逻辑，带 Checking UI 态）
/// - 用户忽略后记录版本号，同版本不再自动弹窗
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update_info.dart';
import '../services/app_logger.dart';
import '../services/app_update_checker.dart';
import '../utils/version_compare.dart';
import 'package_info_provider.dart';

part 'app_update_provider.g.dart';

/// 日志 tag
const _logTag = 'AppUpdate';

/// SharedPreferences key: 用户已忽略的版本号
const _keyDismissedVersion = 'app_update_dismissed_version';

/// App 版本更新 Provider
@Riverpod(keepAlive: true)
class AppUpdate extends _$AppUpdate {
  AppUpdateChecker? _checker;

  /// 后台检查是否正在进行，避免并发重复请求
  bool _backgroundChecking = false;

  @override
  AppUpdateState build() {
    // bundleId 仅 iOS 路径使用（Lookup API），其他平台忽略
    final bundleId = ref.read(packageInfoProvider).packageName;
    _checker = AppUpdateChecker(bundleId: bundleId);
    ref.onDispose(() => _checker?.dispose());
    // build() 返回前 state 未初始化，checkInBackground 第一行就读 state 会抛
    // "Tried to read the state of an uninitialized provider"。延迟到下一个 microtask 执行。
    Future<void>.microtask(checkInBackground);
    return const AppUpdateInitial();
  }

  /// 后台静默检查
  ///
  /// 冷启动、回到前台都调用。不触发 [AppUpdateChecking] 过渡态，
  /// 避免设置页 spinner 闪烁；所有异常静默回退为 [AppUpdateResult.none]。
  /// 手动检查进行中时让位，结果不覆盖手动检查的 state。
  Future<void> checkInBackground() async {
    if (_backgroundChecking) {
      AppLogger.log(_logTag, 'checkInBackground skipped: already running');
      return;
    }
    if (state is AppUpdateChecking) {
      AppLogger.log(
        _logTag,
        'checkInBackground skipped: manual check in flight',
      );
      return;
    }
    _backgroundChecking = true;
    AppLogger.log(_logTag, 'checkInBackground start');
    try {
      final prefs = await SharedPreferences.getInstance();
      final info = await _checker?.check();
      if (state is AppUpdateChecking) {
        AppLogger.log(
          _logTag,
          'checkInBackground yield: manual check took over',
        );
        return;
      }
      final result = _buildResult(info: info, isManual: false, prefs: prefs);
      state = result;
      AppLogger.log(
        _logTag,
        'checkInBackground done: remote=${info?.latestVersion ?? "null"} '
        'type=${result.type.name}',
      );
    } catch (e) {
      if (state is AppUpdateChecking) return;
      state = const AppUpdateResult(type: AppUpdateType.none);
      AppLogger.log(_logTag, 'checkInBackground error: $e');
    } finally {
      _backgroundChecking = false;
    }
  }

  /// 手动检查（绕过忽略逻辑）
  ///
  /// 返回检查结果，不更新 provider state，
  /// 避免 MainShell listener 重复弹窗。
  Future<AppUpdateResult> manualCheck() async {
    AppLogger.log(_logTag, 'manualCheck start');
    state = const AppUpdateChecking();

    final info = await _checker?.check();
    final result = _buildResult(info: info, isManual: true);
    AppLogger.log(
      _logTag,
      'manualCheck done: remote=${info?.latestVersion ?? "null"} '
      'type=${result.type.name}',
    );

    // 手动检查结束后恢复为初始状态，不触发 MainShell listener
    state = const AppUpdateInitial();
    return result;
  }

  /// 根据远程信息构建检查结果
  AppUpdateResult _buildResult({
    required AppUpdateInfo? info,
    required bool isManual,
    SharedPreferences? prefs,
  }) {
    if (info == null) {
      return const AppUpdateResult(type: AppUpdateType.none);
    }

    final packageInfo = ref.read(packageInfoProvider);
    // 仅用 versionName 做版本比较；buildNumber 是平台内部升降级机制，
    // 不参与业务版本判断（同一 versionName 唯一对应一次正式发布）。
    final localVersion = packageInfo.version;
    final updateType = determineUpdateType(localVersion, info);

    // 非手动检查时，检查是否已忽略此版本
    if (!isManual && updateType == AppUpdateType.softUpdate && prefs != null) {
      final dismissed = prefs.getString(_keyDismissedVersion);
      if (dismissed == info.latestVersion) {
        AppLogger.log(
          _logTag,
          'suppress dialog: version ${info.latestVersion} dismissed earlier',
        );
        return const AppUpdateResult(type: AppUpdateType.none);
      }
    }

    return AppUpdateResult(type: updateType, info: info);
  }

  /// 用户点击"稍后提醒"，记录忽略版本
  Future<void> dismiss() async {
    final current = state;
    if (current is AppUpdateResult && current.info != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDismissedVersion, current.info!.latestVersion);
      AppLogger.log(_logTag, 'dismiss version ${current.info!.latestVersion}');
    }
    state = const AppUpdateDismissed();
  }

  /// 判断更新类型（static 公开方法，方便测试）
  static AppUpdateType determineUpdateType(
    String localVersion,
    AppUpdateInfo info,
  ) {
    if (compareVersions(localVersion, info.minimumVersion) < 0) {
      return AppUpdateType.forceUpdate;
    }
    if (compareVersions(localVersion, info.latestVersion) < 0) {
      return AppUpdateType.softUpdate;
    }
    return AppUpdateType.none;
  }

  /// 获取当前平台的下载链接
  static String? getDownloadUrl(AppUpdateInfo info) {
    if (kIsWeb) return info.downloadUrl['fallback'];
    final platformKey = _platformKey();
    return info.downloadUrl[platformKey] ?? info.downloadUrl['fallback'];
  }

  static String _platformKey() {
    if (kIsWeb) return 'fallback';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) return 'android';
    return 'fallback';
  }
}
