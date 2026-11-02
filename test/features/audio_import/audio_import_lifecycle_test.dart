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

void main() {
  group('导入控制器生命周期', () {
    test('导入进行中 provider 被销毁（取消）时，不抛出 Ref 已销毁异常', () async {
      // 导入中途关闭所有监听 → autoDispose 销毁并取消下载 → catch 分支不得写 state。
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
      await service.started.future;
      sub.close();
      await Future<void>.delayed(Duration.zero);

      await expectLater(importing, completion(isNull));
    });

    test('播客单集下载进行中 provider 被销毁时，不抛出 Ref 已销毁异常', () async {
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
      await service.started.future;
      sub.close();
      await Future<void>.delayed(Duration.zero);

      await expectLater(downloading, completion(isFalse));
    });
  });
}
