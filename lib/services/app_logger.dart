/// 应用内日志服务
///
/// 环形缓冲区存储最近的日志，供开发者选项中的日志页面查看。
/// 全局单例，通过 [AppLogger.instance] 访问。
/// 调用 [AppLogger.log] 记录日志，同时会 print 到控制台。
library;

import 'dart:collection';

/// 单条日志
class LogEntry {
  final DateTime time;
  final String tag;
  final String message;

  const LogEntry({
    required this.time,
    required this.tag,
    required this.message,
  });

  @override
  String toString() {
    final t =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
    return '$t [$tag] $message';
  }
}

/// 应用内日志服务（环形缓冲区，最多保留 500 条）
class AppLogger {
  AppLogger._();
  static final instance = AppLogger._();

  static const _maxEntries = 500;
  final _entries = Queue<LogEntry>();
  final _listeners = <void Function()>[];

  /// 所有日志条目（只读）
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// 记录日志并 print 到控制台
  static void log(String tag, String message) {
    final entry = LogEntry(time: DateTime.now(), tag: tag, message: message);
    // ignore: avoid_print
    print(entry);
    final logger = instance;
    logger._entries.addLast(entry);
    if (logger._entries.length > _maxEntries) {
      logger._entries.removeFirst();
    }
    for (final listener in logger._listeners) {
      listener();
    }
  }

  /// 清空日志
  void clear() {
    _entries.clear();
    for (final listener in _listeners) {
      listener();
    }
  }

  /// 添加监听器（日志页面用于刷新 UI）
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }
}
