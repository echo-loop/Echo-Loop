import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/audio_item.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/collection_provider.dart';
import '../../providers/download_clock_provider.dart';
import '../../providers/download_provider.dart';
import '../../services/download_speed_meter.dart';
import 'audio_import_models.dart';
import 'audio_import_service.dart';

part 'audio_import_provider.g.dart';

@riverpod
AudioImportService audioImportService(Ref ref) {
  return AudioImportService(
    backgroundDownloader: ref.watch(backgroundFileDownloadServiceProvider),
  );
}

// keepAlive：离开页面不销毁控制器，下载在后台继续，完成后照常入库。
// 下载只能由用户主动 cancel() 取消，不能因为页面销毁而取消。
@Riverpod(keepAlive: true)
class AudioImportController extends _$AudioImportController {
  CancelToken? _cancelToken;
  int _sessionId = 0;

  @override
  AudioImportState build() => const AudioImportIdle();

  /// 异步结果是否已过期：用户开启了新会话，或 provider 已销毁（销毁会取消下载）。
  /// 过期时不得再读 [ref] 或写 state。
  bool _isStale(int sid) => sid != _sessionId || !ref.mounted;

  Future<AudioItem?> importFromUrl(String url, {String? collectionId}) async {
    if (state is AudioImportDownloading || state is AudioImportSaving) {
      return null;
    }

    _sessionId++;
    final sid = _sessionId;
    _cancelToken = CancelToken();
    state = const AudioImportResolving();

    try {
      final item = await ref
          .read(audioImportServiceProvider)
          .importFromUrl(
            url: url,
            audioLibrary: ref.read(audioLibraryProvider.notifier),
            audioLibraryState: ref.read(audioLibraryProvider),
            collectionList: collectionId == null
                ? null
                : ref.read(collectionListProvider.notifier),
            collectionState: collectionId == null
                ? null
                : ref.read(collectionListProvider),
            collectionId: collectionId,
            cancelToken: _cancelToken,
            onProgress: (received, total) {
              if (_isStale(sid)) return;
              final progress = total == null || total <= 0
                  ? -1.0
                  : received / total;
              state = AudioImportDownloading(
                displayName: url,
                progress: progress,
                receivedBytes: received,
                totalBytes: total,
              );
            },
          );
      if (_isStale(sid)) return null;
      state = AudioImportCompleted(item);
      // 后台检测内容有效性（不阻塞返回）。
      unawaited(
        ref.read(audioLibraryProvider.notifier).checkAudioContent(item.id),
      );
      return item;
    } on AudioImportException catch (e) {
      if (_isStale(sid)) return null;
      state = e.code == AudioImportFailureCode.canceled
          ? const AudioImportIdle()
          : AudioImportFailed(e);
      return null;
    } catch (e) {
      if (_isStale(sid)) return null;
      state = AudioImportFailed(
        AudioImportException(
          AudioImportFailureCode.unknown,
          'Audio import failed',
          e,
        ),
      );
      return null;
    } finally {
      if (sid == _sessionId) _cancelToken = null;
    }
  }

  Future<void> cancel() async {
    _cancelToken?.cancel('user-cancelled');
  }

  void reset() {
    if (state is AudioImportDownloading || state is AudioImportSaving) return;
    state = const AudioImportIdle();
  }
}

/// Podcast 单集懒下载控制器。
///
/// 与 [AudioImportController]（从链接导入）**完全独立**：两条流程各自持有状态，
/// 一方的下载失败不会污染另一方的 UI（避免播客下载失败后，打开「从链接导入」
/// 误显下载失败提示）。复用同一套 [AudioImportState] 模型类。
// keepAlive：同 AudioImportController，离开页面后下载继续。
@Riverpod(keepAlive: true)
class PodcastDownloadController extends _$PodcastDownloadController {
  final Map<String, _PodcastDownload> _active = {};
  int _sessionCounter = 0;

  /// 每个单集一个状态；不同单集可以同时下载，超出并发的由下载队列排队。
  @override
  Map<String, AudioImportState> build() => const {};

  /// 异步结果是否已过期：该单集已取消、已结束或被新会话替换。过期时不得写 state。
  bool _isStale(String audioItemId, int sid) =>
      _active[audioItemId]?.sessionId != sid || !ref.mounted;

  void _put(String audioItemId, AudioImportState value) {
    state = {...state, audioItemId: value};
  }

  void _remove(String audioItemId) {
    if (!state.containsKey(audioItemId)) return;
    state = Map.of(state)..remove(audioItemId);
  }

  /// Podcast 单集懒下载：下载 enclosure 到沙盒并**就地更新现有占位条目**，
  /// 不新建 [AudioItem]（避免资源库出现重复孤儿条目）。
  ///
  /// 成功返回 true 并已写回 audioPath / 时长 / 指纹；失败返回 false 并置
  /// [AudioImportFailed]。后台下载通知沿用列表项的 [AudioItem.name]；state 的
  /// displayName 仍取 enclosure URL，与列表项的行内进度条匹配逻辑一致。
  Future<bool> downloadPodcastEpisode(AudioItem item) async {
    // 同一单集已在下载或保存中：不再建第二个任务。
    // 上一次失败留下的 AudioImportFailed 不是进行中的任务，必须允许用户重试覆盖它。
    final current = state[item.id];
    if (current != null && current is! AudioImportFailed) return false;
    final enclosureUrl = item.podcastEnclosureUrl;
    if (enclosureUrl == null || enclosureUrl.isEmpty) return false;

    final sid = ++_sessionCounter;
    final cancelToken = CancelToken();
    _active[item.id] = _PodcastDownload(sid, cancelToken);
    // 立即进入下载态，保证行内进度条第一时间出现（不定进度）。
    _put(
      item.id,
      AudioImportDownloading(displayName: enclosureUrl, progress: -1.0),
    );

    final service = ref.read(audioImportServiceProvider);
    final speedMeter = DownloadSpeedMeter(now: ref.read(downloadClockProvider));
    try {
      final result = await service.downloadEpisodeToSandbox(
        url: enclosureUrl,
        displayName: item.name,
        enclosureType: item.podcastEnclosureType,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (_isStale(item.id, sid)) return;
          final progress = total == null || total <= 0
              ? -1.0
              : received / total;
          _put(
            item.id,
            AudioImportDownloading(
              displayName: enclosureUrl,
              progress: progress,
              receivedBytes: received,
              totalBytes: total,
              speedBytesPerSecond: speedMeter.record(received),
            ),
          );
        },
      );
      if (_isStale(item.id, sid)) {
        await service.discardDownloadedAudio(result);
        return false;
      }

      // 解码失败（durationSeconds==0）不再回退 RSS 时长：宁可不显示，也不展示
      // 假时长。内容检测另用 FFmpeg 短解码和波形判断，不依赖此时长。
      final downloadedItem = item.copyWith(
        audioPath: result.relativePath,
        totalDuration: result.durationSeconds,
        audioSha256: result.audioSha256,
        originalAudioSha256: result.originalAudioSha256,
      );
      await ref
          .read(audioLibraryProvider.notifier)
          .updateAudioItem(downloadedItem);
      // 音频已写回资源库；provider 若已销毁则不再写 state（结果已持久化，无需回滚）。
      if (!ref.mounted) return true;
      _remove(item.id);
      // 后台检测内容有效性（复用已算出的解码时长，不阻塞返回）。
      unawaited(
        ref
            .read(audioLibraryProvider.notifier)
            .checkAudioContent(
              item.id,
              decodedDurationSeconds: result.durationSeconds,
            ),
      );
      return true;
    } on AudioImportException catch (e) {
      if (_isStale(item.id, sid)) return false;
      _put(item.id, AudioImportFailed(e, audioItemId: item.id));
      return false;
    } catch (e) {
      if (_isStale(item.id, sid)) return false;
      _put(
        item.id,
        AudioImportFailed(
          AudioImportException(
            AudioImportFailureCode.unknown,
            'Podcast episode download failed',
            e,
          ),
          audioItemId: item.id,
        ),
      );
      return false;
    } finally {
      if (_active[item.id]?.sessionId == sid) _active.remove(item.id);
    }
  }

  /// 取消某个单集的下载，并让迟到的下载结果失效。
  void cancel(String audioItemId) {
    final active = _active.remove(audioItemId);
    _remove(audioItemId);
    active?.token.cancel('user-cancelled');
  }
}

/// 单个单集的进行中下载。
class _PodcastDownload {
  _PodcastDownload(this.sessionId, this.token);

  final int sessionId;
  final CancelToken token;
}
