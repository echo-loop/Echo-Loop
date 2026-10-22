/// 触发评分邀请的事件类型。
enum RatingPromptEvent { shadowingCompleted, retellCompleted }

/// 一组评分邀请条件。
///
/// 组内条件为 AND；策略中的多个组为 OR。这样可在保持当前单组产品规则的
/// 同时，为后续新增活动或实验组保留扩展点。
class RatingPromptRuleGroup {
  /// 创建一组必须全部满足的条件。
  const RatingPromptRuleGroup({
    required this.minimumInstallAge,
    required this.minimumEffectiveStudyDays,
    required this.events,
  });

  /// 安装后必须经过的最短时间。
  final Duration minimumInstallAge;

  /// 距上次请求后必须达到的有效学习天数。
  final int minimumEffectiveStudyDays;

  /// 可满足此条件组的练习完成事件。
  final Set<RatingPromptEvent> events;
}

/// 单次评分邀请的资格输入。
class RatingPromptFacts {
  /// 创建用于评估评分邀请资格的数据。
  const RatingPromptFacts({
    required this.now,
    required this.installTime,
    required this.effectiveStudyDays,
    required this.event,
    required this.isStoreInstall,
  });

  /// 本次评估时间。
  final DateTime now;

  /// 应用安装时间；平台无法提供时为 `null`。
  final DateTime? installTime;

  /// 达到有效学习时长门槛的天数。
  final int effectiveStudyDays;

  /// 触发本次评估的练习完成事件。
  final RatingPromptEvent event;

  /// 应用是否通过符合条件的应用商店安装。
  final bool isStoreInstall;
}

/// 纯评分邀请规则求值器。
class RatingPromptPolicy {
  /// 创建由多个备选条件组组成的策略。
  const RatingPromptPolicy({required this.groups});

  /// 当前默认策略只有一组条件；组内所有条件均必须满足。
  static const defaultPolicy = RatingPromptPolicy(
    groups: [
      RatingPromptRuleGroup(
        minimumInstallAge: Duration(days: 7),
        minimumEffectiveStudyDays: 3,
        events: {
          RatingPromptEvent.shadowingCompleted,
          RatingPromptEvent.retellCompleted,
        },
      ),
    ],
  );

  /// 使用 OR 逻辑求值的备选条件组列表。
  final List<RatingPromptRuleGroup> groups;

  /// 任一条件组通过即满足策略。缺失安装时间时保守地不触发。
  bool allows(RatingPromptFacts facts) {
    final installTime = facts.installTime;
    if (installTime == null ||
        facts.effectiveStudyDays < 0 ||
        !facts.isStoreInstall) {
      return false;
    }

    return groups.any((group) {
      final installAge = facts.now.difference(installTime);
      return installAge >= group.minimumInstallAge &&
          facts.effectiveStudyDays >= group.minimumEffectiveStudyDays &&
          group.events.contains(facts.event);
    });
  }
}
