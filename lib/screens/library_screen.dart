import 'dart:io';
import 'package:flutter/material.dart';
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
        onTap: () {
          context.read<PlayerProvider>().loadAudio(audioItem);
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
    final downloadsPath = '${Platform.environment['HOME']}/Downloads';
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      initialDirectory: downloadsPath,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _audioPath = result.files.single.path;
        _audioName = path.basenameWithoutExtension(_audioPath!);
      });
    }
  }

  Future<void> _pickTranscriptFile() async {
    final downloadsPath = '${Platform.environment['HOME']}/Downloads';
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      allowMultiple: false,
      initialDirectory: downloadsPath,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _transcriptPath = result.files.single.path;
      });
    }
  }

  Future<void> _addAudio() async {
    if (_audioPath == null) return;

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

    await context.read<AudioLibraryProvider>().addAudioItem(audioItem);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
