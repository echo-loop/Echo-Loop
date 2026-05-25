// 字幕文件选择与上传工具
//
// 提供字幕文件选择、保存到沙盒、覆盖确认等公共方法，
// 供音频列表项菜单和合集详情页共用。
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'app_data_dir.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/audio_item.dart';
import '../providers/audio_library_provider.dart';
import '../l10n/app_localizations.dart';
import 'transcript_stats.dart';

/// 选择并保存字幕文件到沙盒，返回相对路径。用户取消返回 null。
Future<String?> pickAndSaveTranscript() async {
  final FilePickerResult? result;

  if (!kIsWeb && Platform.isIOS) {
    result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      allowMultiple: false,
    );
  } else {
    final initialDir = !kIsWeb && Platform.isMacOS
        ? await _getDownloadsDirectory()
        : null;
    result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      initialDirectory: initialDir,
      allowMultiple: false,
    );
  }

  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  return _saveFileToSandbox(file, 'transcripts');
}

/// 为音频上传字幕（含已有字幕覆盖确认）
///
/// 如果音频已有字幕，先弹出确认对话框；确认后选择文件并更新音频项。
Future<void> uploadTranscriptForAudio(
  BuildContext context,
  WidgetRef ref,
  AudioItem audioItem,
) async {
  final l10n = AppLocalizations.of(context)!;

  // 已有字幕时弹出覆盖确认
  if (audioItem.hasTranscript) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.replaceTranscriptTitle),
        content: Text(l10n.replaceTranscriptMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.replace),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  }

  // 选择字幕文件
  try {
    final newPath = await pickAndSaveTranscript();
    if (newPath == null) return;

    // 统计字幕句子数和单词数
    final stats = await getTranscriptStats(newPath);

    // 更新音频项的字幕路径和统计数据
    if (!context.mounted) return;
    ref
        .read(audioLibraryProvider.notifier)
        .updateAudioItem(
          audioItem.copyWith(
            transcriptPath: newPath,
            sentenceCount: stats.$1,
            wordCount: stats.$2,
          ),
        );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.pickTranscriptFileFailed}: $e')),
    );
  }
}

/// 获取 macOS 下载目录路径
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
Future<String> _saveFileToSandbox(PlatformFile file, String subdir) async {
  final dataDir = await getAppDataDirectory();
  final dir = Directory(path.join(dataDir.path, subdir));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final baseName = file.name.isNotEmpty
      ? file.name
      : (file.path != null ? path.basename(file.path!) : 'file');
  final destPath = path.join(dir.path, baseName);

  // 字幕上传场景始终覆盖已有文件
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
