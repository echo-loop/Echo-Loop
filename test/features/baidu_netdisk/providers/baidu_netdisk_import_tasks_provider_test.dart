import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_import_service.dart';
import 'package:echo_loop/providers/download_clock_provider.dart';
import 'package:echo_loop/features/baidu_netdisk/models/cloud_drive_models.dart';
import 'package:echo_loop/features/baidu_netdisk/providers/baidu_netdisk_import_tasks_provider.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

/// 可手动推进的时钟，用于验证速度窗口。
class _FakeClock {
  DateTime now = DateTime(2026, 11, 4, 10);

  void advance(Duration duration) {
    now = now.add(duration);
  }
}

/// 可控的批量取链接执行函数。
///
/// 默认立即返回；[holdFetches] 为 true 时挂起，由测试调用 [releaseFetch] 决定结果。
class _FakeLinkFetcher {
  bool holdFetches = false;
  Object? failWith;
  final List<List<int>> requestedFsIds = <List<int>>[];
  final List<Completer<Map<int, BaiduDownloadLink>>> _held =
      <Completer<Map<int, BaiduDownloadLink>>>[];

  Future<Map<int, BaiduDownloadLink>> call(List<CloudDriveEntry> entries) {
    requestedFsIds.add([for (final entry in entries) entry.fsId]);
    final failure = failWith;
    if (failure != null) return Future.error(failure);
    final links = {
      for (final entry in entries)
        entry.fsId: BaiduDownloadLink(
          fsId: entry.fsId,
          dlink: 'https://d.pcs.baidu.com/file/${entry.fsId}',
        ),
    };
    if (!holdFetches) return Future.value(links);
    final completer = Completer<Map<int, BaiduDownloadLink>>();
    _held.add(completer);
    return completer.future;
  }

  /// 让最近一次挂起的取链接返回结果。
  void releaseFetch() {
    final links = {
      for (final fsId in requestedFsIds.last)
        fsId: BaiduDownloadLink(
          fsId: fsId,
          dlink: 'https://d.pcs.baidu.com/file/$fsId',
        ),
    };
    _held.removeLast().complete(links);
  }
}

/// 可控的单文件导入执行函数：每次调用挂起，由测试决定成功或失败。
class _FakeItemRunner {
  final List<int> startedFsIds = <int>[];

  /// 按调用次序记录每次执行的结果控制器，便于让旧任务迟到地失败。
  final List<({int fsId, Completer<AudioItem> completer})> _calls =
      <({int fsId, Completer<AudioItem> completer})>[];
  final Map<int, CancelToken> _tokens = <int, CancelToken>{};
  final Map<int, CloudDriveEntry?> _subtitles = <int, CloudDriveEntry?>{};
  final Map<int, BaiduNetdiskImportProgressCallback> _progress =
      <int, BaiduNetdiskImportProgressCallback>{};

  Future<AudioItem> call({
    required CloudDriveEntry entry,
    CloudDriveEntry? subtitleEntry,
    String? collectionId,
    required Map<int, BaiduDownloadLink> downloadLinks,
    required CancelToken cancelToken,
    required BaiduNetdiskImportProgressCallback onProgress,
  }) {
    startedFsIds.add(entry.fsId);
    final completer = Completer<AudioItem>();
    _calls.add((fsId: entry.fsId, completer: completer));
    _tokens[entry.fsId] = cancelToken;
    _subtitles[entry.fsId] = subtitleEntry;
    _progress[entry.fsId] = onProgress;
    return completer.future;
  }

  CancelToken tokenOf(int fsId) => _tokens[fsId]!;

  CloudDriveEntry? subtitleOf(int fsId) => _subtitles[fsId];

  void reportProgress(int fsId, int received, int? total) {
    _progress[fsId]!(_entryFor(fsId), received, total);
  }

  /// 让该文件最近一次执行成功。
  void succeed(int fsId) {
    _latestCompleter(fsId).complete(_item(fsId));
  }

  /// 让该文件最近一次执行失败。
  void fail(int fsId, Object error) {
    _latestCompleter(fsId).completeError(error);
  }

  /// 让第 [callIndex] 次执行（从 0 开始）失败，用于模拟已取消的旧任务迟到结束。
  void failCall(int callIndex, Object error) {
    _calls[callIndex].completer.completeError(error);
  }

  Completer<AudioItem> _latestCompleter(int fsId) {
    return _calls.lastWhere((call) => call.fsId == fsId).completer;
  }

  CloudDriveEntry _entryFor(int fsId) => CloudDriveEntry(
    fsId: fsId,
    name: 'file-$fsId.mp3',
    path: '/file-$fsId.mp3',
    isDirectory: false,
    size: 100,
  );

  AudioItem _item(int fsId) => AudioItem(
    id: 'item-$fsId',
    name: 'file-$fsId',
    audioPath: 'audios/imported/$fsId.mp3',
    addedDate: DateTime(2026, 1, 1),
  );
}

CloudDriveEntry _audio(int fsId, {String? name}) => CloudDriveEntry(
  fsId: fsId,
  name: name ?? 'lesson-$fsId.mp3',
  path: '/lesson-$fsId.mp3',
  isDirectory: false,
  size: 100,
);

CloudDriveEntry _subtitle(int fsId, {required String name}) => CloudDriveEntry(
  fsId: fsId,
  name: name,
  path: '/$name',
  isDirectory: false,
  size: 10,
);

/// 等待一次事件循环，让 Notifier 内的异步结算完成。
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('BaiduNetdiskImportTasks', () {
    late _FakeItemRunner runner;
    late _FakeLinkFetcher linkFetcher;
    late _FakeClock clock;
    late ProviderContainer container;

    ProviderContainer createContainer({Set<int> imported = const <int>{}}) {
      final analytics = _MockAnalyticsService();
      when(() => analytics.track(any(), any())).thenAnswer((_) async {});
      return ProviderContainer(
        overrides: [
          baiduImportItemRunnerProvider.overrideWithValue(runner.call),
          baiduImportLinkFetcherProvider.overrideWithValue(linkFetcher.call),
          baiduImportedFsIdsProvider.overrideWithValue(imported),
          downloadClockProvider.overrideWithValue(() => clock.now),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
      );
    }

    BaiduNetdiskImportTasks notifier() =>
        container.read(baiduNetdiskImportTasksProvider.notifier);

    Map<int, BaiduImportTask> tasks() =>
        container.read(baiduNetdiskImportTasksProvider);

    setUp(() {
      runner = _FakeItemRunner();
      linkFetcher = _FakeLinkFetcher();
      clock = _FakeClock();
      container = createContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('整批入队只取一次下载链接，并整批提交（同时下载数由原生队列限制）', () async {
      notifier().enqueue(
        audioEntries: [_audio(1), _audio(2), _audio(3)],
        subtitleEntries: const [],
      );
      await _flush();

      expect(linkFetcher.requestedFsIds, [
        [1, 2, 3],
      ]);
      expect(runner.startedFsIds, [1, 2, 3]);
      expect(tasks()[3]!.status, BaiduImportTaskStatus.downloading);
    });

    test('同名字幕的链接与音频在同一次请求中获取', () async {
      final subtitle = _subtitle(9, name: 'lesson-1.srt');

      notifier().enqueue(audioEntries: const [], subtitleEntries: [subtitle]);
      await _flush();
      expect(linkFetcher.requestedFsIds, isEmpty);
      expect(runner.startedFsIds, isEmpty);

      notifier().enqueue(
        audioEntries: [_audio(1, name: 'lesson-1.mp3')],
        subtitleEntries: [subtitle],
      );
      await _flush();

      expect(linkFetcher.requestedFsIds.last, [1, 9]);
      expect(runner.subtitleOf(1), subtitle);
      expect(tasks()[1]!.subtitleEntry, subtitle);
    });

    test('取链接期间保持排队状态，链接就绪后才提交原生队列', () async {
      linkFetcher.holdFetches = true;

      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();

      expect(tasks()[1]!.status, BaiduImportTaskStatus.queued);
      expect(runner.startedFsIds, isEmpty);

      linkFetcher.releaseFetch();
      await _flush();

      expect(tasks()[1]!.status, BaiduImportTaskStatus.downloading);
      expect(runner.startedFsIds, [1]);
    });

    test('取链接期间取消的文件不会提交，其余文件正常提交', () async {
      linkFetcher.holdFetches = true;
      notifier().enqueue(
        audioEntries: [_audio(1), _audio(2)],
        subtitleEntries: const [],
      );
      await _flush();

      notifier().cancel(1);
      linkFetcher.releaseFetch();
      await _flush();

      expect(runner.startedFsIds, [2]);
      expect(tasks().containsKey(1), isFalse);
      expect(tasks()[2]!.status, BaiduImportTaskStatus.downloading);
    });

    test('取链接失败时整批标记为失败并保留原因，重试会重新取链接', () async {
      linkFetcher.failWith = const BaiduNetdiskFileException(
        kind: BaiduNetdiskFileErrorKind.network,
        message: 'links down',
      );
      notifier().enqueue(
        audioEntries: [_audio(1), _audio(2)],
        subtitleEntries: const [],
      );
      await _flush();

      expect(tasks()[1]!.status, BaiduImportTaskStatus.failed);
      expect(tasks()[1]!.failureMessage, 'links down');
      expect(tasks()[2]!.status, BaiduImportTaskStatus.failed);
      expect(runner.startedFsIds, isEmpty);

      linkFetcher.failWith = null;
      notifier().retry(1);
      await _flush();

      expect(linkFetcher.requestedFsIds, [
        [1, 2],
        [1],
      ]);
      expect(runner.startedFsIds, [1]);
      expect(tasks()[1]!.status, BaiduImportTaskStatus.downloading);
    });

    test('同一文件重复入队只取链接并下载一次', () async {
      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();

      expect(linkFetcher.requestedFsIds, [
        [1],
      ]);
      expect(runner.startedFsIds, [1]);
      expect(tasks(), hasLength(1));
    });

    test('资源库中已导入的文件仍会入队，交给导入流程做合集关联或补挂字幕', () async {
      container.dispose();
      container = createContainer(imported: {7});

      notifier().enqueue(audioEntries: [_audio(7)], subtitleEntries: const []);
      await _flush();

      expect(runner.startedFsIds, [7]);
      expect(tasks()[7]!.status, BaiduImportTaskStatus.downloading);
    });

    test('取消运行中的任务只取消该文件', () async {
      notifier().enqueue(
        audioEntries: [_audio(1), _audio(2)],
        subtitleEntries: const [],
      );
      await _flush();
      final cancelledToken = runner.tokenOf(1);

      notifier().cancel(1);

      expect(cancelledToken.isCancelled, isTrue);
      expect(runner.tokenOf(2).isCancelled, isFalse);
      expect(tasks().containsKey(1), isFalse);
      expect(tasks()[2]!.status, BaiduImportTaskStatus.downloading);
    });

    test('取消后重新入队，旧任务的失败结果不会覆盖新任务', () async {
      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();
      notifier().cancel(1);
      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();

      runner.failCall(
        0,
        const AudioImportException(
          AudioImportFailureCode.network,
          'stale failure',
        ),
      );
      await _flush();

      expect(runner.startedFsIds, [1, 1]);
      expect(tasks()[1]!.status, BaiduImportTaskStatus.downloading);
      expect(tasks()[1]!.failureMessage, isNull);
    });

    test('下载进度更新当前任务的已下载字节数', () async {
      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();

      runner.reportProgress(1, 40, 100);

      expect(tasks()[1]!.receivedBytes, 40);
      expect(tasks()[1]!.progress, closeTo(0.4, 1e-9));
    });

    test('下载速度按最近采样计算，采样不足时不显示', () async {
      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();

      runner.reportProgress(1, 0, 10000);
      expect(tasks()[1]!.speedBytesPerSecond, isNull);

      clock.advance(const Duration(seconds: 2));
      runner.reportProgress(1, 4096, 10000);
      expect(tasks()[1]!.speedBytesPerSecond, closeTo(2048, 1e-6));
    });

    test('入库成功后保留为本次会话已导入，清除会话标记后移除', () async {
      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();

      runner.succeed(1);
      await _flush();

      expect(tasks()[1]!.status, BaiduImportTaskStatus.added);

      notifier().clearAddedTasks();

      expect(tasks(), isEmpty);
    });

    test('已导入的任务不阻止再次入队（用于补挂字幕或加入其他合集）', () async {
      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();
      runner.succeed(1);
      await _flush();

      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();

      expect(runner.startedFsIds, [1, 1]);
    });

    test('导入失败保留失败原因，重试后重新获取链接并下载', () async {
      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();

      runner.fail(
        1,
        const AudioImportException(
          AudioImportFailureCode.network,
          'network down',
        ),
      );
      await _flush();

      expect(tasks()[1]!.status, BaiduImportTaskStatus.failed);
      expect(tasks()[1]!.failureMessage, 'network down');

      notifier().retry(1);
      await _flush();

      expect(runner.startedFsIds, [1, 1]);
      expect(tasks()[1]!.status, BaiduImportTaskStatus.downloading);
    });

    test('库中已存在同名文件时标记为重复，之后不再重复下载', () async {
      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();

      runner.fail(
        1,
        const AudioImportException(
          AudioImportFailureCode.duplicate,
          'Audio already exists: lesson-1',
        ),
      );
      await _flush();

      expect(tasks()[1]!.status, BaiduImportTaskStatus.duplicate);

      notifier().enqueue(audioEntries: [_audio(1)], subtitleEntries: const []);
      await _flush();

      expect(runner.startedFsIds, [1]);
    });

    test('取消全部任务后清空列表并取消所有下载', () async {
      notifier().enqueue(
        audioEntries: [_audio(1), _audio(2), _audio(3)],
        subtitleEntries: const [],
      );
      await _flush();
      final first = runner.tokenOf(1);
      final second = runner.tokenOf(2);

      notifier().cancelAll();

      expect(first.isCancelled, isTrue);
      expect(second.isCancelled, isTrue);
      expect(tasks(), isEmpty);
    });
  });

  group('baiduFsIdFromImportSourceUrl', () {
    test('解析百度来源 URL 中的 fs_id', () {
      expect(
        baiduFsIdFromImportSourceUrl(
          'baidunetdisk://fs/42?path=${Uri.encodeComponent('/英语/Lesson 1.mp3')}',
        ),
        42,
      );
    });

    test('非百度来源或缺少 fs_id 时返回 null', () {
      expect(baiduFsIdFromImportSourceUrl(null), isNull);
      expect(baiduFsIdFromImportSourceUrl('https://example.com/42'), isNull);
      expect(baiduFsIdFromImportSourceUrl('baidunetdisk://fs/'), isNull);
      expect(baiduFsIdFromImportSourceUrl('baidunetdisk://fs/abc'), isNull);
    });
  });

  group('pairBaiduSubtitles', () {
    test('按去扩展名后的同名规则配对，没有同名字幕的音频不出现', () {
      final pairing = pairBaiduSubtitles(
        audioEntries: [
          _audio(1, name: 'a.mp3'),
          _audio(2, name: 'b.mp3'),
        ],
        subtitleEntries: [_subtitle(3, name: 'a.srt')],
      );

      expect(pairing.keys, [1]);
      expect(pairing[1]!.fsId, 3);
    });
  });

  group('planBaiduImport', () {
    test('字幕可以匹配本次选中的音频', () {
      final plan = planBaiduImport(
        selectedAudios: [_audio(1, name: 'a.mp3')],
        selectedSubtitles: [_subtitle(2, name: 'a.srt')],
        importedAudios: const [],
      );

      expect(plan.audioEntries.map((e) => e.fsId), [1]);
      expect(plan.subtitleByAudio[1]!.fsId, 2);
      expect(plan.unmatchedSubtitleFsIds, isEmpty);
    });

    test('字幕可以匹配已导入的音频，已导入音频随之入队只补挂字幕', () {
      final plan = planBaiduImport(
        selectedAudios: const [],
        selectedSubtitles: [_subtitle(2, name: 'a.srt')],
        importedAudios: [_audio(1, name: 'a.mp3')],
      );

      expect(plan.audioEntries.map((e) => e.fsId), [1]);
      expect(plan.subtitleByAudio[1]!.fsId, 2);
      expect(plan.unmatchedSubtitleFsIds, isEmpty);
    });

    test('已导入的音频没有选中字幕时不入队', () {
      final plan = planBaiduImport(
        selectedAudios: const [],
        selectedSubtitles: const [],
        importedAudios: [_audio(1, name: 'a.mp3')],
      );

      expect(plan.audioEntries, isEmpty);
    });

    test('既没有选中也没有已导入同名音频的字幕标记为未匹配', () {
      final plan = planBaiduImport(
        selectedAudios: [_audio(1, name: 'a.mp3')],
        selectedSubtitles: [_subtitle(2, name: 'b.srt')],
        importedAudios: const [],
      );

      expect(plan.unmatchedSubtitleFsIds, {2});
    });
  });
}
