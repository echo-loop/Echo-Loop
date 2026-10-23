import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../utils/app_data_dir.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'enums.dart' show LearningStage;
import '../services/app_logger.dart';
import '../features/memory_scheduler/adapters/fsrs/fsrs_memory_model_adapter.dart';
import '../features/memory_scheduler/config/memory_profiles.dart';
import '../features/memory_scheduler/domain/memory_namespaces.dart';

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
import 'tables/tts_cache.dart';
import 'tables/memory_schedules.dart';
import 'tables/memory_review_events.dart';
import 'tables/memory_review_queue_entries.dart';
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
import 'daos/study_statistics_dao.dart';
import 'daos/tts_cache_dao.dart';
import 'daos/memory_schedule_dao.dart';
import 'daos/favorite_review_dao.dart';

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
    TtsCache,
    MemorySchedules,
    MemoryReviewEvents,
    MemoryReviewQueueEntries,
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
    StudyStatisticsDao,
    TtsCacheDao,
    MemoryScheduleDao,
    FavoriteReviewDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 当前 schema 版本（静态访问，用于导入前版本检查）
  static const currentSchemaVersion = 60;

  @override
  int get schemaVersion => currentSchemaVersion;

  /// 使用 SQLite `VACUUM INTO` 创建当前数据库的一致性备份快照。
  ///
  /// 该操作由现有 Drift 连接执行，因此无需关闭数据库，也不依赖直接复制可能仍
  /// 带有 WAL 的主数据库文件。SQLite 会在事务中调用或磁盘写入失败时抛出异常；
  /// 无论失败发生在哪个阶段，都删除不完整的目标文件。
  Future<void> createBackupSnapshot(File target) async {
    await target.parent.create(recursive: true);
    if (await target.exists()) {
      await target.delete();
    }

    try {
      await customStatement('VACUUM INTO ?', [target.path]);
    } catch (_) {
      if (await target.exists()) {
        await target.delete();
      }
      rethrow;
    }
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // 创建自定义索引
        await _createCustomIndexes(m);
      },
      beforeOpen: (details) async {
        // v38 发布过程里可能出现过 user_version 已到 38，但 podcast 列未真正落库
        // 的开发/测试数据库。启动时再做一次幂等补列，避免订阅时插入 episode 崩溃。
        await _ensurePodcastColumns();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v51→v52：增加整数毫秒字段，保留旧秒字段兼容历史查询。
        if (from < 52) {
          for (final table in [
            'daily_study_records',
            'daily_stage_study_records',
          ]) {
            await _addColumnIfNotExists(
              table,
              'study_time_milliseconds',
              'INTEGER NOT NULL DEFAULT 0',
            );
            await _addColumnIfNotExists(
              table,
              'input_time_milliseconds',
              'INTEGER NOT NULL DEFAULT 0',
            );
            await _addColumnIfNotExists(
              table,
              'output_time_milliseconds',
              'INTEGER NOT NULL DEFAULT 0',
            );
            if (await _tableExists(table)) {
              await customStatement('''
                UPDATE $table
                SET study_time_milliseconds = study_time_seconds * 1000,
                    input_time_milliseconds = input_time_seconds * 1000,
                    output_time_milliseconds = output_time_seconds * 1000
                WHERE study_time_milliseconds = 0
                  AND input_time_milliseconds = 0
                  AND output_time_milliseconds = 0
              ''');
            }
          }
        }
        // v52→v53：毫秒字段成为统计时长的唯一业务真值。
        // v52 迁移在极端的部分写入数据库上可能只完成了部分回填；这里按列
        // 独立修复，旧秒字段继续保留给旧备份/历史迁移兼容，但不再参与业务计算。
        if (from < 53) {
          for (final table in [
            'daily_study_records',
            'daily_stage_study_records',
          ]) {
            if (!await _tableExists(table)) continue;
            await customStatement('''
              UPDATE $table
              SET study_time_milliseconds = study_time_seconds * 1000
              WHERE study_time_milliseconds = 0
                AND study_time_seconds > 0
            ''');
            await customStatement('''
              UPDATE $table
              SET input_time_milliseconds = input_time_seconds * 1000
              WHERE input_time_milliseconds = 0
                AND input_time_seconds > 0
            ''');
            await customStatement('''
              UPDATE $table
              SET output_time_milliseconds = output_time_seconds * 1000
              WHERE output_time_milliseconds = 0
                AND output_time_seconds > 0
            ''');
          }
        }
        // v53→v54：合集命名统一为社区内容。旧数据库中的 source 值和索引都要
        // 一次性迁移，确保已订阅合集继续通过同一个 remoteId 被 v2 API 更新。
        if (from < 54) {
          await _addColumnIfNotExists(
            'collections',
            'source',
            "TEXT NOT NULL DEFAULT 'local'",
          );
          // 某些开发版数据库虽然 user_version 已经较新，但表是由历史 fixture
          // 重建的。这里幂等补齐 v29/v31 的身份列，保证这些数据库也能继续打开。
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
            'original_date',
            'INTEGER',
          );
          await customStatement(
            'DROP INDEX IF EXISTS idx_collections_remote_id_official',
          );
          await customStatement(
            "UPDATE collections SET source = 'community' WHERE source = 'official'",
          );
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_collections_remote_id_community
            ON collections(remote_id)
            WHERE source = 'community' AND remote_id IS NOT NULL AND deleted_at IS NULL
          ''');
        }
        // v54→v55：保留已有学习记录的社区文件下架状态，避免媒体被删除后再次
        // 自动下载，并允许文件重新出现在 v2 列表时恢复。
        if (from < 55) {
          await _addColumnIfNotExists(
            'audio_items',
            'community_unavailable_at',
            'INTEGER',
          );
        }
        // v55→v56：缓存社区合集发布者昵称，保证资源库详情离线可展示。
        if (from < 56) {
          await _addColumnIfNotExists('collections', 'author_nickname', 'TEXT');
        }
        // v56→v57：保存社区合集发布日期，资源库离线时仍可展示完整元信息。
        if (from < 57) {
          await _addColumnIfNotExists('collections', 'published_at', 'INTEGER');
        }
        // v58→v59：缓存社区合集封面的中国 CDN 镜像地址。
        if (from < 59) {
          await _addColumnIfNotExists('collections', 'cover_url_china', 'TEXT');
        }
        // v59→v60：缓存社区媒体的 CEFR 难度，普通媒体保持 NULL。
        if (from < 60) {
          await _addColumnIfNotExists(
            'audio_items',
            'community_difficulty',
            'TEXT',
          );
        }
        // v49→v50：为收藏单词/意群补稳定的记忆主体 ID，并把收藏句专属的每日
        // 入队去重表泛化为带 namespace 的通用表，供词汇复习共用同一张表。
        if (from < 50) {
          await _addColumnIfNotExists(
            'saved_words',
            'memory_subject_id',
            'TEXT',
          );
          await _addColumnIfNotExists(
            'saved_sense_groups',
            'memory_subject_id',
            'TEXT',
          );
          for (final table in ['saved_words', 'saved_sense_groups']) {
            if (!await _tableExists(table)) continue;
            final rows = await customSelect(
              'SELECT id FROM $table WHERE memory_subject_id IS NULL OR trim(memory_subject_id) = \'\'',
            ).get();
            for (final row in rows) {
              await customStatement(
                'UPDATE $table SET memory_subject_id = ? WHERE id = ?',
                [const Uuid().v4(), row.data['id']],
              );
            }
          }
          if (await _tableExists('bookmark_review_queue_entries')) {
            await customStatement(
              'ALTER TABLE bookmark_review_queue_entries RENAME TO memory_review_queue_entries',
            );
            await _addColumnIfNotExists(
              'memory_review_queue_entries',
              'namespace',
              'TEXT',
            );
            await customStatement(
              "UPDATE memory_review_queue_entries SET namespace = 'saved_sentence' WHERE namespace IS NULL OR trim(namespace) = ''",
            );
            await customStatement(
              'DROP INDEX IF EXISTS idx_bookmark_review_queue_subject_day',
            );
          } else {
            await m.createTable(memoryReviewQueueEntries);
          }
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_memory_review_queue_namespace_subject_day
            ON memory_review_queue_entries(namespace, subject_id, local_date)
          ''');
        }
        // v48→v49：为收藏句补稳定的记忆主体 ID，并建立每日入队去重表。
        if (from < 49) {
          await _addColumnIfNotExists('bookmarks', 'memory_subject_id', 'TEXT');
          if (await _tableExists('bookmarks')) {
            final rows = await customSelect(
              'SELECT id FROM bookmarks WHERE memory_subject_id IS NULL OR trim(memory_subject_id) = \'\'',
            ).get();
            for (final row in rows) {
              await customStatement(
                'UPDATE bookmarks SET memory_subject_id = ? WHERE id = ?',
                [const Uuid().v4(), row.data['id']],
              );
            }
          }
          // memory_review_queue_entries 的建表/改名/索引已由上面 v50 分支统一
          // 处理（该分支对任何 from < 50 都会先执行一次），此处不再重复建表。
        }
        // v47→v48：新增通用记忆调度快照与只追加评分事件；不回填既有业务数据。
        if (from < 48) {
          await m.createTable(memorySchedules);
          await m.createTable(memoryReviewEvents);
          await _createMemorySchedulerIndexes();
        }
        // v43→v44：tts_cache 新增 text 列（原始文本，便于调试）。
        // TTS 仍在开发阶段、缓存可丢弃，直接重建表即可（无需保留旧数据）。
        if (from >= 43 && from < 44) {
          await m.deleteTable('tts_cache');
          await m.createTable(ttsCache);
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_tts_cache_key
            ON tts_cache(cache_key)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_tts_cache_lru
            ON tts_cache(last_accessed_at)
            WHERE is_pinned = 0
          ''');
        }
        // v42→v43：新增 tts_cache 表（TTS 合成结果缓存索引）。
        if (from < 43) {
          await m.createTable(ttsCache);
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_tts_cache_key
            ON tts_cache(cache_key)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_tts_cache_lru
            ON tts_cache(last_accessed_at)
            WHERE is_pinned = 0
          ''');
        }
        // v40→v41：audio_items 新增转码前原始音频 SHA，用作 AI 转录缓存 key。
        if (from < 41) {
          await _addColumnIfNotExists(
            'audio_items',
            'original_audio_sha256',
            'TEXT',
          );
        }
        // v39→v40：Podcast 合集新增最后一次刷新错误状态。
        if (from < 40) {
          await _ensurePodcastRefreshStatusColumns();
        }
        // v38→v39：audio_items 加 audio_content_status（音频内容有效性，新下载时检测）
        if (from < 39) {
          await _addColumnIfNotExists(
            'audio_items',
            'audio_content_status',
            'INTEGER',
          );
        }
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
        // v44→v45：句子解析改为流式结构化结果，旧解析缓存与新 Prompt /
        // 展示契约不兼容。只清理句子解析缓存，保留翻译、查词和意群缓存。
        if (from < 45) {
          if (await _tableExists('sentence_ai_cache')) {
            await customStatement('''
              DELETE FROM sentence_ai_cache
              WHERE type LIKE 'analysis:%'
                 OR type LIKE 'analysis_v2:%'
            ''');
          }
        }
        // v45→v46：翻译改为流式单句 + 上下文（context hash）+ prompt version，
        // 旧翻译缓存（裸 `translation:` type、上下文无关 hash）与新契约不兼容。
        // 只清理翻译缓存，保留解析、查词和意群。新代 type 为 `translation_v2:$lang`，
        // 旧行天然不再命中，此处一并删除回收空间（双保险）。
        if (from < 46) {
          if (await _tableExists('sentence_ai_cache')) {
            await customStatement('''
              DELETE FROM sentence_ai_cache
              WHERE type LIKE 'translation:%'
            ''');
          }
        }
        // v46→v47：learning_progresses 新增 manual_unlock_at
        // （「立即解锁」当前复习轮的时刻，null = 未手动解锁）。
        if (from < 47) {
          await _addColumnIfNotExists(
            'learning_progresses',
            'manual_unlock_at',
            'INTEGER',
          );
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
        // v28→v29：社区合集支持字段
        // - collections 加：source / remoteId / coverUrl / description / deprecatedAt
        // - audio_items 加：remoteAudioId / isAudioDownloaded（默认 true 兼容老数据）
        // - 唯一索引：(remote_id) WHERE source='community' AND remote_id IS NOT NULL
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
          // 避免并发 enroll 写入重复的社区合集行
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_collections_remote_id_community
            ON collections(remote_id)
            WHERE source = 'community' AND remote_id IS NOT NULL
          ''');
          // 同步时按 remoteAudioId 反查
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_audio_items_remote_audio_id
            ON audio_items(remote_audio_id)
            WHERE remote_audio_id IS NOT NULL
          ''');
        }
        // v30→v31：audio_items 加 original_date（音频原始发布/播出日期，社区合集用）
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
        // v35→v36：audio_items 新增 transcript_srt 列（字幕内容入库，DB 成为唯一真相源）。
        // 仅加列，不做文件 IO；旧行内容由启动时全量 backfill 从文件读入。
        if (from < 36) {
          await _addColumnIfNotExists('audio_items', 'transcript_srt', 'TEXT');
        }
        // v36→v37：audio_items 新增用户导入来源字段。
        if (from < 37) {
          await _addColumnIfNotExists(
            'audio_items',
            'import_source_type',
            'TEXT',
          );
          await _addColumnIfNotExists(
            'audio_items',
            'import_source_url',
            'TEXT',
          );
        }
        // v37→v38：Podcast 合集支持字段。
        // - collections 加 podcast_input_url / podcast_feed_url /
        //   podcast_meta_json / podcast_last_refreshed_at
        // - audio_items 加 podcast_episode_guid / podcast_enclosure_url /
        //   podcast_enclosure_type / podcast_description / podcast_image_url /
        //   podcast_link
        if (from < 38) {
          await _ensurePodcastColumns();
        }
        // v41→v42：firstLearn v2（盲听后置）上线后，清理「仍停在 v1 盲听第一步」
        // 的存量进度行。删除后该 audio 无进度行 → plan 回退 kLatestPlanVersions
        // （firstLearn=2）→ 显示新版流程；重新打开时 ensureProgress 建全新 v2 进度。
        //
        // 背景：v33→v34 迁移把存量 audio 的 firstLearn 一律锁 v1。当时无 v2，合理；
        // 但 v2 上线后，从未真正开始（仍在盲听步）的存量音频被永久锁在旧顺序。
        //
        // 必须放在最后：依赖 v33→v34 块创建的 plan_versions_json 列（迁移块按源码
        // 顺序而非版本号执行，老库 from<34 块在此块之前才会跑到）。
        if (from < 42) {
          final lpExists = await customSelect(
            "SELECT COUNT(*) AS cnt FROM sqlite_master "
            "WHERE type='table' AND name = 'learning_progresses'",
          ).getSingle();
          if ((lpExists.data['cnt'] as int) > 0) {
            await _clearUnstartedV1FirstLearnProgress();
          }
        }
        // v58：补齐 v51-v57 期间可能缺少主体 ID 或活动调度快照的收藏。
        // 此后复习队列从 memory_schedules 直接联表读取，因此升级前统一收敛一次。
        if (from < 58) {
          await _createFavoriteReviewIndexes();
          await _migrateLegacyFavoriteMemorySchedules();
        }
      },
    );
  }

  /// 一次性收敛旧收藏与 FSRS 调度快照的生命周期。
  ///
  /// 必须在 schema v58 升级事务内执行：任一数据异常都会使 Drift 回滚升级，
  /// 避免把部分完成的回填标记为成功。运行期收藏入口已负责后续新增、恢复和
  /// 取消收藏的调度生命周期，这里只处理升级前的历史遗留数据。
  Future<void> _migrateLegacyFavoriteMemorySchedules() async {
    final migratedAt = DateTime.now().toUtc();
    final state = FsrsMemoryModelAdapter().createInitialState(
      profile: kFsrsDefaultProfile,
      createdAt: migratedAt,
    );
    final activeAudioIds = (await select(audioItems).get())
        .where((audio) => audio.deletedAt == null)
        .map((audio) => audio.id)
        .toSet();
    final subjectsByNamespace = <String, Set<String>>{
      kSavedSentenceNamespace: <String>{},
      kSavedWordOrPhraseNamespace: <String>{},
      kSavedSenseGroupNamespace: <String>{},
    };
    var created = 0;
    var archived = 0;
    var restored = 0;

    Future<void> reconcile({
      required String namespace,
      required String subjectId,
      required bool shouldBeActive,
      required bool createArchivedWhenMissing,
    }) async {
      final existing =
          await (select(memorySchedules)..where(
                (schedule) =>
                    schedule.namespace.equals(namespace) &
                    schedule.subjectId.equals(subjectId),
              ))
              .getSingleOrNull();
      if (shouldBeActive) {
        if (existing == null) {
          await into(memorySchedules).insert(
            _legacyScheduleCompanion(
              id: const Uuid().v4(),
              namespace: namespace,
              subjectId: subjectId,
              modelStateJson: jsonEncode(state.values),
              at: migratedAt,
            ),
          );
          created += 1;
        } else if (existing.status == 'archived') {
          await (update(
            memorySchedules,
          )..where((schedule) => schedule.id.equals(existing.id))).write(
            MemorySchedulesCompanion(
              status: const Value('active'),
              archivedAt: const Value(null),
              updatedAt: Value(migratedAt),
              revision: Value(existing.revision + 1),
            ),
          );
          restored += 1;
        }
        return;
      }

      if (existing == null) {
        if (!createArchivedWhenMissing) return;
        await into(memorySchedules).insert(
          _legacyScheduleCompanion(
            id: const Uuid().v4(),
            namespace: namespace,
            subjectId: subjectId,
            modelStateJson: jsonEncode(state.values),
            at: migratedAt,
            status: 'archived',
            revision: 1,
          ),
        );
        archived += 1;
      } else if (existing.status == 'active') {
        await (update(
          memorySchedules,
        )..where((schedule) => schedule.id.equals(existing.id))).write(
          MemorySchedulesCompanion(
            status: const Value('archived'),
            archivedAt: Value(migratedAt),
            updatedAt: Value(migratedAt),
            revision: Value(existing.revision + 1),
          ),
        );
        archived += 1;
      }
    }

    for (final bookmark in await select(bookmarks).get()) {
      var subjectId = bookmark.memorySubjectId;
      if (subjectId == null || subjectId.trim().isEmpty) {
        subjectId = const Uuid().v4();
        await (update(bookmarks)..where((row) => row.id.equals(bookmark.id)))
            .write(BookmarksCompanion(memorySubjectId: Value(subjectId)));
      }
      subjectsByNamespace[kSavedSentenceNamespace]!.add(subjectId);
      final isReviewable =
          bookmark.sentenceText.trim().isNotEmpty &&
          bookmark.endTime > bookmark.startTime;
      final hasActiveAudio = activeAudioIds.contains(bookmark.audioItemId);
      await reconcile(
        namespace: kSavedSentenceNamespace,
        subjectId: subjectId,
        shouldBeActive:
            bookmark.deletedAt == null && hasActiveAudio && isReviewable,
        createArchivedWhenMissing: bookmark.deletedAt != null,
      );
    }

    for (final word in await select(savedWords).get()) {
      var subjectId = word.memorySubjectId;
      if (subjectId == null || subjectId.trim().isEmpty) {
        subjectId = const Uuid().v4();
        await (update(savedWords)..where((row) => row.id.equals(word.id)))
            .write(SavedWordsCompanion(memorySubjectId: Value(subjectId)));
      }
      subjectsByNamespace[kSavedWordOrPhraseNamespace]!.add(subjectId);
      await reconcile(
        namespace: kSavedWordOrPhraseNamespace,
        subjectId: subjectId,
        shouldBeActive: word.deletedAt == null && word.word.trim().isNotEmpty,
        createArchivedWhenMissing: word.deletedAt != null,
      );
    }

    for (final group in await select(savedSenseGroups).get()) {
      var subjectId = group.memorySubjectId;
      if (subjectId == null || subjectId.trim().isEmpty) {
        subjectId = const Uuid().v4();
        await (update(
          savedSenseGroups,
        )..where((row) => row.id.equals(group.id))).write(
          SavedSenseGroupsCompanion(memorySubjectId: Value(subjectId)),
        );
      }
      subjectsByNamespace[kSavedSenseGroupNamespace]!.add(subjectId);
      await reconcile(
        namespace: kSavedSenseGroupNamespace,
        subjectId: subjectId,
        shouldBeActive:
            group.deletedAt == null && group.phraseText.trim().isNotEmpty,
        createArchivedWhenMissing: group.deletedAt != null,
      );
    }

    for (final schedule in await select(memorySchedules).get()) {
      if (schedule.status != 'active') continue;
      final knownSubjects = subjectsByNamespace[schedule.namespace];
      if (knownSubjects == null || knownSubjects.contains(schedule.subjectId)) {
        continue;
      }
      await (update(
        memorySchedules,
      )..where((row) => row.id.equals(schedule.id))).write(
        MemorySchedulesCompanion(
          status: const Value('archived'),
          archivedAt: Value(migratedAt),
          updatedAt: Value(migratedAt),
          revision: Value(schedule.revision + 1),
        ),
      );
      archived += 1;
    }

    AppLogger.log(
      'DB.migrate',
      'v58 favorite schedules: created=$created restored=$restored archived=$archived',
    );
  }

  /// 构造旧收藏迁移使用的初始快照；删除来源的历史项直接以归档态落库。
  MemorySchedulesCompanion _legacyScheduleCompanion({
    required String id,
    required String namespace,
    required String subjectId,
    required String modelStateJson,
    required DateTime at,
    String status = 'active',
    int revision = 0,
  }) {
    final isArchived = status == 'archived';
    return MemorySchedulesCompanion.insert(
      id: id,
      namespace: namespace,
      subjectId: subjectId,
      profileId: kFsrsDefaultProfileRef.profileId,
      profileVersion: kFsrsDefaultProfileRef.profileVersion,
      modelId: 'fsrs',
      modelStateVersion: 1,
      modelStateJson: Value(modelStateJson),
      phase: 'newItem',
      status: status,
      dueAt: at,
      reviewCount: const Value(0),
      lapseCount: const Value(0),
      revision: Value(revision),
      createdAt: at,
      updatedAt: at,
      archivedAt: Value(isArchived ? at : null),
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

  /// v41→v42 迁移内核：删除「仍停在 v1 盲听第一步」的 firstLearn 进度行。
  ///
  /// 判定：`current_stage='firstLearn'` 且 `current_sub_stage='blindListen'`
  /// 且 plan 快照里 `firstLearn == 1`。这类 audio 还没迈过 v1 第 1 步，进度行
  /// 只有难度 / 盲听计数等可丢弃信息，直接删除即可。删除后无进度行 → plan 回退
  /// kLatestPlanVersions（firstLearn=2）→ 显示新版顺序（精听优先）。
  ///
  /// **安全点**：v2 音频里 blindListen 是第 3 步，进行到第 3 步的 v2 行同样是
  /// `firstLearn:blindListen`，但有真实进度。必须校验 json `firstLearn == 1`，
  /// 只删 v1 行，绝不能仅凭 current_sub_stage='blindListen' 误删进行中的 v2。
  Future<void> _clearUnstartedV1FirstLearnProgress() async {
    final rows = await customSelect(
      "SELECT audio_item_id, plan_versions_json FROM learning_progresses "
      "WHERE current_stage = 'firstLearn' AND current_sub_stage = 'blindListen'",
    ).get();
    if (rows.isEmpty) {
      AppLogger.log('DB.migrate', 'v41→v42 清理 v1 盲听首步: 无候选行, skip');
      return;
    }

    final idsToDelete = <String>[];
    for (final row in rows) {
      final audioId = row.data['audio_item_id'] as String;
      final raw = row.data['plan_versions_json'] as String? ?? '';
      // 解析失败 / 空 json 视为非 v1（dense baseline 一定含 firstLearn），跳过。
      int? firstLearnVersion;
      if (raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map && decoded['firstLearn'] is int) {
            firstLearnVersion = decoded['firstLearn'] as int;
          }
        } catch (_) {
          firstLearnVersion = null;
        }
      }
      if (firstLearnVersion == 1) idsToDelete.add(audioId);
    }

    for (final audioId in idsToDelete) {
      await customStatement(
        "DELETE FROM learning_progresses WHERE audio_item_id = ?",
        [audioId],
      );
    }
    AppLogger.log(
      'DB.migrate',
      'v41→v42 清理 v1 盲听首步: 候选 ${rows.length} 行, '
          '删除 ${idsToDelete.length} 行 (firstLearn==1)',
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
          studyTimeMilliseconds: Value((data['study_time_'] ?? 0) * 1000),
          inputWords: Value(data['input_words_'] ?? 0),
          outputWords: Value(data['output_words_'] ?? 0),
          inputTimeSeconds: Value(data['input_time_'] ?? 0),
          inputTimeMilliseconds: Value((data['input_time_'] ?? 0) * 1000),
          outputTimeSeconds: Value(data['output_time_'] ?? 0),
          outputTimeMilliseconds: Value((data['output_time_'] ?? 0) * 1000),
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
  Future<bool> _tableExists(String table) async {
    final tableExists = await customSelect(
      "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type='table' AND name = '$table'",
    ).getSingle();
    return (tableExists.data['cnt'] as int) > 0;
  }

  /// 防御性补列：仅在目标表已存在且列缺失时执行 ALTER。
  ///
  /// 某些 legacy fixture 会直接从很早版本跳到当前版本；这些路径里中间表可能尚未
  /// 创建。这里先判表存在，避免迁移过程误打到不存在的表。
  Future<void> _addColumnIfNotExists(
    String table,
    String column,
    String definition,
  ) async {
    if (!await _tableExists(table)) return;

    final result = await customSelect(
      "SELECT COUNT(*) AS cnt FROM pragma_table_info('$table') WHERE name = '$column'",
    ).getSingle();
    if (result.data['cnt'] == 0) {
      await customStatement(
        'ALTER TABLE $table ADD COLUMN $column $definition',
      );
    }
  }

  /// 确保 v38 podcast 合集/episode 字段存在。
  ///
  /// 该方法故意保持幂等：正常迁移路径和启动自愈路径共用它，避免 schema
  /// 版本号与真实表结构短暂不一致时影响用户订阅 podcast。
  Future<void> _ensurePodcastColumns() async {
    await _addColumnIfNotExists('collections', 'podcast_input_url', 'TEXT');
    await _addColumnIfNotExists('collections', 'podcast_feed_url', 'TEXT');
    await _addColumnIfNotExists('collections', 'podcast_meta_json', 'TEXT');
    await _addColumnIfNotExists(
      'collections',
      'podcast_last_refreshed_at',
      'INTEGER',
    );
    await _ensurePodcastRefreshStatusColumns();
    await _addColumnIfNotExists('audio_items', 'podcast_episode_guid', 'TEXT');
    await _addColumnIfNotExists('audio_items', 'podcast_enclosure_url', 'TEXT');
    await _addColumnIfNotExists(
      'audio_items',
      'podcast_enclosure_type',
      'TEXT',
    );
    await _addColumnIfNotExists('audio_items', 'podcast_description', 'TEXT');
    await _addColumnIfNotExists('audio_items', 'podcast_image_url', 'TEXT');
    await _addColumnIfNotExists('audio_items', 'podcast_link', 'TEXT');
  }

  Future<void> _ensurePodcastRefreshStatusColumns() async {
    await _addColumnIfNotExists(
      'collections',
      'podcast_last_refresh_error',
      'TEXT',
    );
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

    // TTS 缓存按 key 唯一查找 + 按 LRU 淘汰
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_tts_cache_key
      ON tts_cache(cache_key)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_tts_cache_lru
      ON tts_cache(last_accessed_at)
      WHERE is_pinned = 0
    ''');

    // 社区合集 remoteId 唯一（防并发 enroll 重复）
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_collections_remote_id_community
      ON collections(remote_id)
      WHERE source = 'community'
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

    await _createMemorySchedulerIndexes();
    await _createFavoriteReviewIndexes();
  }

  /// 为从到期调度反查收藏主体建立轻量部分索引。
  Future<void> _createFavoriteReviewIndexes() async {
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_bookmarks_active_memory_subject
      ON bookmarks(memory_subject_id)
      WHERE deleted_at IS NULL AND memory_subject_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_saved_words_active_memory_subject
      ON saved_words(memory_subject_id)
      WHERE deleted_at IS NULL AND memory_subject_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_saved_sense_groups_active_memory_subject
      ON saved_sense_groups(memory_subject_id)
      WHERE deleted_at IS NULL AND memory_subject_id IS NOT NULL
    ''');
  }

  /// 创建记忆调度快照和事件的查询索引。
  Future<void> _createMemorySchedulerIndexes() async {
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_memory_schedules_active_namespace_due
      ON memory_schedules(namespace, due_at, id)
      WHERE status = 'active'
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_memory_schedules_active_due
      ON memory_schedules(due_at, id)
      WHERE status = 'active'
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_memory_schedules_active_phase_due
      ON memory_schedules(phase, due_at, id)
      WHERE status = 'active'
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_memory_schedules_profile
      ON memory_schedules(profile_id, profile_version)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_memory_review_events_schedule_reviewed
      ON memory_review_events(schedule_id, reviewed_at, sequence)
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
