/// 备份清单（对应 ZIP 内 manifest.json）
///
/// 记录备份的元数据，用于导入前验证和预览。
class BackupManifest {
  /// 当前应用生成的备份格式版本。
  static const currentVersion = 3;

  /// 备份格式版本。
  final int version;

  /// 创建备份时的 App 版本号
  final String appVersion;

  /// 数据库 schema 版本
  final int schemaVersion;

  /// 备份数据已完成的应用升级迁移版本。
  ///
  /// v1/v2 和早期 v3 清单没有该字段时按 0 处理，恢复后幂等地
  /// 重放全部应用升级迁移。
  final int appUpdateMigrationVersion;

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

  /// 已备份的离线资源文件数量（ASR、TTS 模型与在线词典）。
  final int offlineResourceFileCount;

  /// 已备份的离线资源原始大小。
  final int offlineResourceSizeBytes;

  const BackupManifest({
    required this.version,
    required this.appVersion,
    required this.schemaVersion,
    this.appUpdateMigrationVersion = 0,
    required this.createdAt,
    required this.platform,
    required this.dbSha256,
    required this.mediaFileCount,
    required this.totalSizeBytes,
    this.offlineResourceFileCount = 0,
    this.offlineResourceSizeBytes = 0,
  });

  /// 从 JSON Map 反序列化
  factory BackupManifest.fromJson(Map<String, Object?> json) {
    return BackupManifest(
      version: _requiredInt(json, 'version'),
      appVersion: _requiredString(json, 'appVersion'),
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      appUpdateMigrationVersion: _optionalInt(
        json,
        'appUpdateMigrationVersion',
      ),
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')),
      platform: _requiredString(json, 'platform'),
      dbSha256: _requiredString(json, 'dbSha256'),
      mediaFileCount: _requiredInt(json, 'mediaFileCount'),
      totalSizeBytes: _requiredInt(json, 'totalSizeBytes'),
      offlineResourceFileCount: _optionalInt(json, 'offlineResourceFileCount'),
      offlineResourceSizeBytes: _optionalInt(json, 'offlineResourceSizeBytes'),
    );
  }

  /// 序列化为 JSON Map
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'appVersion': appVersion,
      'schemaVersion': schemaVersion,
      'appUpdateMigrationVersion': appUpdateMigrationVersion,
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

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Invalid backup manifest field: $key');
}

int _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return 0;
  if (value is int) return value;
  throw FormatException('Invalid backup manifest field: $key');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Invalid backup manifest field: $key');
}
