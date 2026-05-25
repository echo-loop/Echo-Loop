/// App 版本更新信息模型
///
/// 包含远程版本信息的数据模型和更新状态的 sealed class 定义。
library;

/// 远程版本信息
class AppUpdateInfo {
  /// 最新可用版本
  final String latestVersion;

  /// 最低兼容版本（低于此版本强制更新）
  final String minimumVersion;

  /// 更新说明（locale -> text）
  final Map<String, String> releaseNotes;

  /// 下载链接（platform -> url）
  final Map<String, String> downloadUrl;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.minimumVersion,
    this.releaseNotes = const {},
    this.downloadUrl = const {},
  });

  /// 从 JSON 解析
  ///
  /// [latestVersion] 和 [minimumVersion] 为必填字段，缺失或非 String 时抛 [FormatException]。
  /// [releaseNotes] 和 [downloadUrl] 缺失时降级为空 Map。
  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final latestVersion = json['latestVersion'];
    final minimumVersion = json['minimumVersion'];

    if (latestVersion is! String || latestVersion.isEmpty) {
      throw const FormatException(
        'latestVersion is required and must be a non-empty string',
      );
    }
    if (minimumVersion is! String || minimumVersion.isEmpty) {
      throw const FormatException(
        'minimumVersion is required and must be a non-empty string',
      );
    }

    return AppUpdateInfo(
      latestVersion: latestVersion,
      minimumVersion: minimumVersion,
      releaseNotes: _parseStringMap(json['releaseNotes']),
      downloadUrl: _parseStringMap(json['downloadUrl']),
    );
  }

  static Map<String, String> _parseStringMap(dynamic value) {
    if (value is! Map) return {};
    return value.map(
      (key, val) => MapEntry(key.toString(), val?.toString() ?? ''),
    );
  }
}

/// 更新类型
enum AppUpdateType {
  /// 无需更新
  none,

  /// 可选更新（可跳过）
  softUpdate,

  /// 强制更新（阻断）
  forceUpdate,
}

/// 更新状态
sealed class AppUpdateState {
  const AppUpdateState();
}

/// 初始状态
class AppUpdateInitial extends AppUpdateState {
  const AppUpdateInitial();
}

/// 检查中
class AppUpdateChecking extends AppUpdateState {
  const AppUpdateChecking();
}

/// 检查结果
class AppUpdateResult extends AppUpdateState {
  final AppUpdateType type;
  final AppUpdateInfo? info;

  const AppUpdateResult({required this.type, this.info});
}

/// 用户已忽略
class AppUpdateDismissed extends AppUpdateState {
  const AppUpdateDismissed();
}
