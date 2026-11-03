import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/community_collections/download/download_progress.dart';
import 'package:echo_loop/features/media_readiness/media_readiness.dart';
import 'package:echo_loop/features/audio_import/podcast_audio_uri.dart';
import 'package:echo_loop/features/media_readiness/media_readiness_resolver.dart';
import 'package:echo_loop/features/community_collections/download/download_progress.dart'
    show communityResourceKey;
import 'package:echo_loop/models/audio_item.dart';
import 'package:flutter_test/flutter_test.dart';

AudioItem _community({
  String id = 'audio-1',
  String? audioPath,
  DateTime? unavailableAt,
}) => AudioItem(
  id: id,
  name: 'Puma',
  addedDate: DateTime(2026, 10, 31),
  remoteAudioId: 'remote-file-1',
  audioPath: audioPath,
  communityUnavailableAt: unavailableAt,
);

AudioItem _podcast({String id = 'episode-1', String? audioPath}) => AudioItem(
  id: id,
  name: 'Episode',
  addedDate: DateTime(2026, 10, 31),
  podcastEpisodeGuid: 'guid-1',
  podcastEnclosureUrl: 'https://example.com/ep.mp3',
  audioPath: audioPath,
);

/// 调用方已按 audioItemId 选出本条目的下载状态；未在下载时为 null。
MediaReadiness _resolve(
  AudioItem item, {
  DownloadProgress? community,
  AudioImportState? podcast,
  bool? fileExists,
}) => resolveMediaReadiness(
  item: item,
  communityDownload: community,
  podcastDownload: podcast,
  fileExists: fileExists,
);

void main() {
  group('已就绪与校验', () {
    test('文件存在时为就绪', () {
      expect(
        _resolve(_podcast(audioPath: 'a.mp3'), fileExists: true),
        isA<MediaReady>(),
      );
    });

    test('路径存在但文件缺失时为文件缺失', () {
      expect(
        _resolve(_podcast(audioPath: 'a.mp3'), fileExists: false),
        isA<MediaFileMissing>(),
      );
    });

    test('尚未校验文件时为校验中', () {
      expect(_resolve(_podcast(audioPath: 'a.mp3')), isA<MediaChecking>());
    });

    test('社区文件已下架优先于其它状态', () {
      expect(
        _resolve(
          _community(unavailableAt: DateTime(2026, 11)),
          community: const DownloadInProgress(
            audioItemId: 'audio-1',
            displayName: 'Puma',
            progress: 0.5,
          ),
        ),
        isA<MediaUnavailable>(),
      );
    });
  });

  group('未下载与下载中', () {
    test('社区条目未下载时为未开始', () {
      expect(_resolve(_community()), isA<MediaNotDownloaded>());
    });

    test('播客单集未下载时为未开始', () {
      expect(_resolve(_podcast()), isA<MediaNotDownloaded>());
    });

    test('本项社区下载中返回带比例的下载态', () {
      final readiness = _resolve(
        _community(),
        community: const DownloadInProgress(
          audioItemId: 'audio-1',
          displayName: 'Puma',
          progress: 0.3,
        ),
      );
      expect(readiness, isA<MediaDownloading>());
      expect((readiness as MediaDownloading).progress, 0.3);
    });

    test('总大小未知（-1）时进度为不定态 null', () {
      final readiness = _resolve(
        _community(),
        community: const DownloadInProgress(
          audioItemId: 'audio-1',
          displayName: 'Puma',
          progress: -1,
        ),
      );
      expect((readiness as MediaDownloading).progress, isNull);
    });

    test('本单集播客下载中为下载态', () {
      final readiness = _resolve(
        _podcast(),
        podcast: const AudioImportDownloading(
          displayName: 'https://example.com/ep.mp3',
          progress: 0.6,
        ),
      );
      expect((readiness as MediaDownloading).progress, 0.6);
    });

    test('保存阶段视为不定进度下载', () {
      final readiness = _resolve(
        _podcast(),
        podcast: const AudioImportSaving('https://example.com/ep.mp3'),
      );
      expect((readiness as MediaDownloading).progress, isNull);
    });
  });

  group('排队', () {
    test('已登记但尚未开始的下载显示为排队，而不是下载中', () {
      final readiness = resolveMediaReadiness(
        item: _community(),
        communityDownload: const DownloadInProgress(
          audioItemId: 'audio-1',
          displayName: 'Puma',
          progress: -1,
        ),
        podcastDownload: null,
        fileExists: null,
        isQueued: true,
      );
      expect(readiness, isA<MediaQueued>());
    });

    test('下载器开始传输后不再是排队', () {
      final readiness = resolveMediaReadiness(
        item: _community(),
        communityDownload: const DownloadInProgress(
          audioItemId: 'audio-1',
          displayName: 'Puma',
          progress: 0.2,
        ),
        podcastDownload: null,
        fileExists: null,
      );
      expect(readiness, isA<MediaDownloading>());
    });
  });

  group('下载资源 key', () {
    test('社区条目按远端文件 id，播客条目按规范化后的地址', () {
      expect(
        downloadResourceKeyFor(_community()),
        communityResourceKey('remote-file-1'),
      );
      expect(
        downloadResourceKeyFor(_podcast()),
        podcastResourceKey('https://example.com/ep.mp3'),
      );
      expect(downloadResourceKeyFor(_podcast()), isNotNull);
    });

    test('本地条目没有下载资源', () {
      expect(
        downloadResourceKeyFor(
          AudioItem(id: 'local', name: 'Local', addedDate: DateTime(2026)),
        ),
        isNull,
      );
    });
  });

  group('失败', () {
    test('本项社区下载失败为失败态并携带错误', () {
      final readiness = _resolve(
        _community(),
        community: const DownloadFailed(
          audioItemId: 'audio-1',
          displayName: 'Puma',
          error: 'network',
        ),
      );
      expect(readiness, isA<MediaFailed>());
      expect((readiness as MediaFailed).error, 'network');
    });

    test('本单集播客下载失败为失败态', () {
      expect(
        _resolve(
          _podcast(),
          podcast: AudioImportFailed(
            const AudioImportException(AudioImportFailureCode.network, 'x'),
            audioItemId: 'episode-1',
          ),
        ),
        isA<MediaFailed>(),
      );
    });
  });

  group('downloadSnapshotFor（列表行与计划页共用的下载快照）', () {
    test('社区下载中返回快照，未下载返回 null', () {
      expect(
        downloadSnapshotFor(
          item: _community(),
          communityDownload: const DownloadInProgress(
            audioItemId: 'audio-1',
            displayName: 'Puma',
            progress: 0.3,
          ),
          podcastDownload: null,
        )!.progress,
        0.3,
      );
      expect(
        downloadSnapshotFor(
          item: _community(id: 'audio-2'),
          communityDownload: null,
          podcastDownload: null,
        ),
        isNull,
      );
    });

    test('保存阶段以 -1 表示不定进度，保持列表行原有语义', () {
      final snapshot = downloadSnapshotFor(
        item: _podcast(),
        communityDownload: null,
        podcastDownload: const AudioImportSaving('https://example.com/ep.mp3'),
      );
      expect(snapshot!.progress, -1);
    });
  });
}
