import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_logger.dart';

const String _logTag = 'DownloadNotif';

/// 下载完成通知 ID 区间：位于复习提醒使用的 [1001, 1015] 与 [2000, 901999] 之后，互不覆盖。
const int _downloadNotificationIdBase = 1000000;
const int _downloadNotificationIdSpan = 1000000;

/// 插件在某些平台不发送终态通知时，由应用补发的通知入口。
abstract interface class DownloadCompletionNotifier {
  /// 发送一条下载终态通知；实现内部吞掉失败，调用方无需处理异常。
  Future<void> notify({
    required String taskId,
    required String title,
    required String body,
  });
}

/// macOS 下载完成 / 失败的系统通知。
///
/// background_downloader 在桌面端忽略通知配置（插件文档 doc/notifications.md），
/// 用户离开下载页后将收不到结果，因此由应用发送。
/// 仅在应用不在前台时发送：用户正在使用应用时，结果已在界面中可见。
/// 系统通知权限由复习提醒的 pre-prompt 统一申请，未授权时 show 不会展示。
class MacOSDownloadCompletionNotifier implements DownloadCompletionNotifier {
  MacOSDownloadCompletionNotifier({
    required FlutterLocalNotificationsPlugin plugin,
    required Future<void> Function() ensureInitialized,
    required bool Function() isAppInForeground,
  }) : _plugin = plugin,
       _ensureInitialized = ensureInitialized,
       _isAppInForeground = isAppInForeground;

  final FlutterLocalNotificationsPlugin _plugin;

  /// 插件是进程内单例，初始化须带上点击回调；由复习提醒服务统一负责，避免重复初始化清空回调。
  final Future<void> Function() _ensureInitialized;
  final bool Function() _isAppInForeground;

  @override
  Future<void> notify({
    required String taskId,
    required String title,
    required String body,
  }) async {
    if (_isAppInForeground()) return;
    await _ensureInitialized();
    try {
      await _plugin.show(
        _notificationIdFor(taskId),
        title,
        body,
        const NotificationDetails(
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
    } on PlatformException catch (error) {
      AppLogger.log(_logTag, 'show failed errorType=${error.runtimeType}');
    } on MissingPluginException catch (error) {
      AppLogger.log(_logTag, 'show failed errorType=${error.runtimeType}');
    }
  }
}

/// 同一进程内同一任务得到同一通知 ID；Dart 的 `%` 对正数除数恒返回非负值。
int _notificationIdFor(String taskId) =>
    _downloadNotificationIdBase + taskId.hashCode % _downloadNotificationIdSpan;
