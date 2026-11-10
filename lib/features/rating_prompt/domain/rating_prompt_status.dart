import 'rating_prompt_policy.dart';

/// 评分邀请条件在某一时刻的只读快照，供开发者选项查看。
///
/// 快照由协调器用与实际判定相同的数据组装，[allowsEvent] 复用
/// [RatingPromptPolicy.allows]，保证展示结论与真实触发行为一致。
class RatingPromptStatus {
  /// 创建评分邀请条件快照。
  const RatingPromptStatus({
    required this.now,
    required this.isRemoteEnabled,
    required this.isStoreInstall,
    required this.installerStore,
    required this.installTime,
    required this.lastAttempt,
    required this.cooldownRemaining,
    required this.countedFrom,
    required this.effectiveStudyDays,
    required this.policy,
  });

  /// 快照计算时间。
  final DateTime now;

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

  /// 冷却剩余时长；不在冷却期内时为 `null`。
  final Duration? cooldownRemaining;

  /// 有效学习天数统计的起始自然日。
  final DateTime countedFrom;

  /// 统计范围内的有效学习天数。
  final int effectiveStudyDays;

  /// 当前生效的评分邀请策略。
  final RatingPromptPolicy policy;

  /// 距安装的时长；安装时间未知时为 `null`。
  Duration? get installAge {
    final installedAt = installTime;
    return installedAt == null ? null : now.difference(installedAt);
  }

  /// 完成某个练习事件后是否会请求系统评分（不含页面可见性等运行时检查）。
  bool allowsEvent(RatingPromptEvent event) =>
      isRemoteEnabled &&
      cooldownRemaining == null &&
      policy.allows(
        RatingPromptFacts(
          now: now,
          installTime: installTime,
          effectiveStudyDays: effectiveStudyDays,
          event: event,
          isStoreInstall: isStoreInstall,
        ),
      );
}
