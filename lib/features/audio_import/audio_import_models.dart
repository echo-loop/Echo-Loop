import '../../models/audio_item.dart';

/// 支持的音频导入来源。
///
/// 直链和未来 Podcast RSS 单集都会先规整成可下载的音频来源，再复用同一套
/// 下载、落盘和入库流程。
sealed class AudioImportSource {
  const AudioImportSource();
}

/// 从音频直链导入。
class DirectUrlImportSource extends AudioImportSource {
  const DirectUrlImportSource(this.url);

  final String url;
}

/// 未来 RSS 单集导入的预留来源。
class PodcastEpisodeImportSource extends AudioImportSource {
  const PodcastEpisodeImportSource({
    required this.audioUrl,
    required this.title,
    this.publishedAt,
  });

  final String audioUrl;
  final String title;
  final DateTime? publishedAt;
}

/// 链接解析后的可下载音频信息。
class ResolvedAudioImport {
  const ResolvedAudioImport({
    required this.uri,
    required this.displayName,
    required this.fileName,
    required this.extension,
    this.mimeType,
  });

  final Uri uri;
  final String displayName;
  final String fileName;
  final String extension;
  final String? mimeType;
}

/// 仅落盘的音频下载结果（不入库）。
///
/// 供 podcast 单集懒下载使用：拿到沙盒相对路径、时长、指纹后，由调用方更新
/// 已存在的占位 [AudioItem]，而不是新建条目。
class DownloadedAudio {
  const DownloadedAudio({
    required this.relativePath,
    required this.durationSeconds,
    required this.created,
    this.audioSha256,
    this.originalAudioSha256,
  });

  final String relativePath;
  final int durationSeconds;

  /// 是否由本次下载新建；取消未提交结果时只能删除本次新建的文件。
  final bool created;
  final String? audioSha256;
  final String? originalAudioSha256;
}

/// 被跳过的重复导入项：本次导入名 + 与之内容相同的库中已有条目名。
typedef AudioImportDuplicate = ({String attempted, String existing});

/// 导入结果：成功入库的音频 + 因内容重复被跳过的项。
///
/// 本地文件、链接和网盘导入完成页共用该结构，避免不同来源各自维护完成摘要。
typedef AudioImportOutcome = ({
  List<AudioItem> added,
  List<AudioImportDuplicate> duplicates,
});

/// 待导入确认列表中的一条音频。
///
/// [id] 只用于稳定 widget key；[hasSubtitle] 表示该音频已匹配同名字幕。
class AudioImportSelectionItem {
  const AudioImportSelectionItem({
    required this.id,
    required this.displayName,
    required this.fileSize,
    required this.hasSubtitle,
    this.isVideo = false,
    this.status = AudioImportSelectionStatus.pending,
    this.duplicateExistingName,
    this.failureMessage,
  });

  final String id;
  final String displayName;
  final int fileSize;
  final bool hasSubtitle;

  /// 是否为视频媒体，由导入文件扩展名派生。
  final bool isVideo;
  final AudioImportSelectionStatus status;
  final String? duplicateExistingName;
  final String? failureMessage;
}

/// 待导入列表单行状态。
enum AudioImportSelectionStatus {
  /// 尚未开始；导入中表示等待导入。
  pending,

  /// 正在导入。
  importing,

  /// 已成功导入。
  added,

  /// 因内容重复被跳过。
  skipped,

  /// 因下载、解析或入库错误失败。
  failed,
}

/// 待导入确认列表底部的统一进度信息。
///
/// [value] 为 `0..1` 时显示确定进度；为 null 时显示不定进度。
class AudioImportSelectionProgress {
  const AudioImportSelectionProgress({
    required this.label,
    this.value,
    this.progressPercent,
    this.speedBytesPerSecond,
  });

  final String label;
  final double? value;

  /// 当前文件下载百分比；仅云盘下载导入中使用。
  final int? progressPercent;

  /// 当前文件下载速度，单位 bytes/s；仅云盘下载导入中使用。
  final double? speedBytesPerSecond;
}

/// 待导入列表底部的完成汇总。
class AudioImportSelectionSummary {
  const AudioImportSelectionSummary({
    required this.addedCount,
    required this.subtitleCount,
    required this.skippedCount,
    this.failedCount = 0,
  });

  final int addedCount;
  final int subtitleCount;
  final int skippedCount;

  /// 下载、解析或入库失败的数量。
  final int failedCount;
}

enum AudioImportFailureCode {
  invalidUrl,
  unsupportedScheme,
  unsupportedFormat,
  network,
  notAudio,
  duplicate,
  storage,
  canceled,
  unknown,
}

class AudioImportException implements Exception {
  const AudioImportException(this.code, this.message, [this.cause]);

  final AudioImportFailureCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

sealed class AudioImportState {
  const AudioImportState();
}

class AudioImportIdle extends AudioImportState {
  const AudioImportIdle();
}

class AudioImportResolving extends AudioImportState {
  const AudioImportResolving();
}

class AudioImportDownloading extends AudioImportState {
  const AudioImportDownloading({
    required this.displayName,
    required this.progress,
    this.receivedBytes,
    this.totalBytes,
  });

  final String displayName;

  /// 0..1；-1 表示服务端未提供总大小，UI 使用不定进度。
  final double progress;
  final int? receivedBytes;
  final int? totalBytes;
}

class AudioImportSaving extends AudioImportState {
  const AudioImportSaving(this.displayName);

  final String displayName;
}

class AudioImportCompleted extends AudioImportState {
  const AudioImportCompleted(this.audioItem);

  final AudioItem audioItem;
}

class AudioImportFailed extends AudioImportState {
  const AudioImportFailed(this.error, {this.audioItemId});

  final AudioImportException error;

  /// 播客单集下载失败时的条目 id，便于计划页归属错误；导入流程为 null。
  final String? audioItemId;
}
