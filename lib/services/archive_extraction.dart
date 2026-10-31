/// 归档解压的后台执行入口。
///
/// `archive` 包的 `extractFileToDisk` 基于同步 IO 且同步解压，直接在 UI isolate
/// 调用会冻结界面（下载模型时表现为进度条卡在 100%、页面白屏）。
library;

import 'dart:isolate';

import 'package:archive/archive_io.dart';

import 'app_logger.dart';

/// 在后台 isolate 中把 [archivePath] 解压到 [outputPath]。
///
/// 只传递字符串路径，不捕获任何 UI 对象，保证可安全跨 isolate 发送。
/// 开始与结束各打一条日志（含耗时），便于在真机日志中确认解压不再阻塞界面。
Future<void> extractArchiveInBackground(
  String archivePath,
  String outputPath,
) async {
  final stopwatch = Stopwatch()..start();
  AppLogger.log('ArchiveExtract', 'start archive=$archivePath');
  try {
    await Isolate.run(() => extractFileToDisk(archivePath, outputPath));
  } catch (error) {
    AppLogger.log(
      'ArchiveExtract',
      'failed archive=$archivePath elapsedMs=${stopwatch.elapsedMilliseconds} error=$error',
    );
    rethrow;
  }
  AppLogger.log(
    'ArchiveExtract',
    'done archive=$archivePath elapsedMs=${stopwatch.elapsedMilliseconds}',
  );
}
