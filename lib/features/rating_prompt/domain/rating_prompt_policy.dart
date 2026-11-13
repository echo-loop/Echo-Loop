/// 评分提醒的固定规则。
class RatingPromptRules {
  /// 创建评分提醒规则；默认值即产品规则。
  const RatingPromptRules({
    this.minimumInstallAge = const Duration(days: 7),
    this.minimumCheckInDays = 3,
    this.cooldown = const Duration(days: 120),
    this.recentTaskWindow = const Duration(minutes: 10),
  });

  /// 产品默认规则。
  static const defaults = RatingPromptRules();

  /// 安装后必须经过的最短时间。
  final Duration minimumInstallAge;

  /// 统计区间内需要达到的每日目标打卡天数。
  ///
  /// 打卡天数直接复用每日学习目标的打卡记录，口径与用户设置的目标一致。
  final int minimumCheckInDays;

  /// 每次发起系统评分请求后（无论系统是否展示）进入的冷却期。
  final Duration cooldown;

  /// 任务正常完成后，多久之内回到首页才允许提醒，避免用户很久没学习时突然弹窗。
  final Duration recentTaskWindow;
}

/// 本次不请求系统评分的原因。
///
/// 枚举顺序即检查顺序，第一条命中即为结论；展示与真实判定共用同一顺序。
enum RatingPromptBlockReason {
  remoteDisabled,
  notStoreInstall,
  installTimeUnknown,
  installTooRecent,
  inCooldown,
  notEnoughCheckInDays,
  noRecentTask,
}

/// 冷却剩余时长；不在冷却期内返回 `null`。
Duration? ratingPromptCooldownRemaining({
  required RatingPromptRules rules,
  required DateTime now,
  required DateTime? lastAttempt,
}) {
  if (lastAttempt == null) return null;
  final remaining = rules.cooldown - now.difference(lastAttempt);
  return remaining > Duration.zero ? remaining : null;
}

/// 任务完成是否仍在提醒窗口内。完成时间晚于当前时间（时钟回拨）视为无效。
bool isRecentTaskCompletion({
  required RatingPromptRules rules,
  required DateTime now,
  required DateTime? completedAt,
}) {
  if (completedAt == null || now.isBefore(completedAt)) return false;
  return now.difference(completedAt) <= rules.recentTaskWindow;
}

/// 判定当前是否可以请求系统评分；返回 `null` 表示可以请求。
///
/// 只包含纯规则，不做 I/O。页面可见性、前台状态等运行时条件由协调器另行检查。
RatingPromptBlockReason? evaluateRatingPrompt({
  required RatingPromptRules rules,
  required DateTime now,
  required bool isRemoteEnabled,
  required bool isStoreInstall,
  required DateTime? installTime,
  required DateTime? lastAttempt,
  required int checkInDays,
  required DateTime? lastTaskCompletedAt,
}) {
  if (!isRemoteEnabled) return RatingPromptBlockReason.remoteDisabled;
  if (!isStoreInstall) return RatingPromptBlockReason.notStoreInstall;
  if (installTime == null) return RatingPromptBlockReason.installTimeUnknown;
  if (now.difference(installTime) < rules.minimumInstallAge) {
    return RatingPromptBlockReason.installTooRecent;
  }
  if (ratingPromptCooldownRemaining(
        rules: rules,
        now: now,
        lastAttempt: lastAttempt,
      ) !=
      null) {
    return RatingPromptBlockReason.inCooldown;
  }
  if (checkInDays < rules.minimumCheckInDays) {
    return RatingPromptBlockReason.notEnoughCheckInDays;
  }
  if (!isRecentTaskCompletion(
    rules: rules,
    now: now,
    completedAt: lastTaskCompletedAt,
  )) {
    return RatingPromptBlockReason.noRecentTask;
  }
  return null;
}

/// 随心听返回时，本次页面有效学习时长超过该值才记为一次任务完成。
const ratingFreeListenMinimumDuration = Duration(minutes: 2);
