/// 平台无关的通知权限报告层。
///
/// 提供统一接口查询/请求通知权限、跳转系统设置。
/// 各平台（macOS/iOS/Android/Web）有独立实现，业务层只依赖抽象接口。
///
/// ## 平台差异
///
/// | 平台 | authorized 判定 | denied 判定 | notDetermined |
/// |------|----------------|------------|---------------|
/// | macOS | authorizationStatus authorized **且** delivery setting enabled | auth denied 或 delivery disabled | auth notDetermined |
/// | iOS | FLN isEnabled=true | ph permanentlyDenied/restricted | FLN isEnabled=false 且非 permanentlyDenied |
/// | Android | areNotificationsEnabled=true | ph permanentlyDenied/restricted | 都不是 |
///
/// macOS 的关键修复：`authorizationStatus` 为 authorized 但用户在系统设置关闭
/// "Allow Notifications" 时，`notificationCenterSetting` 为 disabled。
/// 原生 handler 同时检查两者，避免误报"已授权"。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// 通知授权状态（平台无关）。
enum NotificationAuthorization {
  /// 系统已授权，通知可送达
  authorized,

  /// 用户/系统已明确关闭通知
  denied,

  /// 用户尚未做出选择（iOS/Android 首次弹框前）
  notDetermined,

  /// 系统限制（家长控制等），极少见
  restricted,

  /// 当前平台不支持通知
  unsupported,
}

/// 通知权限报告器接口。
///
/// 各平台有独立实现，通过 [notificationPermissionReporterProvider] 获取。
abstract class NotificationPermissionReporter {
  /// 当前平台是否支持通知功能。
  bool get isSupported;

  /// 查询当前通知授权状态。
  Future<NotificationAuthorization> getAuthorizationStatus();

  /// 请求通知权限。返回 true 表示授权成功。
  ///
  /// 调用前应已通过 in-app pre-prompt 取得用户同意。
  Future<bool> requestAuthorization();

  /// 打开系统设置中的通知页面。
  Future<void> openSettings();
}

// ─────────────────────────────────────────────────────────
// macOS Reporter（method channel → native handler）
// ─────────────────────────────────────────────────────────

class MacOSNotificationPermissionReporter
    implements NotificationPermissionReporter {
  static const _channel = MethodChannel(
    'top.echo-loop/notification_permission',
  );

  @override
  bool get isSupported => !kIsWeb && Platform.isMacOS;

  @override
  Future<NotificationAuthorization> getAuthorizationStatus() async {
    if (!isSupported) return NotificationAuthorization.unsupported;
    try {
      final result = await _channel.invokeMethod('getAuthorizationStatus');
      final status = (result as Map)['status'] as String?;
      return _parseStatus(status);
    } on MissingPluginException {
      return NotificationAuthorization.unsupported;
    } catch (_) {
      return NotificationAuthorization.unsupported;
    }
  }

  @override
  Future<bool> requestAuthorization() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod('requestAuthorization');
      return (result as Map)['granted'] == true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('openSettings');
    } on MissingPluginException {
      // noop
    } catch (_) {
      // noop
    }
  }
}

// ─────────────────────────────────────────────────────────
// iOS Reporter（Method Channel → native UNAuthorizationStatus）
// ─────────────────────────────────────────────────────────

class IOSNotificationPermissionReporter
    implements NotificationPermissionReporter {
  static const _channel = MethodChannel(
    'top.echo-loop/notification_permission',
  );

  @override
  bool get isSupported => !kIsWeb && Platform.isIOS;

  @override
  Future<NotificationAuthorization> getAuthorizationStatus() async {
    if (!isSupported) return NotificationAuthorization.unsupported;
    try {
      final result = await _channel.invokeMethod('getAuthorizationStatus');
      final status = (result as Map)['status'] as String?;
      return _parseStatus(status);
    } on MissingPluginException {
      return NotificationAuthorization.unsupported;
    } catch (_) {
      return NotificationAuthorization.unsupported;
    }
  }

  @override
  Future<bool> requestAuthorization() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod('requestAuthorization');
      return (result as Map)['granted'] == true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('openSettings');
    } on MissingPluginException {
      // noop
    } catch (_) {
      // noop
    }
  }
}

// ─────────────────────────────────────────────────────────
// Android Reporter（FLN only，不含 SP）
// ─────────────────────────────────────────────────────────
//
// Android 系统 API 只返回 bool，无 notDetermined 概念。
// 设置页直接映射：true→authorized, false→denied。
// Pre-prompt 弹窗决策由上层读 SP，不走 reporter。

class AndroidNotificationPermissionReporter
    implements NotificationPermissionReporter {
  AndroidNotificationPermissionReporter(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  @override
  Future<NotificationAuthorization> getAuthorizationStatus() async {
    if (!isSupported) return NotificationAuthorization.unsupported;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final enabled = await android?.areNotificationsEnabled();
      if (enabled == null) return NotificationAuthorization.unsupported;
      return enabled
          ? NotificationAuthorization.authorized
          : NotificationAuthorization.denied;
    } catch (_) {
      return NotificationAuthorization.unsupported;
    }
  }

  @override
  Future<bool> requestAuthorization() async {
    if (!isSupported) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openSettings() async {
    await ph.openAppSettings();
  }
}

// ─────────────────────────────────────────────────────────
// 不支持平台 Reporter（Web / Linux / Windows）
// ─────────────────────────────────────────────────────────

class UnsupportedNotificationPermissionReporter
    implements NotificationPermissionReporter {
  const UnsupportedNotificationPermissionReporter();

  @override
  bool get isSupported => false;

  @override
  Future<NotificationAuthorization> getAuthorizationStatus() async =>
      NotificationAuthorization.unsupported;

  @override
  Future<bool> requestAuthorization() async => false;

  @override
  Future<void> openSettings() async {}
}

// ─────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────

NotificationAuthorization _parseStatus(String? status) {
  switch (status) {
    case 'authorized':
      return NotificationAuthorization.authorized;
    case 'denied':
      return NotificationAuthorization.denied;
    case 'notDetermined':
      return NotificationAuthorization.notDetermined;
    case 'restricted':
      return NotificationAuthorization.restricted;
    default:
      return NotificationAuthorization.unsupported;
  }
}
