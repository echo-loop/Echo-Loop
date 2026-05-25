/// 分析系统统一入口（Facade）
///
/// 业务代码唯一依赖的接口。职责：
/// 1. 合规拦截（用户未同意时丢弃事件）
/// 2. 分发到当前 [AnalyticsChannel]
///
/// 通道在启动时确定，运行中不切换（geo 变化下次启动生效）。
/// 离线缓存和批量上报由 SDK 自身处理。
library;

import '../services/app_logger.dart';
import 'analytics_channel.dart';
import 'consent_manager.dart';

/// 分析服务
///
/// 使用示例：
/// ```dart
/// ref.read(analyticsServiceProvider).track(Events.learningStart, {
///   EventParams.audioId: audioId,
///   EventParams.stage: stage.name,
/// });
/// ```
class AnalyticsService {
  final AnalyticsChannel _channel;
  final ConsentManager _consent;

  AnalyticsService({
    required AnalyticsChannel channel,
    required ConsentManager consent,
  }) : _channel = channel,
       _consent = consent;

  /// 当前通道名称（调试用）
  String get channelName => _channel.name;

  /// 记录事件
  ///
  /// 如果用户未同意数据采集，事件将被静默丢弃。
  Future<void> track(String name, [Map<String, Object>? properties]) async {
    if (!_consent.hasConsented) return;
    try {
      await _channel.logEvent(name, properties);
    } catch (e) {
      // 埋点失败不影响主业务，但需要日志排查
      AppLogger.log('Analytics', 'FAIL "$name": $e');
    }
  }

  /// 设置用户 ID
  Future<void> setUserId(String? id) async {
    if (!_consent.hasConsented) return;
    await _channel.setUserId(id);
  }

  /// 设置用户属性
  Future<void> setUserProperty(String name, String? value) async {
    if (!_consent.hasConsented) return;
    await _channel.setUserProperty(name, value);
  }

  /// 注册 super properties。
  ///
  /// 之后所有事件都会自动附加这些属性（仅 PostHog 通道生效；
  /// 其他通道 no-op）。值在事件发出时被冻结，不会被未来覆盖。
  /// 用户未同意采集时静默丢弃。
  Future<void> registerSuperProperties(Map<String, Object> properties) async {
    if (!_consent.hasConsented) return;
    try {
      await _channel.registerSuperProperties(properties);
    } catch (_) {
      // 埋点永远不应影响主业务流程，静默忽略所有异常
    }
  }
}
