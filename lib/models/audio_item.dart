import '../utils/app_data_dir.dart';
import 'package:path/path.dart' as path;

/// copyWith 用于区分"未传参"与"显式传 null"的哨兵值
const _sentinel = Object();

/// 字幕来源枚举
enum TranscriptSource {
  /// 本地文件上传
  local,

  /// AI 转录生成（云端）
  ai,

  /// 设备本地转录生成（离线 Whisper）。
  ///
  /// 词级时间戳与 [local] 一样是按字符长度合成的近似值（VAD 提供句级真实边界，
  /// sherpa-onnx Whisper 不产词级时间戳），故凡按「ai vs 非 ai」区分词级时间戳
  /// 质量的逻辑，[device] 都与 [local] 同侧处理。
  device;

  /// 从整数值创建（数据库存储用）
  static TranscriptSource? fromIndex(int? index) {
    if (index == null) return null;
    if (index >= 0 && index < values.length) return values[index];
    return null;
  }
}

/// 音频内容有效性状态。
///
/// 仅在新下载/导入完成时检测一次：解码失败（解不出时长）或全程静音都判为
/// [suspectEmpty]。null 表示尚未检测（旧数据或检测前），不展示警告。
enum AudioContentStatus {
  /// 内容正常（能解码且有有效音量）。
  ok,

  /// 疑似为空：文件损坏/解码失败，或全程静音、无人声。
  suspectEmpty;

  /// 从整数值创建（数据库存储用）。
  static AudioContentStatus? fromIndex(int? index) {
    if (index == null) return null;
    if (index >= 0 && index < values.length) return values[index];
    return null;
  }
}

/// 用户导入音频的来源类型。
///
/// 精选/官方合集不使用该字段，继续由 `remoteAudioId` 与合集 `source=official`
/// 表达远端 catalog 身份。
enum AudioImportSourceType {
  /// 从设备本地文件导入。
  local,

  /// 从可直接下载的音频 URL 导入。
  directUrl,

  /// 从网盘来源导入。当前预留，后续接入网盘解析时使用。
  cloudDrive;

  String get storageValue {
    return switch (this) {
      AudioImportSourceType.local => 'local',
      AudioImportSourceType.directUrl => 'direct_url',
      AudioImportSourceType.cloudDrive => 'cloud_drive',
    };
  }

  static AudioImportSourceType? fromStorageValue(String? value) {
    return switch (value) {
      'local' => AudioImportSourceType.local,
      'direct_url' => AudioImportSourceType.directUrl,
      'cloud_drive' => AudioImportSourceType.cloudDrive,
      _ => null,
    };
  }
}

class AudioItem {
  final String id;
  final String name;

  /// 音频文件相对路径。
  ///
  /// NULL 表示未就绪（官方合集加入后、下载完成前）；非 NULL 表示文件已在本地。
  /// 是「音频是否可用」的单一真实来源 —— 播放入口据此判断「直接播」或「触发下载」。
  final String? audioPath;

  /// 字幕文件相对路径。NULL 表示无字幕或尚未下载。
  final String? transcriptPath;
  final DateTime addedDate;
  final int totalDuration; // in seconds
  final int sentenceCount;
  final int wordCount;
  final bool isPinned;

  /// 字幕来源：null 表示无字幕
  final TranscriptSource? transcriptSource;

  /// 音频文件 SHA256 指纹（缓存，避免重复计算）
  final String? audioSha256;

  /// 转码前原始音频 SHA256 指纹。
  ///
  /// 用户导入/下载音频会统一转码为 m4a；不同设备转码后的字节可能不同。
  /// AI 转录请求优先使用该值作为后端字幕缓存 key，提升跨设备缓存命中率。
  final String? originalAudioSha256;

  /// AI 转录使用的语言（'en' / 'multi'）
  final String? transcriptLanguage;

  /// 音频内容有效性状态（新下载时检测一次）。
  ///
  /// null 表示未检测（旧数据或检测前）；[AudioContentStatus.suspectEmpty]
  /// 表示解码失败或全程静音，列表项展示警告、转录前拦截。
  final AudioContentStatus? contentStatus;

  /// 官方合集中该音频在后端的 UUID；用户自建音频为 null。
  /// 同步时按此反查本地行（复用 id）。
  final String? remoteAudioId;

  /// 原始发布/播出日期（官方合集音频专用，如 VOA 某期节目日期）；
  /// 用户自建音频为 null。供官方合集详情页「最早/最新发布」排序用。
  final DateTime? originalDate;

  /// 用户导入来源类型。
  ///
  /// 仅用户导入音频使用；官方/精选合集音频保持 null，避免和 catalog 同步身份混淆。
  final AudioImportSourceType? importSourceType;

  /// 用户导入来源 URL。
  ///
  /// 直链导入记录原始下载 URL；本地文件导入不记录设备绝对路径，保持 null。
  final String? importSourceUrl;

  // ── Podcast Episode 字段 ──────────────────────────────────────────────

  /// Podcast episode 的 RSS guid；同一合集内用于去重。null 表示非 podcast 音频。
  final String? podcastEpisodeGuid;

  /// Episode 音频文件的 enclosure URL（RSS `<enclosure url="...">`）
  final String? podcastEnclosureUrl;

  /// Enclosure MIME type，如 audio/mpeg
  final String? podcastEnclosureType;

  /// Episode 的简介文本，来自 RSS item description。
  final String? podcastDescription;

  /// Episode 的封面图，优先来自 RSS item itunes:image。
  final String? podcastImageUrl;

  /// Episode 的网页链接，来自 RSS item link。
  final String? podcastLink;

  AudioItem({
    required this.id,
    required this.name,
    this.audioPath,
    this.transcriptPath,
    required this.addedDate,
    this.totalDuration = 0,
    this.sentenceCount = 0,
    this.wordCount = 0,
    this.isPinned = false,
    this.transcriptSource,
    this.audioSha256,
    this.originalAudioSha256,
    this.transcriptLanguage,
    this.contentStatus,
    this.remoteAudioId,
    this.originalDate,
    this.importSourceType,
    this.importSourceUrl,
    this.podcastEpisodeGuid,
    this.podcastEnclosureUrl,
    this.podcastEnclosureType,
    this.podcastDescription,
    this.podcastImageUrl,
    this.podcastLink,
  });

  /// 音频文件是否已就绪（在本地可播）。
  bool get isAudioReady => audioPath != null && audioPath!.isNotEmpty;

  /// 是否有字幕。
  ///
  /// 字幕内容入库后，以 [transcriptSource] 是否有值为准（内容存 DB 列，不再依赖
  /// 文件路径）。所有创建点设置 source、删除时清空。
  bool get hasTranscript => transcriptSource != null;

  /// 获取音频文件的完整路径；未就绪时返回 null。
  Future<String?> getFullAudioPath() async {
    if (!isAudioReady) return null;
    final dataDir = await getAppDataDirectory();
    return path.join(dataDir.path, audioPath!);
  }

  /// 获取遗留字幕文件的完整路径；无文件路径时返回 null。
  ///
  /// 字幕内容入库后，新行 [transcriptPath] 为 null（内容在 DB 列），此处返回 null。
  /// 仅旧行/迁移漏网时指向遗留文件，供 backfill、删除清理、导出兜底使用。
  Future<String?> getFullTranscriptPath() async {
    if (transcriptPath == null || transcriptPath!.isEmpty) return null;
    final dataDir = await getAppDataDirectory();
    return path.join(dataDir.path, transcriptPath!);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'audioPath': audioPath,
    'transcriptPath': transcriptPath,
    'addedDate': addedDate.toIso8601String(),
    'totalDuration': totalDuration,
    'sentenceCount': sentenceCount,
    'wordCount': wordCount,
    'isPinned': isPinned,
    'transcriptSource': transcriptSource?.index,
    'audioSha256': audioSha256,
    'originalAudioSha256': originalAudioSha256,
    'transcriptLanguage': transcriptLanguage,
    'contentStatus': contentStatus?.index,
    'remoteAudioId': remoteAudioId,
    'originalDate': originalDate?.toIso8601String(),
    'importSourceType': importSourceType?.storageValue,
    'importSourceUrl': importSourceUrl,
    'podcastEpisodeGuid': podcastEpisodeGuid,
    'podcastEnclosureUrl': podcastEnclosureUrl,
    'podcastEnclosureType': podcastEnclosureType,
    'podcastDescription': podcastDescription,
    'podcastImageUrl': podcastImageUrl,
    'podcastLink': podcastLink,
  };

  factory AudioItem.fromJson(Map<String, dynamic> json) => AudioItem(
    id: json['id'],
    name: json['name'],
    audioPath: json['audioPath'],
    transcriptPath: json['transcriptPath'],
    addedDate: DateTime.parse(json['addedDate']),
    totalDuration: json['totalDuration'] ?? 0,
    sentenceCount: json['sentenceCount'] ?? 0,
    wordCount: json['wordCount'] ?? 0,
    isPinned: json['isPinned'] ?? json['isStarred'] ?? false,
    transcriptSource: TranscriptSource.fromIndex(json['transcriptSource']),
    audioSha256: json['audioSha256'],
    originalAudioSha256: json['originalAudioSha256'],
    transcriptLanguage: json['transcriptLanguage'],
    contentStatus: AudioContentStatus.fromIndex(json['contentStatus']),
    remoteAudioId: json['remoteAudioId'],
    originalDate: json['originalDate'] == null
        ? null
        : DateTime.parse(json['originalDate'] as String),
    importSourceType: AudioImportSourceType.fromStorageValue(
      json['importSourceType'] as String?,
    ),
    importSourceUrl: json['importSourceUrl'] as String?,
    podcastEpisodeGuid: json['podcastEpisodeGuid'] as String?,
    podcastEnclosureUrl: json['podcastEnclosureUrl'] as String?,
    podcastEnclosureType: json['podcastEnclosureType'] as String?,
    podcastDescription: json['podcastDescription'] as String?,
    podcastImageUrl: json['podcastImageUrl'] as String?,
    podcastLink: json['podcastLink'] as String?,
  );

  AudioItem copyWith({
    String? id,
    String? name,
    Object? audioPath = _sentinel,
    Object? transcriptPath = _sentinel,
    DateTime? addedDate,
    int? totalDuration,
    int? sentenceCount,
    int? wordCount,
    bool? isPinned,
    Object? transcriptSource = _sentinel,
    Object? audioSha256 = _sentinel,
    Object? originalAudioSha256 = _sentinel,
    Object? transcriptLanguage = _sentinel,
    Object? contentStatus = _sentinel,
    Object? remoteAudioId = _sentinel,
    Object? originalDate = _sentinel,
    Object? importSourceType = _sentinel,
    Object? importSourceUrl = _sentinel,
    Object? podcastEpisodeGuid = _sentinel,
    Object? podcastEnclosureUrl = _sentinel,
    Object? podcastEnclosureType = _sentinel,
    Object? podcastDescription = _sentinel,
    Object? podcastImageUrl = _sentinel,
    Object? podcastLink = _sentinel,
  }) {
    return AudioItem(
      id: id ?? this.id,
      name: name ?? this.name,
      audioPath: audioPath == _sentinel ? this.audioPath : audioPath as String?,
      transcriptPath: transcriptPath == _sentinel
          ? this.transcriptPath
          : transcriptPath as String?,
      addedDate: addedDate ?? this.addedDate,
      totalDuration: totalDuration ?? this.totalDuration,
      sentenceCount: sentenceCount ?? this.sentenceCount,
      wordCount: wordCount ?? this.wordCount,
      isPinned: isPinned ?? this.isPinned,
      transcriptSource: transcriptSource == _sentinel
          ? this.transcriptSource
          : transcriptSource as TranscriptSource?,
      audioSha256: audioSha256 == _sentinel
          ? this.audioSha256
          : audioSha256 as String?,
      originalAudioSha256: originalAudioSha256 == _sentinel
          ? this.originalAudioSha256
          : originalAudioSha256 as String?,
      transcriptLanguage: transcriptLanguage == _sentinel
          ? this.transcriptLanguage
          : transcriptLanguage as String?,
      contentStatus: contentStatus == _sentinel
          ? this.contentStatus
          : contentStatus as AudioContentStatus?,
      remoteAudioId: remoteAudioId == _sentinel
          ? this.remoteAudioId
          : remoteAudioId as String?,
      originalDate: originalDate == _sentinel
          ? this.originalDate
          : originalDate as DateTime?,
      importSourceType: importSourceType == _sentinel
          ? this.importSourceType
          : importSourceType as AudioImportSourceType?,
      importSourceUrl: importSourceUrl == _sentinel
          ? this.importSourceUrl
          : importSourceUrl as String?,
      podcastEpisodeGuid: podcastEpisodeGuid == _sentinel
          ? this.podcastEpisodeGuid
          : podcastEpisodeGuid as String?,
      podcastEnclosureUrl: podcastEnclosureUrl == _sentinel
          ? this.podcastEnclosureUrl
          : podcastEnclosureUrl as String?,
      podcastEnclosureType: podcastEnclosureType == _sentinel
          ? this.podcastEnclosureType
          : podcastEnclosureType as String?,
      podcastDescription: podcastDescription == _sentinel
          ? this.podcastDescription
          : podcastDescription as String?,
      podcastImageUrl: podcastImageUrl == _sentinel
          ? this.podcastImageUrl
          : podcastImageUrl as String?,
      podcastLink: podcastLink == _sentinel
          ? this.podcastLink
          : podcastLink as String?,
    );
  }
}
