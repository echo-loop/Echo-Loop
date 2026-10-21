/// 上报通道抽象接口（Strategy Pattern）
///
/// 业务代码不直接依赖 Firebase/友盟，只通过此接口上报事件。
/// 具体实现见 [FirebaseChannel]、[UmengChannel]、[LogOnlyChannel]。
library;

/// 分析上报通道
///
/// 每个实现类封装一个第三方 SDK（Firebase Analytics、友盟等）。
/// [AnalyticsService] 持有一个 Channel 实例，将事件转发到此接口。
abstract class AnalyticsChannel {
  /// 初始化通道（如 SDK 初始化）
  Future<void> initialize();

  /// 记录事件
  ///
  /// [name] 事件名（使用 [Events] 常量）。
  /// [parameters] 事件属性，值只允许 String/int/double/bool。
  Future<void> logEvent(String name, Map<String, Object>? parameters);

  /// 设置用户 ID（匿名 ID 或登录后的真实 ID）
  Future<void> setUserId(String? id);

  /// 设置用户属性
  Future<void> setUserProperty(String name, String? value);

  /// 批量更新用户属性；默认实现兼容只支持单字段的通道。
  Future<void> setUserProperties(Map<String, String?> properties) async {
    for (final entry in properties.entries) {
      await setUserProperty(entry.key, entry.value);
    }
  }

  /// 注册 super properties（事件级冻结属性）。
  ///
  /// 调用后，本地 SDK 之后发出的所有事件都会自动附加这些属性，
  /// 值在事件发出时被冻结，不会被未来覆盖。
  /// 仅 PostHog 实现实际行为；其他通道（Firebase / 友盟 / LogOnly）no-op。
  ///
  /// 与 [setUserProperty] 的区别：
  /// - super property 写到事件上，可查"事件发生时的状态"
  /// - user property 写到用户画像，覆盖式更新，查"用户当前状态"
  ///
  /// [properties] 的 value 只允许 String/int/double/bool。
  Future<void> registerSuperProperties(Map<String, Object> properties);

  /// 注销 super property。
  ///
  /// PostHog 可移除后续事件自动附加的属性；其他通道 no-op。
  Future<void> unregisterSuperProperty(String name);
}
