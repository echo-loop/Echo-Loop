import '../../models/audio_item.dart';
import '../audio_import/audio_import_models.dart';
import '../audio_import/podcast_audio_uri.dart';
import '../community_collections/download/download_progress.dart';
import 'media_readiness.dart';

/// 条目对应的下载资源 key；没有下载来源时为 null。与下载时提交的 key 一致。
String? downloadResourceKeyFor(AudioItem item) {
  final remoteAudioId = item.remoteAudioId;
  if (remoteAudioId != null) return communityResourceKey(remoteAudioId);
  final enclosureUrl = item.podcastEnclosureUrl;
  if (enclosureUrl != null) return podcastResourceKey(enclosureUrl);
  return null;
}

/// 某条目的下载快照；列表行与计划页共用同一份数据，保证两处进度一致。
class MediaDownloadSnapshot {
  const MediaDownloadSnapshot({
    required this.progress,
    this.speedBytesPerSecond,
  });

  /// 0..1；-1 表示总大小未知（不定态），与下载器的原始语义保持一致。
  final double progress;

  /// 最近窗口内的平均下载速度（字节/秒）；采样不足时为 null。
  final double? speedBytesPerSecond;

  @override
  bool operator ==(Object other) =>
      other is MediaDownloadSnapshot &&
      other.progress == progress &&
      other.speedBytesPerSecond == speedBytesPerSecond;

  @override
  int get hashCode => Object.hash(progress, speedBytesPerSecond);
}

/// 社区合集音频：存在 remoteAudioId，由社区下载器负责。
bool isCommunityMediaItem(AudioItem item) => item.remoteAudioId != null;

/// 播客单集：存在 enclosure 地址，由播客下载控制器负责。
bool isPodcastMediaItem(AudioItem item) => item.podcastEnclosureUrl != null;

/// 本条目正在进行的下载快照；未在下载时为 null。
///
/// 两个入参都是「本条目」的状态（由调用方按 audioItemId 选出），不再按通道全局判断。
MediaDownloadSnapshot? downloadSnapshotFor({
  required AudioItem item,
  required DownloadProgress? communityDownload,
  required AudioImportState? podcastDownload,
}) {
  if (isCommunityMediaItem(item)) {
    final state = communityDownload;
    if (state is DownloadInProgress) {
      return MediaDownloadSnapshot(
        progress: state.progress,
        speedBytesPerSecond: state.speedBytesPerSecond,
      );
    }
    return null;
  }
  final state = podcastDownload;
  if (state is AudioImportDownloading) {
    return MediaDownloadSnapshot(
      progress: state.progress,
      speedBytesPerSecond: state.speedBytesPerSecond,
    );
  }
  // 保存阶段（写入本地）没有可靠进度，按不定态展示。
  if (state is AudioImportSaving) {
    return const MediaDownloadSnapshot(progress: -1);
  }
  return null;
}

/// 根据条目与其自身的下载状态，解析计划页需要的媒体就绪状态。
///
/// 纯函数，无副作用。优先级：下架 → 已就绪（校验文件）→ 本条目下载中 →
/// 本条目失败 → 未开始。
MediaReadiness resolveMediaReadiness({
  required AudioItem item,
  required DownloadProgress? communityDownload,
  required AudioImportState? podcastDownload,
  required bool? fileExists,
  bool isQueued = false,
}) {
  if (item.isCommunityUnavailable) return const MediaUnavailable();

  if (item.isAudioReady) {
    if (fileExists == null) return const MediaChecking();
    return fileExists ? const MediaReady() : const MediaFileMissing();
  }

  final snapshot = downloadSnapshotFor(
    item: item,
    communityDownload: communityDownload,
    podcastDownload: podcastDownload,
  );
  if (snapshot != null) {
    if (isQueued) return const MediaQueued();
    return MediaDownloading(
      progress: snapshot.progress < 0 ? null : snapshot.progress,
      speedBytesPerSecond: snapshot.speedBytesPerSecond,
    );
  }

  final failure = _ownFailure(item, communityDownload, podcastDownload);
  if (failure != null) return MediaFailed(failure);

  if (isCommunityMediaItem(item) || isPodcastMediaItem(item)) {
    return const MediaNotDownloaded();
  }
  // 既没有媒体路径也没有下载来源，无法自动修复。
  return const MediaFileMissing();
}

Object? _ownFailure(
  AudioItem item,
  DownloadProgress? community,
  AudioImportState? podcast,
) {
  if (isCommunityMediaItem(item)) {
    final state = community;
    if (state is DownloadFailed) return state.error;
    return null;
  }
  final state = podcast;
  if (state is AudioImportFailed) return state.error;
  return null;
}
