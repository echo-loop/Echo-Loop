// 音频导入的同名字幕自动配对
//
// 用户在一次多选里同时选中音频和字幕文件后，按「去扩展名同名」把字幕配对到音频，
// 免去逐个手动上传。纯逻辑、无 IO，便于单测。

import 'package:path/path.dart' as p;

import '../../models/audio_item.dart';

/// 支持导入的音频扩展名（小写、不含点）。
///
/// opus/ogg 由 ffmpeg-kit 解码转录、media_kit（libmpv）播放，两端的构建都包含
/// Ogg 解封装与 Opus / Vorbis 解码器。
const audioImportExtensions = {
  'mp3',
  'wav',
  'm4a',
  'aac',
  'flac',
  'opus',
  'ogg',
};

/// 支持导入的字幕扩展名（小写、不含点）。同名多字幕的优先级见 [_subtitlePriority]。
const subtitleImportExtensions = {'srt', 'vtt', 'lrc'};

/// 归一化扩展名：允许调用方传入 `.mp4` 或 `mp4`，统一返回小写且不含点。
String normalizeImportExtension(String extension) {
  final trimmed = extension.trim().toLowerCase();
  return trimmed.startsWith('.') ? trimmed.substring(1) : trimmed;
}

/// 是否为可作为主学习素材导入的扩展名（音频或视频）。
///
/// 本地文件、网盘文件等所有来源都应复用这个判断，避免新增媒体类型时各入口
/// 过滤规则不一致。
bool isImportablePrimaryMediaExtension(String extension) {
  final ext = normalizeImportExtension(extension);
  return audioImportExtensions.contains(ext) ||
      videoFileExtensions.contains(ext);
}

/// 是否为可导入的视频扩展名。
bool isVideoImportExtension(String extension) {
  return videoFileExtensions.contains(normalizeImportExtension(extension));
}

/// 同名多字幕时的选取优先级：srt > vtt > lrc（值越小越优先）。
const _subtitlePriority = {'srt': 0, 'vtt': 1, 'lrc': 2};

/// 选中文件按扩展名分类的结果。
class ImportFileClassification {
  const ImportFileClassification({
    required this.audioNames,
    required this.videoNames,
    required this.subtitleNames,
    required this.rejectedExtensions,
  });

  /// 音频文件名（保持输入顺序）。
  final List<String> audioNames;

  /// 视频文件名（保持输入顺序）。
  final List<String> videoNames;

  /// 字幕文件名（保持输入顺序）。
  final List<String> subtitleNames;

  /// 既非音频也非字幕的文件扩展名（小写；无扩展名记为 `?`），供错误提示。
  final List<String> rejectedExtensions;
}

/// 把一批文件名按扩展名白名单分类为音频 / 字幕 / 不支持。
ImportFileClassification classifyImportFiles(Iterable<String> fileNames) {
  final audioNames = <String>[];
  final videoNames = <String>[];
  final subtitleNames = <String>[];
  final rejected = <String>[];
  for (final name in fileNames) {
    final ext = _extensionOf(name);
    if (audioImportExtensions.contains(ext)) {
      audioNames.add(name);
    } else if (isVideoImportExtension(ext)) {
      videoNames.add(name);
    } else if (subtitleImportExtensions.contains(ext)) {
      subtitleNames.add(name);
    } else {
      rejected.add(ext.isNotEmpty ? ext : '?');
    }
  }
  return ImportFileClassification(
    audioNames: audioNames,
    videoNames: videoNames,
    subtitleNames: subtitleNames,
    rejectedExtensions: rejected,
  );
}

/// 为每个音频文件名匹配同目录下去扩展名同名的字幕文件名。
///
/// - 匹配键：文件名去扩展名后转小写（大小写不敏感）。
/// - 同名同时存在多种字幕时，按 [_subtitlePriority] 取优先级最高的一种。
/// - 返回：音频文件名 → 匹配到的字幕文件名（无匹配为 null）。返回的键保留音频原始文件名。
///
/// [fileNames] 为一批混合文件名（音频 + 字幕 + 其它），其它扩展名忽略。
Map<String, String?> matchSubtitlesForAudios(Iterable<String> fileNames) {
  final audios = <String>[];
  // 去扩展名(小写) → 该基名下已知的最佳字幕文件名。
  final bestSubtitleByStem = <String, String>{};

  for (final name in fileNames) {
    final ext = _extensionOf(name);
    final stem = _stemOf(name).toLowerCase();
    if (isImportablePrimaryMediaExtension(ext)) {
      audios.add(name);
    } else if (subtitleImportExtensions.contains(ext)) {
      final current = bestSubtitleByStem[stem];
      if (current == null || _isHigherPriority(name, current)) {
        bestSubtitleByStem[stem] = name;
      }
    }
  }

  final result = <String, String?>{};
  for (final audio in audios) {
    result[audio] = bestSubtitleByStem[_stemOf(audio).toLowerCase()];
  }
  return result;
}

/// 字幕扩展名（小写、不含点）；无扩展名返回空串。
String subtitleExtensionOf(String fileName) => _extensionOf(fileName);

/// [candidate] 是否比 [current] 优先级更高（更小的优先级值）。
bool _isHigherPriority(String candidate, String current) {
  final a = _subtitlePriority[_extensionOf(candidate)] ?? 99;
  final b = _subtitlePriority[_extensionOf(current)] ?? 99;
  return a < b;
}

String _extensionOf(String name) {
  final ext = p.extension(name);
  if (ext.isEmpty) return '';
  return ext.substring(1).toLowerCase();
}

String _stemOf(String name) => p.basenameWithoutExtension(name);
