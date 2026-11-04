/// 云盘文件与导入结果通用模型。
///
/// 任务 2 先定义稳定模型边界；实际目录列表、下载和入库会在后续任务中实现。
library;

/// 云盘条目。
class CloudDriveEntry {
  /// 构造云盘条目。
  const CloudDriveEntry({
    required this.fsId,
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    this.modifiedAt,
  });

  /// 从百度 `xpan/file?method=list` 或 `filemetas` 响应解析条目。
  factory CloudDriveEntry.fromBaiduJson(Map<dynamic, dynamic> json) {
    final rawIsDir = json['isdir'];
    return CloudDriveEntry(
      fsId: _asInt(json['fs_id']),
      name: _asString(json['server_filename']),
      path: _asString(json['path']),
      isDirectory: rawIsDir == 1 || rawIsDir == true,
      size: _asInt(json['size']),
      modifiedAt: _dateTimeFromSeconds(json['server_mtime'] ?? json['mtime']),
    );
  }

  /// 百度 fs_id。
  final int fsId;

  /// 展示名称。
  final String name;

  /// 百度返回的云端路径。
  final String path;

  /// 是否为目录。
  final bool isDirectory;

  /// 文件大小；目录通常为 0。
  final int size;

  /// 修改时间。
  final DateTime? modifiedAt;

  /// 文件扩展名，小写且不含点。
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}

/// 云盘分页结果。
class CloudDriveListPage {
  /// 构造分页结果。
  const CloudDriveListPage({
    required this.entries,
    required this.nextStart,
    required this.hasMore,
  });

  /// 当前页条目。
  final List<CloudDriveEntry> entries;

  /// 下一页 start 参数。
  final int nextStart;

  /// 是否可能还有下一页。
  final bool hasMore;
}

/// 百度 dlink 元信息。
class BaiduDownloadLink {
  /// 构造 dlink 元信息。
  const BaiduDownloadLink({
    required this.fsId,
    required this.dlink,
    this.size,
    this.name,
  });

  /// 从百度 `filemetas` 响应的单项解析。
  factory BaiduDownloadLink.fromBaiduJson(Map<dynamic, dynamic> json) {
    return BaiduDownloadLink(
      fsId: _asInt(json['fs_id']),
      dlink: _asString(json['dlink']),
      size: _nullableInt(json['size']),
      name: _nullableString(json['server_filename'] ?? json['filename']),
    );
  }

  /// 百度 fs_id。
  final int fsId;

  /// 百度临时下载链接。
  final String dlink;

  /// 文件大小。
  final int? size;

  /// 文件名。
  final String? name;
}

/// 百度网盘文件 API 错误类型。
enum BaiduNetdiskFileErrorKind {
  /// access token 缺失或已失效。
  unauthorized,

  /// 请求参数无效或服务端拒绝。
  badRequest,

  /// 文件不存在或无权访问。
  notFound,

  /// 服务端限流。
  rateLimited,

  /// 网络或服务临时不可用。
  network,

  /// 用户取消。
  canceled,

  /// 未知错误。
  unknown,
}

/// 百度网盘文件 API 异常。
class BaiduNetdiskFileException implements Exception {
  /// 构造文件 API 异常。
  const BaiduNetdiskFileException({
    required this.kind,
    required this.message,
    this.errno,
    this.cause,
  });

  /// 稳定错误类型。
  final BaiduNetdiskFileErrorKind kind;

  /// 可展示或记录的错误消息。
  final String message;

  /// 百度 errno。
  final int? errno;

  /// 原始异常。
  final Object? cause;

  @override
  String toString() {
    final suffix = errno == null ? '' : ' errno=$errno';
    return 'BaiduNetdiskFileException(${kind.name}$suffix, $message)';
  }
}

int _asInt(Object? value) {
  final parsed = _nullableInt(value);
  if (parsed != null) return parsed;
  throw FormatException('Expected integer, got $value');
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String _asString(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Expected non-empty string, got $value');
}

String? _nullableString(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

DateTime? _dateTimeFromSeconds(Object? value) {
  final seconds = _nullableInt(value);
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: false);
}
