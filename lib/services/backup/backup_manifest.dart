/// 备份清单（对应 ZIP 内 manifest.json）
///
/// 记录备份的元数据，用于导入前验证和预览。
class BackupManifest {
  /// 备份格式版本，当前固定为 1
  final int version;

  /// 创建备份时的 App 版本号
  final String appVersion;

  /// 数据库 schema 版本
  final int schemaVersion;

  /// 备份创建时间
  final DateTime createdAt;

  /// 平台标识（ios / macos / android）
  final String platform;

  /// 数据库文件 SHA256 校验值
  final String dbSha256;

  /// 媒体文件数量
  final int mediaFileCount;

  /// 备份总大小（字节）
  final int totalSizeBytes;

  /// 已备份的离线资源文件数量（ASR、TTS 模型与本地词典）。
  final int offlineResourceFileCount;

  /// 已备份的离线资源原始大小。
  final int offlineResourceSizeBytes;

  const BackupManifest({
    required this.version,
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.platform,
    required this.dbSha256,
    required this.mediaFileCount,
    required this.totalSizeBytes,
    this.offlineResourceFileCount = 0,
    this.offlineResourceSizeBytes = 0,
  });

  /// 从 JSON Map 反序列化
  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      version: json['version'] as int,
      appVersion: json['appVersion'] as String,
      schemaVersion: json['schemaVersion'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      platform: json['platform'] as String,
      dbSha256: json['dbSha256'] as String,
      mediaFileCount: json['mediaFileCount'] as int,
      totalSizeBytes: json['totalSizeBytes'] as int,
      offlineResourceFileCount: json['offlineResourceFileCount'] as int? ?? 0,
      offlineResourceSizeBytes: json['offlineResourceSizeBytes'] as int? ?? 0,
    );
  }

  /// 序列化为 JSON Map
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'appVersion': appVersion,
      'schemaVersion': schemaVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'platform': platform,
      'dbSha256': dbSha256,
      'mediaFileCount': mediaFileCount,
      'totalSizeBytes': totalSizeBytes,
      'offlineResourceFileCount': offlineResourceFileCount,
      'offlineResourceSizeBytes': offlineResourceSizeBytes,
    };
  }

  /// 格式化总大小为人类可读字符串
  String get formattedSize {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
