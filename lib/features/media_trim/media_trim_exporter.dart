import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../models/audio_item.dart';
import '../../models/word_timestamp.dart';
import '../../services/app_logger.dart';
import '../../utils/app_data_dir.dart';
import '../../utils/audio_fingerprint.dart';
import 'media_trim_clip.dart';
import 'media_trim_processor.dart';
import 'media_trim_repository.dart';

final mediaTrimProcessorProvider = Provider<MediaTrimProcessor>(
  (ref) => const MediaTrimProcessor(),
);

final mediaTrimExporterProvider = Provider<MediaTrimExporter>(
  (ref) => MediaTrimExporter(
    repository: ref.watch(mediaTrimRepositoryProvider),
    processor: ref.watch(mediaTrimProcessorProvider),
  ),
);

/// 待导出的片段及其最终名称。
typedef MediaTrimNamedClip = ({MediaTrimClip clip, String name});

class MediaTrimExportProgress {
  const MediaTrimExportProgress({
    required this.completedClips,
    required this.totalClips,
    required this.fraction,
  });

  final int completedClips;
  final int totalClips;

  /// 整批进度，0~1。
  final double fraction;
}

class MediaTrimExportResult {
  const MediaTrimExportResult({
    required this.collectionId,
    required this.createdCount,
    required this.reusedCount,
  });

  final String collectionId;
  final int createdCount;

  /// 内容与已有材料相同、直接加入合集的片段数。
  final int reusedCount;
}

/// 保存流程编排：逐段编码到独占任务目录，全部成功后整批入库。
///
/// 提交前任何失败或取消都会删除整个任务目录；原材料文件和数据库记录从不改动。
class MediaTrimExporter {
  MediaTrimExporter({required this.repository, required this.processor});

  final MediaTrimRepository repository;
  final MediaTrimProcessor processor;

  /// 当前进程内正在写入的任务目录，启动清理会跳过它们。
  static final Set<String> _activeDirectories = {};

  Future<int> cleanupUncommitted() async => repository.cleanupUncommitted(
    dataDirectory: await getAppDataDirectory(),
    isActive: _activeDirectories.contains,
  );

  Future<MediaTrimExportResult> export({
    required AudioItem source,
    required MediaTrimBoundaries boundaries,
    required List<WordTimestamp> words,
    required List<MediaTrimNamedClip> clips,
    required MediaTrimDestination destination,
    required MediaTrimCancellation cancellation,
    required void Function(MediaTrimExportProgress progress) onProgress,
  }) async {
    if (clips.isEmpty) throw const MediaTrimException(MediaTrimFailure.noClips);
    if (destination case MediaTrimNewCollection(:final name)
        when name.trim().isEmpty) {
      throw const MediaTrimException(MediaTrimFailure.collectionNameEmpty);
    }
    final sourcePath = await source.getFullAudioPath();
    if (sourcePath == null || !await File(sourcePath).exists()) {
      throw const MediaTrimException(MediaTrimFailure.sourceMissing);
    }
    final info = await processor.probe(sourcePath);
    // 以导出时重新探测的时长校验，防止原文件在编辑期间被替换。
    final current = MediaTrimBoundaries(
      total: info.duration,
      sentences: boundaries.sentences,
    );
    for (final entry in clips) {
      final failure = current.validate(entry.clip);
      if (failure != null) throw MediaTrimException(failure);
    }

    final dataDirectory = await getAppDataDirectory();
    final taskId = const Uuid().v4();
    final relativeDirectory = p.join(
      source.isVideo ? 'videos' : 'audios',
      'trimmed',
      taskId,
    );
    final directory = Directory(p.join(dataDirectory.path, relativeDirectory));
    final stopwatch = Stopwatch()..start();
    AppLogger.log(
      'MediaTrim',
      '开始保存 task=$taskId source=${source.id} video=${source.isVideo} '
          'clips=${clips.length} destination=${destination.runtimeType}',
    );
    _activeDirectories.add(directory.path);
    var committed = false;
    try {
      await directory.create(recursive: true);
      final drafts = <MediaTrimDraft>[];
      final hashes = <String>{};
      var skippedInBatch = 0;
      for (var i = 0; i < clips.length; i++) {
        final (:clip, :name) = clips[i];
        final id = const Uuid().v4();
        final relativePath = p.join(
          relativeDirectory,
          '$id.${source.isVideo ? 'mp4' : 'm4a'}',
        );
        final output = p.join(dataDirectory.path, relativePath);
        final clipWatch = Stopwatch()..start();
        await processor.render(
          source: sourcePath,
          output: output,
          start: clip.start,
          end: clip.end,
          isVideo: source.isVideo,
          sourceVideoBitrate: info.videoBitrate,
          cancellation: cancellation,
          onProgress: (fraction) => onProgress(
            MediaTrimExportProgress(
              completedClips: i,
              totalClips: clips.length,
              fraction: (i + fraction) / clips.length,
            ),
          ),
        );
        final sha256 = await computeAudioSha256(output);
        cancellation.throwIfCancelled();
        AppLogger.log(
          'MediaTrim',
          '片段编码完成 task=$taskId index=${i + 1}/${clips.length} '
              'range=${clip.start.inMilliseconds}-${clip.end.inMilliseconds}ms '
              'bytes=${await File(output).length()} '
              'cost=${clipWatch.elapsedMilliseconds}ms',
        );
        if (!hashes.add(sha256)) {
          // 同一批里内容完全相同的片段只保留一份。
          await File(output).delete();
          skippedInBatch++;
          continue;
        }
        final sentences = clip.sentencesWithin(boundaries.sentences);
        final shiftedWords = clip.shiftedWords(words);
        final hasSubtitle = sentences.isNotEmpty;
        drafts.add(
          MediaTrimDraft(
            id: id,
            name: name,
            relativePath: relativePath,
            sha256: sha256,
            durationSeconds: (clip.duration.inMilliseconds / 1000).round(),
            transcriptSource: hasSubtitle ? source.transcriptSource : null,
            transcriptLanguage: hasSubtitle ? source.transcriptLanguage : null,
            transcriptSrt: hasSubtitle
                ? clip.shiftedSubtitle(boundaries.sentences)
                : null,
            wordTimestampsJson: shiftedWords.isEmpty
                ? null
                : encodeWordTimestamps(shiftedWords),
            sentenceCount: sentences.length,
            wordCount: sentences.fold(
              0,
              (count, sentence) =>
                  count +
                  sentence.text
                      .split(RegExp(r'\s+'))
                      .where((word) => word.isNotEmpty)
                      .length,
            ),
          ),
        );
      }
      cancellation.throwIfCancelled();
      final result = await repository.commit(
        drafts: drafts,
        destination: destination,
      );
      committed = true;
      for (final relativePath in result.unusedRelativePaths) {
        await File(p.join(dataDirectory.path, relativePath)).delete();
      }
      if (result.createdIds.isEmpty) await directory.delete(recursive: true);
      onProgress(
        MediaTrimExportProgress(
          completedClips: clips.length,
          totalClips: clips.length,
          fraction: 1,
        ),
      );
      AppLogger.log(
        'MediaTrim',
        '整批入库完成 task=$taskId collection=${result.collectionId} '
            'created=${result.createdIds.length} '
            'reused=${result.reusedIds.length + skippedInBatch} '
            'cost=${stopwatch.elapsedMilliseconds}ms',
      );
      return MediaTrimExportResult(
        collectionId: result.collectionId,
        createdCount: result.createdIds.length,
        reusedCount: result.reusedIds.length + skippedInBatch,
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        'MediaTrim',
        '保存未完成 task=$taskId committed=$committed reason=$error'
            '${error is MediaTrimException ? '' : '\n$stackTrace'}',
      );
      rethrow;
    } finally {
      _activeDirectories.remove(directory.path);
      if (!committed && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }
}
