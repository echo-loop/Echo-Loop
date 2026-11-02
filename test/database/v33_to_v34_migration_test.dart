import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

/// v33 → v34 迁移：把 plan 版本统一存入 `plan_versions_json` dense map。
///
/// 规则：每条 audio baseline 全 v1（保留老体验）；每个 review stage 若在
/// `stage_completions` 表里**无任何记录** → 升级到 v2。
///
/// 验证 4 类 fixture：
/// 1. 全新 audio（无任何 completion）→ 所有 review stage 都升 v2
/// 2. 完成 firstLearn（无 review completion）→ 所有 review stage 升 v2
/// 3. 完成 review0 全部、review1 中途 → review0/1 锁 v1，review2+ 升 v2
/// 4. review0 完成 reviewRetellParagraph（v1 plan 末项）→ review0 锁 v1（critic 提的边界）
void main() {
  test(
    'v33→v34 加 plan_versions_json 列并按 stage completion 是否存在判定 v1/v2',
    () async {
      final dir = Directory.systemTemp.createTempSync('fluency_v33_to_v34_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/echo_loop.db');
      await _createV33Fixture(file);

      final db = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
      addTearDown(db.close);

      // 列存在
      final columns = await db
          .customSelect('PRAGMA table_info(learning_progresses)')
          .get();
      final columnNames = columns
          .map((row) => row.data['name'] as String)
          .toSet();
      expect(columnNames, contains('plan_versions_json'));
      // 旧的 review0_plan_version 列不应存在（已删除）
      expect(columnNames, isNot(contains('review0_plan_version')));

      // 读取每条 audio 的 plan_versions_json 并解析
      final rows = await db
          .customSelect(
            'SELECT audio_item_id, plan_versions_json FROM learning_progresses '
            'ORDER BY audio_item_id',
          )
          .get();
      final byId = <String, Map<String, dynamic>>{
        for (final r in rows)
          r.data['audio_item_id'] as String:
              jsonDecode(r.data['plan_versions_json'] as String)
                  as Map<String, dynamic>,
      };

      // 每个 audio 应该有完整 dense baseline 的 8 个 stage key（除 completed）
      const allStageKeys = [
        'firstLearn',
        'review0',
        'review1',
        'review2',
        'review4',
        'review7',
        'review14',
        'review28',
      ];
      for (final entry in byId.entries) {
        expect(
          entry.value.keys.toSet(),
          containsAll(allStageKeys),
          reason: '${entry.key} 应含所有带 plan 的 LearningStage',
        );
        expect(
          entry.value.containsKey('completed'),
          isFalse,
          reason: '${entry.key} 不应含 completed',
        );
        // firstLearn 永远 v1（无变体）
        expect(
          entry.value['firstLearn'],
          1,
          reason: '${entry.key} firstLearn 应为 v1',
        );
      }

      // (1) 全新 audio（firstLearn/blindListen/v1）会被后续 v41→v42 迁移清理掉
      //     （仍停在 v1 盲听首步 → 删除，重新打开时建全新 v2 进度），故链式迁移到
      //     head 后该行已不存在。本用例验 v34 review 版本判定改用 audio-only-firstlearn。
      expect(
        byId.containsKey('audio-fresh'),
        isFalse,
        reason: 'firstLearn/blindListen/v1 行被 v41→v42 清理',
      );

      // (2) firstLearn 完成但无 review completion：review 全 v2
      final onlyFirstLearn = byId['audio-only-firstlearn']!;
      expect(onlyFirstLearn['review0'], 2);
      expect(onlyFirstLearn['review1'], 2);
      expect(onlyFirstLearn['review2'], 2);
      expect(onlyFirstLearn['review28'], 2);

      // (3) review0/1 已碰过 → 锁 v1；review2+ 没碰过 → v2
      final midReview1 = byId['audio-mid-review1']!;
      expect(midReview1['review0'], 1);
      expect(midReview1['review1'], 1);
      expect(midReview1['review2'], 2);
      expect(midReview1['review28'], 2);

      // (4) **critic 边界**：review0 完成 reviewRetellParagraph（v1 末项）
      //     → review0 有 completion → 锁 v1 → UI 渲染 v1 plan 含历史 ✅
      final review0V1End = byId['audio-review0-v1-end']!;
      expect(
        review0V1End['review0'],
        1,
        reason: 'review0 有 completion 必须锁 v1，避免完成的复述消失',
      );
      expect(review0V1End['review1'], 2);

      // (5) **current_sub_stage snap 验证**：
      //     audio-mid-review1 currentStage=review1, currentSubStage=blindListen
      //     （v1 时代 cross-stage 设的 v1 plan first），但 review1 无 completion
      //     → 升 v2 → snap currentSubStage 到 reviewDifficultPractice（v2 plan first）
      final snappedRow = await db
          .customSelect(
            "SELECT current_sub_stage FROM learning_progresses "
            "WHERE audio_item_id = 'audio-snap-needed'",
          )
          .getSingle();
      expect(
        snappedRow.data['current_sub_stage'],
        'reviewDifficultPractice',
        reason: '升 v2 时 v1 plan 残留的 blindListen 必须 snap 到 v2 plan first',
      );

      // 反例：audio-mid-review1 在 review1 已有 completion → 不 snap，保留 v1 plan
      final notSnappedRow = await db
          .customSelect(
            "SELECT current_sub_stage FROM learning_progresses "
            "WHERE audio_item_id = 'audio-mid-review1'",
          )
          .getSingle();
      expect(
        notSnappedRow.data['current_sub_stage'],
        'blindListen',
        reason: 'review1 已有 completion → 锁 v1，不 snap',
      );
    },
  );
}

Future<void> _createV33Fixture(File file) async {
  await seedCurrentSchema(file);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('DROP TABLE learning_progresses');
    raw.execute('DROP TABLE stage_completions');
    // 模拟 v33 schema（含 is_paused，无 review0_plan_version 和 plan_versions_json）
    raw.execute('''
      CREATE TABLE learning_progresses (
        audio_item_id TEXT NOT NULL PRIMARY KEY,
        current_stage TEXT NOT NULL DEFAULT 'firstLearn',
        current_sub_stage TEXT NOT NULL DEFAULT 'blindListen',
        difficulty INTEGER NOT NULL DEFAULT 1,
        first_learn_completed_at INTEGER,
        last_stage_completed_at INTEGER,
        current_stage_started_at INTEGER,
        total_study_duration_ms INTEGER NOT NULL DEFAULT 0,
        blind_listen_pass_count INTEGER NOT NULL DEFAULT 0,
        intensive_listen_sentence_index INTEGER,
        intensive_listen_difficult_count INTEGER,
        intensive_listen_pass_count INTEGER,
        shadowing_pass_count INTEGER,
        shadowing_sentence_index INTEGER,
        difficult_practice_sentence_index INTEGER,
        retell_paragraph_index INTEGER,
        retell_pass_count INTEGER,
        blind_listen_paragraph_index INTEGER,
        free_play_blind_listen_paragraph_index INTEGER,
        free_play_intensive_listen_sentence_index INTEGER,
        free_play_shadowing_sentence_index INTEGER,
        free_play_difficult_practice_sentence_index INTEGER,
        free_play_retell_paragraph_index INTEGER,
        new_learning_breakpoint_saved_at INTEGER,
        free_play_breakpoint_saved_at INTEGER,
        updated_at INTEGER NOT NULL,
        skipped_sub_stages TEXT NOT NULL DEFAULT '',
        is_paused INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute('''
      CREATE TABLE stage_completions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        audio_item_id TEXT NOT NULL,
        stage TEXT NOT NULL,
        sub_stage TEXT NOT NULL,
        completed_at INTEGER NOT NULL,
        duration_ms INTEGER
      );
    ''');

    final now = DateTime(2026, 5, 16).millisecondsSinceEpoch;
    final progressFixtures = <(String, String, String)>[
      ('audio-fresh', 'firstLearn', 'blindListen'),
      ('audio-only-firstlearn', 'review0', 'blindListen'),
      // mid-review1：review1 已有 completion → 不 snap
      ('audio-mid-review1', 'review1', 'blindListen'),
      ('audio-review0-v1-end', 'review0', 'reviewRetellParagraph'),
      // snap-needed：review1 无 completion + currentSubStage 是 v1 残留 blindListen
      ('audio-snap-needed', 'review1', 'blindListen'),
    ];
    for (final (id, stage, sub) in progressFixtures) {
      raw.execute(
        '''
        INSERT INTO learning_progresses (
          audio_item_id, current_stage, current_sub_stage, updated_at
        ) VALUES (?, ?, ?, ?)
        ''',
        [id, stage, sub, now],
      );
    }

    final completions = <(String, String, String, int)>[
      // audio-only-firstlearn：只有 firstLearn 完成（无 review）
      (
        'audio-only-firstlearn',
        'firstLearn',
        'blindListen',
        now - 7 * 86400000,
      ),
      ('audio-only-firstlearn', 'firstLearn', 'retell', now - 6 * 86400000),
      // audio-mid-review1：review0 完成、review1 中途
      ('audio-mid-review1', 'firstLearn', 'blindListen', now - 14 * 86400000),
      (
        'audio-mid-review1',
        'review0',
        'reviewDifficultPractice',
        now - 7 * 86400000,
      ),
      (
        'audio-mid-review1',
        'review0',
        'reviewRetellParagraph',
        now - 7 * 86400000,
      ),
      ('audio-mid-review1', 'review1', 'blindListen', now - 86400000),
      // audio-review0-v1-end：review0 完成了 reviewRetellParagraph（v1 末项）
      ('audio-review0-v1-end', 'firstLearn', 'retell', now - 7 * 86400000),
      (
        'audio-review0-v1-end',
        'review0',
        'reviewDifficultPractice',
        now - 86400000,
      ),
      (
        'audio-review0-v1-end',
        'review0',
        'reviewRetellParagraph',
        now - 86400000,
      ),
    ];
    for (final (audioId, stage, sub, completedAt) in completions) {
      raw.execute(
        '''
        INSERT INTO stage_completions (
          audio_item_id, stage, sub_stage, completed_at, duration_ms
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        [audioId, stage, sub, completedAt, 0],
      );
    }

    raw.execute('PRAGMA user_version = 33');
  } finally {
    raw.close();
  }
}
