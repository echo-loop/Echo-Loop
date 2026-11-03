/// 开发者选项：下载任务调试页
///
/// 列出用户文件下载队列（网盘导入、播客音频、共享合集）的持久化任务，
/// 用于排查排队、重试与卡住问题。普通用户不可见。
library;

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/download_provider.dart';
import '../services/app_logger.dart';
import '../services/background_download_task_inspector.dart';
import '../utils/file_size.dart';

/// 下载任务调试页。
class DownloadTasksScreen extends ConsumerWidget {
  const DownloadTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadTaskInfosProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载任务'),
        actions: [
          IconButton(
            tooltip: '清除已结束',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () => _runAction(
              context,
              ref,
              failureMessage: '清除已结束任务失败',
              action: (inspector) => inspector.clearFinished(),
            ),
          ),
        ],
      ),
      body: tasks.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('暂无下载任务'))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final task = items[index];
                  return _DownloadTaskTile(
                    task: task,
                    onRemove: () => _runAction(
                      context,
                      ref,
                      failureMessage: '删除下载任务失败',
                      action: (inspector) => inspector.remove(task.taskId),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('读取下载任务失败：$error')),
      ),
    );
  }

  /// 执行一次调试操作。失败只记录错误类型，不展示原始异常文本，避免泄露 URL。
  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref, {
    required String failureMessage,
    required Future<void> Function(DownloadTaskInspector inspector) action,
  }) async {
    final inspector = ref.read(downloadTaskInspectorProvider);
    try {
      await action(inspector);
    } on Object catch (error) {
      AppLogger.log(
        'DownloadTasks',
        '$failureMessage errorType=${error.runtimeType}',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureMessage)));
      return;
    }
    if (!context.mounted) return;
    ref.invalidate(downloadTaskInfosProvider);
  }
}

class _DownloadTaskTile extends StatelessWidget {
  const _DownloadTaskTile({required this.task, required this.onRemove});

  final DownloadTaskInfo task;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = task.progress;
    return ListTile(
      title: Text(
        task.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'resource: ${task.resourceKey}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          Text(_summary(task)),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(value: progress),
            ),
          if (task.errorDescription != null)
            Text(
              task.errorDescription!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      trailing: IconButton(
        tooltip: '删除',
        icon: const Icon(Icons.delete_outline),
        onPressed: onRemove,
      ),
    );
  }

  String _summary(DownloadTaskInfo task) {
    final parts = <String>[
      if (task.host.isNotEmpty) task.host,
      _statusLabel(task.status),
      '剩余重试 ${task.retriesRemaining} 次',
      if (task.receivedBytes != null && task.expectedBytes != null)
        '${formatBytes(task.receivedBytes!)} / ${formatBytes(task.expectedBytes!)}',
    ];
    return parts.join(' · ');
  }

  String _statusLabel(TaskStatus status) => switch (status) {
    TaskStatus.enqueued => '排队中',
    TaskStatus.running => '下载中',
    TaskStatus.waitingToRetry => '等待重试',
    TaskStatus.paused => '已暂停',
    TaskStatus.complete => '已完成',
    TaskStatus.failed => '失败',
    TaskStatus.canceled => '已取消',
    TaskStatus.notFound => '未找到',
  };
}
