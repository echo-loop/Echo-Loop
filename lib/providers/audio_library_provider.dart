import 'package:drift/drift.dart';
import 'package:universal_io/io.dart';
import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../features/usage/usage_event.dart';
import '../features/usage/usage_providers.dart';
import '../utils/app_data_dir.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/app_database.dart' as db;
import '../database/providers.dart';
import '../models/audio_item.dart';
import '../services/app_logger.dart';
import '../utils/audio_duration.dart';
import '../utils/transcript_stats.dart';
import 'collection_provider.dart';
import 'learning_progress_provider.dart';
import 'tag_provider.dart';

part 'audio_library_provider.g.dart';

class AudioLibraryState {
  final List<AudioItem> audioItems;
  final bool isLoading;

  const AudioLibraryState({this.audioItems = const [], this.isLoading = false});

  bool get isEmpty => audioItems.isEmpty;

  AudioLibraryState copyWith({List<AudioItem>? audioItems, bool? isLoading}) {
    return AudioLibraryState(
      audioItems: audioItems ?? this.audioItems,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@Riverpod(keepAlive: true)
class AudioLibrary extends _$AudioLibrary {
  @override
  AudioLibraryState build() {
    return const AudioLibraryState();
  }

  Future<void> loadLibrary() async {
    state = state.copyWith(isLoading: true);

    try {
      final dao = ref.read(audioItemDaoProvider);
      final dbItems = await dao.getAllActive();
      AppLogger.log('StartupLoad', 'audio query ok: dbRows=${dbItems.length}');

      // 将 Drift 数据转换为模型
      final allItems = dbItems
          .map(
            (row) => AudioItem(
              id: row.id,
              name: row.name,
              audioPath: row.audioPath,
              transcriptPath: row.transcriptPath,
              addedDate: row.addedDate,
              totalDuration: row.totalDuration,
              sentenceCount: row.sentenceCount,
              wordCount: row.wordCount,
              isPinned: row.isPinned,
              transcriptSource: TranscriptSource.fromIndex(
                row.transcriptSource,
              ),
              audioSha256: row.audioSha256,
              transcriptLanguage: row.transcriptLanguage,
              remoteAudioId: row.remoteAudioId,
              originalDate: row.originalDate,
            ),
          )
          .toList();

      final validItems = <AudioItem>[];
      bool hasMigratedItems = false;

      for (final item in allItems) {
        AudioItem processedItem = item;

        // audioPath=null → 未就绪（官方合集未下载）；直接保留为合法条目
        final currentAudioPath = item.audioPath;
        if (currentAudioPath == null) {
          validItems.add(processedItem);
          continue;
        }

        // 老数据绝对路径 → 相对路径迁移（仅对已就绪音频做）
        if (currentAudioPath.startsWith('/')) {
          final migratedItem = await _migrateToRelativePath(item);
          if (migratedItem != null) {
            processedItem = migratedItem;
            hasMigratedItems = true;
            AppLogger.log(
              'AudioLib',
              'Migrated ${item.name} from absolute to relative path',
            );
          } else {
            AppLogger.log(
              'AudioLib',
              'Failed to migrate ${item.name}, skipping',
            );
            continue;
          }
        }

        validItems.add(processedItem);
      }

      final readyCount = validItems.where((item) => item.isAudioReady).length;
      final remoteCount = validItems
          .where((item) => item.remoteAudioId != null)
          .length;
      AppLogger.log(
        'StartupLoad',
        'audio mapped: visible=${validItems.length}, ready=$readyCount, '
            'remote=$remoteCount, migrated=$hasMigratedItems',
      );

      state = state.copyWith(audioItems: validItems, isLoading: false);

      if (hasMigratedItems) {
        // 更新迁移后的音频项到数据库
        for (final item in validItems) {
          await _upsertItem(item);
        }
        AppLogger.log(
          'AudioLib',
          'Migrated paths from absolute to relative format',
        );
      }
    } catch (e, st) {
      AppLogger.log('StartupLoad', 'audio load failed: $e');
      AppLogger.log('StartupLoad', st.toString());
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<AudioItem?> _migrateToRelativePath(AudioItem item) async {
    try {
      final dataDir = await getAppDataDirectory();
      final docsPath = dataDir.path;

      final absAudio = item.audioPath;
      if (absAudio == null || !absAudio.startsWith(docsPath)) {
        return null;
      }

      final relativeAudioPath = absAudio.substring(docsPath.length + 1);

      String? relativeTranscriptPath;
      final transcript = item.transcriptPath;
      if (transcript != null && transcript.startsWith(docsPath)) {
        relativeTranscriptPath = transcript.substring(docsPath.length + 1);
      } else if (transcript != null && !transcript.startsWith('/')) {
        relativeTranscriptPath = transcript;
      }

      return item.copyWith(
        audioPath: relativeAudioPath,
        transcriptPath: relativeTranscriptPath,
      );
    } catch (e) {
      AppLogger.log('AudioLib', 'Error migrating path for ${item.name}: $e');
      return null;
    }
  }

  Future<void> addAudioItem(AudioItem item) async {
    state = state.copyWith(audioItems: [...state.audioItems, item]);
    await _upsertItem(item);
    ref
        .read(usageTrackerProvider)
        .record(
          UsageEvent.audioUpload,
          analyticsParams: {
            EventParams.audioId: item.id,
            EventParams.audioName: item.name,
          },
        );
  }

  Future<void> removeAudioItem(String id) async {
    AudioItem? item;
    try {
      item = state.audioItems.firstWhere((item) => item.id == id);
    } catch (e) {
      AppLogger.log('AudioLib', 'Audio item not found: $id');
      return;
    }

    // 埋点：删除音频
    ref.read(analyticsServiceProvider).track(Events.audioDelete, {
      EventParams.audioId: id,
      EventParams.audioName: item.name,
    });

    try {
      final audioPath = await item.getFullAudioPath();
      if (audioPath != null) {
        final audioFile = File(audioPath);
        if (await audioFile.exists()) {
          await audioFile.delete();
          AppLogger.log('AudioLib', 'Deleted audio file: $audioPath');
        }
      }
    } catch (e) {
      AppLogger.log('AudioLib', 'Error deleting audio file: $e');
    }

    if (item.hasTranscript) {
      try {
        final transcriptPath = await item.getFullTranscriptPath();
        if (transcriptPath != null) {
          final transcriptFile = File(transcriptPath);
          if (await transcriptFile.exists()) {
            await transcriptFile.delete();
            AppLogger.log(
              'AudioLib',
              'Deleted transcript file: $transcriptPath',
            );
          }
        }
      } catch (e) {
        AppLogger.log('AudioLib', 'Error deleting transcript file: $e');
      }
    }

    state = state.copyWith(
      audioItems: state.audioItems.where((item) => item.id != id).toList(),
    );

    // 清除收藏单词的上下文信息（sentenceText/sentenceIndex 非 FK 字段，需手动置 NULL）
    // 必须在 hardDelete 之前调用，因为 hardDelete 的 CASCADE 会将 audioItemId SET NULL
    final savedWordDao = ref.read(savedWordDaoProvider);
    await savedWordDao.clearContextForAudio(id);
    final savedSenseGroupDao = ref.read(savedSenseGroupDaoProvider);
    await savedSenseGroupDao.clearContextForAudio(id);

    // 硬删除（CASCADE 会自动清理 junction、bookmarks、playback_states、learning_progresses）
    final dao = ref.read(audioItemDaoProvider);
    await dao.hardDelete(id);

    // 清理学习进度内存状态（硬删除 CASCADE 已清理数据库）
    ref.read(learningProgressNotifierProvider.notifier).deleteProgress(id);

    // 从所有合集中清理对该音频的引用（更新 Provider 内存状态）
    ref.read(collectionListProvider.notifier).removeAudioFromAllCollections(id);

    // 从所有标签中清理对该音频的引用（更新 Provider 内存状态）
    ref.read(tagListProvider.notifier).removeAudioFromAllTags(id);
  }

  Future<void> updateAudioItem(AudioItem updatedItem) async {
    final items = [...state.audioItems];
    final index = items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      items[index] = updatedItem;
      state = state.copyWith(audioItems: items);
      await _upsertItem(updatedItem);
    }
  }

  /// 切换音频置顶状态（乐观更新 + 持久化，排序由 UI 层统一处理）
  Future<void> togglePin(String id) async {
    final items = [...state.audioItems];
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(isPinned: !items[index].isPinned);
      state = state.copyWith(audioItems: items);
      await _upsertItem(items[index]);
    }
  }

  AudioItem? getItemById(String id) {
    try {
      return state.audioItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 补填缺失时长 — 对已就绪且 totalDuration == 0 的音频逐个提取并持久化
  Future<void> backfillDurations() async {
    final missing = state.audioItems
        .where((item) => item.totalDuration == 0 && item.isAudioReady)
        .toList();
    for (final item in missing) {
      final seconds = await getAudioDurationSeconds(item.audioPath!);
      if (seconds > 0) {
        updateAudioItem(item.copyWith(totalDuration: seconds));
      }
    }
  }

  /// 全量 backfill 字幕内容 — 把旧行的 SRT 文件读入 transcript_srt 列。
  ///
  /// 字幕内容入库后的一次性迁移：列填满后该查询返回空、后续启动为 no-op，
  /// 也能自愈漏网行。文件缺失/读失败的行保持 NULL，下次启动重试。
  Future<void> backfillTranscriptSrt() async {
    final dao = ref.read(audioItemDaoProvider);
    final rows = await dao.getRowsNeedingSrtBackfill();
    if (rows.isEmpty) return;
    int filled = 0;
    for (final row in rows) {
      try {
        final relativePath = row.transcriptPath;
        if (relativePath == null || relativePath.isEmpty) continue;
        final dataDir = await getAppDataDirectory();
        final file = File('${dataDir.path}/$relativePath');
        if (!await file.exists()) continue;
        final content = await file.readAsString();
        if (content.isEmpty) continue;
        await dao.updateTranscriptSrt(row.id, content);
        filled++;
      } catch (e) {
        AppLogger.log('AudioLib', 'backfillTranscriptSrt 跳过 ${row.id}: $e');
      }
    }
    AppLogger.log(
      'AudioLib',
      'backfillTranscriptSrt done: rows=${rows.length}, filled=$filled',
    );
  }

  /// 补填字幕统计 — 对有字幕但 sentenceCount == 0 的音频逐个统计并持久化
  Future<void> backfillTranscriptStats() async {
    final missing = state.audioItems
        .where((item) => item.hasTranscript && item.sentenceCount == 0)
        .toList();
    if (missing.isEmpty) return;
    final dao = ref.read(audioItemDaoProvider);
    for (final item in missing) {
      // 优先用 DB 列内容算统计；列空时回退遗留文件路径。
      final srt = await dao.getTranscriptSrt(item.id);
      final (int, int) stats;
      if (srt != null && srt.isNotEmpty) {
        stats = await getTranscriptStatsFromSrt(srt);
      } else if (item.transcriptPath != null &&
          item.transcriptPath!.isNotEmpty) {
        stats = await getTranscriptStats(item.transcriptPath!);
      } else {
        continue;
      }
      if (stats.$1 > 0) {
        updateAudioItem(
          item.copyWith(sentenceCount: stats.$1, wordCount: stats.$2),
        );
      }
    }
  }

  /// 将 AudioItem 模型写入 Drift 数据库
  Future<void> _upsertItem(AudioItem item) async {
    final dao = ref.read(audioItemDaoProvider);
    await dao.upsert(
      db.AudioItemsCompanion(
        id: Value(item.id),
        name: Value(item.name),
        audioPath: Value(item.audioPath),
        transcriptPath: Value(item.transcriptPath),
        addedDate: Value(item.addedDate),
        totalDuration: Value(item.totalDuration),
        sentenceCount: Value(item.sentenceCount),
        wordCount: Value(item.wordCount),
        isPinned: Value(item.isPinned),
        transcriptSource: Value(item.transcriptSource?.index),
        audioSha256: Value(item.audioSha256),
        transcriptLanguage: Value(item.transcriptLanguage),
        remoteAudioId: Value(item.remoteAudioId),
        originalDate: Value(item.originalDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
