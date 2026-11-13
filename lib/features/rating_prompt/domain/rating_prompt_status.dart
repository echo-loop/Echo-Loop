import 'rating_prompt_policy.dart';

/// 评分提醒条件在某一时刻的只读快照，供开发者选项查看，也供协调器判定。
///
/// 展示的结论与真实请求使用同一个 [blockReason]，两者不会出现分歧。
class RatingPromptStatus {
  /// 创建评分提醒条件快照。
  const RatingPromptStatus({
    required this.now,
    required this.rules,
    required this.isRemoteEnabled,
    required this.isStoreInstall,
    required this.installerStore,
    required this.installTime,
    required this.lastAttempt,
    required this.countedFrom,
    required this.checkInDays,
    required this.lastTaskCompletedAt,
  });

  /// 快照计算时间。
  final DateTime now;

  /// 本次判定使用的规则。
  final RatingPromptRules rules;

  /// 远程开关是否开启。
  final bool isRemoteEnabled;

  /// 是否判定为商店安装。
  final bool isStoreInstall;

  /// 平台报告的安装来源原始值，便于判断为何不是商店安装。
  final String? installerStore;

  /// 应用安装时间；平台无法提供时为 `null`。
  final DateTime? installTime;

  /// 上次发起系统评分请求的时间；从未请求时为 `null`。
  final DateTime? lastAttempt;

  /// 打卡天数统计的起始自然日：从未请求时为安装日，否则为上次请求的次日。
  final DateTime countedFrom;

  /// 统计范围内完成每日目标打卡的天数。
  final int checkInDays;

  /// 最近一次正常完成学习任务的时间；从未完成过时为 `null`。
  final DateTime? lastTaskCompletedAt;

  /// 距安装的时长；安装时间未知时为 `null`。
  Duration? get installAge {
    final installedAt = installTime;
    return installedAt == null ? null : now.difference(installedAt);
  }

  /// 冷却剩余时长；不在冷却期内时为 `null`。
  Duration? get cooldownRemaining => ratingPromptCooldownRemaining(
    rules: rules,
    now: now,
    lastAttempt: lastAttempt,
  );

  /// 不请求的原因；为 `null` 表示条件已满足。
  RatingPromptBlockReason? get blockReason => evaluateRatingPrompt(
    rules: rules,
    now: now,
    isRemoteEnabled: isRemoteEnabled,
    isStoreInstall: isStoreInstall,
    installTime: installTime,
    lastAttempt: lastAttempt,
    checkInDays: checkInDays,
    lastTaskCompletedAt: lastTaskCompletedAt,
  );
}
