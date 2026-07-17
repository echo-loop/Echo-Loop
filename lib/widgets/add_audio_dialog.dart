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
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import '../utils/app_data_dir.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../features/audio_import/audio_finalization_service.dart';
import '../features/audio_import/audio_registration_service.dart';
import '../features/audio_import/subtitle_pairing.dart';
import '../models/audio_item.dart';
import '../providers/collection_provider.dart';
import '../providers/audio_library_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/app_logger.dart';
import '../utils/transcript_picker.dart';
import 'common/secondary_action_button.dart';

/// 已选中的音频文件信息
///
/// [file] 为原始选中文件（含缓存路径/字节）；复制到沙盒、算指纹等重活延后到点击
/// 「添加」时做，保证选择后预览秒出。[subtitleText]/[subtitleExt] 为同一次多选里
/// 配对到的同名字幕（已解码原始文本与扩展名 srt/vtt/lrc），无匹配或解码失败为 null；
/// 转 SRT 延后到入库时（需音频时长）。
typedef _PickedAudio = ({
  PlatformFile file,
  String name,
  String displayName,
  int fileSize,
  String? subtitleText,
  String? subtitleExt,
});

typedef _SavedPickedAudio = ({
  String path,
  String fileName,
  String audioSha256,
  String originalAudioSha256,
  bool created,
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
  final ValueChanged<List<AudioItem>>? onComplete;
  final AudioImportSourceType importSourceType;
  final bool preferDownloadsDirectory;

  /// 面板创建后是否立即唤起文件选择器（用于「点入口即选择」的流程）。
  final bool autoPickOnStart;

  /// 自动唤起的选择器被取消、且当前未选中任何文件时回调（供上层退回来源选择页）。
  final VoidCallback? onPickerDismissedEmpty;

  const AddAudioDialog({
    super.key,
    this.collectionId,
    this.embedded = false,
    this.onComplete,
    this.importSourceType = AudioImportSourceType.local,
    this.preferDownloadsDirectory = true,
    this.autoPickOnStart = false,
    this.onPickerDismissedEmpty,
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

  /// 文件选择器是否正在唤起中（用于展示占位加载态）
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    // 「点入口即选择」：面板挂载后立即唤起系统文件选择器。
    if (widget.autoPickOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickAudioFiles();
      });
    }
  }

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
                // 取消：直接关闭整个导入流程；返回来源选择页由顶部返回箭头处理。
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                label: l10n.cancel,
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
        // embedded 流程由来源选择页直接唤起选择器，面板内不再展示选择按钮与网盘提示，
        // 只呈现已选文件列表。非 embedded（独立弹窗）仍保留手动选择入口。
        if (!widget.embedded) _buildSelectAudioFileButton(l10n, colorScheme),
        // 选择器唤起中且尚无已选文件：展示占位加载态，避免空白面板。
        if (widget.embedded && _isPicking && _pickedFiles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
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
              file.displayName,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 已配对同名字幕徽章：固定槽位（无论有无都占位），保证后续大小列对齐。
          const SizedBox(width: 6),
          SizedBox(
            width: 16,
            child: file.subtitleText != null
                ? Tooltip(
                    message: AppLocalizations.of(context)!.subtitlePairedBadge,
                    child: Icon(
                      Icons.closed_caption_outlined,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          // 大小列固定宽度右对齐，长标题不挤占此列，各行大小与删除按钮竖直对齐。
          SizedBox(
            width: 64,
            child: Text(
              _formatFileSize(file.fileSize),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
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

  /// 选择音频文件（支持多选，可同时选中同名字幕自动配对）
  ///
  /// 选择器放行「音频 + 字幕」并集，用户一次把成对的音频和字幕都选上；App 在选中集合内
  /// 按去扩展名同名把字幕配对到音频，导入时一并入库，免去逐个手动上传字幕。
  Future<void> _pickAudioFiles() async {
    if (mounted) setState(() => _isPicking = true);
    try {
      final result = await _showAudioFilePicker();
      if (result == null || result.files.isEmpty) {
        // 未选中任何文件：若当前也无已选文件，通知上层退回来源选择页。
        if (_pickedFiles.isEmpty) widget.onPickerDismissedEmpty?.call();
        return;
      }

      // 1. 建立文件名 → 文件映射，并按扩展名分类（音频 / 字幕 / 不支持）。
      final byName = <String, PlatformFile>{
        for (final f in result.files) f.name: f,
      };
      final classification = classifyImportFiles(byName.keys);
      final audioFiles = [
        for (final n in classification.audioNames) byName[n]!,
      ];
      final subtitleFiles = <String, PlatformFile>{
        for (final n in classification.subtitleNames) n: byName[n]!,
      };
      final rejectedExts = classification.rejectedExtensions;

      // 2. 同名配对（音频文件名 → 字幕文件名）。
      final pairing = matchSubtitlesForAudios(byName.keys);

      // 3. 配对到的字幕就地解码（文本很小，文本+扩展名留到入库时转 SRT）。
      //    音频不在此复制/算指纹——那些重活延后到点击「添加」时做，保证预览秒出。
      final List<_PickedAudio> picked = [];
      var matchedCount = 0;
      for (final file in audioFiles) {
        final sourcePath = file.path;
        final sourceName = file.name.isNotEmpty
            ? file.name
            : sourcePath == null
            ? 'file'
            : path.basename(sourcePath);

        String? subtitleText;
        String? subtitleExt;
        final matchedName = pairing[file.name];
        final subtitleFile = matchedName == null
            ? null
            : subtitleFiles[matchedName];
        if (matchedName != null && subtitleFile != null) {
          try {
            final bytes = await _readPlatformFileBytes(subtitleFile);
            // 仅解码取文本；具体格式（srt/vtt/lrc）解析交给入库时按扩展名处理。
            final decoded = await decodeTranscriptBytes(bytes);
            subtitleText = decoded.text;
            subtitleExt = _extOf(matchedName);
            matchedCount++;
          } catch (e) {
            // 字幕解码失败不影响音频导入，仅记录。
            AppLogger.log(
              'AudioImport',
              'decode subtitle "$matchedName" for "${file.name}" failed: $e',
            );
          }
        }

        picked.add((
          file: file,
          name: path.basenameWithoutExtension(sourceName),
          displayName: sourceName,
          fileSize: file.size,
          subtitleText: subtitleText,
          subtitleExt: subtitleExt,
        ));
      }

      AppLogger.log(
        'AudioImport',
        'picked audios=${audioFiles.length} subtitles=${subtitleFiles.length} '
            'matched=$matchedCount rejected=${rejectedExts.length}',
      );

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
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  /// 弹出系统文件选择器，放行「音频 + 字幕」扩展名并集。
  Future<FilePickerResult?> _showAudioFilePicker() {
    final allowed = [...audioImportExtensions, ...subtitleImportExtensions];
    if (!kIsWeb && Platform.isAndroid) {
      // Android SAF 在 FileType.custom + 多扩展名场景会按精确 MIME 匹配，
      // 导致 m4a/flac 等被设备索引成非标 MIME 的文件被灰掉、无法选中；且 FileType.audio
      // 会隐藏字幕文件。改用 FileType.any（不过滤），选中后我们自己按白名单过滤。
      return FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowed,
        allowMultiple: true,
      );
    }
    return _getDownloadsDirectory().then((initialDir) {
      return FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowed,
        allowMultiple: true,
        initialDirectory:
            widget.preferDownloadsDirectory && !kIsWeb && Platform.isMacOS
            ? initialDir
            : null,
      );
    });
  }

  /// 读取选中文件的字节（路径 / bytes / 流三种来源）。
  Future<Uint8List> _readPlatformFileBytes(PlatformFile file) async {
    final sourcePath = file.path;
    if (sourcePath != null) return File(sourcePath).readAsBytes();
    final bytes = file.bytes;
    if (bytes != null) return bytes;
    final readStream = file.readStream;
    if (readStream != null) {
      final chunks = <int>[];
      await for (final chunk in readStream) {
        chunks.addAll(chunk);
      }
      return Uint8List.fromList(chunks);
    }
    throw Exception('Unable to access picked subtitle file');
  }

  /// 提取文件扩展名（小写、不含点）。
  static String _extOf(String name) =>
      path.extension(name).replaceFirst('.', '').toLowerCase();

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
  Future<_SavedPickedAudio> _savePickedFileToSandbox(
    PlatformFile file,
    String subdir,
  ) async {
    final dataDir = await getAppDataDirectory();
    final tmpDir = Directory(path.join(dataDir.path, 'tmp', 'audio_import'));
    await tmpDir.create(recursive: true);

    final sourcePath = file.path;
    final baseName = file.name.isNotEmpty
        ? file.name
        : sourcePath == null
        ? 'file'
        : path.basename(sourcePath);

    final tmpName =
        '${DateTime.now().microsecondsSinceEpoch}-${path.basename(baseName)}';
    final tmpPath = path.join(tmpDir.path, tmpName);

    // 先复制到临时目录，转码/落盘交给与链接导入共用的 finalize 流程。
    final bytes = file.bytes;
    final readStream = file.readStream;
    if (sourcePath != null) {
      await File(sourcePath).copy(tmpPath);
    } else if (bytes != null) {
      await File(tmpPath).writeAsBytes(bytes);
    } else if (readStream != null) {
      final out = File(tmpPath).openWrite();
      await readStream.pipe(out);
      await out.close();
    } else {
      throw Exception('Unable to access picked file');
    }

    final finalized = await AudioFinalizationService().finalize(
      dataDir: dataDir,
      tempRelativePath: path.join('tmp', 'audio_import', tmpName),
      targetSubdir: subdir,
    );

    return (
      path: finalized.relativePath,
      fileName: path.basename(finalized.relativePath),
      audioSha256: finalized.sha256,
      originalAudioSha256: finalized.originalSha256,
      created: finalized.created,
    );
  }

  /// 若该音频配对到了字幕且尚无字幕，则按音频时长转 SRT 并入库。
  ///
  /// 字幕入库失败不影响音频本身（音频已注册）；返回值反映最终字幕状态，供完成页判断。
  Future<AudioItem> _attachPairedSubtitle(
    AudioItem item,
    _PickedAudio file,
  ) async {
    final subtitleText = file.subtitleText;
    final subtitleExt = file.subtitleExt;
    if (subtitleText == null || subtitleExt == null || item.hasTranscript) {
      return item;
    }
    try {
      await importLocalSubtitle(
        ref,
        item,
        text: subtitleText,
        ext: subtitleExt,
      );
      AppLogger.log(
        'AudioImport',
        'attached subtitle to "${item.name}" (ext=$subtitleExt)',
      );
      return item.copyWith(transcriptSource: TranscriptSource.local);
    } catch (e) {
      AppLogger.log(
        'AudioImport',
        'attach subtitle to "${item.name}" failed: $e',
      );
      return item;
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }

  /// 批量添加音频
  Future<void> _addAudio() async {
    // 重入守卫：_isLoading 同步置位前的窗口内若重复点击会重复入库，这里直接拦截。
    if (_pickedFiles.isEmpty || _isLoading) return;

    final l10n = AppLocalizations.of(context)!;
    final collectionId = widget.collectionId ?? _selectedCollectionId;
    final library = ref.read(audioLibraryProvider.notifier);
    final collectionList = ref.read(collectionListProvider.notifier);
    final registrationService = AudioRegistrationService();

    setState(() {
      _isLoading = true;
      _processedCount = 0;
    });

    final List<AudioItem> results = [];
    // 跳过的重复项：本次导入名 + 与之重复的库中已有条目名。
    final List<({String attempted, String existing})> skippedDuplicates = [];

    // 全程包裹 try/catch/finally：任一文件入库（读时长/写库）抛异常都不能让面板
    // 卡在 loading（按钮全禁用、只能杀进程），finally 统一恢复可交互。
    try {
      final dataDir = await getAppDataDirectory();

      for (var i = 0; i < _pickedFiles.length; i++) {
        final file = _pickedFiles[i];

        // 落沙盒 + 算内容指纹（重活）在此进行，受下方进度条覆盖。
        final saved = await _savePickedFileToSandbox(file.file, 'audios');

        final result = await registrationService.registerSandboxedAudio(
          input: SandboxedAudioRegistrationInput(
            name: file.name,
            relativePath: saved.path,
            importSourceType: widget.importSourceType,
            audioSha256: saved.audioSha256,
            originalAudioSha256: saved.originalAudioSha256,
          ),
          audioLibrary: library,
          audioLibraryState: ref.read(audioLibraryProvider),
          collectionList: collectionList,
          collectionState: ref.read(collectionListProvider),
          collectionId: collectionId,
        );

        switch (result) {
          case AudioRegistrationAdded(:final item):
            if (saved.created && item.audioPath != saved.path) {
              await _deleteIfExists(File(path.join(dataDir.path, saved.path)));
            }
            results.add(await _attachPairedSubtitle(item, file));
          case AudioRegistrationDuplicate(
            :final attemptedName,
            :final existingName,
          ):
            if (saved.created) {
              await _deleteIfExists(File(path.join(dataDir.path, saved.path)));
            }
            skippedDuplicates.add((
              attempted: attemptedName,
              existing: existingName,
            ));
        }

        if (!mounted) return;
        setState(() => _processedCount = i + 1);
      }
    } catch (e) {
      if (mounted) {
        _showInlineError(
          _InlineError(_AudioErrorKind.generic, '${l10n.addAudioFailed}: $e'),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    // 有跳过项时弹窗提示
    if (skippedDuplicates.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (_) => DuplicatesSkippedDialog(duplicates: skippedDuplicates),
      );
    }

    // embedded 全部重复时 onComplete 收到空列表不前进，面板停留本页（_isLoading
    // 已在 finally 恢复），用户可删除或改选其它文件。
    if (mounted && widget.embedded) {
      widget.onComplete?.call(results);
      return;
    }

    if (mounted) {
      Navigator.pop(context, results);
    }
  }
}

/// 重复音频跳过提示弹窗。
///
/// 批量导入时，内容与库中已有音频完全相同（按 SHA256 去重）的文件会被跳过。
/// 弹窗以限高滚动卡片列出被跳过项，避免大量重复时撑破弹窗，并在导入名与已有名
/// 不同时标注与哪个已有音频内容相同。
class DuplicatesSkippedDialog extends StatelessWidget {
  const DuplicatesSkippedDialog({super.key, required this.duplicates});

  /// 被跳过的重复项：本次导入名 + 与之内容相同的库中已有条目名。
  final List<({String attempted, String existing})> duplicates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      // 标题行：图标 + 计数，左对齐更紧凑直观。
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.copy_all_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.duplicatesSkipped(duplicates.length),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.duplicatesSkippedDetail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            // 重复项可能很多：装进限高、带滚动条的卡片，避免撑破弹窗。
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Scrollbar(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: duplicates.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      indent: 44,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (_, i) =>
                        _buildRow(theme, l10n, duplicates[i]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.ok),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单条重复项行：音频图标 + 导入名（+ 与哪个已有音频内容相同的次行）。
  Widget _buildRow(
    ThemeData theme,
    AppLocalizations l10n,
    ({String attempted, String existing}) dup,
  ) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dup.attempted,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // 仅当导入名与已有名不同时，标注与哪个已有音频内容相同。
                if (dup.existing != dup.attempted)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.duplicateOfExisting(dup.existing),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.75,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
