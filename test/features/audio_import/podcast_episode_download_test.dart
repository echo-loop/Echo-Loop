import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_import_provider.dart';
import 'package:echo_loop/features/audio_import/audio_import_service.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';

import '../../helpers/mock_providers.dart';

/// 伪 AudioImportService：只覆写单集下载，便于不触网验证 controller 行为。
class _FakeEpisodeDownloadService extends AudioImportService {
  _FakeEpisodeDownloadService({this.shouldThrow = false});

  final bool shouldThrow;

  @override
  Future<DownloadedAudio> downloadEpisodeToSandbox({
    required String url,
    String? enclosureType,
    CancelToken? cancelToken,
    AudioImportProgressCallback? onProgress,
  }) async {
    if (shouldThrow) {
      throw const AudioImportException(
        AudioImportFailureCode.network,
        'download failed',
      );
    }
    onProgress?.call(50, 100); // 触发一次进度回调
    return const DownloadedAudio(
      relativePath: 'audios/imported/episode.m4a',
      durationSeconds: 321,
      audioSha256: 'sha-xyz',
    );
  }
}

void main() {
  group('AudioImportController.downloadPodcastEpisode', () {
    AudioItem podcastItem() =>
        createTestAudioItem(id: 'ep-1', name: 'Episode 1').copyWith(
          audioPath: null,
          totalDuration: 0,
          podcastEpisodeGuid: 'guid-1',
          podcastEnclosureUrl: 'https://example.com/episode.mp3',
          podcastEnclosureType: 'audio/mpeg',
        );

    ProviderContainer makeContainer(
      AudioImportService service,
      AudioItem item,
    ) {
      return ProviderContainer(
        overrides: [
          audioImportServiceProvider.overrideWithValue(service),
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
        ],
      );
    }

    test('成功下载就地更新现有条目，不新建条目', () async {
      final item = podcastItem();
      final container = makeContainer(_FakeEpisodeDownloadService(), item);
      addTearDown(container.dispose);

      final ok = await container
          .read(audioImportControllerProvider.notifier)
          .downloadPodcastEpisode(item);

      expect(ok, isTrue);
      final items = container.read(audioLibraryProvider).audioItems;
      // 仍只有一个条目（未产生孤儿）
      expect(items.length, 1);
      final updated = items.single;
      expect(updated.id, 'ep-1');
      expect(updated.audioPath, 'audios/imported/episode.m4a');
      expect(updated.totalDuration, 321);
      expect(updated.audioSha256, 'sha-xyz');
      // podcast 元字段保留
      expect(updated.podcastEpisodeGuid, 'guid-1');
      // 收尾回到 idle
      expect(
        container.read(audioImportControllerProvider),
        isA<AudioImportIdle>(),
      );
    });

    test('下载失败置 AudioImportFailed 且不修改条目', () async {
      final item = podcastItem();
      final container = makeContainer(
        _FakeEpisodeDownloadService(shouldThrow: true),
        item,
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(audioImportControllerProvider.notifier)
          .downloadPodcastEpisode(item);

      expect(ok, isFalse);
      final items = container.read(audioLibraryProvider).audioItems;
      expect(items.single.audioPath, isNull);
      expect(
        container.read(audioImportControllerProvider),
        isA<AudioImportFailed>(),
      );
    });

    test('缺少 enclosure URL 时直接返回 false', () async {
      final item = createTestAudioItem(
        id: 'ep-2',
        name: 'No URL',
      ).copyWith(audioPath: null, podcastEpisodeGuid: 'guid-2');
      final container = makeContainer(_FakeEpisodeDownloadService(), item);
      addTearDown(container.dispose);

      final ok = await container
          .read(audioImportControllerProvider.notifier)
          .downloadPodcastEpisode(item);

      expect(ok, isFalse);
    });
  });
}
