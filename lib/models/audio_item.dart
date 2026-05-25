import '../utils/app_data_dir.dart';
import 'package:path/path.dart' as path;

/// copyWith 用于区分"未传参"与"显式传 null"的哨兵值
const _sentinel = Object();

/// 字幕来源枚举
enum TranscriptSource {
  /// 本地文件上传
  local,

  /// AI 转录生成
  ai;

  /// 从整数值创建（数据库存储用）
  static TranscriptSource? fromIndex(int? index) {
    if (index == null) return null;
    if (index >= 0 && index < values.length) return values[index];
    return null;
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

  /// AI 转录使用的语言（'en' / 'multi'）
  final String? transcriptLanguage;

  /// 官方合集中该音频在后端的 UUID；用户自建音频为 null。
  /// 同步时按此反查本地行（复用 id）。
  final String? remoteAudioId;

  /// 原始发布/播出日期（官方合集音频专用，如 VOA 某期节目日期）；
  /// 用户自建音频为 null。供官方合集详情页「最早/最新发布」排序用。
  final DateTime? originalDate;

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
    this.transcriptLanguage,
    this.remoteAudioId,
    this.originalDate,
  });

  /// 音频文件是否已就绪（在本地可播）。
  bool get isAudioReady => audioPath != null && audioPath!.isNotEmpty;

  /// 字幕文件是否已在本地可用。
  bool get hasTranscript =>
      transcriptPath != null && transcriptPath!.isNotEmpty;

  /// 获取音频文件的完整路径；未就绪时返回 null。
  Future<String?> getFullAudioPath() async {
    if (!isAudioReady) return null;
    final dataDir = await getAppDataDirectory();
    return path.join(dataDir.path, audioPath!);
  }

  /// 获取字幕文件的完整路径
  Future<String?> getFullTranscriptPath() async {
    if (!hasTranscript) return null;
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
    'transcriptLanguage': transcriptLanguage,
    'remoteAudioId': remoteAudioId,
    'originalDate': originalDate?.toIso8601String(),
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
    transcriptLanguage: json['transcriptLanguage'],
    remoteAudioId: json['remoteAudioId'],
    originalDate: json['originalDate'] == null
        ? null
        : DateTime.parse(json['originalDate'] as String),
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
    Object? transcriptLanguage = _sentinel,
    Object? remoteAudioId = _sentinel,
    Object? originalDate = _sentinel,
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
      transcriptLanguage: transcriptLanguage == _sentinel
          ? this.transcriptLanguage
          : transcriptLanguage as String?,
      remoteAudioId: remoteAudioId == _sentinel
          ? this.remoteAudioId
          : remoteAudioId as String?,
      originalDate: originalDate == _sentinel
          ? this.originalDate
          : originalDate as DateTime?,
    );
  }
}
