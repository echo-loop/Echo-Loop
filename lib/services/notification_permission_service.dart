/// 通知权限请求时机协调器。
///
/// 价值锚点（首次完成 sub_stage、首次收藏等）调用 [maybeTriggerPrompt]，
/// 由本服务统一判断是否要弹 in-app pre-prompt。
///
/// 状态机（[NotificationPermissionState]）由 [NotificationPermissionReporter]
/// 的平台无关授权状态派生：
///
/// | reporter 返回 | 状态 |
/// |-------------|------|
/// | authorized | granted |
/// | notDetermined | canRequest（首次安装 / 用户没走过系统流程） |
/// | denied / restricted | blocked（用户已明确关闭 → 跳设置） |
/// | unsupported | canRequest（UI 层不展示 banner） |
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_service.dart';
import '../analytics/models/event_names.dart';
import 'app_logger.dart';
import 'notification_permission_reporter.dart';

const String _logTag = 'NotifPerm';

/// pre-prompt 已弹过的冷却天数，期满后允许在新锚点重新弹一次
const int _redismissCooldownDays = 14;

/// 触发 pre-prompt 显示的"接口"，由 Provider 层注入 Riverpod Notifier。
abstract class NotificationPromptTrigger {
  /// 请求显示 pre-prompt。若已在显示中应自行 no-op。
  void trigger();

  /// dialog 关闭后调用，解除并发保护。
  void onDialogClosed();

  /// 当前是否正在显示 dialog。
  bool get isShowing;
}

/// 判定 pre-prompt 是否要弹时考虑的精确权限状态。
enum NotificationPermissionState {
  /// 系统已授权（含 provisional / limited）
  granted,

  /// 还可以弹系统授权框：用户尚未走过系统授权流程（iOS notDetermined / Android 首次）
  canRequest,

  /// 用户已走过系统流程或明确关闭 → 不再弹 pre-prompt，引导跳系统设置
  blocked,
}

class NotificationPermissionService {
  NotificationPermissionService({
    required SharedPreferences prefs,
    required AnalyticsService analytics,
    required NotificationPromptTrigger trigger,
    required NotificationPermissionReporter reporter,
  }) : _prefs = prefs,
       _analytics = analytics,
       _trigger = trigger,
       _reporter = reporter;

  /// 上次 pre-prompt 展示时间（millisSinceEpoch）。
  static const String _spKeyLastShownAt = 'notification_prompt_last_shown_at';

  /// 上次用户对 pre-prompt 的动作（'grant' / 'dismiss'）。
  static const String _spKeyLastAction = 'notification_prompt_last_action';

  /// 用户通过 pre-prompt 走完系统授权流程后的结果。
  /// `true`=已授权, `false`=已拒绝, `null`=未确定（未曾走过流程或仅推迟）。
  /// 仅在 Android reporter 内部用于区分 denied vs notDetermined，
  /// 设置页不依赖此 SP。
  static const String _spKeyAuthorizationStatus =
      'notification_authorization_status';

  static const String _actionGrant = 'grant';
  static const String _actionDismiss = 'dismiss';

  final SharedPreferences _prefs;
  final AnalyticsService _analytics;
  final NotificationPromptTrigger _trigger;
  final NotificationPermissionReporter _reporter;

  /// 注入测试时间的钩子，默认走真实时钟。
  DateTime Function() now = DateTime.now;

  /// 读取当前权限状态。UI 层（reminder_settings_screen）必须走这个方法。
  Future<NotificationPermissionState> getCurrentState() => _readState();

  /// 是否满足 pre-prompt 展示条件。
  ///
  /// 读 SP `authorization_status`：不存在（未曾走过流程）且不在冷却期 → 可弹。
  /// 不读 reporter，与设置页的 OS 状态判断独立。
  Future<bool> canShowPrompt() async {
    final spExists = _prefs.containsKey(_spKeyAuthorizationStatus);
    if (spExists) {
      AppLogger.log(_logTag, 'canShowPrompt: SP exists -> false');
      return false;
    }
    if (_isInCooldown()) {
      AppLogger.log(_logTag, 'canShowPrompt: cooldown -> false');
      return false;
    }
    return true;
  }

  /// 从系统读取实际权限状态并同步到 SP。
  ///
  /// 启动和回前台时调用。若系统已授权（如 Android 默认开启）或已拒绝，
  /// 写入 SP 阻止 pre-prompt 弹窗。notDetermined 时保留 SP 原样，
  /// 让用户仍有机会通过 pre-prompt 触发系统授权。
  Future<void> syncSystemAuthorizationStatus() async {
    try {
      final status = await _reporter.getAuthorizationStatus();
      switch (status) {
        case NotificationAuthorization.authorized:
          await _prefs.setBool(_spKeyAuthorizationStatus, true);
          AppLogger.log(_logTag, 'syncSystemStatus: authorized -> SP=true');
        case NotificationAuthorization.denied:
        case NotificationAuthorization.restricted:
          await _prefs.setBool(_spKeyAuthorizationStatus, false);
          AppLogger.log(_logTag, 'syncSystemStatus: $status -> SP=false');
        case NotificationAuthorization.notDetermined:
        case NotificationAuthorization.unsupported:
          // 保留 SP 原样，用户尚未做决定
          AppLogger.log(_logTag, 'syncSystemStatus: $status -> SP unchanged');
      }
    } catch (e) {
      AppLogger.log(_logTag, 'syncSystemStatus ERROR: $e');
    }
  }

  /// 价值锚点调用入口：每次"用户产生学习成果 / 首次收藏"时调用，
  /// 由本服务决定是否真的弹 pre-prompt。
  ///
  /// 读 SP `authorization_status`：不存在（未曾走过流程）→ 可弹，
  /// 已存在（允许/拒绝过）→ 跳过。不依赖 reporter 的 OS 状态。
  Future<void> maybeTriggerPrompt() async {
    AppLogger.log(_logTag, 'maybeTriggerPrompt: called from anchor');

    final spExists = _prefs.containsKey(_spKeyAuthorizationStatus);
    if (spExists) {
      AppLogger.log(_logTag, 'maybeTriggerPrompt: skip (already_decided)');
      _trackSkipped('already_decided');
      return;
    }

    if (_isInCooldown()) {
      final lastShown = _prefs.getInt(_spKeyLastShownAt) ?? 0;
      AppLogger.log(
        _logTag,
        'maybeTriggerPrompt: skip (cooldown) '
        'lastShownAt=${DateTime.fromMillisecondsSinceEpoch(lastShown)} '
        'lastAction=${_prefs.getString(_spKeyLastAction)}',
      );
      _trackSkipped('cooldown');
      return;
    }

    AppLogger.log(
      _logTag,
      'maybeTriggerPrompt: triggering pre-prompt '
      '(showing=${_trigger.isShowing})',
    );
    _trigger.trigger();
  }

  /// 用户在 pre-prompt 点"开启"后调用，串联系统授权 + 持久化 + 埋点。
  ///
  /// 返回值：系统是否真的授权成功。
  ///
  /// 写 SP `[_spKeyAuthorizationStatus]`：
  /// - `true` — 用户明确允许
  /// - `false` — 用户明确拒绝（reporter 确认为 denied/restricted）
  /// - 不写 — 无法确认决策（iOS 手势 dismiss，仍为 notDetermined）
  Future<bool> onUserAcceptedPrompt() async {
    AppLogger.log(_logTag, 'onUserAccepted: requesting system permission');
    _analytics.track(Events.notificationPromptResult, const {
      EventParams.action: _actionGrant,
    });
    await _persistAction(_actionGrant);

    final granted = await _reporter.requestAuthorization();
    final status = await _reporter.getAuthorizationStatus();

    // 仅当能确认用户已决策时才写 SP：
    // - granted=true 或 reporter 返回 denied/restricted → 确认决策
    // - reporter 返回 notDetermined → 未决策（iOS 手势 dismiss），不写
    final reallyDecided =
        granted ||
        status == NotificationAuthorization.denied ||
        status == NotificationAuthorization.restricted;

    if (reallyDecided) {
      await _prefs.setBool(_spKeyAuthorizationStatus, granted);
      AppLogger.log(
        _logTag,
        'onUserAccepted: granted=$granted status=$status -> '
        'SP authorization_status=$granted',
      );
    } else {
      AppLogger.log(
        _logTag,
        'onUserAccepted: granted=$granted status=$status -> '
        'NOT decided, SP unchanged',
      );
    }

    _analytics.track(Events.notificationSystemResult, {
      EventParams.status: granted ? 'granted' : 'denied',
    });
    return granted;
  }

  /// 用户在 pre-prompt 点"暂不"时调用。
  Future<void> onUserDismissedPrompt() async {
    AppLogger.log(_logTag, 'onUserDismissed: dismissed by user');
    _analytics.track(Events.notificationPromptResult, const {
      EventParams.action: _actionDismiss,
    });
    await _persistAction(_actionDismiss);
  }

  /// 读当前通知系统授权状态，仅依赖 [NotificationPermissionReporter]。
  Future<NotificationPermissionState> _readState() async {
    final NotificationAuthorization status;
    try {
      status = await _reporter.getAuthorizationStatus();
    } catch (e) {
      AppLogger.log(_logTag, 'getCurrentState ERROR: $e (fallback canRequest)');
      return NotificationPermissionState.canRequest;
    }

    switch (status) {
      case NotificationAuthorization.authorized:
        AppLogger.log(_logTag, 'getCurrentState: authorized -> granted');
        return NotificationPermissionState.granted;
      case NotificationAuthorization.notDetermined:
        AppLogger.log(_logTag, 'getCurrentState: notDetermined -> canRequest');
        return NotificationPermissionState.canRequest;
      case NotificationAuthorization.denied:
      case NotificationAuthorization.restricted:
        AppLogger.log(_logTag, 'getCurrentState: $status -> blocked');
        return NotificationPermissionState.blocked;
      case NotificationAuthorization.unsupported:
        AppLogger.log(_logTag, 'getCurrentState: unsupported -> canRequest');
        return NotificationPermissionState.canRequest;
    }
  }

  bool _isInCooldown() {
    final lastShown = _prefs.getInt(_spKeyLastShownAt);
    if (lastShown == null) return false;
    final elapsedMs = now().millisecondsSinceEpoch - lastShown;
    final cooldownMs = _redismissCooldownDays * 24 * 3600 * 1000;
    return elapsedMs < cooldownMs;
  }

  Future<void> _persistAction(String action) async {
    await _prefs.setString(_spKeyLastAction, action);
    await _prefs.setInt(_spKeyLastShownAt, now().millisecondsSinceEpoch);
  }

  void _trackSkipped(String reason) {
    _analytics.track(Events.notificationPromptSkipped, {
      EventParams.reason: reason,
    });
  }
}
