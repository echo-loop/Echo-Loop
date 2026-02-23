import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/audio_items.dart';
import 'tables/collections.dart';
import 'tables/collection_audio_items.dart';
import 'tables/bookmarks.dart';
import 'tables/playback_states.dart';
import 'tables/learning_progresses.dart';
import 'tables/stage_completions.dart';
import 'tables/tags.dart';
import 'tables/audio_item_tags.dart';
import 'daos/audio_item_dao.dart';
import 'daos/collection_dao.dart';
import 'daos/bookmark_dao.dart';
import 'daos/playback_state_dao.dart';
import 'daos/learning_progress_dao.dart';
import 'daos/stage_completion_dao.dart';
import 'daos/tag_dao.dart';

part 'app_database.g.dart';

/// Fluency 应用数据库
/// 包含 9 张表：audio_items, collections, collection_audio_items, bookmarks,
/// playback_states, learning_progresses, stage_completions, tags, audio_item_tags
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
  ],
  daos: [
    AudioItemDao,
    CollectionDao,
    BookmarkDao,
    PlaybackStateDao,
    LearningProgressDao,
    StageCompletionDao,
    TagDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 9;

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
        // v2→v7：learning_progresses 多次变更（列类型、新增列等）
        // App 尚未发布，直接重建表
        if (from < 7) {
          await m.deleteTable('learning_progresses');
          await m.createTable(learningProgresses);
          // v4 新增 stage_completions 表
          if (from < 4) {
            await m.createTable(stageCompletions);
          }
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
        // v5→v6：audio_items 新增 sentenceCount、wordCount 列
        if (from < 6) {
          await customStatement(
            'ALTER TABLE audio_items ADD COLUMN sentence_count INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE audio_items ADD COLUMN word_count INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  /// 防御性补列：检查列是否存在，不存在则添加
  ///
  /// 解决开发阶段可能出现的迁移版本号已更新但列未实际添加的问题。
  Future<void> _addColumnIfNotExists(
    String table,
    String column,
    String definition,
  ) async {
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
  }
}

/// 创建数据库连接（生产环境使用）
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fluency.db'));
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}
