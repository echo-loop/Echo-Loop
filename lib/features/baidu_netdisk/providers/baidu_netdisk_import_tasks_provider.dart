/// 百度网盘导入下载任务（App 运行期常驻，不落库）。
library;

import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../analytics/models/event_names.dart';
import '../../../models/audio_item.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../providers/download_clock_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/app_logger.dart';
import '../../../services/background_download_task_inspector.dart';
import '../../../services/download_speed_meter.dart';
import '../../../services/resource_download_registry.dart';
import '../../audio_import/audio_import_models.dart';
import '../../audio_import/subtitle_pairing.dart';
import '../data/baidu_credential_repository.dart';
import '../data/baidu_netdisk_api.dart';
import '../data/baidu_netdisk_import_service.dart';
import '../models/cloud_drive_models.dart';
import 'baidu_netdisk_providers.dart';

/// 单个文件导入任务的状态。
///
/// 同时下载的数量由原生下载队列（`maxConcurrentDownloads`）限制，Dart 侧不再排队：
/// 任务一旦取得下载链接就整批提交原生队列，App 进入后台后仍能自行推进。
enum BaiduImportTaskStatus {
  /// 正在批量获取下载链接，尚未提交原生队列。
  queued,

  /// 已提交原生队列（含同名字幕），等待或正在下载与入库。
  /// 是否仍在原生队列中排队由资源登记表区分（见 import_audio_sheet）。
  downloading,

  /// 库中已存在同名或同 SHA 的音频，未重复入库。
  duplicate,

  /// 本次导入弹窗打开期间成功（入库，或为已导入素材补挂字幕/加入合集）。
  /// 弹窗再次打开时清除，目录行据此显示对勾。
  added,

  /// 下载或入库失败，可重试。
  failed,
}

/// 一个百度网盘音频导入任务。
///
/// 成功入库的任务会被移除：是否"已导入"由音频库派生（见 [baiduImportedFsIdsProvider]），
/// 这样删除库内素材后可以重新导入。
@immutable
class BaiduImportTask {
  /// 构造导入任务。
  const BaiduImportTask({
    required this.audioEntry,
    this.subtitleEntry,
    this.collectionId,
    this.status = BaiduImportTaskStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes,
    this.speedBytesPerSecond,
    this.failureMessage,
  });

  /// 要导入的音频条目。
  final CloudDriveEntry audioEntry;

  /// 与音频同名配对的字幕条目；无配对时为 null。
  final CloudDriveEntry? subtitleEntry;

  /// 导入目标合集；null 表示只进入资源库。
  final String? collectionId;

  /// 当前状态。
  final BaiduImportTaskStatus status;

  /// 音频已下载字节数。
  final int receivedBytes;

  /// 音频总字节数；未知时为 null。
  final int? totalBytes;

  /// 最近约 5 秒的平均下载速度（字节/秒）；采样不足时为 null。
  final double? speedBytesPerSecond;

  /// 失败原因，仅 [BaiduImportTaskStatus.failed] 时有值。
  final String? failureMessage;

  /// 下载进度 0~1；总量未知时为 null（不定进度）。
  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }

  /// 是否仍在进行中（取链接、排队或下载）。
  bool get isActive =>
      status == BaiduImportTaskStatus.queued ||
      status == BaiduImportTaskStatus.downloading;

  /// 复制任务。[failureMessage] 仅在失败时写入，其余状态流转由调用方重建任务。
  BaiduImportTask copyWith({
    BaiduImportTaskStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? failureMessage,
  }) {
    return BaiduImportTask(
      audioEntry: audioEntry,
      subtitleEntry: subtitleEntry,
      collectionId: collectionId,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }

  /// 写入一次下载进度；速度总是以本次计算结果为准（包括 null）。
  BaiduImportTask withProgress({
    required int receivedBytes,
    required int? totalBytes,
    required double? speedBytesPerSecond,
  }) {
    return BaiduImportTask(
      audioEntry: audioEntry,
      subtitleEntry: subtitleEntry,
      collectionId: collectionId,
      status: status,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
      speedBytesPerSecond: speedBytesPerSecond,
      failureMessage: failureMessage,
    );
  }
}

/// 单个文件的导入执行函数。生产环境绑定到 [BaiduNetdiskImportService.importAudio]。
typedef BaiduImportItemRunner = Future<AudioItem> Function({
  required CloudDriveEntry entry,
  CloudDriveEntry? subtitleEntry,
  String? collectionId,
  required Map<int, BaiduDownloadLink> downloadLinks,
  required CancelToken cancelToken,
  required BaiduNetdiskImportProgressCallback onProgress,
});

/// 批量获取下载链接的执行函数。生产环境绑定到 [BaiduNetdiskImportService.fetchDownloadLinks]。
typedef BaiduImportLinkFetcher = Future<Map<int, BaiduDownloadLink>> Function(
  List<CloudDriveEntry> entries,
);

/// 批量获取下载链接 provider；测试中可替换为假实现。
final baiduImportLinkFetcherProvider = Provider<BaiduImportLinkFetcher>((ref) {
  final service = ref.watch(baiduNetdiskImportServiceProvider);
  return (entries) => service.fetchDownloadLinks(entries: entries);
});

/// 单文件导入执行函数 provider；测试中可替换为假实现。
final baiduImportItemRunnerProvider = Provider<BaiduImportItemRunner>((ref) {
  final service = ref.watch(baiduNetdiskImportServiceProvider);
  return ({
    required CloudDriveEntry entry,
    CloudDriveEntry? subtitleEntry,
    String? collectionId,
    required Map<int, BaiduDownloadLink> downloadLinks,
    required CancelToken cancelToken,
    required BaiduNetdiskImportProgressCallback onProgress,
  }) {
    // 库状态在注册时才读取，避免同批任务并发时使用过期快照。
    final hasCollection = collectionId != null;
    return service.importAudio(
      entry: entry,
      subtitleEntry: subtitleEntry,
      audioLibrary: ref.read(audioLibraryProvider.notifier),
      readAudioLibraryState: () => ref.read(audioLibraryProvider),
      collectionList: hasCollection
          ? ref.read(collectionListProvider.notifier)
          : null,
      readCollectionState: hasCollection
          ? () => ref.read(collectionListProvider)
          : null,
      collectionId: collectionId,
      downloadLinks: downloadLinks,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
  };
});

/// 正在获取下载链接（尚未提交原生队列）的百度导入任务，映射为调试页可展示的任务信息。
///
/// 这些任务没有持久化记录，因此不可删除。
final baiduWaitingDownloadInfosProvider = Provider<List<DownloadTaskInfo>>((
  ref,
) {
  final tasks = ref.watch(baiduNetdiskImportTasksProvider).values;
  return [
    for (final task in tasks)
      if (task.status == BaiduImportTaskStatus.queued)
        DownloadTaskInfo(
          taskId: 'waiting-${task.audioEntry.fsId}',
          resourceKey: baiduResourceKey(task.audioEntry.fsId),
          displayName: task.audioEntry.name,
          host: '',
          status: TaskStatus.enqueued,
          progress: null,
          receivedBytes: null,
          expectedBytes: null,
          // 原生任务启动后会使用的重试次数，等待期间尚未消耗。
          retriesRemaining: 2,
          errorDescription: null,
        ),
  ];
});

/// 已由百度网盘导入的文件 fs_id -> 其所在合集的名称（不在任何合集中时为空列表）。
///
/// 目录行据此提示"已导入到哪些合集"。
final baiduImportedCollectionNamesProvider = Provider<Map<int, List<String>>>((
  ref,
) {
  final items = ref.watch(audioLibraryProvider).audioItems;
  final collections = ref.watch(collectionListProvider);
  final collectionIdsByAudioId = collections.audioToCollectionsMap;
  final nameByCollectionId = {
    for (final collection in collections.rawCollections)
      collection.id: collection.name,
  };
  final result = <int, List<String>>{};
  for (final item in items) {
    if (item.importSourceType != AudioImportSourceType.cloudDrive) continue;
    final fsId = baiduFsIdFromImportSourceUrl(item.importSourceUrl);
    if (fsId == null) continue;
    result[fsId] = [
      for (final collectionId
          in collectionIdsByAudioId[item.id] ?? const <String>[])
        ?nameByCollectionId[collectionId],
    ];
  }
  return result;
});

/// 资源库中已由百度网盘导入的文件 fs_id 集合。
///
/// 以音频库为唯一事实来源，删除素材后自动从集合中移除。
final baiduImportedFsIdsProvider = Provider<Set<int>>((ref) {
  final items = ref.watch(audioLibraryProvider).audioItems;
  return {
    for (final item in items)
      if (item.importSourceType == AudioImportSourceType.cloudDrive)
        ?baiduFsIdFromImportSourceUrl(item.importSourceUrl),
  };
});

/// 已提交原生下载队列、但尚未轮到开始下载的百度导入音频 fs_id 集合。
///
/// 任务状态为 downloading 只表示已提交；是否真正排队由资源登记表决定（同一时刻只下 2 个）。
final baiduNativelyQueuedFsIdsProvider = Provider<Set<int>>((ref) {
  final tasks = ref.watch(baiduNetdiskImportTasksProvider);
  final resources = ref.watch(resourceDownloadsProvider);
  return {
    for (final task in tasks.values)
      if (task.status == BaiduImportTaskStatus.downloading &&
          resources[baiduResourceKey(task.audioEntry.fsId)] is ResourceQueued)
        task.audioEntry.fsId,
  };
});

/// 把同批选中的音频与字幕按去扩展名同名配对。
///
/// 返回 音频 fs_id -> 字幕条目；没有同名字幕的音频不出现在结果中。
Map<int, CloudDriveEntry> pairBaiduSubtitles({
  required List<CloudDriveEntry> audioEntries,
  required List<CloudDriveEntry> subtitleEntries,
}) {
  if (audioEntries.isEmpty || subtitleEntries.isEmpty) {
    return const <int, CloudDriveEntry>{};
  }
  final entriesByName = <String, CloudDriveEntry>{
    for (final entry in [...audioEntries, ...subtitleEntries])
      entry.name: entry,
  };
  final pairing = matchSubtitlesForAudios(entriesByName.keys);
  final result = <int, CloudDriveEntry>{};
  for (final audio in audioEntries) {
    final subtitleName = pairing[audio.name];
    final subtitle = subtitleName == null ? null : entriesByName[subtitleName];
    if (subtitle != null) result[audio.fsId] = subtitle;
  }
  return result;
}

/// 一次导入的计划：哪些音频入队、哪些字幕配对上、哪些字幕没有配对。
class BaiduImportPlan {
  const BaiduImportPlan({
    required this.audioEntries,
    required this.subtitleEntries,
    required this.subtitleByAudio,
    required this.unmatchedSubtitleFsIds,
  });

  /// 需要入队的音频：本次选中的，加上与选中字幕配对的已导入音频。
  final List<CloudDriveEntry> audioEntries;

  /// 本次选中的字幕。
  final List<CloudDriveEntry> subtitleEntries;

  /// 音频 fs_id -> 配对的字幕。
  final Map<int, CloudDriveEntry> subtitleByAudio;

  /// 已选中但没有同名音频（本次选中或已导入）的字幕 fs_id。
  final Set<int> unmatchedSubtitleFsIds;
}

/// 计算导入计划。字幕可以匹配“本次选中的音频”，也可以匹配“当前目录中已导入的音频”。
///
/// 已导入的音频只在能配对上选中字幕时才入队，入队后只补挂字幕，不重复下载音频。
BaiduImportPlan planBaiduImport({
  required List<CloudDriveEntry> selectedAudios,
  required List<CloudDriveEntry> selectedSubtitles,
  required List<CloudDriveEntry> importedAudios,
}) {
  final selectedFsIds = {for (final audio in selectedAudios) audio.fsId};
  final candidates = [
    ...selectedAudios,
    for (final audio in importedAudios)
      if (!selectedFsIds.contains(audio.fsId)) audio,
  ];
  final pairs = pairBaiduSubtitles(
    audioEntries: candidates,
    subtitleEntries: selectedSubtitles,
  );
  final pairedSubtitleFsIds = {
    for (final subtitle in pairs.values) subtitle.fsId,
  };
  return BaiduImportPlan(
    audioEntries: [
      ...selectedAudios,
      for (final audio in importedAudios)
        if (!selectedFsIds.contains(audio.fsId) &&
            pairs.containsKey(audio.fsId))
          audio,
    ],
    subtitleEntries: selectedSubtitles,
    subtitleByAudio: pairs,
    unmatchedSubtitleFsIds: {
      for (final subtitle in selectedSubtitles)
        if (!pairedSubtitleFsIds.contains(subtitle.fsId)) subtitle.fsId,
    },
  );
}

/// 百度网盘导入任务 provider。状态为 音频 fs_id -> 任务。
final baiduNetdiskImportTasksProvider =
    NotifierProvider<BaiduNetdiskImportTasks, Map<int, BaiduImportTask>>(
      BaiduNetdiskImportTasks.new,
    );

/// 管理百度网盘导入任务：入队去重、并发调度、单任务取消与重试。
///
/// 每个运行中的任务持有独立 [CancelToken]，并以它识别是否仍为当前任务：
/// 取消或重试后，旧任务的回调不会覆盖新状态（见 docs/troubleshooting.md §7.37）。
class BaiduNetdiskImportTasks extends Notifier<Map<int, BaiduImportTask>> {
  /// 进行中（取链接或下载）任务的取消令牌，按音频 fs_id 索引。
  final Map<int, CancelToken> _runningTokens = <int, CancelToken>{};

  /// 运行中任务的速度计算器，每次开始下载时重建。
  final Map<int, DownloadSpeedMeter> _speedMeters = <int, DownloadSpeedMeter>{};

  @override
  Map<int, BaiduImportTask> build() {
    ref.onDispose(() {
      for (final token in _runningTokens.values) {
        token.cancel('disposed');
      }
      _runningTokens.clear();
    });
    return const <int, BaiduImportTask>{};
  }

  /// 把选中的音频加入下载队列，同名字幕自动挂到对应音频上。
  ///
  /// 已排队/下载中/重复的文件与资源库中已导入的文件会被跳过。仅选中字幕时不入队。
  void enqueue({
    required List<CloudDriveEntry> audioEntries,
    required List<CloudDriveEntry> subtitleEntries,
    String? collectionId,
  }) {
    final subtitleByAudio = pairBaiduSubtitles(
      audioEntries: audioEntries,
      subtitleEntries: subtitleEntries,
    );
    final next = Map<int, BaiduImportTask>.of(state);
    final batch = <BaiduImportTask>[];
    for (final audio in audioEntries) {
      // 已导入的素材也允许入队：服务层会跳过音频下载，只关联合集或补挂字幕。
      if (_blocksEnqueue(next[audio.fsId])) continue;
      next.remove(audio.fsId);
      final task = BaiduImportTask(
        audioEntry: audio,
        subtitleEntry: subtitleByAudio[audio.fsId],
        collectionId: collectionId,
      );
      next[audio.fsId] = task;
      batch.add(task);
    }
    if (batch.isEmpty) return;
    AppLogger.log('BaiduNetdiskImport', '加入下载队列 ${batch.length} 个文件');
    state = next;
    unawaited(_submitBatch(batch));
  }

  /// 取消单个任务。取链接中或下载中的任务会立即取消，取链接结束后会被识别为过期而丢弃。
  void cancel(int audioFsId) {
    final token = _runningTokens.remove(audioFsId);
    _speedMeters.remove(audioFsId);
    if (token == null && !state.containsKey(audioFsId)) return;
    state = Map<int, BaiduImportTask>.of(state)..remove(audioFsId);
    token?.cancel('user-cancelled');
    AppLogger.log('BaiduNetdiskImport', '用户取消导入任务 fs_id=$audioFsId');
  }

  /// 重新导入失败的任务，沿用原字幕配对与合集。
  void retry(int audioFsId) {
    final task = state[audioFsId];
    if (task == null || task.status != BaiduImportTaskStatus.failed) return;
    final subtitle = task.subtitleEntry;
    enqueue(
      audioEntries: [task.audioEntry],
      subtitleEntries: subtitle == null ? const [] : [subtitle],
      collectionId: task.collectionId,
    );
  }

  /// 清除本次会话成功的任务标记（导入弹窗打开时调用）。
  void clearAddedTasks() {
    if (!state.values.any(
      (task) => task.status == BaiduImportTaskStatus.added,
    )) {
      return;
    }
    state = Map<int, BaiduImportTask>.of(state)
      ..removeWhere((_, task) => task.status == BaiduImportTaskStatus.added);
  }

  /// 取消全部任务并清空列表（断开百度账号时调用）。
  void cancelAll() {
    for (final token in _runningTokens.values) {
      token.cancel('user-cancelled');
    }
    _runningTokens.clear();
    _speedMeters.clear();
    state = const <int, BaiduImportTask>{};
  }

  /// 是否阻止同一文件再次入队：排队/下载中，或上次为重复（不再重复下载）。
  /// 失败的任务允许重新入队。
  bool _blocksEnqueue(BaiduImportTask? task) {
    if (task == null) return false;
    return switch (task.status) {
      BaiduImportTaskStatus.queued ||
      BaiduImportTaskStatus.downloading ||
      BaiduImportTaskStatus.duplicate => true,
      BaiduImportTaskStatus.added || BaiduImportTaskStatus.failed => false,
    };
  }

  /// 整批获取下载链接后，逐个提交给原生下载队列。同时下载数由原生队列限制，
  /// 因此 App 进入后台后，原生队列完成一个文件即可自动接上下一个。
  ///
  /// 取链接失败时整批标记为失败，每个文件可单独重试。
  Future<void> _submitBatch(List<BaiduImportTask> batch) async {
    final tokens = <int, CancelToken>{
      for (final task in batch) task.audioEntry.fsId: CancelToken(),
    };
    _runningTokens.addAll(tokens);
    final fetchLinks = ref.read(baiduImportLinkFetcherProvider);
    final Map<int, BaiduDownloadLink> downloadLinks;
    try {
      downloadLinks = await fetchLinks([
        for (final task in batch) ...[task.audioEntry, ?task.subtitleEntry],
      ]);
    } on Object catch (error, stackTrace) {
      AppLogger.log(
        'BaiduNetdiskImport',
        '获取下载链接失败 count=${batch.length}: $error\n$stackTrace',
      );
      for (final task in batch) {
        final fsId = task.audioEntry.fsId;
        final token = tokens[fsId]!;
        if (!_isCurrent(fsId, token)) continue;
        // 必须先结算再释放 token：结算依赖 token 判断是否仍为当前任务。
        _settle(fsId, token, _TaskOutcome.failed, _messageForError(error));
        _releaseToken(fsId, token);
      }
      return;
    }
    for (final task in batch) {
      final fsId = task.audioEntry.fsId;
      final token = tokens[fsId]!;
      // 取链接期间若已取消或重试，旧批次的结果直接丢弃。
      if (!_isCurrent(fsId, token)) continue;
      unawaited(_run(fsId, token, downloadLinks));
    }
  }

  void _releaseToken(int audioFsId, CancelToken token) {
    if (!identical(_runningTokens[audioFsId], token)) return;
    _runningTokens.remove(audioFsId);
    _speedMeters.remove(audioFsId);
  }

  Future<void> _run(
    int audioFsId,
    CancelToken token,
    Map<int, BaiduDownloadLink> downloadLinks,
  ) async {
    final task = state[audioFsId];
    if (task == null) return;
    _speedMeters[audioFsId] = DownloadSpeedMeter(
      now: ref.read(downloadClockProvider),
    );
    _replace(
      audioFsId,
      task.copyWith(status: BaiduImportTaskStatus.downloading),
    );
    final runner = ref.read(baiduImportItemRunnerProvider);
    var outcome = _TaskOutcome.completed;
    String? failureMessage;
    try {
      await runner(
        entry: task.audioEntry,
        subtitleEntry: task.subtitleEntry,
        collectionId: task.collectionId,
        downloadLinks: downloadLinks,
        cancelToken: token,
        onProgress: (entry, received, total) =>
            _onProgress(audioFsId, token, received, total),
      );
    } on AudioImportException catch (error) {
      outcome = switch (error.code) {
        AudioImportFailureCode.duplicate => _TaskOutcome.duplicate,
        AudioImportFailureCode.canceled => _TaskOutcome.canceled,
        _ => _TaskOutcome.failed,
      };
      failureMessage = error.message;
    } on Object catch (error, stackTrace) {
      if (_isCancellation(error)) {
        outcome = _TaskOutcome.canceled;
      } else {
        outcome = _TaskOutcome.failed;
        failureMessage = _messageForError(error);
        AppLogger.log(
          'BaiduNetdiskImport',
          '导入失败 fs_id=$audioFsId: $error\n$stackTrace',
        );
      }
    } finally {
      // 必须先结算再释放 token：结算依赖 token 判断是否仍为当前任务。
      _settle(audioFsId, token, outcome, failureMessage);
      _releaseToken(audioFsId, token);
    }
  }

  void _onProgress(int audioFsId, CancelToken token, int received, int? total) {
    if (!_isCurrent(audioFsId, token)) return;
    final task = state[audioFsId];
    if (task == null) return;
    _replace(
      audioFsId,
      task.withProgress(
        receivedBytes: received,
        totalBytes: total,
        speedBytesPerSecond: _speedMeters[audioFsId]?.record(received),
      ),
    );
  }

  void _settle(
    int audioFsId,
    CancelToken token,
    _TaskOutcome outcome,
    String? failureMessage,
  ) {
    _trackResult(outcome);
    if (!_isCurrent(audioFsId, token)) return;
    final task = state[audioFsId];
    if (task == null) return;
    switch (outcome) {
      case _TaskOutcome.completed:
        // 保留为"本次会话已导入"，目录行据此显示对勾；弹窗打开时清除。
        _replace(audioFsId, task.copyWith(status: BaiduImportTaskStatus.added));
      case _TaskOutcome.duplicate:
        _replace(
          audioFsId,
          task.copyWith(status: BaiduImportTaskStatus.duplicate),
        );
      case _TaskOutcome.failed:
        _replace(
          audioFsId,
          BaiduImportTask(
            audioEntry: task.audioEntry,
            subtitleEntry: task.subtitleEntry,
            collectionId: task.collectionId,
            status: BaiduImportTaskStatus.failed,
            failureMessage: failureMessage,
          ),
        );
      case _TaskOutcome.canceled:
        // 取消已在 cancel() 中移除任务，这里无需再改状态。
        break;
    }
  }

  bool _isCurrent(int audioFsId, CancelToken token) {
    return identical(_runningTokens[audioFsId], token);
  }

  void _replace(int audioFsId, BaiduImportTask task) {
    state = Map<int, BaiduImportTask>.of(state)..[audioFsId] = task;
  }

  void _trackResult(_TaskOutcome outcome) {
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(Events.cloudImportResult, {
      EventParams.result: switch (outcome) {
        _TaskOutcome.completed => 'completed',
        _TaskOutcome.duplicate => 'duplicate',
        _TaskOutcome.canceled => 'cancelled',
        _TaskOutcome.failed => 'failed',
      },
      EventParams.source: 'baidu_netdisk',
      EventParams.selectedCount: 1,
    });
  }

  bool _isCancellation(Object error) => switch (error) {
    BaiduNetdiskFileException(kind: BaiduNetdiskFileErrorKind.canceled) => true,
    DioException() when CancelToken.isCancel(error) => true,
    _ => false,
  };

  String _messageForError(Object error) {
    if (error is BaiduReauthorizationRequiredException) {
      return 'Please connect Baidu Netdisk again.';
    }
    if (error is BaiduNetdiskFileException) return error.message;
    return 'Baidu Netdisk import failed.';
  }
}

enum _TaskOutcome { completed, duplicate, canceled, failed }
