import '../../models/audio_item.dart';
import '../audio_import/audio_import_models.dart';
import '../community_collections/download/download_progress.dart';
import 'media_readiness.dart';

/// 某条目的下载快照；列表行与计划页共用同一份数据，保证两处进度一致。
class MediaDownloadSnapshot {
  const MediaDownloadSnapshot({required this.progress});

  /// 0..1；-1 表示总大小未知（不定态），与下载器的原始语义保持一致。
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is MediaDownloadSnapshot && other.progress == progress;

  @override
  int get hashCode => progress.hashCode;
}

/// 社区合集音频：存在 remoteAudioId，由社区下载器负责。
bool isCommunityMediaItem(AudioItem item) => item.remoteAudioId != null;

/// 播客单集：存在 enclosure 地址，由播客下载控制器负责。
bool isPodcastMediaItem(AudioItem item) => item.podcastEnclosureUrl != null;

/// 返回本条目正在进行的下载快照；其它条目占用通道时返回 null。
///
/// 这是「本条目是否在下载」的唯一判断，列表行进度与计划页状态都由它派生。
MediaDownloadSnapshot? downloadSnapshotFor({
  required AudioItem item,
  required DownloadProgress community,
  required AudioImportState podcast,
}) {
  if (isCommunityMediaItem(item)) {
    final state = community;
    if (state is DownloadInProgress && state.audioItemId == item.id) {
      return MediaDownloadSnapshot(progress: state.progress);
    }
    return null;
  }
  final enclosureUrl = item.podcastEnclosureUrl;
  if (enclosureUrl == null) return null;
  final state = podcast;
  if (state is AudioImportDownloading && state.displayName == enclosureUrl) {
    return MediaDownloadSnapshot(progress: state.progress);
  }
  // 保存阶段（写入本地）没有可靠进度，按不定态展示。
  if (state is AudioImportSaving && state.displayName == enclosureUrl) {
    return const MediaDownloadSnapshot(progress: -1);
  }
  return null;
}

/// 根据条目与两个下载通道的状态，解析计划页需要的媒体就绪状态。
///
/// 纯函数，无副作用。优先级：下架 → 已就绪（校验文件）→ 本条目下载中 →
/// 本条目失败 → 同通道被其它材料占用 → 未开始。
MediaReadiness resolveMediaReadiness({
  required AudioItem item,
  required DownloadProgress communityDownload,
  required AudioImportState podcastDownload,
  required bool? fileExists,
}) {
  if (item.isCommunityUnavailable) return const MediaUnavailable();

  if (item.isAudioReady) {
    if (fileExists == null) return const MediaChecking();
    return fileExists ? const MediaReady() : const MediaFileMissing();
  }

  final snapshot = downloadSnapshotFor(
    item: item,
    community: communityDownload,
    podcast: podcastDownload,
  );
  if (snapshot != null) {
    return MediaDownloading(
      progress: snapshot.progress < 0 ? null : snapshot.progress,
    );
  }

  final failure = _ownFailure(item, communityDownload, podcastDownload);
  if (failure != null) return MediaFailed(failure);

  if (_channelBusyWithOther(item, communityDownload, podcastDownload)) {
    return const MediaWaiting();
  }

  if (isCommunityMediaItem(item) || isPodcastMediaItem(item)) {
    return const MediaNotDownloaded();
  }
  // 既没有媒体路径也没有下载来源，无法自动修复。
  return const MediaFileMissing();
}

Object? _ownFailure(
  AudioItem item,
  DownloadProgress community,
  AudioImportState podcast,
) {
  if (isCommunityMediaItem(item)) {
    final state = community;
    if (state is DownloadFailed && state.audioItemId == item.id) {
      return state.error;
    }
    return null;
  }
  final state = podcast;
  if (state is AudioImportFailed && state.audioItemId == item.id) {
    return state.error;
  }
  return null;
}

/// 同一下载通道正被其它材料占用（本条目自身的下载已在前面判定）。
bool _channelBusyWithOther(
  AudioItem item,
  DownloadProgress community,
  AudioImportState podcast,
) {
  if (isCommunityMediaItem(item)) return community is DownloadInProgress;
  if (isPodcastMediaItem(item)) {
    return podcast is AudioImportDownloading || podcast is AudioImportSaving;
  }
  return false;
}
