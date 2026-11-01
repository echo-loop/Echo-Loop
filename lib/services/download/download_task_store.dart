import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'download_failure.dart';

enum DownloadTaskStatus {
  notDownloaded,
  queued,
  downloading,
  downloaded,
  failed,
}

class DownloadTaskRecord {
  const DownloadTaskRecord({
    required this.resourceId,
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes,
    this.failure,
    this.updatedAt,
  });

  final String resourceId;
  final DownloadTaskStatus status;
  final int receivedBytes;
  final int? totalBytes;
  final DownloadFailureKind? failure;
  final DateTime? updatedAt;

  DownloadTaskRecord copyWith({
    DownloadTaskStatus? status,
    int? receivedBytes,
    int? totalBytes,
    DownloadFailureKind? failure,
    bool clearFailure = false,
  }) => DownloadTaskRecord(
    resourceId: resourceId,
    status: status ?? this.status,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    failure: clearFailure ? null : failure ?? this.failure,
    updatedAt: DateTime.now(),
  );

  Map<String, Object?> toJson() => {
    'resourceId': resourceId,
    'status': status.name,
    'receivedBytes': receivedBytes,
    'totalBytes': totalBytes,
    'failure': failure?.name,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  static DownloadTaskRecord? fromJson(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final status = DownloadTaskStatus.values.byName(json['status'] as String);
      final failureName = json['failure'] as String?;
      return DownloadTaskRecord(
        resourceId: json['resourceId'] as String,
        status: status,
        receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
        totalBytes: (json['totalBytes'] as num?)?.toInt(),
        failure: failureName == null
            ? null
            : DownloadFailureKind.values.byName(failureName),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}

abstract interface class DownloadTaskStore {
  Future<DownloadTaskRecord?> read(String resourceId);
  Future<void> write(DownloadTaskRecord record);
  Future<void> remove(String resourceId);
}

class SharedPreferencesDownloadTaskStore implements DownloadTaskStore {
  SharedPreferencesDownloadTaskStore(this._preferences);

  final SharedPreferences _preferences;
  static const _prefix = 'download_task_v1_';

  @override
  Future<DownloadTaskRecord?> read(String resourceId) async {
    final raw = _preferences.getString('$_prefix$resourceId');
    return raw == null ? null : DownloadTaskRecord.fromJson(raw);
  }

  @override
  Future<void> write(DownloadTaskRecord record) async {
    await _preferences.setString(
      '$_prefix${record.resourceId}',
      jsonEncode(record.toJson()),
    );
  }

  @override
  Future<void> remove(String resourceId) =>
      _preferences.remove('$_prefix$resourceId');
}
