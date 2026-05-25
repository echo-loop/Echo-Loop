// 添加音频对话框
//
// 支持两种模式：
// - 有 collectionId：添加音频后自动关联到指定合集
// - 无 collectionId：显示合集下拉框，可选择归入合集
//
// 支持一次选择多个音频文件批量添加。
// 单文件添加成功后返回 [AudioItem] 供调用方弹出字幕确认；
// 多文件直接添加，不弹字幕确认。
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import '../utils/app_data_dir.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/audio_item.dart';
import '../providers/collection_provider.dart';
import '../providers/audio_library_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/audio_duration.dart';

/// 已选中的音频文件信息
typedef _PickedAudio = ({
  String path,
  String name,
  String fileName,
  int fileSize,
});

/// 添加音频对话框 — 支持批量选择
///
/// 返回值：
/// - `List<AudioItem>` — 成功添加的音频列表
/// - `null` — 用户取消
class AddAudioDialog extends ConsumerStatefulWidget {
  /// 合集 ID（为 null 时显示合集下拉框）
  final String? collectionId;

  const AddAudioDialog({super.key, this.collectionId});

  @override
  ConsumerState<AddAudioDialog> createState() => _AddAudioDialogState();
}

class _AddAudioDialogState extends ConsumerState<AddAudioDialog> {
  /// 已选中的音频文件列表
  List<_PickedAudio> _pickedFiles = [];

  bool _isLoading = false;

  /// 批量添加时的进度
  int _processedCount = 0;

  /// 用户选择的合集 ID（仅 collectionId == null 时使用）
  String? _selectedCollectionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        widget.collectionId != null ? l10n.addAudioToCollection : l10n.addAudio,
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickAudioFiles,
                icon: const Icon(Icons.audiotrack),
                label: Text(l10n.selectAudioFile),
              ),
            ),
            // 已选文件列表
            if (_pickedFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              // 多文件时显示文件数量 + 总大小
              if (_pickedFiles.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${l10n.filesSelected(_pickedFiles.length)}'
                    '  ·  ${_formatFileSize(_pickedFiles.fold<int>(0, (sum, f) => sum + f.fileSize))}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _pickedFiles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final file = _pickedFiles[index];
                      return _buildFileRow(file, index, colorScheme);
                    },
                  ),
                ),
              ),
            ],
            // 加载进度
            if (_isLoading && _pickedFiles.length > 1) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _processedCount / _pickedFiles.length,
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(
                  context,
                )!.processingFileOf(_processedCount + 1, _pickedFiles.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            // 无 collectionId 时显示合集下拉框
            if (widget.collectionId == null) ...[
              const SizedBox(height: 16),
              _buildCollectionDropdown(l10n),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _pickedFiles.isEmpty || _isLoading
                    ? null
                    : _addAudio,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.add),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建单个文件行（单行：图标 + 文件名 + 大小 + 删除）
  Widget _buildFileRow(_PickedAudio file, int index, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4, right: 4),
      child: Row(
        children: [
          Icon(Icons.audio_file_outlined, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              file.fileName,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              _formatFileSize(file.fileSize),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        _pickedFiles = List.of(_pickedFiles)..removeAt(index);
                      }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化文件大小
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 构建合集下拉选择框
  ///
  /// 精选/官方合集（[Collection.isOfficial]）由远端定义，用户不能向其中添加自有音频，
  /// 因此下拉框只展示本地合集。
  Widget _buildCollectionDropdown(AppLocalizations l10n) {
    final collections = ref
        .watch(collectionListProvider)
        .rawCollections
        .where((c) => !c.isOfficial)
        .toList();
    return DropdownButtonFormField<String?>(
      initialValue: _selectedCollectionId,
      decoration: InputDecoration(
        labelText: l10n.selectCollection,
        isDense: true,
      ),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(l10n.noCollection)),
        ...collections.map(
          (c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
        ),
      ],
      onChanged: _isLoading
          ? null
          : (value) => setState(() => _selectedCollectionId = value),
    );
  }

  /// 选择音频文件（支持多选）
  Future<void> _pickAudioFiles() async {
    try {
      final FilePickerResult? result;
      const extensions = ['mp3', 'wav', 'm4a', 'aac', 'flac'];

      if (!kIsWeb && Platform.isIOS) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: extensions,
          allowMultiple: true,
        );
      } else {
        final initialDir = !kIsWeb && Platform.isMacOS
            ? await _getDownloadsDirectory()
            : null;
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: extensions,
          allowMultiple: true,
          initialDirectory: initialDir,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final List<_PickedAudio> picked = [];
        for (final file in result.files) {
          final dest = await _savePickedFileToSandbox(file, 'audios');
          picked.add((
            path: dest,
            name: path.basenameWithoutExtension(dest),
            fileName: path.basename(dest),
            fileSize: file.size,
          ));
        }
        if (!mounted) return;
        setState(() => _pickedFiles = picked);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.pickAudioFileFailed}: $e')),
        );
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

  /// 保存文件到应用沙盒，返回相对于数据目录的相对路径
  Future<String> _savePickedFileToSandbox(
    PlatformFile file,
    String subdir,
  ) async {
    final dataDir = await getAppDataDirectory();
    final dir = Directory(path.join(dataDir.path, subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final baseName = file.name.isNotEmpty
        ? file.name
        : (file.path != null ? path.basename(file.path!) : 'file');
    final destPath = path.join(dir.path, baseName);

    // 如果文件已存在，直接返回相对路径
    if (await File(destPath).exists()) {
      return path.join(subdir, baseName);
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

    return path.join(subdir, baseName);
  }

  /// 批量添加音频
  Future<void> _addAudio() async {
    if (_pickedFiles.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final collectionId = widget.collectionId ?? _selectedCollectionId;
    final library = ref.read(audioLibraryProvider.notifier);
    final libraryState = ref.read(audioLibraryProvider);
    final collectionState = ref.read(collectionListProvider);

    setState(() {
      _isLoading = true;
      _processedCount = 0;
    });

    final List<AudioItem> results = [];
    final List<String> skippedDuplicates = [];
    const uuid = Uuid();

    for (var i = 0; i < _pickedFiles.length; i++) {
      final file = _pickedFiles[i];

      // 检查合集中是否已存在同名音频
      if (collectionId != null) {
        final collection = collectionState.rawCollections
            .where((c) => c.id == collectionId)
            .firstOrNull;
        if (collection != null) {
          final existingAudioIds = collectionState.getAudioIds(collectionId);
          final isDupInCollection = existingAudioIds.any((id) {
            final item = library.getItemById(id);
            return item != null && item.name == file.name;
          });
          if (isDupInCollection) {
            skippedDuplicates.add(file.name);
            setState(() => _processedCount = i + 1);
            continue;
          }
        }
      }

      // 检查音频库中是否已存在同名音频
      final existingItem = libraryState.audioItems
          .where((item) => item.name == file.name)
          .firstOrNull;

      String audioId;
      AudioItem resultItem;

      if (existingItem != null) {
        if (collectionId != null) {
          // 有合集：音频已存在于库中，直接关联
          audioId = existingItem.id;
          resultItem = existingItem;
        } else {
          // 无合集：跳过重复
          skippedDuplicates.add(file.name);
          setState(() => _processedCount = i + 1);
          continue;
        }
      } else {
        // 新音频，添加到音频库
        final duration = await getAudioDurationSeconds(file.path);
        final audioItem = AudioItem(
          id: uuid.v4(),
          name: file.name,
          audioPath: file.path,
          addedDate: DateTime.now(),
          totalDuration: duration,
        );
        await library.addAudioItem(audioItem);
        audioId = audioItem.id;
        resultItem = audioItem;
      }

      // 关联到合集
      if (collectionId != null && mounted) {
        await ref
            .read(collectionListProvider.notifier)
            .addAudioToCollection(collectionId, audioId);
      }

      results.add(resultItem);
      setState(() => _processedCount = i + 1);
    }

    if (!mounted) return;

    // 有跳过项时弹窗提示
    if (skippedDuplicates.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.duplicatesSkipped(skippedDuplicates.length)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.duplicatesSkippedDetail),
              const SizedBox(height: 8),
              ...skippedDuplicates.map((name) => Text('• $name')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    }

    if (mounted) {
      Navigator.pop(context, results);
    }
  }
}
