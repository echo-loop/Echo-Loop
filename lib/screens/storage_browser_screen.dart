/// 开发者工具：应用内部存储浏览器。
///
/// 列举 Application Support、Documents、tmp 目录下的文件和子目录，
/// 显示各项大小，支持点击进入子目录。用于排查存储占用问题。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/file_size.dart';

/// 应用内部存储浏览页面。
class StorageBrowserScreen extends StatefulWidget {
  const StorageBrowserScreen({super.key});

  @override
  State<StorageBrowserScreen> createState() => _StorageBrowserScreenState();
}

class _StorageBrowserScreenState extends State<StorageBrowserScreen> {
  late Future<List<_StorageRoot>> _rootsFuture;

  @override
  void initState() {
    super.initState();
    _rootsFuture = _loadRoots();
  }

  Future<List<_StorageRoot>> _loadRoots() async {
    final roots = <_StorageRoot>[];

    final appSupport = await getApplicationSupportDirectory();
    roots.add(_StorageRoot(label: 'Application Support', dir: appSupport));

    final docs = await getApplicationDocumentsDirectory();
    roots.add(_StorageRoot(label: 'Documents', dir: docs));

    final tmp = await getTemporaryDirectory();
    roots.add(_StorageRoot(label: 'Temporary', dir: tmp));

    // 计算各根目录大小。
    for (final root in roots) {
      if (root.dir.existsSync()) {
        root.sizeBytes = await calculateDirectorySize(root.dir);
      }
    }
    return roots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('内部存储')),
      body: FutureBuilder<List<_StorageRoot>>(
        future: _rootsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final roots = snapshot.data ?? [];
          return ListView.separated(
            itemCount: roots.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final root = roots[index];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(root.label),
                subtitle: Text(root.dir.path),
                trailing: Text(
                  formatBytes(root.sizeBytes),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _DirectoryScreen(
                      title: root.label,
                      directory: root.dir,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// 子目录浏览页面。
class _DirectoryScreen extends StatefulWidget {
  final String title;
  final Directory directory;

  const _DirectoryScreen({required this.title, required this.directory});

  @override
  State<_DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<_DirectoryScreen> {
  late Future<List<_FileEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadEntries();
  }

  Future<List<_FileEntry>> _loadEntries() async {
    if (!widget.directory.existsSync()) return [];

    final entries = <_FileEntry>[];
    await for (final entity in widget.directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        final size = await calculateDirectorySize(entity);
        entries.add(
          _FileEntry(
            name: name,
            path: entity.path,
            isDirectory: true,
            sizeBytes: size,
          ),
        );
      } else if (entity is File) {
        final size = await entity.length();
        entries.add(
          _FileEntry(
            name: name,
            path: entity.path,
            isDirectory: false,
            sizeBytes: size,
          ),
        );
      }
    }

    // 目录在前，文件在后；各自按大小降序。
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return b.sizeBytes.compareTo(a.sizeBytes);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<_FileEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(child: Text('(空目录)'));
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: Icon(
                  entry.isDirectory ? Icons.folder : Icons.insert_drive_file,
                ),
                title: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  formatBytes(entry.sizeBytes),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: entry.isDirectory
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _DirectoryScreen(
                            title: entry.name,
                            directory: Directory(entry.path),
                          ),
                        ),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 数据类
// ---------------------------------------------------------------------------

class _StorageRoot {
  final String label;
  final Directory dir;
  int sizeBytes = 0;

  _StorageRoot({required this.label, required this.dir});
}

class _FileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int sizeBytes;

  const _FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.sizeBytes,
  });
}
