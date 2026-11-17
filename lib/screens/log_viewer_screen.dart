/// 开发者日志查看页面
///
/// 实时显示应用内日志，支持滚动、清空、分享。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:echo_loop/widgets/common/svg_action_icon.dart';

import '../services/app_logger.dart';
import '../services/device_diagnostics_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_data_dir.dart';

/// 日志分享启动函数，供 widget 测试替换系统分享面板。
typedef LogShareLauncher =
    Future<ShareResult> Function(
      List<XFile> files, {
      String? subject,
      String? text,
      Rect? sharePositionOrigin,
      List<String>? fileNameOverrides,
    });

/// 在后台 isolate 打包日志支持文件，避免 ZIP 压缩阻塞日志页面。
void _packLogSupportArchive({
  required String archivePath,
  required String logDirectory,
  required String fallbackLog,
}) {
  final archive = Archive();
  final directory = Directory(logDirectory);
  if (directory.existsSync()) {
    for (final entity in directory.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name == 'asr_crash.marker' ||
          (name.startsWith('asr_inference-') && name.endsWith('.pending'))) {
        continue;
      }
      final bytes = entity.readAsBytesSync();
      archive.addFile(ArchiveFile(p.join('logs', name), bytes.length, bytes));
    }
  }
  if (archive.isEmpty) {
    final bytes = utf8.encode(fallbackLog);
    archive.addFile(ArchiveFile('logs/app.log', bytes.length, bytes));
  }

  final encoded = ZipEncoder().encode(archive);
  File(archivePath).writeAsBytesSync(encoded, flush: true);
}

/// 日志查看页面
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key, this.shareLauncher});

  /// 系统分享启动函数。生产环境为空时使用 [Share.shareXFiles]。
  final LogShareLauncher? shareLauncher;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final _scrollController = ScrollController();
  final _deviceDiagnosticsService = const DeviceDiagnosticsService();
  Future<void>? _deviceInfoLogFuture;
  bool _didLogDeviceInfo = false;
  var _persistedEntries = const <LogEntry>[];
  var _displayedEntries = const <LogEntry>[];
  var _logUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _displayedEntries = AppLogger.instance.entries;
    AppLogger.instance.addListener(_onLogUpdated);
    unawaited(_loadPersistedEntries());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLogDeviceInfo) return;
    _didLogDeviceInfo = true;
    _deviceInfoLogFuture = _logDeviceInfo();
  }

  @override
  void dispose() {
    AppLogger.instance.removeListener(_onLogUpdated);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogUpdated() {
    if (!mounted || _logUpdateScheduled) return;
    _logUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logUpdateScheduled = false;
      if (!mounted) return;
      setState(_mergePersistedAndCurrentEntries);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// 日志页打开后才读取跨启动历史；内存日志继续用于实时刷新。
  Future<void> _loadPersistedEntries() async {
    final entries = await AppLogger.readRecentPersistedEntries();
    if (!mounted) return;
    setState(() {
      _persistedEntries = entries;
      _mergePersistedAndCurrentEntries();
    });
  }

  void _mergePersistedAndCurrentEntries() {
    final mergedByLine = <String, LogEntry>{};
    for (final entry in [..._persistedEntries, ...AppLogger.instance.entries]) {
      mergedByLine[entry.toString()] = entry;
    }
    final merged = mergedByLine.values.toList(growable: false);
    _displayedEntries = merged.length <= AppLogger.maxRetainedEntries
        ? merged
        : merged.sublist(merged.length - AppLogger.maxRetainedEntries);
  }

  Future<void> _clearLogs() async {
    await AppLogger.clearPersistedLogs();
    if (!mounted) return;
    setState(() {
      _persistedEntries = const <LogEntry>[];
      _displayedEntries = const <LogEntry>[];
    });
  }

  /// 记录设备信息快照，便于分享日志时直接包含机型、系统版本和 App 版本。
  Future<void> _logDeviceInfo() async {
    try {
      final line = await _deviceDiagnosticsService.buildLogLine(context);
      if (!mounted) return;
      AppLogger.log('DeviceInfo', line);
    } catch (e) {
      AppLogger.log('DeviceInfo', 'collect failed: $e');
    }
  }

  /// 分享日志支持包：保留轮转日志的原文件边界并压缩为一个 ZIP。
  ///
  /// 日志目录不可用时，用当前内存日志生成 `logs/app.log` 兜底；若 ASR 崩溃
  /// ASR 推理 pending 文件仅在推理进行中存在，不放入支持包。
  Future<void> _shareAll() async {
    AppLogger.log('LogViewer', 'share logs start');
    try {
      await _deviceInfoLogFuture;
      AppLogger.log('LogViewer', 'share logs device info ready');
      if (!mounted) return;
      final path = await _writeLogSupportArchive();
      AppLogger.log('LogViewer', 'share logs file ready: $path');
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final share = widget.shareLauncher ?? Share.shareXFiles;
      AppLogger.log(
        'LogViewer',
        'share logs launch custom=${widget.shareLauncher != null}',
      );
      await share(
        [XFile(path, mimeType: 'application/zip')],
        subject: 'Echo Loop Logs',
        sharePositionOrigin: box == null
            ? Rect.zero
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      AppLogger.log('LogViewer', 'share logs failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分享日志失败：$e')));
    }
  }

  /// 写入供系统分享使用的临时 ZIP 支持包。
  ///
  /// 分享后不能立即删除：macOS / AirDrop 可能在用户选择目标后才开始读取文件。
  /// `log_export_` 目录由 temp_cleanup_service 白名单回收。
  Future<String> _writeLogSupportArchive() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final dir = Directory(p.join(tempDir.path, 'log_export_$timestamp'));
    await dir.create(recursive: true);
    final archivePath = p.join(dir.path, 'echo_loop_logs_$timestamp.zip');
    final logDirectory = await appLogDirectoryPath();
    final fallbackLog = AppLogger.instance.entries
        .map((entry) => entry.toString())
        .join('\n');
    await Isolate.run(
      () => _packLogSupportArchive(
        archivePath: archivePath,
        logDirectory: logDirectory,
        fallbackLog: fallbackLog,
      ),
    );
    return archivePath;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _displayedEntries;

    return Scaffold(
      appBar: AppBar(
        title: Text('日志（最近 ${entries.length} 条）'),
        centerTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('log_viewer_share_button'),
            tooltip: '分享日志',
            icon: const SvgActionIcon(assetName: 'assets/icon/share.svg'),
            onPressed: entries.isEmpty ? null : () => unawaited(_shareAll()),
          ),
          IconButton(
            icon: const SvgActionIcon(assetName: 'assets/icon/trash-bin.svg'),
            onPressed: entries.isEmpty ? null : () => unawaited(_clearLogs()),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                '暂无日志',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s,
                    AppSpacing.s,
                    AppSpacing.s,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('仅显示最近 500 条；分享日志可导出完整记录'),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: entries.length,
                    padding: const EdgeInsets.all(AppSpacing.s),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _LogEntryTile(entry: entry);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// 单条日志显示
class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;
  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr =
        '${entry.time.hour.toString().padLeft(2, '0')}:'
        '${entry.time.minute.toString().padLeft(2, '0')}:'
        '${entry.time.second.toString().padLeft(2, '0')}.'
        '${entry.time.millisecond.toString().padLeft(3, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: timeStr,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            TextSpan(
              text: ' [${entry.tag}] ',
              style: TextStyle(
                color: _tagColor(entry.tag, theme),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            TextSpan(
              text: entry.message,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tagColor(String tag, ThemeData theme) {
    return switch (tag) {
      'Turn' => Colors.orange,
      'Player' => Colors.blue,
      'Screen' => Colors.green,
      _ => theme.colorScheme.primary,
    };
  }
}
