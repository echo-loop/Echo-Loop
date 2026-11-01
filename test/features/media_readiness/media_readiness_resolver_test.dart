import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/community_collections/download/download_progress.dart';
import 'package:echo_loop/features/media_readiness/media_readiness.dart';
import 'package:echo_loop/features/media_readiness/media_readiness_resolver.dart';
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

const _idle = DownloadIdle();
const _podcastIdle = AudioImportIdle();

MediaReadiness _resolve(
  AudioItem item, {
  DownloadProgress community = _idle,
  AudioImportState podcast = _podcastIdle,
  bool? fileExists,
}) => resolveMediaReadiness(
  item: item,
  communityDownload: community,
  podcastDownload: podcast,
  fileExists: fileExists,
);

void main() {
  group('已就绪媒体', () {
    test('文件存在时为就绪', () {
      expect(
        _resolve(
          _community(audioPath: 'audios/community/a.m4a'),
          fileExists: true,
        ),
        isA<MediaReady>(),
      );
    });

    test('路径存在但文件缺失时为文件缺失', () {
      expect(
        _resolve(
          _community(audioPath: 'audios/community/a.m4a'),
          fileExists: false,
        ),
        isA<MediaFileMissing>(),
      );
    });

    test('尚未校验文件时为校验中', () {
      expect(
        _resolve(_community(audioPath: 'audios/community/a.m4a')),
        isA<MediaChecking>(),
      );
    });

    test('社区文件已下架优先于其它状态', () {
      expect(
        _resolve(
          _community(unavailableAt: DateTime(2026, 10, 31)),
          community: const DownloadFailed(
            audioItemId: 'audio-1',
            displayName: 'Puma',
            error: 'boom',
          ),
        ),
        isA<MediaUnavailable>(),
      );
    });
  });

  group('社区合集音频', () {
    test('未下载且通道空闲时为未开始', () {
      expect(_resolve(_community()), isA<MediaNotDownloaded>());
    });

    test('本项下载中返回带比例的下载态', () {
      final readiness = _resolve(
        _community(),
        community: const DownloadInProgress(
          audioItemId: 'audio-1',
          displayName: 'Puma',
          progress: 0.4,
        ),
      );
      expect(readiness, isA<MediaDownloading>());
      final downloading = readiness as MediaDownloading;
      expect(downloading.progress, 0.4);
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

    test('另一材料占用下载通道时为等待', () {
      expect(
        _resolve(
          _community(),
          community: const DownloadInProgress(
            audioItemId: 'other-audio',
            displayName: 'Other',
            progress: 0.1,
          ),
        ),
        isA<MediaWaiting>(),
      );
    });

    test('本项下载失败时为失败态并携带错误', () {
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

    test('其它材料的失败不影响本项', () {
      expect(
        _resolve(
          _community(),
          community: const DownloadFailed(
            audioItemId: 'other-audio',
            displayName: 'Other',
            error: 'network',
          ),
        ),
        isA<MediaNotDownloaded>(),
      );
    });

    test('播客下载占用不影响社区材料的判断', () {
      expect(
        _resolve(
          _community(),
          podcast: const AudioImportDownloading(
            displayName: 'https://example.com/ep.mp3',
            progress: 0.5,
          ),
        ),
        isA<MediaNotDownloaded>(),
      );
    });
  });

  group('播客单集', () {
    const enclosure = 'https://example.com/ep.mp3';

    test('未下载且通道空闲时为未开始', () {
      expect(_resolve(_podcast()), isA<MediaNotDownloaded>());
    });

    test('本项下载中（按 enclosure 匹配）为下载态', () {
      final readiness = _resolve(
        _podcast(),
        podcast: const AudioImportDownloading(
          displayName: enclosure,
          progress: 0.25,
        ),
      );
      expect((readiness as MediaDownloading).progress, 0.25);
    });

    test('保存阶段视为不定进度下载', () {
      final readiness = _resolve(
        _podcast(),
        podcast: const AudioImportSaving(enclosure),
      );
      expect(readiness, isA<MediaDownloading>());
      expect((readiness as MediaDownloading).progress, isNull);
    });

    test('另一单集下载中为等待', () {
      expect(
        _resolve(
          _podcast(),
          podcast: const AudioImportDownloading(
            displayName: 'https://example.com/other.mp3',
            progress: 0.5,
          ),
        ),
        isA<MediaWaiting>(),
      );
    });

    test('本单集下载失败为失败态，其它单集的失败被忽略', () {
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
      expect(
        _resolve(
          _podcast(),
          podcast: AudioImportFailed(
            const AudioImportException(AudioImportFailureCode.network, 'x'),
            audioItemId: 'other-episode',
          ),
        ),
        isA<MediaNotDownloaded>(),
      );
    });

    test('已下载单集校验文件存在后为就绪', () {
      expect(
        _resolve(_podcast(audioPath: 'audios/podcast/e.mp3'), fileExists: true),
        isA<MediaReady>(),
      );
    });
  });

  group('既不能下载也未就绪的条目', () {
    test('本地条目无媒体路径时为文件缺失（不提供下载）', () {
      expect(
        _resolve(
          AudioItem(
            id: 'local',
            name: 'Local',
            addedDate: DateTime(2026, 10, 31),
          ),
        ),
        isA<MediaFileMissing>(),
      );
    });
  });

  group('downloadSnapshotFor（列表行与计划页共用的下载快照）', () {
    test('本项社区下载返回快照，其它项返回 null', () {
      const state = DownloadInProgress(
        audioItemId: 'audio-1',
        displayName: 'Puma',
        progress: 0.3,
      );
      final snapshot = downloadSnapshotFor(
        item: _community(),
        community: state,
        podcast: _podcastIdle,
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.progress, 0.3);
      expect(
        downloadSnapshotFor(
          item: _community(id: 'audio-2'),
          community: state,
          podcast: _podcastIdle,
        ),
        isNull,
      );
    });

    test('不定进度以 -1 表示，保持列表行原有语义', () {
      final snapshot = downloadSnapshotFor(
        item: _podcast(),
        community: _idle,
        podcast: const AudioImportSaving('https://example.com/ep.mp3'),
      );
      expect(snapshot!.progress, -1);
    });
  });
}
