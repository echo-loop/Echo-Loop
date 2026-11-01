import 'dart:io';

import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_import_provider.dart';
import 'package:echo_loop/features/community_collections/download/community_download_notifier.dart';
import 'package:echo_loop/features/community_collections/download/download_progress.dart';
import 'package:echo_loop/features/media_readiness/media_readiness.dart';
import 'package:echo_loop/features/media_readiness/media_readiness_provider.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/mock_providers.dart';

class _IdleCommunityDownload extends CommunityDownload {
  @override
  DownloadProgress build() => const DownloadIdle();
}

class _IdlePodcastDownload extends PodcastDownloadController {
  @override
  AudioImportState build() => const AudioImportIdle();
}

void main() {
  const audioId = 'local-audio-1';
  const relativePath = 'audios/local/audio-1.m4a';

  late Directory dataDir;
  late ProviderContainer container;

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('media_readiness_test');
    await File(p.join(dataDir.path, relativePath)).create(recursive: true);
    appDataDirectoryOverride = dataDir;
    final item = AudioItem(
      id: audioId,
      name: 'Local audio',
      addedDate: DateTime(2026, 11, 1),
      audioPath: relativePath,
    );
    container = ProviderContainer(
      overrides: [
        audioLibraryProvider.overrideWith(
          () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
        ),
        communityDownloadProvider.overrideWith(_IdleCommunityDownload.new),
        podcastDownloadControllerProvider.overrideWith(_IdlePodcastDownload.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    appDataDirectoryOverride = null;
    await dataDir.delete(recursive: true);
  });

  test('库刷新重建条目对象（路径不变）时，就绪状态不得回退为校验中', () async {
    final seen = <MediaReadiness>[];
    final subscription = container.listen(
      mediaReadinessProvider(audioId),
      (_, next) => seen.add(next),
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    // 等待首次文件校验完成，进入就绪态。
    await container.read(localMediaFileExistsProvider(audioId).future);
    expect(container.read(mediaReadinessProvider(audioId)), isA<MediaReady>());

    seen.clear();
    final current = container
        .read(audioLibraryProvider)
        .audioItems
        .firstWhere((item) => item.id == audioId);
    await container
        .read(audioLibraryProvider.notifier)
        .updateAudioItem(current.copyWith(name: 'Renamed'));
    await container.read(localMediaFileExistsProvider(audioId).future);

    expect(seen.whereType<MediaChecking>(), isEmpty);
    expect(container.read(mediaReadinessProvider(audioId)), isA<MediaReady>());
  });
}
