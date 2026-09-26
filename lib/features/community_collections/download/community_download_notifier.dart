import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../database/app_database.dart' as db;
import '../../../database/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/word_timestamp.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../providers/favorite_sentence_lifecycle_provider.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../providers/listening_practice/listening_practice_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/app_logger.dart';
import '../../../utils/app_data_dir.dart';
import '../../../utils/srt_generator.dart';
import '../../../utils/transcript_stats.dart';
import '../data/community_collection_api.dart';
import '../data/community_file_lifecycle.dart';
import '../models/community_collection_models.dart';
import 'download_progress.dart';

part 'community_download_notifier.g.dart';

/// 用于在任何页面推送下载失败提示的全局 key。
final GlobalKey<ScaffoldMessengerState> communityDownloadScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 社区合集媒体和字幕下载调度器；同一时刻只运行一个任务。
@Riverpod(keepAlive: true)
class CommunityDownload extends _$CommunityDownload {
  CancelToken? _cancelToken;
  int _sessionId = 0;
  String? _activeDisplayName;
  Future<bool>? _activeDownload;

  @override
  DownloadProgress build() => const DownloadIdle();

  /// 下载文件及对应字幕，下载前通过 remote collection/file ID 定位资源。
  Future<StartResult> start({
    required String audioItemId,
    required String displayName,
  }) async {
    if (state is DownloadInProgress) return StartResult.busy;
    final database = ref.read(appDatabaseProvider);
    final item = await database.audioItemDao.getById(audioItemId);
    if (item?.communityUnavailableAt != null) {
      return StartResult.unavailable;
    }
    if (item == null || item.remoteAudioId == null || item.audioPath != null) {
      return StartResult.alreadyDownloaded;
    }
    final collectionId = await database.collectionDao
        .getCommunityRemoteIdForAudio(audioItemId);
    if (collectionId == null) return StartResult.notCommunity;

    final sessionId = ++_sessionId;
    final token = CancelToken();
    _cancelToken = token;
    _activeDisplayName = displayName;
    state = DownloadInProgress(
      audioItemId: audioItemId,
      displayName: displayName,
      progress: -1,
    );
    final future = _runDownload(sessionId, item, collectionId, token);
    _activeDownload = future;
    unawaited(future);
    return StartResult.started;
  }

  /// 等待当前下载完成。
  Future<bool> awaitCompletion() => _activeDownload ?? Future.value(false);

  /// 取消当前任务，并等待旧任务清理临时文件。
  Future<void> cancel() async {
    if (state is! DownloadInProgress) return;
    final future = _activeDownload;
    _sessionId++;
    _cancelToken?.cancel('user-cancelled');
    _cancelToken = null;
    state = const DownloadIdle();
    if (future != null) await future;
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
      localCollectionId: collection.id,
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
        .read(learningProgressNotifierProvider.notifier)
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
      final subtitle = detail.subtitle;
      if (sessionId != _sessionId) return false;
      final database = ref.read(appDatabaseProvider);
      final localCollection = await database.collectionDao.getByRemoteId(
        collectionId,
      );
      if (localCollection == null) {
        throw StateError('Community collection was removed during download');
      }
      await _persistFileMetadata(
        database,
        audioItemId: item.id,
        localCollectionId: localCollection.id,
        file: file,
      );
      await ref.read(audioLibraryProvider.notifier).loadLibrary();
      await ref.read(collectionListProvider.notifier).loadCollections();
      final srt = _toSrt(subtitle);
      if (srt.isEmpty) throw CommunitySubtitleUnavailable(file.id);
      final extension = _safeExtension(file.mediaUrl, file.mediaType);
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
            uri: Uri.parse(file.mediaUrl),
            savePath: tempFile.path,
            // 通知展示社区合集标题，避免回退显示 `.part` 临时文件名。
            displayName: file.title,
            cancelToken: cancelToken,
            onProgress: _updateProgress,
          );
      if (sessionId != _sessionId) return false;
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
      if (sessionId != _sessionId) return false;
      state = const DownloadIdle();
      return true;
    } catch (error, stackTrace) {
      if (sessionId == _sessionId) {
        AppLogger.log('CommunityDownload', 'failed: $error');
        AppLogger.log('CommunityDownload', stackTrace.toString());
        state = DownloadFailed(
          audioItemId: item.id,
          displayName: _activeDisplayName ?? item.name,
          error: error,
        );
        final messenger = communityDownloadScaffoldMessengerKey.currentState;
        final l10n = _pickL10n();
        if (messenger != null && l10n != null) {
          final message = error is CommunityFileUnavailable
              ? l10n.communityFileUnavailable
              : l10n.downloadFailed(_activeDisplayName ?? item.name);
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
      }
      return false;
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> _persistFileMetadata(
    db.AppDatabase database, {
    required String audioItemId,
    required String localCollectionId,
    required CommunityCollectionFile file,
  }) async {
    final duration = file.durationSec;
    await database.transaction(() async {
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
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (database.update(database.collectionAudioItems)..where(
            (table) =>
                table.collectionId.equals(localCollectionId) &
                table.audioItemId.equals(audioItemId),
          ))
          .write(
            db.CollectionAudioItemsCompanion(sortOrder: Value(file.sortOrder)),
          );
    });
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

  void _updateProgress(int received, int? total) {
    final current = state;
    if (current is! DownloadInProgress) return;
    state = DownloadInProgress(
      audioItemId: current.audioItemId,
      displayName: current.displayName,
      progress: total != null && total > 0 ? received / total : -1,
      receivedBytes: received,
      totalBytes: total,
    );
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

enum StartResult { started, alreadyDownloaded, busy, notCommunity, unavailable }

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
