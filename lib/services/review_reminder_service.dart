import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_io/io.dart' as io;

import 'notification_tap_router_bridge.dart';
import 'review_reminder_time_calculator.dart';

/// 收藏复习提醒通知 ID 范围：[1001, 1015]（15 天独立调度）
const int _savedReviewIdBase = 1001;
const int _savedReviewDays = 15;
const String _savedReviewChannelId = 'saved_review';
const String _savedReviewChannelName = 'Saved Review Reminder';
const String _savedReviewChannelDescription =
    'Reminder to review saved sentences and words';
const String _openFavoritesPayload = 'open_favorites';

/// 建议性文案池，按天轮换，不对用户行为做判断
const List<String> _savedReviewBodies = [
  '复习一下收藏的句子和单词吧',
  '听一遍收藏的句子，巩固记忆',
  '碎片时间听几句，积少成多',
  '收藏的句子在等你，来复习一下',
  '反复听才能记住，来复习吧',
  '收藏的好句子，多听几遍才是你的',
  '间隔重复是记忆的关键，来听一轮',
  '熟悉的句子再听一遍，会有新感觉',
  '收藏了就要复习，不然会忘',
  '听力靠积累，来复习收藏的句子',
];

/// 单条音频复习通知的 channel
const String _perAudioChannelId = 'per_audio_review';
const String _perAudioChannelName = 'Per-Audio Review Reminder';
const String _perAudioChannelDescription =
    'Individual reminder when an audio review is due';

/// `open_audio:` payload 前缀，后跟 audioId
const String _openAudioPrefix = 'open_audio:';

/// per-audio 通知 ID 范围：[_perAudioIdMin, _perAudioIdMax]
const int _perAudioIdMin = 2000;
const int _perAudioIdRange = 900000;
const int _perAudioIdMax = _perAudioIdMin + _perAudioIdRange - 1;

/// 单条音频复习提醒所需信息
class PerAudioReminderInfo {
  final String audioId;
  final String audioName;

  /// nextReviewAt — 到期时间
  final DateTime triggerAt;

  /// 1~7，用于文案「第 X 轮复习」
  final int reviewRound;

  const PerAudioReminderInfo({
    required this.audioId,
    required this.audioName,
    required this.triggerAt,
    required this.reviewRound,
  });
}

/// 后台点击回调占位（系统可能在后台 isolate 触发）。
@pragma('vm:entry-point')
void reviewReminderBackgroundNotificationTap(NotificationResponse response) {}

/// 收藏复习 + 单条音频精准复习提醒服务
class ReviewReminderService {
  ReviewReminderService({
    required FlutterLocalNotificationsPlugin plugin,
    required NotificationTapRouterBridge bridge,
    required ReviewReminderTimeCalculator timeCalculator,
    bool? supportsSystemNotificationOverride,
  }) : _plugin = plugin,
       _bridge = bridge,
       _timeCalculator = timeCalculator,
       _supportsSystemNotificationOverride = supportsSystemNotificationOverride;

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationTapRouterBridge _bridge;
  ReviewReminderTimeCalculator _timeCalculator;

  /// 测试覆盖：指定是否支持系统通知
  final bool? _supportsSystemNotificationOverride;

  bool _initialized = false;
  bool _timezoneReady = false;

  /// 已调度的单条音频通知 ID，下次同步时先逐个 cancel
  final Set<int> _scheduledPerAudioIds = {};

  /// 快照去重：`"$audioId|$triggerAtMs"` 集合不变则跳过（null 表示首次同步）
  Set<String>? _lastSnapshot;

  bool get _supportsSystemNotification {
    if (_supportsSystemNotificationOverride != null) {
      return _supportsSystemNotificationOverride!;
    }
    if (kIsWeb) return false;
    return io.Platform.isIOS || io.Platform.isAndroid || io.Platform.isMacOS;
  }

  /// 仅初始化插件 + 时区，**不主动请求任何系统授权**。
  ///
  /// `DarwinInitializationSettings` 的 request* 三参数显式置 false，
  /// 避免 iOS / macOS 在 `_plugin.initialize()` 时弹出系统授权框。
  /// 调度通知本身在未授权时也不会抛错（iOS 静默不展示；后续授权后
  /// 已有的 schedule 仍按时展示）。
  ///
  /// 真正的权限请求由 [NotificationPermissionReporter.requestAuthorization] 在 in-app
  /// pre-prompt 取得用户同意后显式发起。
  Future<void> initPlugin() async {
    if (_initialized) return;
    if (!_supportsSystemNotification) return;

    try {
      await _ensureTimezoneReady();

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse:
            reviewReminderBackgroundNotificationTap,
      );

      _initialized = true;

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final payload = launchDetails?.notificationResponse?.payload;
      _handlePayload(payload);
    } on MissingPluginException {
      debugPrint('ReviewReminderService: plugin unavailable on this runtime');
    } catch (e) {
      debugPrint('ReviewReminderService.initPlugin error: $e');
    }
  }

  /// 调度未来 15 天的收藏复习提醒（每天一个独立通知）
  ///
  /// [hasSavedContent] 为 false 时取消所有已调度的收藏复习提醒。
  /// 每次调用先 cancel 旧的 15 个，再重新调度。
  Future<void> syncSavedReviewReminder({required bool hasSavedContent}) async {
    if (!_supportsSystemNotification) return;

    await initPlugin();
    if (!_initialized) return;

    if (!hasSavedContent) {
      await cancelSavedReviewReminder();
      return;
    }

    final now = DateTime.now();
    final firstTrigger = _timeCalculator.nextTriggerAt(now);

    debugPrint(
      'ReviewReminderService: scheduling $_savedReviewDays saved review '
      'reminders starting at $firstTrigger (now=$now)',
    );

    try {
      // 先取消旧的
      for (var i = 0; i < _savedReviewDays; i++) {
        await _plugin.cancel(_savedReviewIdBase + i);
      }

      // 调度未来 15 天
      for (var i = 0; i < _savedReviewDays; i++) {
        final triggerAt = firstTrigger.add(Duration(days: i));
        final triggerTz = tz.TZDateTime.from(triggerAt, tz.local);
        final body = _savedReviewBodies[i % _savedReviewBodies.length];

        await _plugin.zonedSchedule(
          _savedReviewIdBase + i,
          'Echo Loop',
          body,
          triggerTz,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _savedReviewChannelId,
              _savedReviewChannelName,
              channelDescription: _savedReviewChannelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: _openFavoritesPayload,
        );
      }
    } on MissingPluginException {
      debugPrint('ReviewReminderService: plugin unavailable during schedule');
    } catch (e) {
      debugPrint('ReviewReminderService.syncSavedReviewReminder error: $e');
    }
  }

  /// 全量覆盖式调度单条音频复习通知
  ///
  /// 每次调用先 cancel 上一轮调度的所有通知 ID，再为 [reminders]
  /// 中每条信息 zonedSchedule 一个新通知。快照不变时跳过。
  Future<void> syncPerAudioReminders(
    List<PerAudioReminderInfo> reminders,
  ) async {
    if (!_supportsSystemNotification) return;

    await initPlugin();
    if (!_initialized) return;

    // 构建快照
    final newSnapshot = <String>{
      for (final r in reminders)
        '${r.audioId}|${r.triggerAt.millisecondsSinceEpoch}',
    };
    if (_lastSnapshot != null && setEquals(newSnapshot, _lastSnapshot)) return;
    _lastSnapshot = newSnapshot;

    try {
      // cancel 旧通知（含跨重启残留的 per-audio 通知）
      await _cancelStalePerAudioNotifications(reminders);

      // 调度新通知
      for (final r in reminders) {
        final nid = _perAudioNotificationId(r.audioId);
        final scheduledTz = tz.TZDateTime.from(r.triggerAt, tz.local);

        await _plugin.zonedSchedule(
          nid,
          'Echo Loop',
          '${r.audioName} · 第${r.reviewRound}轮复习时间到了',
          scheduledTz,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _perAudioChannelId,
              _perAudioChannelName,
              channelDescription: _perAudioChannelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: '$_openAudioPrefix${r.audioId}',
        );
        _scheduledPerAudioIds.add(nid);
      }
    } on MissingPluginException {
      debugPrint(
        'ReviewReminderService: plugin unavailable during per-audio schedule',
      );
    } catch (e) {
      debugPrint('ReviewReminderService.syncPerAudioReminders error: $e');
    }
  }

  /// 更新提醒时间计算器（设置变更时调用，不重建 service 实例）
  void updateTimeCalculator(ReviewReminderTimeCalculator calculator) {
    _timeCalculator = calculator;
  }

  /// 取消所有已调度的 per-audio 复习通知
  ///
  /// 关闭 perAudio 开关时调用，清除系统中所有 per-audio 范围内的通知
  /// 和内存快照，确保重新开启时能重新调度。
  Future<void> cancelAllPerAudioReminders() async {
    if (!_supportsSystemNotification) return;

    try {
      // 查询系统中所有 pending 通知，cancel per-audio 范围内的
      final pending = await _plugin.pendingNotificationRequests();
      for (final n in pending) {
        if (n.id >= _perAudioIdMin && n.id <= _perAudioIdMax) {
          await _plugin.cancel(n.id);
        }
      }

      // 清理内存状态
      for (final id in _scheduledPerAudioIds.toList()) {
        await _plugin.cancel(id);
      }
      _scheduledPerAudioIds.clear();
      _lastSnapshot = null;
    } on MissingPluginException {
      debugPrint('ReviewReminderService: plugin unavailable during cancelAll');
    } catch (e) {
      debugPrint('ReviewReminderService.cancelAllPerAudioReminders error: $e');
    }
  }

  /// 取消所有已调度的收藏复习提醒（15 天）
  Future<void> cancelSavedReviewReminder() async {
    if (!_supportsSystemNotification) return;
    try {
      for (var i = 0; i < _savedReviewDays; i++) {
        await _plugin.cancel(_savedReviewIdBase + i);
      }
    } on MissingPluginException {
      debugPrint('ReviewReminderService: plugin unavailable during cancel');
    } catch (e) {
      debugPrint('ReviewReminderService.cancelSavedReviewReminder error: $e');
    }
  }

  /// 取消所有不在本次 [reminders] 中的 per-audio 通知
  ///
  /// 查询系统 pending 通知，过滤出 per-audio ID 范围内的，
  /// 将不在本次调度列表中的全部 cancel。解决跨重启残留问题。
  Future<void> _cancelStalePerAudioNotifications(
    List<PerAudioReminderInfo> reminders,
  ) async {
    final newIds = {
      for (final r in reminders) _perAudioNotificationId(r.audioId),
    };

    // 查询系统中所有 pending 通知
    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.id >= _perAudioIdMin &&
          n.id <= _perAudioIdMax &&
          !newIds.contains(n.id)) {
        await _plugin.cancel(n.id);
      }
    }

    // 同时清理内存中的旧 ID 集合
    for (final id in _scheduledPerAudioIds.toList()) {
      if (!newIds.contains(id)) {
        await _plugin.cancel(id);
      }
    }
    _scheduledPerAudioIds.clear();
  }

  Future<void> _ensureTimezoneReady() async {
    if (_timezoneReady) return;
    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      debugPrint('ReviewReminderService: fallback timezone due to $e');
    }
    _timezoneReady = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  /// 解析 payload 并发射对应意图
  void _handlePayload(String? payload) {
    if (payload == null) return;
    // 兼容旧版本 payload，旧"每日提醒"已重命名为"收藏复习提醒"
    if (payload == _openFavoritesPayload || payload == 'open_study_tasks') {
      _bridge.emit(const OpenFavorites());
      return;
    }
    if (payload.startsWith(_openAudioPrefix)) {
      final audioId = payload.substring(_openAudioPrefix.length);
      if (audioId.isNotEmpty) {
        _bridge.emit(OpenAudioLearningPlan(audioId));
      }
    }
  }

  /// 为 audioId 生成确定性通知 ID（FNV-1a hash，范围 2000~901999）
  static int _perAudioNotificationId(String audioId) {
    // FNV-1a 32-bit
    var hash = 0x811c9dc5;
    for (var i = 0; i < audioId.length; i++) {
      hash ^= audioId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return _perAudioIdMin + (hash % _perAudioIdRange);
  }
}
