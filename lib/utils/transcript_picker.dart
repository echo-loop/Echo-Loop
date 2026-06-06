// 字幕文件选择与上传工具
//
// 提供字幕文件选择、保存到沙盒、覆盖确认等公共方法，
// 供音频列表项菜单和合集详情页共用。
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle/subtitle.dart' show SubtitleType;
import 'package:universal_io/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../database/providers.dart';
import '../models/audio_item.dart';
import '../providers/audio_library_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/subtitle_parser.dart';
import 'transcript_stats.dart';

/// 选择字幕文件并返回其原始字符串内容（不复制到沙盒）。用户取消返回 null。
///
/// 字幕内容入库后的上传入口：选文件 → 严格校验 → 直接返回内容，由调用方写入
/// DB 列。校验失败抛 [SubtitleParseException]。
Future<String?> pickTranscriptContent() async {
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
  final ext = _extensionOf(file.name).toLowerCase();
  if (ext != 'srt' && ext != 'vtt') {
    throw SubtitleParseException(SubtitleParseErrorKind.unsupportedFormat, ext);
  }
  final type = ext == 'vtt' ? SubtitleType.vtt : SubtitleType.srt;

  // 读取内容：优先文件路径，其次 bytes / readStream（web）。
  final String content;
  if (file.path != null) {
    content = await File(file.path!).readAsString();
  } else if (file.bytes != null) {
    content = utf8.decode(file.bytes!, allowMalformed: true);
  } else if (file.readStream != null) {
    final bytes = <int>[];
    await for (final chunk in file.readStream!) {
      bytes.addAll(chunk);
    }
    content = utf8.decode(bytes, allowMalformed: true);
  } else {
    throw Exception('Unable to access picked file');
  }

  // 严格校验内容（失败抛 SubtitleParseException）。
  await SubtitleParser.parseSubtitleStrictString(content, type: type);
  return content;
}

/// 提取文件名扩展名（不含点）。
String _extensionOf(String name) {
  final lastDot = name.lastIndexOf('.');
  if (lastDot < 0 || lastDot == name.length - 1) return '';
  return name.substring(lastDot + 1);
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
    final content = await pickTranscriptContent();
    if (content == null) return;

    // 统计字幕句子数和单词数
    final stats = await getTranscriptStatsFromSrt(content);

    // 字幕内容入 DB 列；transcriptPath 置 null
    await ref
        .read(audioItemDaoProvider)
        .updateTranscriptSrt(audioItem.id, content);

    // 更新音频项的统计数据与来源
    if (!context.mounted) return;
    ref
        .read(audioLibraryProvider.notifier)
        .updateAudioItem(
          audioItem.copyWith(
            transcriptPath: null,
            sentenceCount: stats.$1,
            wordCount: stats.$2,
            transcriptSource: TranscriptSource.local,
          ),
        );
  } on SubtitleParseException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(subtitleParseErrorMessage(l10n, e))));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.pickTranscriptFileFailed}: $e')),
    );
  }
}

/// 把 [SubtitleParseException] 映射为本地化的提示文案。
String subtitleParseErrorMessage(
  AppLocalizations l10n,
  SubtitleParseException e,
) {
  switch (e.kind) {
    case SubtitleParseErrorKind.unsupportedFormat:
      return l10n.subtitleUnsupportedFormat(e.detail ?? '?');
    case SubtitleParseErrorKind.formatInvalid:
      return l10n.subtitleFormatInvalid;
    case SubtitleParseErrorKind.empty:
      return l10n.subtitleFileEmpty;
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
