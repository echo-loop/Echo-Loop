/// 通知权限请求时机协调器的 Riverpod 接线。
///
/// - [notificationPromptTriggerProvider]: 用 Notifier<int> 作为一次性事件流，
///   每次 `trigger()` 通过 +1 通知监听者（同值不通知，所以并发触发也只算一次）。
///   MainShell 监听后用 [rootNavigatorKey] 弹 dialog。
/// - [notificationPermissionReporterProvider]: 平台通知权限报告器，
///   根据运行平台返回对应实现（macOS/iOS/Android/Unsupported）。
/// - [notificationPermissionServiceProvider]: 业务入口，价值锚点调用
///   `maybeTriggerPrompt()` 即可，内部判定 + 触发。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_providers.dart';
import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../services/app_logger.dart';
import '../services/notification_permission_reporter.dart';
import '../services/notification_permission_service.dart';

const String _logTag = 'NotifPerm';

/// 平台通知权限报告器 —— 根据运行平台返回对应实现。
final notificationPermissionReporterProvider =
    Provider<NotificationPermissionReporter>((ref) {
      if (kIsWeb) return const UnsupportedNotificationPermissionReporter();
      if (Platform.isMacOS) return MacOSNotificationPermissionReporter();
      if (Platform.isIOS) {
        return IOSNotificationPermissionReporter();
      }
      if (Platform.isAndroid) {
        return AndroidNotificationPermissionReporter(
          FlutterLocalNotificationsPlugin(),
        );
      }
      return const UnsupportedNotificationPermissionReporter();
    });

/// pre-prompt 触发器：内部用计数器作为一次性事件流。
class NotificationPromptTriggerNotifier extends Notifier<int>
    implements NotificationPromptTrigger {
  bool _showing = false;

  @override
  int build() => 0;

  @override
  bool get isShowing => _showing;

  @override
  void trigger() {
    if (_showing) {
      AppLogger.log(_logTag, 'trigger: short-circuit (already showing)');
      return;
    }
    _showing = true;
    state = state + 1;
    AppLogger.log(_logTag, 'trigger: fired count=$state');
  }

  @override
  void onDialogClosed() {
    AppLogger.log(_logTag, 'onDialogClosed');
    _showing = false;
  }
}

/// 一次性事件流：MainShell 监听该 provider，状态 +1 时弹 dialog。
final notificationPromptTriggerProvider =
    NotifierProvider<NotificationPromptTriggerNotifier, int>(
      NotificationPromptTriggerNotifier.new,
    );

/// 业务入口：价值锚点调用 `maybeTriggerPrompt()` 即可。
final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>((ref) {
      return NotificationPermissionService(
        prefs: ref.read(sharedPreferencesProvider),
        analytics: ref.read(analyticsServiceProvider),
        trigger: ref.read(notificationPromptTriggerProvider.notifier),
        reporter: ref.read(notificationPermissionReporterProvider),
      );
    });
