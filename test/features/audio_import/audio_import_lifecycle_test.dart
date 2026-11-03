import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_import_provider.dart';
import 'package:echo_loop/features/audio_import/audio_import_service.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';

import '../../helpers/mock_providers.dart';

/// 导入/下载阻塞直到被取消；取消后抛出 canceled，模拟真实网络层的行为。
class _BlockingImportService extends AudioImportService {
  final started = Completer<CancelToken>();

  @override
  Future<AudioItem> importFromUrl({
    required String url,
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    AudioImportProgressCallback? onProgress,
  }) async {
    final token = cancelToken;
    if (token == null) throw StateError('cancel token is required');
    started.complete(token);
    await token.whenCancel;
    throw const AudioImportException(
      AudioImportFailureCode.canceled,
      'import canceled',
    );
  }

  @override
  Future<DownloadedAudio> downloadEpisodeToSandbox({
    required String url,
    required String displayName,
    String? enclosureType,
    CancelToken? cancelToken,
    AudioImportProgressCallback? onProgress,
  }) async {
    final token = cancelToken;
    if (token == null) throw StateError('cancel token is required');
    started.complete(token);
    await token.whenCancel;
    throw const AudioImportException(
      AudioImportFailureCode.canceled,
      'download canceled',
    );
  }
}

/// 每次下载都挂起并记录令牌，直到被取消；用于验证多个单集并发。
class _HoldingEpisodeService extends AudioImportService {
  final List<CancelToken> tokens = [];

  @override
  Future<DownloadedAudio> downloadEpisodeToSandbox({
    required String url,
    required String displayName,
    String? enclosureType,
    CancelToken? cancelToken,
    AudioImportProgressCallback? onProgress,
  }) async {
    final token = cancelToken;
    if (token == null) throw StateError('cancel token is required');
    tokens.add(token);
    await token.whenCancel;
    throw const AudioImportException(
      AudioImportFailureCode.canceled,
      'download canceled',
    );
  }
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 500 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('导入控制器生命周期', () {
    test('离开页面（关闭所有监听）后导入继续，只有用户主动取消才取消', () async {
      final service = _BlockingImportService();
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioImportServiceProvider.overrideWithValue(service),
          audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
        ]),
      );
      addTearDown(container.dispose);
      final sub = container.listen(audioImportControllerProvider, (_, __) {});

      final importing = container
          .read(audioImportControllerProvider.notifier)
          .importFromUrl('https://example.com/a.mp3');
      final token = await service.started.future;
      sub.close();
      await Future<void>.delayed(Duration.zero);
      expect(token.isCancelled, isFalse);

      await container.read(audioImportControllerProvider.notifier).cancel();
      await expectLater(importing, completion(isNull));
      expect(token.isCancelled, isTrue);
    });

    test('播客单集下载进行中离开页面不取消，用户取消才取消', () async {
      final service = _BlockingImportService();
      final item = createTestAudioItem(id: 'ep-1', name: 'Episode 1').copyWith(
        audioPath: null,
        totalDuration: 0,
        podcastEnclosureUrl: 'https://example.com/episode.mp3',
        podcastEnclosureType: 'audio/mpeg',
      );
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioImportServiceProvider.overrideWithValue(service),
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
        ]),
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        podcastDownloadControllerProvider,
        (_, __) {},
      );

      final downloading = container
          .read(podcastDownloadControllerProvider.notifier)
          .downloadPodcastEpisode(item);
      final token = await service.started.future;
      sub.close();
      await Future<void>.delayed(Duration.zero);
      expect(token.isCancelled, isFalse);

      container.read(podcastDownloadControllerProvider.notifier).cancel('ep-1');
      await expectLater(downloading, completion(isFalse));
      expect(token.isCancelled, isTrue);
    });
    test('不同单集可以同时下载，同一单集重复请求不会建第二个下载', () async {
      final service = _HoldingEpisodeService();
      final episodeA = createTestAudioItem(id: 'ep-a', name: 'A').copyWith(
        audioPath: null,
        totalDuration: 0,
        podcastEnclosureUrl: 'https://example.com/a.mp3',
        podcastEnclosureType: 'audio/mpeg',
      );
      final episodeB = createTestAudioItem(id: 'ep-b', name: 'B').copyWith(
        audioPath: null,
        totalDuration: 0,
        podcastEnclosureUrl: 'https://example.com/b.mp3',
        podcastEnclosureType: 'audio/mpeg',
      );
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioImportServiceProvider.overrideWithValue(service),
          audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
        ]),
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        podcastDownloadControllerProvider.notifier,
      );

      final a = notifier.downloadPodcastEpisode(episodeA);
      final b = notifier.downloadPodcastEpisode(episodeB);
      expect(await notifier.downloadPodcastEpisode(episodeA), isFalse);

      await _until(() => service.tokens.length == 2);
      expect(service.tokens, hasLength(2));
      expect(
        container.read(podcastDownloadControllerProvider).keys,
        unorderedEquals(['ep-a', 'ep-b']),
      );

      notifier.cancel('ep-a');
      expect(service.tokens[0].isCancelled, isTrue);
      expect(service.tokens[1].isCancelled, isFalse);

      notifier.cancel('ep-b');
      await a;
      await b;
    });
  });
}
