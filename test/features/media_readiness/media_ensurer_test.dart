import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_import_provider.dart';
import 'package:echo_loop/features/community_collections/download/community_download_notifier.dart';
import 'package:echo_loop/features/community_collections/download/download_progress.dart';
import 'package:echo_loop/features/media_readiness/media_provisioner.dart';
import 'package:echo_loop/features/media_readiness/media_readiness_provider.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// 记录 start 调用；成功启动后把状态置为下载中，模拟真实下载器。
class _RecordingCommunityDownload extends CommunityDownload {
  _RecordingCommunityDownload(this.initial);

  final Map<String, DownloadProgress> initial;
  final List<String> startedIds = [];

  @override
  Map<String, DownloadProgress> build() => initial;

  @override
  Future<StartResult> start({
    required String audioItemId,
    required String displayName,
  }) async {
    startedIds.add(audioItemId);
    state = {
      ...state,
      audioItemId: DownloadInProgress(
        audioItemId: audioItemId,
        displayName: displayName,
        progress: -1,
      ),
    };
    return StartResult.started;
  }
}

class _RecordingPodcastDownload extends PodcastDownloadController {
  final List<String> downloadedIds = [];

  @override
  Map<String, AudioImportState> build() => const {};

  @override
  Future<bool> downloadPodcastEpisode(AudioItem item) async {
    downloadedIds.add(item.id);
    return true;
  }
}

AudioItem _community({String? audioPath, DateTime? unavailableAt}) => AudioItem(
  id: 'audio-1',
  name: 'Puma',
  addedDate: DateTime(2026, 10, 31),
  remoteAudioId: 'remote-file-1',
  audioPath: audioPath,
  communityUnavailableAt: unavailableAt,
);

AudioItem _podcast() => AudioItem(
  id: 'episode-1',
  name: 'Episode',
  addedDate: DateTime(2026, 10, 31),
  podcastEpisodeGuid: 'guid-1',
  podcastEnclosureUrl: 'https://example.com/ep.mp3',
);

void main() {
  late _RecordingCommunityDownload community;
  late _RecordingPodcastDownload podcast;

  ProviderContainer makeContainer(
    AudioItem item, {
    Map<String, DownloadProgress> communityState = const {},
    bool localFileExists = false,
  }) {
    community = _RecordingCommunityDownload(communityState);
    podcast = _RecordingPodcastDownload();
    final container = ProviderContainer(
      overrides: dedupeOverrides([
        audioLibraryProvider.overrideWith(
          () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
        ),
        communityDownloadProvider.overrideWith(() => community),
        podcastDownloadControllerProvider.overrideWith(() => podcast),
        localMediaFileExistsProvider(
          item.id,
        ).overrideWith((ref) => Future.value(localFileExists)),
      ]),
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> ensure(ProviderContainer container, String id) async {
    await container.read(mediaEnsurerProvider).ensure(id);
  }

  test('社区音频未下载时启动下载', () async {
    final container = makeContainer(_community());

    await ensure(container, 'audio-1');

    expect(community.startedIds, ['audio-1']);
  });

  test('播客单集未下载时启动音频下载', () async {
    final container = makeContainer(_podcast());

    await ensure(container, 'episode-1');

    expect(podcast.downloadedIds, ['episode-1']);
    expect(community.startedIds, isEmpty);
  });

  test('下载已在进行中时不重复启动（幂等）', () async {
    final container = makeContainer(_community());

    await ensure(container, 'audio-1');
    await ensure(container, 'audio-1');

    expect(community.startedIds, ['audio-1']);
  });

  test('失败后再次 ensure 视为用户重试并重新启动', () async {
    final container = makeContainer(
      _community(),
      communityState: {
        'audio-1': const DownloadFailed(
          audioItemId: 'audio-1',
          displayName: 'Puma',
          error: 'network',
        ),
      },
    );

    await ensure(container, 'audio-1');

    expect(community.startedIds, ['audio-1']);
  });

  test('已就绪时不下载', () async {
    final container = makeContainer(
      _community(audioPath: 'audios/community/audio-1.m4a'),
      localFileExists: true,
    );

    await ensure(container, 'audio-1');

    expect(community.startedIds, isEmpty);
  });

  test('社区文件已下架时不下载', () async {
    final container = makeContainer(
      _community(unavailableAt: DateTime(2026, 10, 31)),
    );

    await ensure(container, 'audio-1');

    expect(community.startedIds, isEmpty);
  });

  test('没有下载来源的本地条目不触发任何下载', () async {
    final container = makeContainer(
      AudioItem(id: 'local', name: 'Local', addedDate: DateTime(2026, 10, 31)),
    );

    await ensure(container, 'local');

    expect(community.startedIds, isEmpty);
    expect(podcast.downloadedIds, isEmpty);
  });

  test('ensure 之后计划页读取的就绪状态进入下载中', () async {
    final container = makeContainer(_community());

    await ensure(container, 'audio-1');

    expect(container.read(mediaDownloadSnapshotProvider('audio-1')), isNotNull);
  });
}
