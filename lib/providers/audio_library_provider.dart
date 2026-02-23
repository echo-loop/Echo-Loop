import 'package:drift/drift.dart';
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/app_database.dart' as db;
import '../database/providers.dart';
import '../models/audio_item.dart';
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

    final dao = ref.read(audioItemDaoProvider);
    final dbItems = await dao.getAllActive();

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
            isStarred: row.isStarred,
          ),
        )
        .toList();

    final validItems = <AudioItem>[];
    bool hasMigratedItems = false;

    for (final item in allItems) {
      AudioItem processedItem = item;

      if (item.audioPath.startsWith('/')) {
        final migratedItem = await _migrateToRelativePath(item);
        if (migratedItem != null) {
          processedItem = migratedItem;
          hasMigratedItems = true;
          print('Migrated ${item.name} from absolute to relative path');
        } else {
          print('Failed to migrate ${item.name}, marking as invalid');
          continue;
        }
      }

      final fullAudioPath = await processedItem.getFullAudioPath();
      final audioFile = File(fullAudioPath);
      final audioExists = await audioFile.exists();

      // 验证字幕文件是否存在，不存在则清除路径
      if (audioExists && processedItem.hasTranscript) {
        final fullTranscriptPath = await processedItem.getFullTranscriptPath();
        if (fullTranscriptPath != null) {
          final transcriptFile = File(fullTranscriptPath);
          if (!await transcriptFile.exists()) {
            processedItem = processedItem.copyWith(
              transcriptPath: null,
              sentenceCount: 0,
              wordCount: 0,
            );
            hasMigratedItems = true;
          }
        }
      }

      if (audioExists) {
        validItems.add(processedItem);
      } else {
        // 软删除无效音频
        await dao.softDelete(item.id);
        print(
          'Removed invalid audio item: ${processedItem.name} (audio file not found at: $fullAudioPath)',
        );
      }
    }

    state = state.copyWith(audioItems: validItems, isLoading: false);

    if (hasMigratedItems) {
      // 更新迁移后的音频项到数据库
      for (final item in validItems) {
        await _upsertItem(item);
      }
      print('Migrated paths from absolute to relative format');
    }
  }

  Future<AudioItem?> _migrateToRelativePath(AudioItem item) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final docsPath = docs.path;

      if (!item.audioPath.startsWith(docsPath)) {
        return null;
      }

      final relativeAudioPath = item.audioPath.substring(docsPath.length + 1);

      String? relativeTranscriptPath;
      if (item.transcriptPath != null &&
          item.transcriptPath!.startsWith(docsPath)) {
        relativeTranscriptPath = item.transcriptPath!.substring(
          docsPath.length + 1,
        );
      } else if (item.transcriptPath != null &&
          !item.transcriptPath!.startsWith('/')) {
        relativeTranscriptPath = item.transcriptPath;
      }

      return item.copyWith(
        audioPath: relativeAudioPath,
        transcriptPath: relativeTranscriptPath,
      );
    } catch (e) {
      print('Error migrating path for ${item.name}: $e');
      return null;
    }
  }

  Future<void> addAudioItem(AudioItem item) async {
    state = state.copyWith(audioItems: [...state.audioItems, item]);
    await _upsertItem(item);
  }

  Future<void> removeAudioItem(String id) async {
    AudioItem? item;
    try {
      item = state.audioItems.firstWhere((item) => item.id == id);
    } catch (e) {
      print('Audio item not found: $id');
      return;
    }

    try {
      final audioPath = await item.getFullAudioPath();
      final audioFile = File(audioPath);
      if (await audioFile.exists()) {
        await audioFile.delete();
        print('Deleted audio file: $audioPath');
      }
    } catch (e) {
      print('Error deleting audio file: $e');
    }

    if (item.hasTranscript) {
      try {
        final transcriptPath = await item.getFullTranscriptPath();
        if (transcriptPath != null) {
          final transcriptFile = File(transcriptPath);
          if (await transcriptFile.exists()) {
            await transcriptFile.delete();
            print('Deleted transcript file: $transcriptPath');
          }
        }
      } catch (e) {
        print('Error deleting transcript file: $e');
      }
    }

    state = state.copyWith(
      audioItems: state.audioItems.where((item) => item.id != id).toList(),
    );

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

  /// 切换音频星标状态（乐观更新 + 持久化）
  Future<void> toggleStar(String id) async {
    final items = [...state.audioItems];
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(
        isStarred: !items[index].isStarred,
      );
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

  /// 补填缺失时长 — 对 totalDuration == 0 的音频逐个提取并持久化
  Future<void> backfillDurations() async {
    final missing =
        state.audioItems.where((item) => item.totalDuration == 0).toList();
    for (final item in missing) {
      final seconds = await getAudioDurationSeconds(item.audioPath);
      if (seconds > 0) {
        updateAudioItem(item.copyWith(totalDuration: seconds));
      }
    }
  }

  /// 补填字幕统计 — 对有字幕但 sentenceCount == 0 的音频逐个统计并持久化
  Future<void> backfillTranscriptStats() async {
    final missing = state.audioItems
        .where((item) => item.hasTranscript && item.sentenceCount == 0)
        .toList();
    for (final item in missing) {
      final stats = await getTranscriptStats(item.transcriptPath!);
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
        isStarred: Value(item.isStarred),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
