import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../utils/app_data_dir.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'enums.dart' show LearningStage;
import '../services/app_logger.dart';

import 'tables/audio_items.dart';
import 'tables/collections.dart';
import 'tables/collection_audio_items.dart';
import 'tables/bookmarks.dart';
import 'tables/playback_states.dart';
import 'tables/learning_progresses.dart';
import 'tables/stage_completions.dart';
import 'tables/tags.dart';
import 'tables/audio_item_tags.dart';
import 'tables/sentence_ai_cache.dart';
import 'tables/saved_words.dart';
import 'tables/saved_sense_groups.dart';
import 'tables/learned_word_forms.dart';
import 'tables/daily_study_records.dart';
import 'tables/daily_stage_study_records.dart';
import '../models/study_stage.dart';
import 'daos/audio_item_dao.dart';
import 'daos/collection_dao.dart';
import 'daos/bookmark_dao.dart';
import 'daos/playback_state_dao.dart';
import 'daos/learning_progress_dao.dart';
import 'daos/stage_completion_dao.dart';
import 'daos/tag_dao.dart';
import 'daos/sentence_ai_cache_dao.dart';
import 'daos/saved_word_dao.dart';
import 'daos/saved_sense_group_dao.dart';
import 'daos/learned_word_form_dao.dart';
import 'daos/daily_study_record_dao.dart';
import 'daos/daily_stage_study_record_dao.dart';

part 'app_database.g.dart';

/// Echo Loop 应用数据库
/// 包含 14 张表：audio_items, collections, collection_audio_items, bookmarks,
/// playback_states, learning_progresses, stage_completions, tags, audio_item_tags,
/// sentence_ai_cache, saved_words, learned_word_forms, daily_study_records,
/// daily_stage_study_records
@DriftDatabase(
  tables: [
    AudioItems,
    Collections,
    CollectionAudioItems,
    Bookmarks,
    PlaybackStates,
    LearningProgresses,
    StageCompletions,
    Tags,
    AudioItemTags,
    SentenceAiCache,
    SavedWords,
    SavedSenseGroups,
    LearnedWordForms,
    DailyStudyRecords,
    DailyStageStudyRecords,
  ],
  daos: [
    AudioItemDao,
    CollectionDao,
    BookmarkDao,
    PlaybackStateDao,
    LearningProgressDao,
    StageCompletionDao,
    TagDao,
    SentenceAiCacheDao,
    SavedWordDao,
    SavedSenseGroupDao,
    LearnedWordFormDao,
    DailyStudyRecordDao,
    DailyStageStudyRecordDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 当前 schema 版本（静态访问，用于导入前版本检查）
  static const currentSchemaVersion = 35;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // 创建自定义索引
        await _createCustomIndexes(m);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(learningProgresses);
        }
        // v2→v11：learning_progresses 多次变更（列类型、新增列、字段重命名等）
        // 旧版本直接重建表
        if (from < 11) {
          await m.deleteTable('learning_progresses');
          await m.createTable(learningProgresses);
          // v4 新增 stage_completions 表
          if (from < 4) {
            await m.createTable(stageCompletions);
          }
        }
        // v11→v12：learning_progresses 新增 difficult_practice_sentence_index 列
        if (from >= 11 && from < 12) {
          await _addColumnIfNotExists(
            'learning_progresses',
            'difficult_practice_sentence_index',
            'INTEGER',
          );
        }
        // v13→v14：新增 sentence_ai_cache 表（AI 翻译/解析缓存）
        if (from < 14) {
          await m.createTable(sentenceAiCache);
        }
        // v14→v15：新增 saved_words 表（收藏单词）
        if (from < 15) {
          await m.createTable(savedWords);
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_saved_words_active
            ON saved_words(created_at DESC)
            WHERE deleted_at IS NULL
          ''');
        }
        // v17→v18：新增 learned_word_forms 表（已学习唯一词形）
        if (from < 18) {
          await m.createTable(learnedWordForms);
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_learned_word_forms_first_learned_at
            ON learned_word_forms(first_learned_at DESC)
          ''');
        }
        // v16→v17：saved_words 新增 Flashcard 练习统计列
        if (from >= 15 && from < 17) {
          await _addColumnIfNotExists(
            'saved_words',
            'practice_count',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addColumnIfNotExists(
            'saved_words',
            'total_study_ms',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addColumnIfNotExists(
            'saved_words',
            'viewed_back',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addColumnIfNotExists(
            'saved_words',
            'last_practiced_at',
            'INTEGER',
          );
        }
        // v15→v16：saved_words 新增 sentence_start_ms, sentence_end_ms 列
        if (from >= 15 && from < 16) {
          await _addColumnIfNotExists(
            'saved_words',
            'sentence_start_ms',
            'INTEGER',
          );
          await _addColumnIfNotExists(
            'saved_words',
            'sentence_end_ms',
            'INTEGER',
          );
        }
        // v18→v19：新增 daily_study_records 表 + 从 SP 迁移数据
        if (from < 19) {
          await m.createTable(dailyStudyRecords);
          await _migrateStudyDataFromSP();
        }
        // v19→v20：新增 daily_stage_study_records 表（按阶段统计每日听说时长）
        if (from < 20) {
          await m.createTable(dailyStageStudyRecords);
        }
        // v20→v21：learning_progresses 新增断点来源字段（v1 方案，已被 v22 替代）
        if (from < 21) {
          await _addColumnIfNotExists(
            'learning_progresses',
            'breakpoint_from_normal_learning',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addColumnIfNotExists(
            'learning_progresses',
            'breakpoint_saved_at',
            'INTEGER',
          );
        }
        // v21→v22：learning_progresses 双轨断点分离（各自独立索引 + 过期时间戳）
        // v22→v23：盲听断点续学段落索引
        if (from < 23) {
          await _addColumnIfNotExists(
            'learning_progresses',
            'blind_listen_paragraph_index',
            'INTEGER',
          );
          await _addColumnIfNotExists(
            'learning_progresses',
            'free_play_blind_listen_paragraph_index',
            'INTEGER',
          );
        }
        if (from < 22) {
          await _addColumnIfNotExists(
            'learning_progresses',
            'free_play_intensive_listen_sentence_index',
            'INTEGER',
          );
          await _addColumnIfNotExists(
            'learning_progresses',
            'free_play_shadowing_sentence_index',
            'INTEGER',
          );
          await _addColumnIfNotExists(
            'learning_progresses',
            'free_play_difficult_practice_sentence_index',
            'INTEGER',
          );
          await _addColumnIfNotExists(
            'learning_progresses',
            'free_play_retell_paragraph_index',
            'INTEGER',
          );
          await _addColumnIfNotExists(
            'learning_progresses',
            'new_learning_breakpoint_saved_at',
            'INTEGER',
          );
          await _addColumnIfNotExists(
            'learning_progresses',
            'free_play_breakpoint_saved_at',
            'INTEGER',
          );
        }
        // v24→v25：词级时间戳从独立表迁移到 audio_items 列
        if (from < 25) {
          await _addColumnIfNotExists(
            'audio_items',
            'word_timestamps_json',
            'TEXT',
          );
          // 从旧表迁移数据（旧表可能不存在，忽略错误）
          try {
            await customStatement('''
              UPDATE audio_items
              SET word_timestamps_json = (
                SELECT data FROM word_timestamp_cache
                WHERE word_timestamp_cache.audio_item_id = audio_items.id
              )
            ''');
          } catch (_) {
            // word_timestamp_cache 表可能不存在（全新安装直接到 v25）
          }
          await customStatement('DROP TABLE IF EXISTS word_timestamp_cache');
        }
        // v25→v26：新建 saved_sense_groups 表
        if (from < 26) {
          await m.createTable(savedSenseGroups);
        }
        // v26→v27：saved_sense_groups 新增练习统计字段
        if (from < 27) {
          await _addColumnIfNotExists(
            'saved_sense_groups',
            'total_study_ms',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addColumnIfNotExists(
            'saved_sense_groups',
            'viewed_back',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addColumnIfNotExists(
            'saved_sense_groups',
            'last_practiced_at',
            'INTEGER',
          );
        }
        // v12→v13：audio_items 新增 transcript_source, audio_sha256, transcript_language 列
        if (from < 13) {
          await _addColumnIfNotExists(
            'audio_items',
            'transcript_source',
            'INTEGER',
          );
          await _addColumnIfNotExists('audio_items', 'audio_sha256', 'TEXT');
          await _addColumnIfNotExists(
            'audio_items',
            'transcript_language',
            'TEXT',
          );
          // 回填：已有字幕的记录设 transcript_source = 0 (local)
          await customStatement('''
            UPDATE audio_items
            SET transcript_source = 0
            WHERE transcript_path IS NOT NULL
              AND transcript_path != ''
              AND transcript_source IS NULL
          ''');
        }
        // v7→v8：audio_items 新增 isStarred 列
        if (from < 8) {
          await customStatement(
            'ALTER TABLE audio_items ADD COLUMN is_starred INTEGER NOT NULL DEFAULT 0',
          );
        }
        // v8→v9：新增 tags 和 audio_item_tags 表
        if (from < 9) {
          // 防御性补列：is_starred 可能因旧版迁移异常未实际添加
          await _addColumnIfNotExists(
            'audio_items',
            'is_starred',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await m.createTable(tags);
          await m.createTable(audioItemTags);
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_audio_item_tags_reverse
            ON audio_item_tags(audio_item_id)
          ''');
        }
        // v27→v28：isStarred → isPinned 重命名
        if (from < 28) {
          await customStatement(
            'ALTER TABLE audio_items RENAME COLUMN is_starred TO is_pinned',
          );
          await customStatement(
            'ALTER TABLE collections RENAME COLUMN is_starred TO is_pinned',
          );
        }
        // v28→v29：官方合集支持字段
        // - collections 加：source / remoteId / coverUrl / description / deprecatedAt
        // - audio_items 加：remoteAudioId / isAudioDownloaded（默认 true 兼容老数据）
        // - 唯一索引：(remote_id) WHERE source='official' AND remote_id IS NOT NULL
        if (from < 29) {
          await _addColumnIfNotExists(
            'collections',
            'source',
            "TEXT NOT NULL DEFAULT 'local'",
          );
          await _addColumnIfNotExists('collections', 'remote_id', 'TEXT');
          await _addColumnIfNotExists('collections', 'cover_url', 'TEXT');
          await _addColumnIfNotExists('collections', 'description', 'TEXT');
          await _addColumnIfNotExists(
            'collections',
            'deprecated_at',
            'INTEGER',
          );
          await _addColumnIfNotExists('audio_items', 'remote_audio_id', 'TEXT');
          await _addColumnIfNotExists(
            'audio_items',
            'is_audio_downloaded',
            'INTEGER NOT NULL DEFAULT 1',
          );
          // 避免并发 enroll 写入重复的官方合集行
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_collections_remote_id_official
            ON collections(remote_id)
            WHERE source = 'official' AND remote_id IS NOT NULL
          ''');
          // 同步时按 remoteAudioId 反查
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_audio_items_remote_audio_id
            ON audio_items(remote_audio_id)
            WHERE remote_audio_id IS NOT NULL
          ''');
        }
        // v30→v31：audio_items 加 original_date（音频原始发布/播出日期，官方合集用）
        //
        // 注意：这里必须在 v29→v30 的 alterTable 之前执行。Drift 的
        // TableMigration 会按当前表定义重建 audio_items，当前表已包含
        // original_date；若旧表还没有该列，重建时会在 SELECT 阶段缺列失败。
        if (from < 31) {
          await _addColumnIfNotExists(
            'audio_items',
            'original_date',
            'INTEGER',
          );
        }
        // v29→v30：audio_path 改 nullable，删除 is_audio_downloaded 字段
        // - 单一真实来源：audioPath != null ↔ 文件已下载
        // - 先按 is_audio_downloaded=0 把预置但文件不存在的 path 清成 NULL
        // - 然后走 Drift alterTable 重建表（nullable audio_path + 去掉 is_audio_downloaded 列）
        //
        // 该块依赖 v28→v29 先补出 is_audio_downloaded。老用户从 v28 或更早
        // 直接升到当前版本时，如果顺序反了，会在表重建时报 no such column。
        if (from < 30) {
          // 上一次失败的 TableMigration 可能留下临时拷贝表；重试前清理残留。
          await customStatement(
            'DROP TABLE IF EXISTS tmp_for_copy_audio_items',
          );
          await m.alterTable(
            // ignore: experimental_member_use
            TableMigration(
              audioItems,
              columnTransformer: {
                audioItems.audioPath: const CustomExpression<String>(
                  'CASE WHEN is_audio_downloaded = 0 THEN NULL ELSE audio_path END',
                ),
                audioItems.transcriptPath: const CustomExpression<String>(
                  'CASE WHEN is_audio_downloaded = 0 THEN NULL ELSE transcript_path END',
                ),
              },
            ),
          );
          // alterTable 重建表后索引需要重建
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_audio_items_remote_audio_id
            ON audio_items(remote_audio_id)
            WHERE remote_audio_id IS NOT NULL
          ''');
        }
        // v5→v6：audio_items 新增 sentenceCount、wordCount 列
        if (from < 6) {
          await customStatement(
            'ALTER TABLE audio_items ADD COLUMN sentence_count INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE audio_items ADD COLUMN word_count INTEGER NOT NULL DEFAULT 0',
          );
        }
        // v31→v32：learning_progresses 新增 skipped_sub_stages 列
        // 存储用户手动跳过 / 自动跳过策略产生的跳过记录，与 stage_completions 互斥。
        if (from < 32) {
          await _addColumnIfNotExists(
            'learning_progresses',
            'skipped_sub_stages',
            "TEXT NOT NULL DEFAULT ''",
          );
        }
        // v32→v33：learning_progresses 新增 is_paused 列
        // true 表示该音频不参与复习调度，可由用户随时恢复。
        if (from < 33) {
          await _addColumnIfNotExists(
            'learning_progresses',
            'is_paused',
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
        // v33→v34：learning_progresses 新增 plan_versions_json 列。
        // 统一存所有 LearningStage 的 plan 版本（dense JSON map）。
        //
        // 规则：每条 audio baseline 全 v1（保留老体验），对每个 review
        // stage 检查 stage_completions 表是否有该 stage 的任何完成记录：
        // **无记录 → 升级到 v2**（用户还没碰过这一轮，给新版体验）。
        // firstLearn 永远 v1（暂无变体）。
        if (from < 34) {
          await _addColumnIfNotExists(
            'learning_progresses',
            'plan_versions_json',
            "TEXT NOT NULL DEFAULT '{}'",
          );
          final tableExists = await customSelect(
            "SELECT COUNT(*) AS cnt FROM sqlite_master "
            "WHERE type='table' AND name = 'learning_progresses'",
          ).getSingle();
          if ((tableExists.data['cnt'] as int) > 0) {
            await _migrateToPlanVersionsJson();
          }
        }
        // v34→v35：盲听/复述断点改成全局句子 index 粒度。
        //
        // - 4 个列重命名：*_paragraph_index → *_sentence_index
        // - 盲听旧值（段索引语义）直接清零，避免被当成句子 index 错误恢复
        // - 复述旧值（实际就是句首句的全局 index）语义不变，保留
        if (from < 35) {
          final lpExists = await customSelect(
            "SELECT COUNT(*) AS cnt FROM sqlite_master "
            "WHERE type='table' AND name = 'learning_progresses'",
          ).getSingle();
          if ((lpExists.data['cnt'] as int) == 0) return;
          await customStatement(
            'ALTER TABLE learning_progresses '
            'RENAME COLUMN blind_listen_paragraph_index '
            'TO blind_listen_sentence_index',
          );
          await customStatement(
            'ALTER TABLE learning_progresses '
            'RENAME COLUMN free_play_blind_listen_paragraph_index '
            'TO free_play_blind_listen_sentence_index',
          );
          await customStatement(
            'ALTER TABLE learning_progresses '
            'RENAME COLUMN retell_paragraph_index '
            'TO retell_sentence_index',
          );
          await customStatement(
            'ALTER TABLE learning_progresses '
            'RENAME COLUMN free_play_retell_paragraph_index '
            'TO free_play_retell_sentence_index',
          );
          await customStatement(
            'UPDATE learning_progresses SET '
            'blind_listen_sentence_index = NULL, '
            'free_play_blind_listen_sentence_index = NULL',
          );
        }
      },
    );
  }

  /// v33→v34 迁移内核：把每条 audio 的 plan 版本翻译进 `plan_versions_json` 列，
  /// 并修正 v1 → v2 切换时被设错位的 `current_sub_stage`。
  ///
  /// 规则：
  /// 1. plan_versions：每个 audio baseline 全 v1；review stage 若**无 completion** → v2
  /// 2. current_sub_stage snap：若 `current_stage` 是 review1-28 且正升 v2（无 completion）
  ///    且 `current_sub_stage` 不是 `reviewDifficultPractice`（v2 plan first），
  ///    snap 到 `reviewDifficultPractice`。
  ///    原因：v1 时代 `current_sub_stage` 在跨阶段被设为 v1 plan first = `blindListen`；
  ///    升 v2 后 `blindListen` 变成 v2 plan 第二项 → 用户像「跳过了第一步」。
  ///    review0 不需要 snap（v1/v2 plan first 同为 `reviewDifficultPractice`）。
  Future<void> _migrateToPlanVersionsJson() async {
    // 1. 拉所有 audio 进度（id + currentStage + currentSubStage）
    final progresses = await customSelect(
      "SELECT audio_item_id, current_stage, current_sub_stage "
      "FROM learning_progresses",
    ).get();
    if (progresses.isEmpty) {
      AppLogger.log('DB.migrate', 'v33→v34 plan_versions_json: no rows, skip');
      return;
    }
    AppLogger.log(
      'DB.migrate',
      'v33→v34 plan_versions_json: start, audio count = ${progresses.length}',
    );

    // 2. 预查每条 audio 在 review0-28 各阶段是否有任何 completion
    //    stage_completions 表可能不存在（某些老 fixture 升级路径），守一下
    final touchedStages = <String, Set<String>>{};
    final scExists = await customSelect(
      "SELECT COUNT(*) AS cnt FROM sqlite_master "
      "WHERE type='table' AND name = 'stage_completions'",
    ).getSingle();
    if ((scExists.data['cnt'] as int) > 0) {
      final rows = await customSelect(
        "SELECT DISTINCT audio_item_id, stage FROM stage_completions "
        "WHERE stage IN ('review0','review1','review2','review4',"
        "'review7','review14','review28')",
      ).get();
      for (final row in rows) {
        final audioId = row.data['audio_item_id'] as String;
        final stage = row.data['stage'] as String;
        touchedStages.putIfAbsent(audioId, () => <String>{}).add(stage);
      }
      AppLogger.log(
        'DB.migrate',
        'v33→v34: touchedStages 聚合完成，涉及 audio 数 = ${touchedStages.length}',
      );
    } else {
      AppLogger.log('DB.migrate', 'v33→v34: stage_completions 表不存在，跳过启发式');
    }

    // 3. 对每条 audio 计算最终 map 并写回
    const reviewStageKeys = [
      'review0',
      'review1',
      'review2',
      'review4',
      'review7',
      'review14',
      'review28',
    ];
    var lockedV1Count = 0;
    var allV2Count = 0;
    var subStageSnappedCount = 0;
    // review1-28 升 v2 后 plan first 固定是 reviewDifficultPractice。
    // review0 v1/v2 plan first 都是 reviewDifficultPractice，无需 snap。
    const v2SnapTargetForReview1Plus = 'reviewDifficultPractice';
    const snapApplicableStages = {
      'review1',
      'review2',
      'review4',
      'review7',
      'review14',
      'review28',
    };
    for (final p in progresses) {
      final audioId = p.data['audio_item_id'] as String;
      final currentStage = p.data['current_stage'] as String;
      final currentSubStage = p.data['current_sub_stage'] as String;
      // baseline：现存 audio 全 v1（保留老体验）
      final map = <String, int>{
        for (final s in LearningStage.values)
          if (s != LearningStage.completed) s.key: 1,
      };
      // 未碰过的 review stage 升级到 v2
      final touched = touchedStages[audioId] ?? const <String>{};
      for (final stageKey in reviewStageKeys) {
        if (!touched.contains(stageKey)) {
          map[stageKey] = 2;
        }
      }
      if (touched.isEmpty) {
        allV2Count++;
      } else {
        lockedV1Count++;
      }
      final lockedStages = map.entries
          .where((e) => e.value == 1 && e.key != 'firstLearn')
          .map((e) => e.key)
          .toList();

      // 修正 current_sub_stage：当前 stage 是 review1-28 且正升 v2 + 不在 v2 first
      String? newSubStage;
      if (snapApplicableStages.contains(currentStage) &&
          !touched.contains(currentStage) &&
          currentSubStage != v2SnapTargetForReview1Plus) {
        newSubStage = v2SnapTargetForReview1Plus;
        subStageSnappedCount++;
        AppLogger.log(
          'DB.migrate',
          'v33→v34 audio=$audioId snap current_sub_stage '
              '$currentStage:$currentSubStage → $currentStage:$newSubStage '
              '(stage 升 v2，currentSubStage 是 v1 plan 残留)',
        );
      }

      AppLogger.log(
        'DB.migrate',
        'v33→v34 audio=$audioId touched=${touched.toList()} '
            'lockedV1=$lockedStages',
      );
      if (newSubStage != null) {
        await customStatement(
          "UPDATE learning_progresses "
          "SET plan_versions_json = ?, current_sub_stage = ? "
          "WHERE audio_item_id = ?",
          [jsonEncode(map), newSubStage, audioId],
        );
      } else {
        await customStatement(
          "UPDATE learning_progresses SET plan_versions_json = ? "
          "WHERE audio_item_id = ?",
          [jsonEncode(map), audioId],
        );
      }
    }
    AppLogger.log(
      'DB.migrate',
      'v33→v34 done. 全 v2 (未碰过任何 review) = $allV2Count, '
          '部分锁 v1 = $lockedV1Count, current_sub_stage snap = $subStageSnappedCount',
    );
  }

  /// 从 SharedPreferences 迁移学习统计数据到 daily_study_records 表
  ///
  /// 扫描 5 种前缀的 SP key，按日期分组后写入 SQLite，最后删除旧 key。
  Future<void> _migrateStudyDataFromSP() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    const prefixes = [
      'study_time_',
      'input_words_',
      'output_words_',
      'input_time_',
      'output_time_',
    ];

    // 按日期聚合数据
    final Map<String, Map<String, int>> dateMap = {};
    final List<String> keysToRemove = [];

    for (final key in allKeys) {
      for (final prefix in prefixes) {
        if (key.startsWith(prefix)) {
          final dateStr = key.substring(prefix.length);
          final value = prefs.getInt(key) ?? 0;
          if (value > 0) {
            dateMap.putIfAbsent(dateStr, () => {});
            dateMap[dateStr]![prefix] = value;
          }
          keysToRemove.add(key);
          break;
        }
      }
    }

    // 写入 SQLite
    for (final entry in dateMap.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;

      final date = DateTime(year, month, day);
      final data = entry.value;

      await into(dailyStudyRecords).insert(
        DailyStudyRecordsCompanion.insert(
          date: date,
          studyTimeSeconds: Value(data['study_time_'] ?? 0),
          inputWords: Value(data['input_words_'] ?? 0),
          outputWords: Value(data['output_words_'] ?? 0),
          inputTimeSeconds: Value(data['input_time_'] ?? 0),
          outputTimeSeconds: Value(data['output_time_'] ?? 0),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }

    // 删除旧 SP key
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  /// 防御性重命名列：旧列存在则 rename，否则确保新列存在。
  /// 防御性补列：检查列是否存在，不存在则添加
  ///
  /// 解决开发阶段可能出现的迁移版本号已更新但列未实际添加的问题。
  Future<void> _addColumnIfNotExists(
    String table,
    String column,
    String definition,
  ) async {
    // 先校验表存在；不存在直接跳过（某些 legacy 迁移路径里 learning_progresses
    // 可能在到达本步骤前还没创建，例如从 v28 fixture 直接升级到当前版本）。
    final tableExists = await customSelect(
      "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type='table' AND name = '$table'",
    ).getSingle();
    if ((tableExists.data['cnt'] as int) == 0) return;

    final result = await customSelect(
      "SELECT COUNT(*) AS cnt FROM pragma_table_info('$table') WHERE name = '$column'",
    ).getSingle();
    if (result.data['cnt'] == 0) {
      await customStatement(
        'ALTER TABLE $table ADD COLUMN $column $definition',
      );
    }
  }

  /// 创建自定义索引
  Future<void> _createCustomIndexes(Migrator m) async {
    // 书签按音频加载（排除已删除）
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_bookmarks_audio
      ON bookmarks(audio_item_id)
      WHERE deleted_at IS NULL
    ''');

    // Junction 表反向查询
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_collection_audio_reverse
      ON collection_audio_items(audio_item_id)
    ''');

    // 活跃音频列表（按添加时间倒序，排除已删除）
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_audio_active
      ON audio_items(added_date DESC)
      WHERE deleted_at IS NULL
    ''');

    // 合集按创建时间排序（排除已删除）
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_collections_created
      ON collections(created_date DESC)
      WHERE deleted_at IS NULL
    ''');

    // 同步批量查询（未来同步时使用）
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_audio_sync
      ON audio_items(sync_status)
      WHERE sync_status != 0
    ''');

    // 标签 Junction 表反向查询
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_audio_item_tags_reverse
      ON audio_item_tags(audio_item_id)
    ''');

    // 收藏单词按时间倒序（排除已删除）
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_saved_words_active
      ON saved_words(created_at DESC)
      WHERE deleted_at IS NULL
    ''');

    // 已学习词形首次学习时间索引
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_learned_word_forms_first_learned_at
      ON learned_word_forms(first_learned_at DESC)
    ''');

    // 官方合集 remoteId 唯一（防并发 enroll 重复）
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_collections_remote_id_official
      ON collections(remote_id)
      WHERE source = 'official'
        AND remote_id IS NOT NULL
        AND deleted_at IS NULL
    ''');

    // 同步时按 remoteAudioId 反查 audio_items。
    // UNIQUE：防并发 syncAll 把同一个 remoteAudioId 插成两行。
    // 老版本可能已经创建了非 UNIQUE 的同名索引，这里先 DROP 再 CREATE 保证升级到 UNIQUE。
    await customStatement(
      'DROP INDEX IF EXISTS idx_audio_items_remote_audio_id',
    );
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_audio_items_remote_audio_id
      ON audio_items(remote_audio_id)
      WHERE remote_audio_id IS NOT NULL
        AND deleted_at IS NULL
    ''');
  }
}

/// 创建数据库连接（生产环境使用）
LazyDatabase openConnection() {
  return openConnectionWithName('echo_loop.db');
}

/// 创建指定文件名的数据库连接。
///
/// 用于运行时切换数据库（如演示模式使用 `echo_loop_demo.db`）。
LazyDatabase openConnectionWithName(String fileName) {
  return LazyDatabase(() async {
    final dbFolder = await getAppDataDirectory();
    final file = File(p.join(dbFolder.path, fileName));
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}
