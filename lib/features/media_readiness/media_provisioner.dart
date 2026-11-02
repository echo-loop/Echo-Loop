import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/audio_item.dart';
import '../../providers/audio_library_provider.dart';
import '../../services/app_logger.dart';
import '../audio_import/audio_import_provider.dart';
import '../community_collections/download/community_download_notifier.dart';
import 'media_readiness.dart';
import 'media_readiness_provider.dart';
import 'media_readiness_resolver.dart';

part 'media_provisioner.g.dart';

const _logTag = 'MediaEnsure';

/// 某一类来源（社区合集、播客等）的媒体获取实现。
abstract interface class MediaProvisioner {
  /// 是否由本实现负责该条目。
  bool handles(AudioItem item);

  /// 启动下载。进度与结果通过对应下载器的状态回流到 [mediaReadinessProvider]。
  Future<void> provision(AudioItem item);
}

/// 社区合集：音频与字幕由社区下载器一并获取。
class CommunityMediaProvisioner implements MediaProvisioner {
  CommunityMediaProvisioner(this._ref);

  final Ref _ref;

  @override
  bool handles(AudioItem item) => isCommunityMediaItem(item);

  @override
  Future<void> provision(AudioItem item) async {
    final result = await _ref
        .read(communityDownloadProvider.notifier)
        .start(audioItemId: item.id, displayName: item.name);
    AppLogger.log(
      _logTag,
      'community provision id=${item.id} result=${result.name}',
    );
  }
}

/// 播客单集：仅下载音频；RSS 字幕由控制器在音频成功后附加（没有字幕地址则跳过）。
class PodcastMediaProvisioner implements MediaProvisioner {
  PodcastMediaProvisioner(this._ref);

  final Ref _ref;

  @override
  bool handles(AudioItem item) => isPodcastMediaItem(item);

  @override
  Future<void> provision(AudioItem item) async {
    final ok = await _ref
        .read(podcastDownloadControllerProvider.notifier)
        .downloadPodcastEpisode(item);
    AppLogger.log(_logTag, 'podcast provision id=${item.id} ok=$ok');
  }
}

/// 确保媒体就绪的唯一入口：只在「未开始」或「失败后用户重试」时启动下载。
class MediaEnsurer {
  MediaEnsurer(this._ref, this._provisioners);

  final Ref _ref;
  final List<MediaProvisioner> _provisioners;

  /// 幂等：已就绪、校验中、下载中、等待、下架等状态下直接返回。
  Future<void> ensure(String audioItemId) async {
    final item = _ref
        .read(audioLibraryProvider.notifier)
        .getItemById(audioItemId);
    if (item == null) {
      AppLogger.log(_logTag, 'skip: audio not in library id=$audioItemId');
      return;
    }
    final readiness = _ref.read(mediaReadinessProvider(audioItemId));
    if (readiness is! MediaNotDownloaded && readiness is! MediaFailed) return;

    for (final provisioner in _provisioners) {
      if (provisioner.handles(item)) {
        await provisioner.provision(item);
        return;
      }
    }
    AppLogger.log(_logTag, 'skip: no provisioner id=$audioItemId');
  }
}

@Riverpod(keepAlive: true)
MediaEnsurer mediaEnsurer(Ref ref) => MediaEnsurer(ref, [
  CommunityMediaProvisioner(ref),
  PodcastMediaProvisioner(ref),
]);
