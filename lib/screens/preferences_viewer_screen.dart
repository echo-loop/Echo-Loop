/// 开发者选项：偏好设置查看页
///
/// 展示当前 [SharedPreferences] 中保存的所有 key-value，
/// 方便排查用户设置相关的问题。支持关键字过滤、长按复制、整体复制，
/// 以及向左滑动单条 key 进行删除（仅供测试场景使用）。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 偏好设置查看页面。
class PreferencesViewerScreen extends StatefulWidget {
  const PreferencesViewerScreen({super.key});

  @override
  State<PreferencesViewerScreen> createState() =>
      _PreferencesViewerScreenState();
}

class _PreferencesViewerScreenState extends State<PreferencesViewerScreen> {
  /// 当前 SP 的全部条目（按 key 排序后的快照）。
  List<_PrefEntry> _entries = const [];

  /// 搜索关键字（同时匹配 key 和 value）。
  String _query = '';

  /// 是否正在加载。
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 读取全部 SharedPreferences 并生成快照。
  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList()..sort();
    final entries = keys.map((k) => _PrefEntry.from(prefs, k)).toList();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  /// 将所有条目以 `key: value` 的形式拼接复制到剪贴板。
  Future<void> _copyAll() async {
    final text = _entries.map((e) => '${e.key}: ${e.display}').join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制全部偏好设置到剪贴板')));
  }

  /// 过滤当前快照，忽略大小写匹配 key 或 value。
  List<_PrefEntry> get _filtered {
    if (_query.isEmpty) return _entries;
    final q = _query.toLowerCase();
    return _entries
        .where(
          (e) =>
              e.key.toLowerCase().contains(q) ||
              e.display.toLowerCase().contains(q),
        )
        .toList();
  }

  /// 弹出二次确认对话框，询问是否删除指定 [key]。
  ///
  /// 仅用于开发者测试场景。返回 `true` 时调用方应执行删除。
  Future<bool> _confirmDelete(String key) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('删除偏好设置？'),
          content: Text('key: $key\n此操作不可撤销，仅用于测试。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// 从 [SharedPreferences] 中删除 [key]，并同步更新内存快照与 UI 提示。
  ///
  /// 直接增量更新 [_entries]，避免重新走 [_load] 引起的列表抖动。
  Future<void> _deleteKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    if (!mounted) return;
    setState(() {
      _entries = _entries.where((e) => e.key != key).toList();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除 $key')));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('偏好设置'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            tooltip: '复制全部',
            icon: const Icon(Icons.copy_all),
            onPressed: _entries.isEmpty ? null : _copyAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索 key 或 value',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '共 ${_entries.length} 条${_query.isEmpty ? '' : ' · 命中 ${filtered.length} 条'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      _entries.isEmpty ? '无偏好设置' : '无匹配项',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final theme = Theme.of(context);
                      return Dismissible(
                        key: ValueKey('pref-${entry.key}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: theme.colorScheme.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Icon(
                            Icons.delete,
                            color: theme.colorScheme.onError,
                          ),
                        ),
                        confirmDismiss: (_) => _confirmDelete(entry.key),
                        onDismissed: (_) => _deleteKey(entry.key),
                        child: _PrefTile(entry: entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 列表行：展示单条偏好设置，支持点击复制。
class _PrefTile extends StatelessWidget {
  const _PrefTile({required this.entry});

  final _PrefEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(entry.key, style: theme.textTheme.titleSmall),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          entry.display,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: Text(
        entry.typeLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      onLongPress: () async {
        await Clipboard.setData(
          ClipboardData(text: '${entry.key}: ${entry.display}'),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已复制 ${entry.key}')));
      },
    );
  }
}

/// 单条偏好设置快照，仅承载展示所需的派生字段。
class _PrefEntry {
  _PrefEntry({
    required this.key,
    required this.display,
    required this.typeLabel,
  });

  final String key;
  final String display;
  final String typeLabel;

  /// 从 [prefs] 读取 [key] 对应值，自动识别类型并格式化。
  ///
  /// 字符串形态若为合法 JSON 对象/数组则会 pretty-print，便于阅读复杂设置。
  factory _PrefEntry.from(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    final String display;
    final String typeLabel;
    if (value is String) {
      typeLabel = 'String';
      display = _tryPrettyJson(value) ?? value;
    } else if (value is bool) {
      typeLabel = 'bool';
      display = value.toString();
    } else if (value is int) {
      typeLabel = 'int';
      display = value.toString();
    } else if (value is double) {
      typeLabel = 'double';
      display = value.toString();
    } else if (value is List<String>) {
      typeLabel = 'List<String>';
      display = const JsonEncoder.withIndent('  ').convert(value);
    } else {
      typeLabel = value?.runtimeType.toString() ?? 'null';
      display = value?.toString() ?? 'null';
    }
    return _PrefEntry(key: key, display: display, typeLabel: typeLabel);
  }
}

/// 尝试将字符串解析成 JSON 并 pretty-print，失败返回 null。
String? _tryPrettyJson(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final first = trimmed.codeUnitAt(0);
  // 只处理对象和数组开头，避免误把普通字符串（如 "zh"）当成 JSON。
  if (first != 0x7B /* { */ && first != 0x5B /* [ */ ) return null;
  try {
    final decoded = jsonDecode(trimmed);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return null;
  }
}
