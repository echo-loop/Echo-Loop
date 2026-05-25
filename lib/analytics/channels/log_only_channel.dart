/// Debug 模式日志通道
///
/// 只将事件输出到 [AppLogger]，不发送到任何远程服务。
/// 在 `kDebugMode` 下自动使用，避免开发期间污染生产数据。
library;

import '../analytics_channel.dart';
import '../../services/app_logger.dart';

/// 仅打日志的分析通道（Debug 用）
class LogOnlyChannel implements AnalyticsChannel {
  static const _tag = 'Analytics';

  @override
  String get name => 'LogOnly';

  @override
  Future<void> initialize() async {
    AppLogger.log(_tag, 'LogOnlyChannel initialized (debug mode)');
  }

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    final params =
        parameters?.entries.map((e) => '${e.key}=${e.value}').join(', ') ?? '';
    AppLogger.log(_tag, 'Event: $name${params.isEmpty ? '' : ' {$params}'}');
  }

  @override
  Future<void> setUserId(String? id) async {
    AppLogger.log(_tag, 'setUserId: $id');
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    AppLogger.log(_tag, 'setUserProperty: $name=$value');
  }

  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {
    final pairs = properties.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    AppLogger.log(_tag, 'registerSuperProperties: {$pairs}');
  }
}
