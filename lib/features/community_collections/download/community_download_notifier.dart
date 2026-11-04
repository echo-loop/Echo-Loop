import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../database/app_database.dart' as db;
import '../../../database/providers.dart';
import '../../../features/user_region/user_region_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/word_timestamp.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../providers/favorite_sentence_lifecycle_provider.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../providers/listening_practice/listening_practice_provider.dart';
import '../../../providers/download_clock_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/app_logger.dart';
import '../../../services/download_speed_meter.dart';
import '../../../utils/app_data_dir.dart';
import '../../../utils/srt_generator.dart';
import '../../../utils/transcript_stats.dart';
import '../data/community_collection_api.dart';
import '../data/community_file_lifecycle.dart';
import '../models/community_asset_url.dart';
import '../models/community_collection_models.dart';
import 'download_progress.dart';

part 'community_download_notifier.g.dart';

/// 用于在任何页面推送下载失败提示的全局 key。
final GlobalKey<ScaffoldMessengerState> communityDownloadScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 社区合集媒体和字幕下载调度器。
///
/// 状态按条目（audioItemId）保存：不同条目可以同时下载，超出并发的由下载队列排队；
/// 同一条目重复请求不会建第二个任务。
@Riverpod(keepAlive: true)
class CommunityDownload extends _$CommunityDownload {
  final Map<String, _ActiveDownload> _active = {};
  final Set<String> _starting = {};
  int _sessionCounter = 0;

  @override
  Map<String, DownloadProgress> build() => const {};

  /// 下载文件及对应字幕，下载前通过 remote collection/file ID 定位资源。
  Future<StartResult> start({
    required String audioItemId,
    required String displayName,
  }) async {
    if (state.containsKey(audioItemId) || !_starting.add(audioItemId)) {
      AppLogger.log(
        'CommunityDownload',
        'start rejected: already running id=$audioItemId',
      );
      return StartResult.alreadyRunning;
    }
    try {
      final database = ref.read(appDatabaseProvider);
      final item = await database.audioItemDao.getById(audioItemId);
      if (item?.communityUnavailableAt != null) {
        AppLogger.log(
          'CommunityDownload',
          'start rejected: unavailable id=$audioItemId',
        );
        return StartResult.unavailable;
      }
      if (item == null ||
          item.remoteAudioId == null ||
          item.audioPath != null) {
        AppLogger.log(
          'CommunityDownload',
          'start rejected: already ready or not remote id=$audioItemId',
        );
        return StartResult.alreadyDownloaded;
      }
      final collectionId = await database.collectionDao
          .getCommunityRemoteIdForAudio(audioItemId);
      if (collectionId == null) {
        AppLogger.log(
          'CommunityDownload',
          'start rejected: not community id=$audioItemId',
        );
        return StartResult.notCommunity;
      }

      final sessionId = ++_sessionCounter;
      AppLogger.log(
        'CommunityDownload',
        'start session=$sessionId id=$audioItemId '
            'collection=$collectionId remoteAudio=${item.remoteAudioId}',
      );
      final active = _ActiveDownload(
        sessionId: sessionId,
        token: CancelToken(),
        speedMeter: DownloadSpeedMeter(now: ref.read(downloadClockProvider)),
      );
      _active[audioItemId] = active;
      state = {
        ...state,
        audioItemId: DownloadInProgress(
          audioItemId: audioItemId,
          displayName: displayName,
          progress: -1,
        ),
      };
      active.future = _runDownload(
        sessionId,
        item,
        collectionId,
        active.token,
        displayName,
      );
      unawaited(active.future);
      return StartResult.started;
    } finally {
      _starting.remove(audioItemId);
    }
  }

  /// 取消某个条目的下载，并等待旧任务清理临时文件。
  Future<void> cancel(String audioItemId) async {
    final active = _active.remove(audioItemId);
    _remove(audioItemId);
    if (active == null) return;
    AppLogger.log('CommunityDownload', 'cancel by user id=$audioItemId');
    active.token.cancel('user-cancelled');
    await active.future;
  }

  /// 拉取最新字幕并清理依赖旧句子索引的学习状态。
  Future<SubtitleUpdateResult> updateTranscript({
    required String audioItemId,
  }) async {
    final database = ref.read(appDatabaseProvider);
    final item = await database.audioItemDao.getById(audioItemId);
    if (item == null) return SubtitleUpdateResult.notFound;
    final remoteId = item.remoteAudioId;
    final collectionId = await database.collectionDao
        .getCommunityRemoteIdForAudio(audioItemId);
    if (remoteId == null || collectionId == null) {
      return SubtitleUpdateResult.notCommunity;
    }
    final collection = await database.collectionDao.getByRemoteId(collectionId);
    if (collection == null) return SubtitleUpdateResult.notCommunity;
    final subtitle = await ref
        .read(communityCollectionApiProvider)
        .getFileDetail(collectionId, remoteId);
    await _persistFileMetadata(
      database,
      audioItemId: audioItemId,
      file: subtitle.file,
    );
    await ref.read(audioLibraryProvider.notifier).loadLibrary();
    await ref.read(collectionListProvider.notifier).loadCollections();
    final srt = _toSrt(subtitle.subtitle);
    if (srt.isEmpty) throw CommunitySubtitleUnavailable(remoteId);
    final stats = await getTranscriptStatsFromSrt(srt);
    await (database.update(
      database.audioItems,
    )..where((table) => table.id.equals(audioItemId))).write(
      db.AudioItemsCompanion(
        transcriptPath: const Value(null),
        transcriptSrt: Value(srt),
        wordTimestampsJson: Value(
          encodeWordTimestamps(subtitle.subtitle.words),
        ),
        transcriptSource: const Value(1),
        sentenceCount: Value(stats.$1),
        wordCount: Value(stats.$2),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await ref
        .read(favoriteSentenceLifecycleProvider)
        .removeAllForAudio(audioItemId);
    await ref
        .read(learningProgressProvider.notifier)
        .deleteProgress(audioItemId);
    await ref.read(audioLibraryProvider.notifier).loadLibrary();
    await _reloadCurrentSessionIfNeeded(audioItemId);
    return SubtitleUpdateResult.updated;
  }

  Future<bool> _runDownload(
    int sessionId,
    db.AudioItem item,
    String collectionId,
    CancelToken cancelToken,
    String displayName,
  ) async {
    File? tempFile;
    try {
      final remoteAudioId = item.remoteAudioId;
      if (remoteAudioId == null) {
        throw StateError('Community download is missing remoteAudioId');
      }
      late final CommunityCollectionFileDetail detail;
      try {
        detail = await ref
            .read(communityCollectionApiProvider)
            .getFileDetail(
              collectionId,
              remoteAudioId,
              cancelToken: cancelToken,
            );
      } on CommunityFileNotFound {
        await _markFileUnavailable(item.id, collectionId);
        throw CommunityFileUnavailable(remoteAudioId);
      }
      final file = detail.file;
      final mediaUrl =
          communityAssetUrlForRegion(
            globalUrl: file.mediaUrl,
            chinaUrl: file.mediaUrlChina,
            isChinaUser: ref.read(isChinaUserProvider),
          ) ??
          file.mediaUrl;
      final subtitle = detail.subtitle;
      if (_isStale(item.id, sessionId)) return false;
      final database = ref.read(appDatabaseProvider);
      final localCollection = await database.collectionDao.getByRemoteId(
        collectionId,
      );
      if (localCollection == null) {
        throw StateError('Community collection was removed during download');
      }
      await _persistFileMetadata(database, audioItemId: item.id, file: file);
      await ref.read(audioLibraryProvider.notifier).loadLibrary();
      await ref.read(collectionListProvider.notifier).loadCollections();
      final srt = _toSrt(subtitle);
      if (srt.isEmpty) throw CommunitySubtitleUnavailable(file.id);
      final extension = _safeExtension(mediaUrl, file.mediaType);
      final tempDir = await getAppDataDirectory();
      tempFile = File(
        p.join(tempDir.path, 'tmp', 'community_media', '${item.id}.part'),
      );
      final relativePath = p.join(
        file.mediaType == CommunityMediaType.video ? 'videos' : 'audios',
        'community',
        '${item.id}.$extension',
      );
      final finalFile = File(p.join(tempDir.path, relativePath));
      await finalFile.parent.create(recursive: true);
      await ref
          .read(backgroundFileDownloadServiceProvider)
          .download(
            uri: Uri.parse(mediaUrl),
            savePath: tempFile.path,
            resourceKey: communityResourceKey(remoteAudioId),
            // 通知展示社区合集标题，避免回退显示 `.part` 临时文件名。
            displayName: file.title,
            cancelToken: cancelToken,
            onProgress: (received, total) =>
                _updateProgress(item.id, sessionId, received, total),
          );
      if (_isStale(item.id, sessionId)) return false;
      await tempFile.rename(finalFile.path);

      final hasTranscript = item.transcriptSrt?.isNotEmpty ?? false;
      final companion = hasTranscript
          ? db.AudioItemsCompanion(
              audioPath: Value(relativePath),
              updatedAt: Value(DateTime.now()),
            )
          : db.AudioItemsCompanion(
              audioPath: Value(relativePath),
              transcriptPath: const Value(null),
              transcriptSrt: Value(srt),
              wordTimestampsJson: Value(encodeWordTimestamps(subtitle.words)),
              transcriptSource: const Value(1),
              sentenceCount: Value((await getTranscriptStatsFromSrt(srt)).$1),
              wordCount: Value((await getTranscriptStatsFromSrt(srt)).$2),
              updatedAt: Value(DateTime.now()),
            );
      await (database.update(
        database.audioItems,
      )..where((table) => table.id.equals(item.id))).write(companion);
      await ref.read(audioLibraryProvider.notifier).loadLibrary();
      if (_isStale(item.id, sessionId)) return false;
      _remove(item.id);
      AppLogger.log(
        'CommunityDownload',
        'done session=$sessionId id=${item.id} audioPath=$relativePath',
      );
      return true;
    } catch (error, stackTrace) {
      if (!_isStale(item.id, sessionId)) {
        AppLogger.log('CommunityDownload', 'failed: $error');
        AppLogger.log('CommunityDownload', stackTrace.toString());
        _put(
          item.id,
          DownloadFailed(
            audioItemId: item.id,
            displayName: displayName,
            error: error,
          ),
        );
        final messenger = communityDownloadScaffoldMessengerKey.currentState;
        final l10n = _pickL10n();
        if (messenger != null && l10n != null) {
          final message = error is CommunityFileUnavailable
              ? l10n.communityFileUnavailable
              : l10n.downloadFailed(displayName);
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
      }
      return false;
    } finally {
      if (_active[item.id]?.sessionId == sessionId) _active.remove(item.id);
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// 持久化文件详情中的音频元数据，不修改合集关联排序。
  Future<void> _persistFileMetadata(
    db.AppDatabase database, {
    required String audioItemId,
    required CommunityCollectionFile file,
  }) async {
    final duration = file.durationSec;
    await (database.update(
      database.audioItems,
    )..where((table) => table.id.equals(audioItemId))).write(
      db.AudioItemsCompanion(
        name: Value(file.title),
        totalDuration: duration == null
            ? const Value.absent()
            : Value(duration),
        originalDate: Value(file.publishedAt),
        communityUnavailableAt: const Value(null),
        description: Value(file.normalizedDescription),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _markFileUnavailable(
    String audioItemId,
    String remoteCollectionId,
  ) async {
    final database = ref.read(appDatabaseProvider);
    final collection = await database.collectionDao.getByRemoteId(
      remoteCollectionId,
    );
    if (collection == null) return;
    await ref
        .read(communityFileLifecycleServiceProvider)
        .markUnavailable(
          audioItemId: audioItemId,
          localCollectionId: collection.id,
        );
    await ref.read(audioLibraryProvider.notifier).loadLibrary();
    await ref.read(collectionListProvider.notifier).loadCollections();
  }

  void _updateProgress(
    String audioItemId,
    int sessionId,
    int received,
    int? total,
  ) {
    if (_isStale(audioItemId, sessionId)) return;
    final current = state[audioItemId];
    if (current is! DownloadInProgress) return;
    _put(
      audioItemId,
      DownloadInProgress(
        audioItemId: current.audioItemId,
        displayName: current.displayName,
        progress: total != null && total > 0 ? received / total : -1,
        receivedBytes: received,
        totalBytes: total,
        speedBytesPerSecond: _active[audioItemId]?.speedMeter.record(received),
      ),
    );
  }

  /// 该 session 是否已不再是条目的当前任务（已取消、已完成或被新任务替换）。
  bool _isStale(String audioItemId, int sessionId) =>
      _active[audioItemId]?.sessionId != sessionId;

  void _put(String audioItemId, DownloadProgress value) {
    state = {...state, audioItemId: value};
  }

  void _remove(String audioItemId) {
    if (!state.containsKey(audioItemId)) return;
    state = Map.of(state)..remove(audioItemId);
  }

  String _toSrt(CommunitySubtitle subtitle) {
    return generateSrtContent(
      subtitle.sentences
          .map(
            (sentence) => TranscriptSentence(
              text: sentence.text,
              startTime: sentence.startTime,
              endTime: sentence.endTime,
            ),
          )
          .toList(growable: false),
    );
  }

  String _safeExtension(String url, CommunityMediaType type) {
    final extension = p
        .extension(Uri.tryParse(url)?.path ?? '')
        .replaceFirst('.', '')
        .toLowerCase();
    if (extension.isNotEmpty && extension.length <= 5) return extension;
    return type == CommunityMediaType.video ? 'mp4' : 'm4a';
  }

  Future<void> _reloadCurrentSessionIfNeeded(String audioItemId) async {
    try {
      if (!ref.exists(listeningPracticeProvider)) return;
      final current = ref.read(listeningPracticeProvider).currentAudioItem;
      if (current?.id != audioItemId) return;
      final updated = ref
          .read(audioLibraryProvider.notifier)
          .getItemById(audioItemId);
      if (updated != null) {
        await ref
            .read(listeningPracticeProvider.notifier)
            .loadAudio(updated, forceTranscriptReload: true);
      }
    } catch (error) {
      AppLogger.log('CommunitySubtitle', 'session reload failed: $error');
    }
  }

  AppLocalizations? _pickL10n() {
    final context = communityDownloadScaffoldMessengerKey.currentContext;
    return context == null ? null : AppLocalizations.of(context);
  }
}

enum StartResult {
  started,
  alreadyDownloaded,
  alreadyRunning,
  notCommunity,
  unavailable,
}

/// 单个条目的进行中任务。[future] 在启动后立即赋值。
class _ActiveDownload {
  _ActiveDownload({
    required this.sessionId,
    required this.token,
    required this.speedMeter,
  });

  final int sessionId;
  final CancelToken token;
  final DownloadSpeedMeter speedMeter;
  late Future<bool> future;
}

enum SubtitleUpdateResult { updated, notFound, notCommunity }

/// v2 文件已经不在远端合集列表中。
class CommunityFileUnavailable implements Exception {
  final String fileId;

  const CommunityFileUnavailable(this.fileId);
}

/// 启动时清理社区媒体下载残留。
Future<void> cleanupCommunityDownloadTmp() async {
  try {
    final dir = Directory(
      p.join((await getAppDataDirectory()).path, 'tmp', 'community_media'),
    );
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (error) {
    AppLogger.log('CommunityDownload', 'cleanup tmp failed: $error');
  }
}
