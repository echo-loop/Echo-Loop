import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_io/io.dart' as io;

import 'app_logger.dart';
import 'notification_tap_router_bridge.dart';
import 'review_reminder_texts.dart';
import 'review_reminder_time_calculator.dart';

/// 收藏复习提醒通知 ID 范围：[1001, 1015]（15 天独立调度）
const int _savedReviewIdBase = 1001;
const int _savedReviewDays = 15;
const String _savedReviewChannelId = 'saved_review';
const String _savedReviewChannelName = 'Saved Review Reminder';
const String _savedReviewChannelDescription =
    'Reminder to review saved sentences and words';
const String _openFavoritesPayload = 'open_favorites';
const String _logTag = 'ReviewReminder';

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
    DateTime Function()? systemNow,
    ReviewReminderTexts Function()? resolveTexts,
  }) : _plugin = plugin,
       _bridge = bridge,
       _timeCalculator = timeCalculator,
       _supportsSystemNotificationOverride = supportsSystemNotificationOverride,
       _systemNow = systemNow ?? DateTime.now,
       _resolveTexts = resolveTexts ?? ReviewReminderTexts.english;

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationTapRouterBridge _bridge;
  ReviewReminderTimeCalculator _timeCalculator;

  /// 测试覆盖：指定是否支持系统通知
  final bool? _supportsSystemNotificationOverride;

  /// 系统通知插件使用设备真实时间校验 scheduledDate，不能跟随开发者时光机。
  final DateTime Function() _systemNow;

  /// 解析当前界面语言的通知文案（每次同步时调用，语言切换后下一次同步生效）
  final ReviewReminderTexts Function() _resolveTexts;

  bool _initialized = false;
  bool _timezoneReady = false;

  /// 已调度的单条音频通知 ID，下次同步时先逐个 cancel
  final Set<int> _scheduledPerAudioIds = {};

  /// 快照去重：`"$audioId|$triggerAtMs"` 集合不变则跳过（null 表示首次同步）
  Set<String>? _lastSnapshot;

  bool get _supportsSystemNotification {
    if (_supportsSystemNotificationOverride != null) {
      return _supportsSystemNotificationOverride;
    }
    if (kIsWeb) return false;
    return io.Platform.isIOS || io.Platform.isAndroid || io.Platform.isMacOS;
  }

  /// 解析通知文案；解析失败只记录日志并回退英文，保证提醒仍能调度。
  ReviewReminderTexts _currentTexts() {
    try {
      return _resolveTexts();
    } on Object catch (error) {
      AppLogger.log(
        _logTag,
        'texts fallback to english errorType=${error.runtimeType}',
      );
      return ReviewReminderTexts.english();
    }
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
    if (_initialized) {
      return;
    }
    if (!_supportsSystemNotification) {
      AppLogger.log(
        _logTag,
        'initPlugin skipped reason=unsupported platform=${_platformName()}',
      );
      return;
    }

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
      if (payload != null) {
        AppLogger.log(_logTag, 'launch payload=$payload');
      }
      _handlePayload(payload);
    } on MissingPluginException {
      AppLogger.log(_logTag, 'initPlugin failed reason=missingPlugin');
    } catch (e, st) {
      AppLogger.log(_logTag, 'initPlugin failed error=$e\n$st');
    }
  }

  /// 调度未来 15 天的收藏复习提醒（每天一个独立通知）
  ///
  /// [hasSavedContent] 为 false 时取消所有已调度的收藏复习提醒。
  /// 每次调用先 cancel 旧的 15 个，再重新调度。
  Future<void> syncSavedReviewReminder({required bool hasSavedContent}) async {
    if (!_supportsSystemNotification) {
      AppLogger.log(
        _logTag,
        'syncSavedReviewReminder skipped reason=unsupported',
      );
      return;
    }

    await initPlugin();
    if (!_initialized) {
      return;
    }

    if (!hasSavedContent) {
      await cancelSavedReviewReminder();
      return;
    }

    final now = DateTime.now();
    final firstTrigger = _timeCalculator.nextTriggerAt(now);
    final texts = _currentTexts();

    AppLogger.log(
      _logTag,
      'syncSavedReviewReminder scheduling count=$_savedReviewDays '
      'firstTrigger=$firstTrigger now=$now '
      'androidMode=${AndroidScheduleMode.inexactAllowWhileIdle.name}',
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
        final body = texts.savedBodies[i % texts.savedBodies.length];

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
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: _openFavoritesPayload,
        );
      }
      AppLogger.log(
        _logTag,
        'syncSavedReviewReminder success count=$_savedReviewDays',
      );
      await _logPendingSnapshot('savedReviewScheduled');
    } on MissingPluginException {
      AppLogger.log(
        _logTag,
        'syncSavedReviewReminder failed reason=missingPlugin',
      );
    } catch (e, st) {
      AppLogger.log(_logTag, 'syncSavedReviewReminder failed error=$e\n$st');
    }
  }

  /// 全量覆盖式调度单条音频复习通知
  ///
  /// 每次调用先 cancel 上一轮调度的所有通知 ID，再为 [reminders]
  /// 中每条信息 zonedSchedule 一个新通知。快照不变时跳过。
  Future<void> syncPerAudioReminders(
    List<PerAudioReminderInfo> reminders,
  ) async {
    if (!_supportsSystemNotification) {
      AppLogger.log(
        _logTag,
        'syncPerAudioReminders skipped reason=unsupported',
      );
      return;
    }

    await initPlugin();
    if (!_initialized) {
      return;
    }

    // 系统通知使用真实设备时间；开发者时光机可能让业务层传入
    // 对应用内时间来说是未来、但对系统来说已过期的提醒。
    final systemNow = _systemNow();
    final schedulableReminders = reminders
        .where((r) => r.triggerAt.isAfter(systemNow))
        .toList(growable: false);
    var skippedExpiredCount = reminders.length - schedulableReminders.length;

    // 构建快照；语言标识参与去重，切换语言后即使提醒不变也会重新调度
    final texts = _currentTexts();
    final newSnapshot = <String>{
      'locale|${texts.localeTag}',
      for (final r in schedulableReminders)
        '${r.audioId}|${r.triggerAt.millisecondsSinceEpoch}',
    };
    if (_lastSnapshot != null && setEquals(newSnapshot, _lastSnapshot)) {
      return;
    }
    _lastSnapshot = newSnapshot;

    try {
      // cancel 旧通知（含跨重启残留的 per-audio 通知）
      await _cancelStalePerAudioNotifications(schedulableReminders);
      AppLogger.log(
        _logTag,
        'syncPerAudioReminders scheduling count=${schedulableReminders.length} '
        'skippedExpired=$skippedExpiredCount '
        'androidMode=${AndroidScheduleMode.inexactAllowWhileIdle.name}',
      );

      // 调度新通知
      var scheduledCount = 0;
      for (final r in schedulableReminders) {
        final nid = _perAudioNotificationId(r.audioId);
        if (!r.triggerAt.isAfter(_systemNow())) {
          skippedExpiredCount += 1;
          continue;
        }
        final scheduledTz = tz.TZDateTime.from(r.triggerAt, tz.local);

        await _plugin.zonedSchedule(
          nid,
          'Echo Loop',
          texts.perAudioBody(r.audioName, r.reviewRound),
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
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '$_openAudioPrefix${r.audioId}',
        );
        _scheduledPerAudioIds.add(nid);
        scheduledCount += 1;
      }
      AppLogger.log(
        _logTag,
        'syncPerAudioReminders success count=$scheduledCount '
        'skippedExpired=$skippedExpiredCount',
      );
      await _logPendingSnapshot('perAudioScheduled');
    } on MissingPluginException {
      AppLogger.log(
        _logTag,
        'syncPerAudioReminders failed reason=missingPlugin',
      );
    } catch (e, st) {
      AppLogger.log(_logTag, 'syncPerAudioReminders failed error=$e\n$st');
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
    if (!_supportsSystemNotification) {
      AppLogger.log(
        _logTag,
        'cancelAllPerAudioReminders skipped reason=unsupported',
      );
      return;
    }

    try {
      // 查询系统中所有 pending 通知，cancel per-audio 范围内的
      final pending = await _plugin.pendingNotificationRequests();
      var canceledFromPending = 0;
      for (final n in pending) {
        if (n.id >= _perAudioIdMin && n.id <= _perAudioIdMax) {
          await _plugin.cancel(n.id);
          canceledFromPending++;
        }
      }

      // 清理内存状态
      var canceledFromMemory = 0;
      for (final id in _scheduledPerAudioIds.toList()) {
        await _plugin.cancel(id);
        canceledFromMemory++;
      }
      _scheduledPerAudioIds.clear();
      _lastSnapshot = null;
      AppLogger.log(
        _logTag,
        'cancelAllPerAudioReminders success pending=$canceledFromPending '
        'memory=$canceledFromMemory',
      );
    } on MissingPluginException {
      AppLogger.log(
        _logTag,
        'cancelAllPerAudioReminders failed reason=missingPlugin',
      );
    } catch (e, st) {
      AppLogger.log(_logTag, 'cancelAllPerAudioReminders failed error=$e\n$st');
    }
  }

  /// 取消所有已调度的收藏复习提醒（15 天）
  Future<void> cancelSavedReviewReminder() async {
    if (!_supportsSystemNotification) {
      AppLogger.log(
        _logTag,
        'cancelSavedReviewReminder skipped reason=unsupported',
      );
      return;
    }
    try {
      for (var i = 0; i < _savedReviewDays; i++) {
        await _plugin.cancel(_savedReviewIdBase + i);
      }
      AppLogger.log(
        _logTag,
        'cancelSavedReviewReminder success ids=$_savedReviewIdBase..'
        '${_savedReviewIdBase + _savedReviewDays - 1}',
      );
    } on MissingPluginException {
      AppLogger.log(
        _logTag,
        'cancelSavedReviewReminder failed reason=missingPlugin',
      );
    } catch (e, st) {
      AppLogger.log(_logTag, 'cancelSavedReviewReminder failed error=$e\n$st');
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
    } catch (e, st) {
      AppLogger.log(_logTag, 'timezone fallback error=$e\n$st');
    }
    _timezoneReady = true;
  }

  /// 记录系统 pending notification 摘要，确认调度请求已进入平台队列。
  Future<void> _logPendingSnapshot(String reason) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final savedCount = pending
          .where(
            (n) =>
                n.id >= _savedReviewIdBase &&
                n.id < _savedReviewIdBase + _savedReviewDays,
          )
          .length;
      final perAudioCount = pending
          .where((n) => n.id >= _perAudioIdMin && n.id <= _perAudioIdMax)
          .length;
      AppLogger.log(
        _logTag,
        'pending snapshot reason=$reason total=${pending.length} '
        'saved=$savedCount perAudio=$perAudioCount',
      );
    } on MissingPluginException {
      AppLogger.log(_logTag, 'pending snapshot skipped reason=missingPlugin');
    } catch (e, st) {
      AppLogger.log(_logTag, 'pending snapshot failed error=$e\n$st');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    AppLogger.log(_logTag, 'notification tapped payload=${response.payload}');
    _handlePayload(response.payload);
  }

  /// 解析 payload 并发射对应意图
  void _handlePayload(String? payload) {
    if (payload == null) return;
    // 兼容旧版本 payload，旧"每日提醒"已重命名为"收藏复习提醒"
    if (payload == _openFavoritesPayload || payload == 'open_study_tasks') {
      AppLogger.log(_logTag, 'route payload=$payload intent=openFavorites');
      _bridge.emit(const OpenFavorites());
      return;
    }
    if (payload.startsWith(_openAudioPrefix)) {
      final audioId = payload.substring(_openAudioPrefix.length);
      if (audioId.isNotEmpty) {
        AppLogger.log(_logTag, 'route payload=$payload intent=openAudio');
        _bridge.emit(OpenAudioLearningPlan(audioId));
      }
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (io.Platform.isAndroid) return 'android';
    if (io.Platform.isIOS) return 'ios';
    if (io.Platform.isMacOS) return 'macos';
    if (io.Platform.isLinux) return 'linux';
    if (io.Platform.isWindows) return 'windows';
    return 'unknown';
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
