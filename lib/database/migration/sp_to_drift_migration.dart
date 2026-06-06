import 'dart:convert';

import 'package:drift/drift.dart';
import '../../utils/app_data_dir.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/audio_item.dart' as model;
import '../../models/collection.dart' as model;
import '../../models/sentence.dart' as model;
import '../../services/subtitle_parser.dart';
import '../app_database.dart';

/// SP → Drift 一次性迁移标记 key
const String migrationCompleteKey = 'drift_migration_v1_complete';

/// SharedPreferences → Drift 迁移服务
/// 将 SP 中的 audio_library, collections, bookmarks, playback_state 迁移到 Drift
class SpToDriftMigration {
  final AppDatabase _db;
  final SharedPreferences _prefs;

  /// 字幕解析回调，用于从字幕文件获取句子信息以补全书签数据
  /// 传入音频项的相对字幕路径，返回解析后的句子列表
  final Future<List<model.Sentence>> Function(String relativeTranscriptPath)?
  _subtitleLoader;

  SpToDriftMigration(
    this._db,
    this._prefs, {
    Future<List<model.Sentence>> Function(String relativeTranscriptPath)?
    subtitleLoader,
  }) : _subtitleLoader = subtitleLoader;

  /// 检查迁移是否已完成
  bool get isMigrationComplete => _prefs.getBool(migrationCompleteKey) ?? false;

  /// 执行迁移
  /// 在单个事务中完成所有数据迁移，失败自动回滚
  Future<void> migrate() async {
    if (isMigrationComplete) return;

    // 读取 SP 旧数据
    final audioItems = _loadAudioItems();
    final collectionsJson = _loadCollectionsJson();

    // 在事务中写入 Drift
    await _db.transaction(() async {
      // 1. 迁移音频项
      await _migrateAudioItems(audioItems);

      // 2. 迁移合集 + junction 表
      await _migrateCollections(collectionsJson);

      // 3. 迁移书签
      await _migrateBookmarks(audioItems);

      // 4. 迁移播放状态
      await _migratePlaybackStates(audioItems);
    });

    // 事务成功后写入迁移标记
    await _prefs.setBool(migrationCompleteKey, true);
  }

  /// 从 SP 读取音频项列表
  List<model.AudioItem> _loadAudioItems() {
    final jsonString = _prefs.getString('audio_library');
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((j) => model.AudioItem.fromJson(j)).toList();
    } catch (e) {
      print('迁移：读取 audio_library 失败: $e');
      return [];
    }
  }

  /// 从 SP 读取合集原始 JSON 列表
  /// 需要同时获取 Collection 模型和 audioItemIds（已从模型中移除）
  List<Map<String, dynamic>> _loadCollectionsJson() {
    final jsonString = _prefs.getString('collections');
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('迁移：读取 collections 失败: $e');
      return [];
    }
  }

  /// 迁移音频项到 Drift
  Future<void> _migrateAudioItems(List<model.AudioItem> items) async {
    if (items.isEmpty) return;

    final now = DateTime.now();
    final entries = items
        .map(
          (item) => AudioItemsCompanion(
            id: Value(item.id),
            name: Value(item.name),
            audioPath: Value(item.audioPath),
            transcriptPath: Value(item.transcriptPath),
            // 有字幕文件的旧行须设 transcriptSource，否则字幕内容入库后 hasTranscript
            // （以 source 为准）会判为无字幕，导致字幕加载不出。SP 时代均为本地字幕。
            transcriptSource: Value(
              (item.transcriptPath != null && item.transcriptPath!.isNotEmpty)
                  ? model.TranscriptSource.local.index
                  : null,
            ),
            addedDate: Value(item.addedDate),
            totalDuration: Value(item.totalDuration),
            isPinned: Value(item.isPinned),
            updatedAt: Value(now),
            syncStatus: Value(0),
          ),
        )
        .toList();

    await _db.audioItemDao.batchInsert(entries);
  }

  /// 迁移合集到 Drift（包括 junction 表）
  /// 接收原始 JSON 以获取 audioItemIds（已从模型中移除）
  Future<void> _migrateCollections(
    List<Map<String, dynamic>> collectionsJson,
  ) async {
    if (collectionsJson.isEmpty) return;

    final now = DateTime.now();

    for (final json in collectionsJson) {
      final c = model.Collection.fromJson(json);
      final audioItemIds = model.Collection.audioItemIdsFromJson(json);

      await _db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value(c.id),
          name: Value(c.name),
          createdDate: Value(c.createdDate),
          isPinned: Value(c.isPinned),
          updatedAt: Value(now),
          syncStatus: Value(0),
        ),
      );

      // 展开 audioItemIds 到 junction 表
      if (audioItemIds.isNotEmpty) {
        final junctions = <CollectionAudioItemsCompanion>[];
        for (int i = 0; i < audioItemIds.length; i++) {
          junctions.add(
            CollectionAudioItemsCompanion(
              collectionId: Value(c.id),
              audioItemId: Value(audioItemIds[i]),
              sortOrder: Value(i),
              addedAt: Value(now),
            ),
          );
        }
        await _db.collectionDao.batchInsertJunctions(junctions);
      }
    }
  }

  /// 迁移书签到 Drift
  /// 从 SP 的 bookmarks_{id} 读取句子索引集合，补充句子文本和时间信息
  Future<void> _migrateBookmarks(List<model.AudioItem> audioItems) async {
    final now = DateTime.now();

    for (final item in audioItems) {
      final jsonString = _prefs.getString('bookmarks_${item.id}');
      if (jsonString == null) continue;

      Set<int> indices;
      try {
        final List<dynamic> list = json.decode(jsonString);
        indices = list.cast<int>().toSet();
      } catch (e) {
        print('迁移：读取 bookmarks_${item.id} 失败: $e');
        continue;
      }

      if (indices.isEmpty) continue;

      // 尝试从字幕文件获取句子信息（SP 时代字幕均为文件，按路径判断）
      Map<int, model.Sentence> sentenceMap = {};
      if (item.transcriptPath != null &&
          item.transcriptPath!.isNotEmpty &&
          _subtitleLoader != null) {
        try {
          final sentences = await _subtitleLoader(item.transcriptPath!);
          sentenceMap = {for (final s in sentences) s.index: s};
        } catch (e) {
          print('迁移：解析字幕失败 (${item.name}): $e');
        }
      }

      // 构建书签记录
      final entries = indices.map((index) {
        final sentence = sentenceMap[index];
        return BookmarksCompanion(
          audioItemId: Value(item.id),
          sentenceIndex: Value(index),
          sentenceText: Value(sentence?.text ?? ''),
          startTime: Value(
            sentence != null ? sentence.startTime.inMilliseconds / 1000.0 : 0.0,
          ),
          endTime: Value(
            sentence != null ? sentence.endTime.inMilliseconds / 1000.0 : 0.0,
          ),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(0),
        );
      }).toList();

      await _db.bookmarkDao.batchInsert(entries);
    }
  }

  /// 迁移播放状态到 Drift
  /// 只取 position，playlist_mode 保留
  Future<void> _migratePlaybackStates(List<model.AudioItem> audioItems) async {
    final now = DateTime.now();

    for (final item in audioItems) {
      final jsonString = _prefs.getString('playback_state_${item.id}');
      if (jsonString == null) continue;

      try {
        final Map<String, dynamic> stateMap = json.decode(jsonString);
        final positionMs = stateMap['position'] as int? ?? 0;
        final playlistMode = stateMap['playlistMode'] as int? ?? 0;

        await _db.playbackStateDao.saveState(
          PlaybackStatesCompanion(
            audioItemId: Value(item.id),
            positionMs: Value(positionMs),
            playlistMode: Value(playlistMode),
            savedAt: Value(now),
          ),
        );
      } catch (e) {
        print('迁移：读取 playback_state_${item.id} 失败: $e');
      }
    }
  }
}

/// 默认的字幕加载函数
/// 接收相对路径，解析为完整路径后使用 SubtitleParser 解析
Future<List<model.Sentence>> defaultSubtitleLoader(
  String relativeTranscriptPath,
) async {
  final dataDir = await getAppDataDirectory();
  final fullPath = '${dataDir.path}/$relativeTranscriptPath';
  return SubtitleParser.parseSubtitle(fullPath);
}
