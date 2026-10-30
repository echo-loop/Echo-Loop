import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_import_provider.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/audio_import/audio_import_service.dart';
import 'package:echo_loop/features/podcast/podcast_transcript_downloader.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';

import '../../helpers/mock_providers.dart';

/// 伪 AudioImportService：只覆写单集下载，便于不触网验证 controller 行为。
class _FakeEpisodeDownloadService extends AudioImportService {
  _FakeEpisodeDownloadService({this.shouldThrow = false});

  final bool shouldThrow;
  String? lastDisplayName;

  @override
  Future<DownloadedAudio> downloadEpisodeToSandbox({
    required String url,
    required String displayName,
    String? enclosureType,
    CancelToken? cancelToken,
    AudioImportProgressCallback? onProgress,
  }) async {
    lastDisplayName = displayName;
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
      created: true,
      audioSha256: 'sha-xyz',
      originalAudioSha256: 'source-sha-xyz',
    );
  }
}

class _BlockingEpisodeDownloadService extends AudioImportService {
  final started = Completer<CancelToken>();

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

/// 伪字幕下载器：返回预设文本或抛出预设错误，并记录调用次数。
class _FakeTranscriptDownloader extends PodcastTranscriptDownloader {
  _FakeTranscriptDownloader({this.text, this.error});

  final String? text;
  final Object? error;
  int callCount = 0;
  String? lastUrl;
  String? lastFormat;

  @override
  Future<String> download(
    String url, {
    required String format,
    CancelToken? cancelToken,
  }) async {
    callCount++;
    lastUrl = url;
    lastFormat = format;
    if (error != null) throw error!;
    return text!;
  }
}

/// 挂起直到被取消或被手动放行的字幕下载器，用于模拟慢速字幕服务器。
class _GatedTranscriptDownloader extends PodcastTranscriptDownloader {
  final started = Completer<void>();
  final _gate = Completer<String>();
  CancelToken? cancelToken;

  /// 放行下载并返回 [text]。
  void release(String text) => _gate.complete(text);

  @override
  Future<String> download(
    String url, {
    required String format,
    CancelToken? cancelToken,
  }) {
    this.cancelToken = cancelToken;
    cancelToken?.whenCancel.then((error) {
      if (!_gate.isCompleted) _gate.completeError(error);
    });
    started.complete();
    return _gate.future;
  }
}

const _episodeSrt = '''1
00:00:00,000 --> 00:00:02,000
Hello there.

2
00:00:02,500 --> 00:00:04,000
Second line.
''';

void main() {
  group('PodcastDownloadController.downloadPodcastEpisode', () {
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
      final service = _FakeEpisodeDownloadService();
      final container = makeContainer(service, item);
      addTearDown(container.dispose);

      final ok = await container
          .read(podcastDownloadControllerProvider.notifier)
          .downloadPodcastEpisode(item);

      expect(ok, isTrue);
      expect(service.lastDisplayName, item.name);
      final items = container.read(audioLibraryProvider).audioItems;
      // 仍只有一个条目（未产生孤儿）
      expect(items.length, 1);
      final updated = items.single;
      expect(updated.id, 'ep-1');
      expect(updated.audioPath, 'audios/imported/episode.m4a');
      expect(updated.totalDuration, 321);
      expect(updated.audioSha256, 'sha-xyz');
      expect(updated.originalAudioSha256, 'source-sha-xyz');
      // podcast 元字段保留
      expect(updated.podcastEpisodeGuid, 'guid-1');
      // 收尾回到 idle
      expect(
        container.read(podcastDownloadControllerProvider),
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
          .read(podcastDownloadControllerProvider.notifier)
          .downloadPodcastEpisode(item);

      expect(ok, isFalse);
      final items = container.read(audioLibraryProvider).audioItems;
      expect(items.single.audioPath, isNull);
      expect(
        container.read(podcastDownloadControllerProvider),
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
          .read(podcastDownloadControllerProvider.notifier)
          .downloadPodcastEpisode(item);

      expect(ok, isFalse);
    });

    test('取消下载会清空状态、取消 token，并忽略迟到结果', () async {
      final item = podcastItem();
      final service = _BlockingEpisodeDownloadService();
      final container = makeContainer(service, item);
      addTearDown(container.dispose);

      final notifier = container.read(
        podcastDownloadControllerProvider.notifier,
      );
      final download = notifier.downloadPodcastEpisode(item);
      final token = await service.started.future;

      await notifier.cancel();

      expect(token.isCancelled, isTrue);
      expect(
        container.read(podcastDownloadControllerProvider),
        isA<AudioImportIdle>(),
      );
      expect(await download, isFalse);
      expect(
        container.read(audioLibraryProvider).audioItems.single.audioPath,
        isNull,
      );
    });

    group('RSS 字幕随音频一并获取', () {
      // 默认无字幕：podcastItem 基于 createTestAudioItem，会按 transcriptPath 推导出
      // 本地字幕来源，这里显式清空，避免用例被"已有字幕"分支提前短路。
      AudioItem transcriptItem({String? url, String? format}) =>
          podcastItem().copyWith(
            transcriptPath: null,
            transcriptSource: null,
            podcastTranscriptUrl: url,
            podcastTranscriptFormat: format,
          );

      ({ProviderContainer container, TestAudioItemDao dao}) makeWith(
        AudioItem item,
        _FakeTranscriptDownloader downloader,
      ) {
        final dao = TestAudioItemDao();
        final container = ProviderContainer(
          overrides: [
            audioImportServiceProvider.overrideWithValue(
              _FakeEpisodeDownloadService(),
            ),
            audioItemDaoProvider.overrideWithValue(dao),
            podcastTranscriptDownloaderProvider.overrideWithValue(downloader),
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
          ],
        );
        addTearDown(container.dispose);
        return (container: container, dao: dao);
      }

      Future<bool> download(ProviderContainer container, AudioItem item) {
        return container
            .read(podcastDownloadControllerProvider.notifier)
            .downloadPodcastEpisode(item);
      }

      test('下载音频后字幕入库为本地来源，且不改动音频字段', () async {
        final item = transcriptItem(
          url: 'https://example.com/ep1.srt',
          format: 'srt',
        );
        final downloader = _FakeTranscriptDownloader(text: _episodeSrt);
        final (:container, :dao) = makeWith(item, downloader);

        expect(await download(container, item), isTrue);

        expect(downloader.lastUrl, 'https://example.com/ep1.srt');
        expect(downloader.lastFormat, 'srt');
        expect(dao.transcriptSrtStore['ep-1'], contains('Hello there.'));
        final updated = container.read(audioLibraryProvider).audioItems.single;
        expect(updated.transcriptSource, TranscriptSource.local);
        expect(updated.sentenceCount, 2);
        expect(updated.audioPath, 'audios/imported/episode.m4a');
        expect(updated.podcastTranscriptUrl, 'https://example.com/ep1.srt');
      });

      test('字幕下载失败时音频仍下载成功，且不设置字幕', () async {
        final item = transcriptItem(
          url: 'https://example.com/ep1.srt',
          format: 'srt',
        );
        final downloader = _FakeTranscriptDownloader(
          error: StateError('network down'),
        );
        final (:container, :dao) = makeWith(item, downloader);

        expect(await download(container, item), isTrue);

        expect(dao.transcriptSrtStore, isEmpty);
        final updated = container.read(audioLibraryProvider).audioItems.single;
        expect(updated.audioPath, 'audios/imported/episode.m4a');
        expect(updated.transcriptSource, isNull);
        expect(
          container.read(podcastDownloadControllerProvider),
          isA<AudioImportIdle>(),
        );
      });

      test('字幕解析后没有任何句子时不入库', () async {
        final item = transcriptItem(
          url: 'https://example.com/ep1.srt',
          format: 'srt',
        );
        final downloader = _FakeTranscriptDownloader(text: 'not a subtitle');
        final (:container, :dao) = makeWith(item, downloader);

        expect(await download(container, item), isTrue);

        expect(dao.transcriptSrtStore, isEmpty);
        expect(
          container
              .read(audioLibraryProvider)
              .audioItems
              .single
              .transcriptSource,
          isNull,
        );
      });

      test('条目已有字幕时不再下载 RSS 字幕，保留原字幕来源', () async {
        final item = transcriptItem(
          url: 'https://example.com/ep1.srt',
          format: 'srt',
        ).copyWith(transcriptSource: TranscriptSource.ai);
        final downloader = _FakeTranscriptDownloader(text: _episodeSrt);
        final (:container, :dao) = makeWith(item, downloader);

        expect(await download(container, item), isTrue);

        expect(downloader.callCount, 0);
        expect(dao.transcriptSrtStore, isEmpty);
        expect(
          container
              .read(audioLibraryProvider)
              .audioItems
              .single
              .transcriptSource,
          TranscriptSource.ai,
        );
      });

      test('没有字幕地址时完全不触发字幕下载（回归）', () async {
        final item = transcriptItem();
        final downloader = _FakeTranscriptDownloader(text: _episodeSrt);
        final (:container, :dao) = makeWith(item, downloader);

        expect(await download(container, item), isTrue);

        expect(downloader.callCount, 0);
        expect(dao.transcriptSrtStore, isEmpty);
      });
    });

    group('RSS 字幕下载期间的并发与取消', () {
      AudioItem transcriptItem() => podcastItem().copyWith(
        transcriptPath: null,
        transcriptSource: null,
        podcastTranscriptUrl: 'https://example.com/ep1.srt',
        podcastTranscriptFormat: 'srt',
      );

      test('字幕下载期间用户已手动加入字幕时，不覆盖用户字幕', () async {
        final item = transcriptItem();
        final downloader = _GatedTranscriptDownloader();
        final dao = TestAudioItemDao();
        final container = ProviderContainer(
          overrides: [
            audioImportServiceProvider.overrideWithValue(
              _FakeEpisodeDownloadService(),
            ),
            audioItemDaoProvider.overrideWithValue(dao),
            podcastTranscriptDownloaderProvider.overrideWithValue(downloader),
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
          ],
        );
        addTearDown(container.dispose);

        final download = container
            .read(podcastDownloadControllerProvider.notifier)
            .downloadPodcastEpisode(item);
        await downloader.started.future;

        // 模拟下载期间用户在其它入口为该条目加入了字幕（来源 ai）。
        final current = container.read(audioLibraryProvider).audioItems.single;
        await container
            .read(audioLibraryProvider.notifier)
            .updateAudioItem(
              current.copyWith(transcriptSource: TranscriptSource.ai),
            );

        downloader.release(_episodeSrt);
        expect(await download, isTrue);

        expect(dao.transcriptSrtStore, isEmpty);
        final updated = container.read(audioLibraryProvider).audioItems.single;
        expect(updated.transcriptSource, TranscriptSource.ai);
        expect(updated.audioPath, 'audios/imported/episode.m4a');
      });

      test('取消下载时字幕请求的 CancelToken 被取消，且不入库', () async {
        final item = transcriptItem();
        final downloader = _GatedTranscriptDownloader();
        final dao = TestAudioItemDao();
        final container = ProviderContainer(
          overrides: [
            audioImportServiceProvider.overrideWithValue(
              _FakeEpisodeDownloadService(),
            ),
            audioItemDaoProvider.overrideWithValue(dao),
            podcastTranscriptDownloaderProvider.overrideWithValue(downloader),
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          podcastDownloadControllerProvider.notifier,
        );
        final download = notifier.downloadPodcastEpisode(item);
        await downloader.started.future;

        await notifier.cancel();

        expect(downloader.cancelToken?.isCancelled, isTrue);
        await download;
        expect(dao.transcriptSrtStore, isEmpty);
        expect(
          container
              .read(audioLibraryProvider)
              .audioItems
              .single
              .transcriptSource,
          isNull,
        );
      });
    });

    test('播客下载失败不污染链接导入 controller 状态（两条流程独立）', () async {
      final item = podcastItem();
      final container = makeContainer(
        _FakeEpisodeDownloadService(shouldThrow: true),
        item,
      );
      addTearDown(container.dispose);

      await container
          .read(podcastDownloadControllerProvider.notifier)
          .downloadPodcastEpisode(item);

      // 播客下载置 Failed，但链接导入 controller 仍为初始 idle。
      expect(
        container.read(podcastDownloadControllerProvider),
        isA<AudioImportFailed>(),
      );
      expect(
        container.read(audioImportControllerProvider),
        isA<AudioImportIdle>(),
      );
    });
  });
}
