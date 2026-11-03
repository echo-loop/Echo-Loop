import 'package:background_downloader/background_downloader.dart';

import 'background_file_download_service.dart';

/// 开发者调试页展示的下载任务只读视图。
///
/// 只保留文件名与 host，不保留完整 URL 和请求头，避免调试页泄露签名参数。
class DownloadTaskInfo {
  const DownloadTaskInfo({
    required this.taskId,
    required this.resourceKey,
    required this.displayName,
    required this.host,
    required this.status,
    required this.progress,
    required this.receivedBytes,
    required this.expectedBytes,
    required this.retriesRemaining,
    required this.errorDescription,
  });

  final String taskId;

  /// 资源标识；同一资源的所有入口共享同一个下载任务。
  final String resourceKey;

  /// 用户可读名称（与下载通知一致）；未提供时回退为落盘文件名，后者常是 UUID。
  final String displayName;
  final String host;
  final TaskStatus status;

  /// 0 到 1 的进度；总大小未知或处于插件状态哨兵时为 null。
  final double? progress;
  final int? receivedBytes;
  final int? expectedBytes;
  final int retriesRemaining;

  /// 已脱敏的失败原因，任务没有失败时为 null。
  final String? errorDescription;

  bool get isFinished => status.isFinalState;
}

/// 用户文件下载队列的调试入口，只读取插件持久化记录，不参与下载流程。
///
/// 插件在注册了 group 回调后不再向 updates 流发事件，但状态与进度仍会写入
/// 持久化记录，因此通过轮询记录获取任务列表。
class DownloadTaskInspector {
  DownloadTaskInspector({required this.downloader});

  final FileDownloader downloader;

  /// 按创建时间倒序返回，最近发起的下载排在最前；插件默认顺序不保证。
  Future<List<DownloadTaskInfo>> list() async {
    final records = await downloader.database.allRecords(
      group: kUserFilesDownloadGroup,
    );
    final sortedRecords = [...records]
      ..sort((a, b) => b.task.creationTime.compareTo(a.task.creationTime));
    return sortedRecords.map(_toInfo).toList(growable: false);
  }

  /// 取消仍在运行或排队的任务，再删除持久化记录。
  Future<void> remove(String taskId) async {
    await downloader.cancelTaskWithId(taskId);
    await downloader.database.deleteRecordWithId(taskId);
  }

  /// 只删除已结束的记录，保留仍在队列中的任务。
  Future<void> clearFinished() async {
    final records = await downloader.database.allRecords(
      group: kUserFilesDownloadGroup,
    );
    final finishedIds = records
        .where((record) => record.status.isFinalState)
        .map((record) => record.taskId)
        .toList(growable: false);
    if (finishedIds.isEmpty) return;
    await downloader.database.deleteRecordsWithIds(finishedIds);
  }

  DownloadTaskInfo _toInfo(TaskRecord record) {
    final exception = record.exception;
    final expectedBytes = record.expectedFileSize > 0
        ? record.expectedFileSize
        : null;
    // 负数进度是插件的状态哨兵（失败、暂停、等待重试等），不代表真实进度。
    final progress = record.progress >= 0 ? record.progress : null;
    final receivedBytes = progress == null || expectedBytes == null
        ? null
        : (progress * expectedBytes).round().clamp(0, expectedBytes).toInt();
    return DownloadTaskInfo(
      taskId: record.taskId,
      resourceKey: record.task.metaData,
      displayName: record.task.displayName.isNotEmpty
          ? record.task.displayName
          : record.task.filename,
      host: _hostOf(record.task.url),
      status: record.status,
      progress: progress,
      receivedBytes: receivedBytes,
      expectedBytes: expectedBytes,
      retriesRemaining: record.task.retriesRemaining,
      errorDescription: exception == null
          ? null
          : safeTaskExceptionDescription(exception),
    );
  }

  String _hostOf(String url) => Uri.tryParse(url)?.host ?? '';
}
