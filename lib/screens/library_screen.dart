import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/audio_item.dart';
import '../providers/audio_library_provider.dart';
import '../providers/player_provider.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Audio',
            onPressed: () => _showAddAudioDialog(context),
          ),
        ],
      ),
      body: Consumer<AudioLibraryProvider>(
        builder: (context, library, child) {
          if (library.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (library.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_music_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No audio files yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add your first audio',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: library.audioItems.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final item = library.audioItems[index];
              return _AudioListTile(audioItem: item);
            },
          );
        },
      ),
    );
  }

  void _showAddAudioDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const _AddAudioDialog());
  }
}

class _AudioListTile extends StatelessWidget {
  final AudioItem audioItem;

  const _AudioListTile({required this.audioItem});

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final isCurrentlyPlaying =
        playerProvider.currentAudioItem?.id == audioItem.id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: isCurrentlyPlaying ? 4 : 1,
      color: null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.audiotrack,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          audioItem.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            if (audioItem.hasTranscript) ...[
              Icon(
                Icons.subtitles,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Transcript',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              'Added: ${_formatDate(audioItem.addedDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentlyPlaying)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Playing',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDelete(context);
                }
              },
            ),
          ],
        ),
        onTap: () async {
          // 验证音频文件是否存在（使用相对路径动态获取完整路径）
          final fullAudioPath = await audioItem.getFullAudioPath();
          final audioFile = File(fullAudioPath);
          if (!await audioFile.exists()) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Audio file not found. The file may have been deleted.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
            // 从库中移除无效条目
            context.read<AudioLibraryProvider>().removeAudioItem(audioItem.id);
            return;
          }
          await context.read<PlayerProvider>().loadAudio(audioItem);
          if (!context.mounted) return;
          Navigator.pushNamed(context, '/player');
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Audio'),
        content: Text('Are you sure you want to delete "${audioItem.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AudioLibraryProvider>().removeAudioItem(
                audioItem.id,
              );
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddAudioDialog extends StatefulWidget {
  const _AddAudioDialog();

  @override
  State<_AddAudioDialog> createState() => _AddAudioDialogState();
}

class _AddAudioDialogState extends State<_AddAudioDialog> {
  String? _audioPath;
  String? _transcriptPath;
  String _audioName = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Audio'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickAudioFile,
              icon: const Icon(Icons.audiotrack),
              label: const Text('Select Audio File'),
            ),
            if (_audioPath != null) ...[
              const SizedBox(height: 8),
              Text(
                path.basename(_audioPath!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickTranscriptFile,
              icon: const Icon(Icons.subtitles),
              label: const Text('Select Transcript (Optional)'),
            ),
            if (_transcriptPath != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      path.basename(_transcriptPath!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _transcriptPath = null;
                      });
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _audioPath == null || _isLoading ? null : _addAudio,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _pickAudioFile() async {
    try {
      final FilePickerResult? result;

      if (!kIsWeb && Platform.isIOS) {
        // iOS: 使用 custom 类型和明确的扩展名列表
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac'],
        );
      } else {
        // macOS 等其他平台：保持原有逻辑
        final initialDir = !kIsWeb && Platform.isMacOS
            ? await _getDownloadsDirectory()
            : null;
        result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          initialDirectory: initialDir,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        // 所有平台统一复制文件到应用沙盒，确保应用重装后仍可访问
        final dest = await _savePickedFileToSandbox(file, 'audios');
        if (!mounted) return;
        setState(() {
          _audioPath = dest;
          _audioName = path.basenameWithoutExtension(dest);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择音频文件失败: $e')));
      }
    }
  }

  Future<void> _pickTranscriptFile() async {
    try {
      final FilePickerResult? result;

      if (!kIsWeb && Platform.isIOS) {
        // iOS: 使用 custom 类型，配合 Info.plist 中注册的 UTType
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['srt', 'lrc', 'txt', 'vtt', 'ass', 'ssa'],
          allowMultiple: false,
        );
      } else {
        // macOS 等其他平台：保持原有逻辑
        final initialDir = !kIsWeb && Platform.isMacOS
            ? await _getDownloadsDirectory()
            : null;
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          initialDirectory: initialDir,
          allowMultiple: false,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        // 所有平台统一复制文件到应用沙盒，确保应用重装后仍可访问
        final dest = await _savePickedFileToSandbox(file, 'transcripts');
        if (!mounted) return;
        setState(() {
          _transcriptPath = dest;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择字幕文件失败: $e')));
      }
    }
  }

  Future<String?> _getDownloadsDirectory() async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return null;
      return path.join(home, 'Downloads');
    } catch (_) {
      return null;
    }
  }

  /// 保存文件到应用沙盒，返回相对于Documents目录的相对路径
  Future<String> _savePickedFileToSandbox(
    PlatformFile file,
    String subdir,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final baseName = file.name.isNotEmpty
        ? file.name
        : (file.path != null ? path.basename(file.path!) : 'file');
    final destPath = path.join(dir.path, baseName);

    // 如果文件已存在，直接返回相对路径
    if (await File(destPath).exists()) {
      return path.join(subdir, baseName); // 返回相对路径
    }

    // 文件不存在，复制到沙盒
    if (file.path != null) {
      await File(file.path!).copy(destPath);
    } else if (file.bytes != null) {
      await File(destPath).writeAsBytes(file.bytes!);
    } else if (file.readStream != null) {
      final out = File(destPath).openWrite();
      await file.readStream!.pipe(out);
      await out.close();
    } else {
      throw Exception('Unable to access picked file');
    }

    // 返回相对路径（相对于Documents目录）
    return path.join(subdir, baseName);
  }

  Future<void> _addAudio() async {
    if (_audioPath == null) return;

    // 检查是否已存在同名文件
    final library = context.read<AudioLibraryProvider>();
    final existingItem = library.audioItems.firstWhere(
      (item) => item.name == _audioName,
      orElse: () =>
          AudioItem(id: '', name: '', audioPath: '', addedDate: DateTime.now()),
    );

    if (existingItem.id.isNotEmpty) {
      // 已存在同名文件，提示用户先删除原音频
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('文件已存在'),
          content: Text('已存在名为 "$_audioName" 的音频文件，请先删除原音频后再导入。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final audioItem = AudioItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _audioName,
      audioPath: _audioPath!,
      transcriptPath: _transcriptPath,
      addedDate: DateTime.now(),
    );

    await library.addAudioItem(audioItem);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
