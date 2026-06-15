// 添加音频对话框
//
// 支持两种模式：
// - 有 collectionId：添加音频后自动关联到指定合集
// - 无 collectionId：显示合集下拉框，可选择归入合集
//
// 支持一次选择多个音频文件批量添加。
// 单文件添加成功后返回 [AudioItem] 供调用方弹出字幕确认；
// 多文件直接添加，不弹字幕确认。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import '../utils/app_data_dir.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../features/audio_import/audio_registration_service.dart';
import '../features/audio_import/audio_transcode_service.dart';
import '../models/audio_item.dart';
import '../providers/collection_provider.dart';
import '../providers/audio_library_provider.dart';
import '../l10n/app_localizations.dart';
import 'common/secondary_action_button.dart';

/// 已选中的音频文件信息
typedef _PickedAudio = ({
  String path,
  String name,
  String fileName,
  int fileSize,
});

/// 内联错误提示种类
enum _AudioErrorKind { unsupportedFormat, generic }

/// 内联错误条数据
class _InlineError {
  final _AudioErrorKind kind;
  final String message;
  const _InlineError(this.kind, this.message);
}

/// 添加音频对话框 — 支持批量选择
///
/// 返回值：
/// - `List<AudioItem>` — 成功添加的音频列表
/// - `null` — 用户取消
class AddAudioDialog extends ConsumerStatefulWidget {
  /// 合集 ID（为 null 时显示合集下拉框）
  final String? collectionId;
  final bool embedded;
  final VoidCallback? onBack;
  final ValueChanged<List<AudioItem>>? onComplete;
  final AudioImportSourceType importSourceType;
  final bool preferDownloadsDirectory;

  const AddAudioDialog({
    super.key,
    this.collectionId,
    this.embedded = false,
    this.onBack,
    this.onComplete,
    this.importSourceType = AudioImportSourceType.local,
    this.preferDownloadsDirectory = true,
  });

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

  /// 内联错误状态（避免 SnackBar 被 dialog scrim 遮蔽）
  _InlineError? _error;
  Timer? _errorClearTimer;

  @override
  void dispose() {
    _errorClearTimer?.cancel();
    super.dispose();
  }

  /// 显示内联错误条，6 秒后自动消失，重复触发重置倒计时
  void _showInlineError(_InlineError err) {
    _errorClearTimer?.cancel();
    setState(() => _error = err);
    _errorClearTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _error = null);
    });
  }

  void _dismissInlineError() {
    _errorClearTimer?.cancel();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    if (widget.embedded) {
      return _buildEmbeddedPanel(l10n, colorScheme);
    }

    // 自适应宽度：默认 AlertDialog 在窄屏（如 360dp 手机）会被 insetPadding 挤到
    // 极窄，文件名只能显示省略号；这里把侧边 inset 收紧到 16dp，并按屏幕宽度的
    // 90% 取宽（封顶 560dp，符合 Material 3 dialog 上限）。
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth - 32).clamp(280.0, 560.0);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        widget.collectionId != null ? l10n.addAudioToCollection : l10n.addAudio,
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: dialogWidth,
        child: _buildContent(l10n, colorScheme),
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

  Widget _buildEmbeddedPanel(AppLocalizations l10n, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContent(l10n, colorScheme, maxFileListHeight: 220),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SecondaryActionButton(
                onPressed: _isLoading
                    ? null
                    : (widget.onBack ?? () => Navigator.pop(context)),
                label: l10n.back,
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

  Widget _buildContent(
    AppLocalizations l10n,
    ColorScheme colorScheme, {
    double maxFileListHeight = 240,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSelectAudioFileButton(l10n, colorScheme),
        if (widget.embedded) ...[
          const SizedBox(height: 12),
          _buildCloudDriveHint(Theme.of(context), l10n),
        ],
        // 内联错误提示（淡入 + 上滑，6 秒自动消失）
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.08),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _error == null
                ? const SizedBox(
                    key: ValueKey('no-err'),
                    width: double.infinity,
                  )
                : Padding(
                    key: ValueKey(_error!.message),
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildInlineErrorCard(
                      Theme.of(context),
                      l10n,
                      _error!,
                    ),
                  ),
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
            constraints: BoxConstraints(maxHeight: maxFileListHeight),
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
          LinearProgressIndicator(value: _processedCount / _pickedFiles.length),
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
    );
  }

  /// 构建本地音频选择入口，保留明确按钮语义并弱化相对底部主操作的层级。
  Widget _buildSelectAudioFileButton(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      key: const ValueKey('select-audio-file-button'),
      width: double.infinity,
      height: 56,
      child: FilledButton.tonalIcon(
        onPressed: _isLoading ? null : _pickAudioFiles,
        style: FilledButton.styleFrom(
          foregroundColor: colorScheme.onSecondaryContainer,
          backgroundColor: colorScheme.secondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.audio_file_outlined),
        label: Text(
          l10n.selectAudioFile,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCloudDriveHint(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.audioFilePickerCloudDriveHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单个文件行（单行：图标 + 文件名 + 大小 + 删除）
  Widget _buildFileRow(_PickedAudio file, int index, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.audio_file_outlined, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              file.fileName,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatFileSize(file.fileSize),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
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

  /// 内联错误提示卡片（与 ManageSubtitlesSheet 视觉一致：浅灰描边 + 橙色图标徽章）
  Widget _buildInlineErrorCard(
    ThemeData theme,
    AppLocalizations l10n,
    _InlineError err,
  ) {
    final colorScheme = theme.colorScheme;
    final accent = Colors.orange.shade700;

    final (IconData icon, String title) = switch (err.kind) {
      _AudioErrorKind.unsupportedFormat => (
        Icons.audiotrack_outlined,
        l10n.audioErrorUnsupportedTitle,
      ),
      _AudioErrorKind.generic => (
        Icons.error_outline,
        l10n.audioErrorGenericTitle,
      ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. ${err.message}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：图标 + 标题 + 关闭
            Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _dismissInlineError,
                  icon: const Icon(Icons.close, size: 18),
                  color: colorScheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
            // 第二行：详细描述（与标题左对齐，占满剩余宽度）
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 2, 4, 0),
              child: Text(
                err.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

      if (!kIsWeb && Platform.isAndroid) {
        // Android SAF 在 FileType.custom + EXTRA_MIME_TYPES 多扩展名场景下
        // 会按精确 MIME 匹配，导致 m4a/flac 等被设备索引成非标 MIME 的文件被灰掉、无法选中。
        // 改用 FileType.audio（audio/*），picker 端不过滤具体类型，我们自己按扩展名白名单过滤。
        result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          allowMultiple: true,
        );
      } else if (!kIsWeb && Platform.isIOS) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: extensions,
          allowMultiple: true,
        );
      } else {
        final initialDir =
            widget.preferDownloadsDirectory && !kIsWeb && Platform.isMacOS
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
        final supportedSet = extensions.toSet();
        final List<_PickedAudio> picked = [];
        final List<String> rejectedExts = [];

        for (final file in result.files) {
          final ext = path
              .extension(file.name)
              .replaceFirst('.', '')
              .toLowerCase();
          if (!supportedSet.contains(ext)) {
            rejectedExts.add(ext.isNotEmpty ? ext : '?');
            continue;
          }
          final dest = await _savePickedFileToSandbox(file, 'audios');
          picked.add((
            path: dest,
            name: path.basenameWithoutExtension(dest),
            fileName: path.basename(dest),
            fileSize: file.size,
          ));
        }

        if (!mounted) return;
        if (rejectedExts.isNotEmpty) {
          final l10n = AppLocalizations.of(context)!;
          final extList = rejectedExts.toSet().map((e) => '.$e').join(', ');
          _showInlineError(
            _InlineError(
              _AudioErrorKind.unsupportedFormat,
              l10n.audioUnsupportedFormat(extList),
            ),
          );
        }
        if (picked.isNotEmpty) {
          setState(() => _pickedFiles = picked);
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showInlineError(
          _InlineError(
            _AudioErrorKind.generic,
            '${l10n.pickAudioFileFailed}: $e',
          ),
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
    final finalDir = Directory(path.join(dataDir.path, subdir));
    final tmpDir = Directory(path.join(dataDir.path, 'tmp', 'audio_import'));
    await finalDir.create(recursive: true);
    await tmpDir.create(recursive: true);

    final baseName = file.name.isNotEmpty
        ? file.name
        : (file.path != null ? path.basename(file.path!) : 'file');
    final finalPath = path.join(finalDir.path, baseName);

    // 如果文件已存在，直接返回相对路径
    if (await File(finalPath).exists()) {
      return path.join(subdir, baseName);
    }

    final tmpName =
        '${DateTime.now().microsecondsSinceEpoch}-${path.basename(baseName)}';
    final tmpPath = path.join(tmpDir.path, tmpName);

    // 先复制到临时目录，转码/回退决策完成后再移动到正式音频目录。
    if (file.path != null) {
      await File(file.path!).copy(tmpPath);
    } else if (file.bytes != null) {
      await File(tmpPath).writeAsBytes(file.bytes!);
    } else if (file.readStream != null) {
      final out = File(tmpPath).openWrite();
      await file.readStream!.pipe(out);
      await out.close();
    } else {
      throw Exception('Unable to access picked file');
    }

    final tmpRelativePath = path.join('tmp', 'audio_import', tmpName);
    final transcodeResult = await AudioTranscodeService().transcodeToM4a(
      dataDir: dataDir,
      relativePath: tmpRelativePath,
    );
    final sourceRelativePath = transcodeResult.relativePath;
    final sourceFile = File(path.join(dataDir.path, sourceRelativePath));
    final requestedBase = path.basenameWithoutExtension(baseName);
    final targetName = transcodeResult.transcoded
        ? '$requestedBase.m4a'
        : baseName;
    final finalName = await _uniqueSandboxFileName(finalDir, targetName);
    final finalFile = File(path.join(finalDir.path, finalName));

    await _movePickedAudioToFinal(sourceFile: sourceFile, finalFile: finalFile);
    await _deleteIfExists(File(tmpPath));

    return path.join(subdir, finalName);
  }

  /// 将本地导入的临时音频移动到正式目录；失败时清理可能写出的半文件。
  Future<void> _movePickedAudioToFinal({
    required File sourceFile,
    required File finalFile,
  }) async {
    try {
      await sourceFile.rename(finalFile.path);
      return;
    } on FileSystemException {
      try {
        await sourceFile.copy(finalFile.path);
        await _deleteIfExists(sourceFile);
        return;
      } on FileSystemException catch (e) {
        await _deleteIfExists(finalFile);
        throw Exception('Failed to save picked audio: ${e.message}');
      }
    }
  }

  Future<String> _uniqueSandboxFileName(Directory dir, String requested) async {
    var candidate = requested;
    final base = path.basenameWithoutExtension(requested);
    final ext = path.extension(requested);
    for (var i = 0; await File(path.join(dir.path, candidate)).exists(); i++) {
      candidate = '$base-${DateTime.now().microsecondsSinceEpoch}-$i$ext';
    }
    return candidate;
  }

  Future<void> _deleteIfExists(File file) async {
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }

  /// 批量添加音频
  Future<void> _addAudio() async {
    if (_pickedFiles.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final collectionId = widget.collectionId ?? _selectedCollectionId;
    final library = ref.read(audioLibraryProvider.notifier);
    final libraryState = ref.read(audioLibraryProvider);
    final collectionState = ref.read(collectionListProvider);
    final collectionList = ref.read(collectionListProvider.notifier);
    final registrationService = AudioRegistrationService();

    setState(() {
      _isLoading = true;
      _processedCount = 0;
    });

    final List<AudioItem> results = [];
    final List<String> skippedDuplicates = [];

    for (var i = 0; i < _pickedFiles.length; i++) {
      final file = _pickedFiles[i];

      final result = await registrationService.registerSandboxedAudio(
        input: SandboxedAudioRegistrationInput(
          name: file.name,
          relativePath: file.path,
          importSourceType: widget.importSourceType,
        ),
        audioLibrary: library,
        audioLibraryState: libraryState,
        collectionList: collectionList,
        collectionState: collectionState,
        collectionId: collectionId,
      );

      switch (result) {
        case AudioRegistrationAdded(:final item):
          results.add(item);
        case AudioRegistrationDuplicate(:final name):
          skippedDuplicates.add(name);
      }

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

    if (mounted && widget.embedded) {
      widget.onComplete?.call(results);
      return;
    }

    if (mounted) {
      Navigator.pop(context, results);
    }
  }
}
