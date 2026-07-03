import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../database/app_database.dart' as db;
import '../../../database/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/word_timestamp.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../providers/listening_practice/listening_practice_provider.dart';
import '../../../services/app_logger.dart';
import '../../../utils/app_data_dir.dart';
import '../../../utils/transcript_stats.dart';
import '../data/official_collection_api.dart';
import 'download_progress.dart';

part 'official_download_notifier.g.dart';

/// 用于在任何页面推 snackbar 的全局 key；由 `main.dart` 绑定到 MaterialApp。
final GlobalKey<ScaffoldMessengerState> officialDownloadScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 全局官方合集音频下载调度器。
///
/// MVP 并发约束：同一时刻最多 1 个任务。新请求到来时若已有任务在跑，
/// 返回 [StartResult.busy]，UI 层给 snackbar 提示而不启动新任务。
///
/// 防竞态：每次 start 递增 `_sessionId`，所有异步回调（progress / result）
/// 都 check 当前 sessionId 是否过期。遵循项目 ADR-3 约束。
@Riverpod(keepAlive: true)
class OfficialDownload extends _$OfficialDownload {
  CancelToken? _cancelToken;

  /// 当前执行中 session 的标识；Dio 回调需 check 避免污染新任务状态。
  int _sessionId = 0;

  /// 正在下载的音频名称（用于 snackbar 文案）。
  String? _activeDisplayName;

  /// 当前进行中的下载任务；供 UI 层 [awaitCompletion] 等待完成后跳转。
  Future<bool>? _activeDownload;

  @override
  DownloadProgress build() => const DownloadIdle();

  /// 尝试启动下载。
  ///
  /// 返回：
  /// - [StartResult.started]：新任务已启动
  /// - [StartResult.alreadyDownloaded]：本地已备好（无需下载）
  /// - [StartResult.busy]：已有其他任务在跑；调用方应 snackbar 提示
  Future<StartResult> start({
    required String audioItemId,
    required String displayName,
  }) async {
    final current = state;
    if (current is DownloadInProgress) {
      return StartResult.busy;
    }

    final audioItem = await ref
        .read(appDatabaseProvider)
        .audioItemDao
        .getById(audioItemId);
    if (audioItem == null) {
      return StartResult.alreadyDownloaded; // 不存在按"无需下载"处理，上层忽略
    }
    final remoteAudioId = audioItem.remoteAudioId;
    if (remoteAudioId == null || audioItem.audioPath != null) {
      // audioPath 非空 → 文件已落地；无 remoteAudioId → 非官方音频不应走下载
      return StartResult.alreadyDownloaded;
    }

    _sessionId++;
    final sid = _sessionId;
    _cancelToken = CancelToken();
    _activeDisplayName = displayName;
    state = DownloadInProgress(
      audioItemId: audioItemId,
      displayName: displayName,
      progress: -1,
    );

    // 异步执行下载主流程；不 await，避免卡住调用方。
    // 同时记录任务 future，供 UI 层 [awaitCompletion] 在下载完成后跳转学习计划页。
    final completion = _runDownload(sid, audioItem, remoteAudioId);
    _activeDownload = completion;
    unawaited(completion);
    return StartResult.started;
  }

  /// 等待当前下载任务结束，返回是否成功落地（与播客下载行为一致）。
  /// 无进行中任务时返回 false。
  Future<bool> awaitCompletion() => _activeDownload ?? Future.value(false);

  /// 取消当前下载任务。
  Future<void> cancel() async {
    if (state is! DownloadInProgress) return;
    final token = _cancelToken;
    _cancelToken = null;
    _sessionId++; // 过期当前 session，后续回调全部被丢弃
    token?.cancel('user-cancelled');
    state = const DownloadIdle();
    // tmp 文件由 _runDownload 的 finally 负责清理
  }

  /// 当前正在下载的音频 id（UI 层决定是否为该音频 tile 展示下载态）。
  String? get activeAudioItemId {
    final s = state;
    return s is DownloadInProgress ? s.audioItemId : null;
  }

  /// 拉取官方音频最新字幕并覆盖本地字幕文件。
  ///
  /// 字幕更新会改变句子切分和索引，因此同步清空该音频的收藏句子和学习进度，
  /// 避免旧的 sentenceIndex / paragraphIndex 指向新版字幕中的错误位置。
  Future<SubtitleUpdateResult> updateTranscript({
    required String audioItemId,
  }) async {
    AppLogger.log('OfficialSubtitle', 'update start audioItemId=$audioItemId');
    final database = ref.read(appDatabaseProvider);
    final audioItem = await database.audioItemDao.getById(audioItemId);
    if (audioItem == null) {
      AppLogger.log('OfficialSubtitle', 'update skipped: local audio missing');
      return SubtitleUpdateResult.notFound;
    }

    final remoteAudioId = audioItem.remoteAudioId;
    if (remoteAudioId == null || remoteAudioId.isEmpty) {
      AppLogger.log('OfficialSubtitle', 'update skipped: not official audio');
      return SubtitleUpdateResult.notOfficial;
    }

    final content = await ref
        .read(officialCollectionApiProvider)
        .getAudioContent(remoteAudioId);
    AppLogger.log(
      'OfficialSubtitle',
      'content fetched remoteAudioId=$remoteAudioId '
          'srtBytes=${content.srt.length} words=${content.wordTimestamps.length}',
    );

    final wordsJson = encodeWordTimestamps(content.wordTimestamps);
    final stats = await getTranscriptStatsFromSrt(content.srt);
    await (database.update(
      database.audioItems,
    )..where((t) => t.id.equals(audioItem.id))).write(
      db.AudioItemsCompanion(
        transcriptPath: const Value(null),
        transcriptSrt: Value(content.srt),
        wordTimestampsJson: Value(wordsJson),
        transcriptSource: const Value(1),
        sentenceCount: Value(stats.$1),
        wordCount: Value(stats.$2),
        updatedAt: Value(DateTime.now()),
      ),
    );
    AppLogger.log(
      'OfficialSubtitle',
      'db updated audioItemId=${audioItem.id} '
          'srtBytes=${content.srt.length} '
          'wordsJsonBytes=${wordsJson.length} '
          'sentences=${stats.$1} words=${stats.$2}',
    );

    await ref.read(bookmarkDaoProvider).removeAllForAudio(audioItem.id);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .deleteProgress(audioItem.id);
    AppLogger.log(
      'OfficialSubtitle',
      'progress cleared audioItemId=${audioItem.id}',
    );

    await ref.read(audioLibraryProvider.notifier).loadLibrary();
    await _reloadCurrentSessionIfNeeded(audioItem.id);
    return SubtitleUpdateResult.updated;
  }

  Future<void> _reloadCurrentSessionIfNeeded(String audioItemId) async {
    try {
      if (!ref.exists(listeningPracticeProvider)) {
        AppLogger.log(
          'OfficialSubtitle',
          'session reload skipped: listeningPractice not initialized',
        );
        return;
      }

      final current = ref.read(listeningPracticeProvider).currentAudioItem;
      if (current?.id != audioItemId) {
        AppLogger.log(
          'OfficialSubtitle',
          'session reload skipped: currentAudioItem=${current?.id}',
        );
        return;
      }

      final updated = ref
          .read(audioLibraryProvider.notifier)
          .getItemById(audioItemId);
      if (updated == null) {
        AppLogger.log(
          'OfficialSubtitle',
          'session reload skipped: updated audio missing',
        );
        return;
      }

      await ref
          .read(listeningPracticeProvider.notifier)
          .loadAudio(updated, forceTranscriptReload: true);
      final sentenceCount = ref
          .read(listeningPracticeProvider)
          .sentences
          .length;
      AppLogger.log(
        'OfficialSubtitle',
        'session reloaded audioItemId=$audioItemId sentences=$sentenceCount',
      );
    } catch (e, st) {
      AppLogger.log('OfficialSubtitle', 'session reload failed: $e');
      AppLogger.log('OfficialSubtitle', st.toString());
    }
  }

  /// 执行下载主流程，返回是否成功落地（true = 音频已写入并刷新库）。
  Future<bool> _runDownload(
    int sid,
    db.AudioItem audioItem,
    String remoteAudioId,
  ) async {
    final api = ref.read(officialCollectionApiProvider);
    final dio = Dio();
    final docDir = await getAppDataDirectory();
    final tmpDir = Directory(p.join(docDir.path, 'tmp', 'official_audio'));
    await tmpDir.create(recursive: true);
    final tmpAudioFile = File(p.join(tmpDir.path, '${audioItem.id}.m4a.part'));

    try {
      // 1) 拉 /content（SRT + wordTimestamps + audioUrl）
      final content = await api.getAudioContent(remoteAudioId);
      if (sid != _sessionId) return false; // 过期

      // 2) 下载音频到 tmp
      await dio.download(
        content.audioUrl,
        tmpAudioFile.path,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (sid != _sessionId) return;
          if (state is! DownloadInProgress) return;
          final prev = state as DownloadInProgress;
          final ratio = total > 0 ? received / total : -1.0;
          state = DownloadInProgress(
            audioItemId: prev.audioItemId,
            displayName: prev.displayName,
            progress: ratio,
            receivedBytes: received,
            totalBytes: total <= 0 ? null : total,
          );
        },
      );
      if (sid != _sessionId) return false;

      // 3) 字幕内容入 DB 列 + wordTimestamps + 移动 tmp → final
      //    audioPath 此时还是 NULL（enroll 时留白），由本次下载决定；
      //    字幕内容存 transcript_srt 列，transcriptPath 置 null（不再落文件）。
      final sha256 = audioItem.audioSha256;
      if (sha256 == null || sha256.isEmpty) {
        throw StateError(
          'audioItem ${audioItem.id} 缺少 audioSha256（enroll 时未写入？）',
        );
      }
      final relativeAudioPath = 'audios/official/$sha256.m4a';

      final audioFinalPath = p.join(docDir.path, relativeAudioPath);
      final audioFinalFile = File(audioFinalPath);
      await audioFinalFile.parent.create(recursive: true);
      await tmpAudioFile.rename(audioFinalPath);

      // 重新下载（用户曾「删除下载」但保留了字幕）时，本地字幕已存在则保留，不覆盖：
      // 覆盖会重排句子切分/索引，导致收藏句与学习进度错位（与 updateTranscript 主动
      // 清理 bookmark/progress 的语义呼应）。字幕单独管理，需要更新走「更新官方字幕」。
      final hasExistingTranscript =
          audioItem.transcriptSrt != null &&
          audioItem.transcriptSrt!.isNotEmpty;

      // 4) 写 DB —— audioPath 是「下载是否就绪」的单一真实来源，
      //    必须在音频落盘之后写入；字幕内容入 transcript_srt 列。
      final database = ref.read(appDatabaseProvider);
      final db.AudioItemsCompanion companion;
      if (hasExistingTranscript) {
        // 仅写下载就绪标记，字幕/词级时间戳/统计沿用已有值。
        companion = db.AudioItemsCompanion(
          audioPath: Value(relativeAudioPath),
          updatedAt: Value(DateTime.now()),
        );
      } else {
        // 首次下载：字幕内容随下载一起入库，否则学习计划页要等下次启动
        // backfillTranscriptStats 才能补上。
        final wordsJson = encodeWordTimestamps(content.wordTimestamps);
        final stats = await getTranscriptStatsFromSrt(content.srt);
        companion = db.AudioItemsCompanion(
          audioPath: Value(relativeAudioPath),
          transcriptPath: const Value(null),
          transcriptSrt: Value(content.srt),
          wordTimestampsJson: Value(wordsJson),
          transcriptSource: const Value(1),
          sentenceCount: Value(stats.$1),
          wordCount: Value(stats.$2),
          updatedAt: Value(DateTime.now()),
        );
      }
      // 不在此处插入 sessionId 检查：原代码约定音频落盘 + DB write 是原子块，
      // 中途 return 会留下 DB 缺 audioPath 的孤儿文件。
      await (database.update(
        database.audioItems,
      )..where((t) => t.id.equals(audioItem.id))).write(companion);
      if (sid != _sessionId) return false;

      // 5) 刷新 audioLibrary state，让学习计划页等 watcher 立即读到新路径
      await ref.read(audioLibraryProvider.notifier).loadLibrary();
      if (sid != _sessionId) return false;

      // 6) 后台检测内容有效性（不阻塞返回；官方时长来自 catalog，让检测器自行探测文件）
      unawaited(
        ref.read(audioLibraryProvider.notifier).checkAudioContent(audioItem.id),
      );

      // 7) 成功不提示，避免遮挡「开始学习」按钮；状态切回 idle 即可
      state = const DownloadIdle();
      return true;
    } catch (e, st) {
      if (sid != _sessionId) return false;
      AppLogger.log('OfficialDownload', 'failed: $e');
      AppLogger.log('OfficialDownload', st.toString());
      state = DownloadFailed(
        audioItemId: audioItem.id,
        displayName: _activeDisplayName ?? '',
        error: e,
      );
      final messenger = officialDownloadScaffoldMessengerKey.currentState;
      final l10n = _pickL10n();
      if (messenger != null && l10n != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.downloadFailed(_activeDisplayName ?? '')),
          ),
        );
      }
    } finally {
      // tmp 残留清理
      if (await tmpAudioFile.exists()) {
        try {
          await tmpAudioFile.delete();
        } catch (_) {}
      }
    }
    // 走到这里说明 catch 分支吞掉了异常（下载失败）。
    return false;
  }

  AppLocalizations? _pickL10n() {
    final ctx = officialDownloadScaffoldMessengerKey.currentContext;
    if (ctx == null) return null;
    return AppLocalizations.of(ctx);
  }
}

enum StartResult { started, alreadyDownloaded, busy }

enum SubtitleUpdateResult { updated, notFound, notOfficial }

/// 启动时扫清 `documents/tmp/official_audio/*.m4a.part` 残留文件。
///
/// App 上次运行时若崩溃/被杀，tmp 文件可能残留。每次 App 启动调一次即可。
Future<void> cleanupOfficialDownloadTmp() async {
  try {
    final docDir = await getAppDataDirectory();
    final tmpDir = Directory(p.join(docDir.path, 'tmp', 'official_audio'));
    if (!await tmpDir.exists()) return;
    await for (final entity in tmpDir.list(followLinks: false)) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  } catch (e) {
    AppLogger.log('OfficialDownload', 'cleanup tmp failed (ignored): $e');
  }
}
