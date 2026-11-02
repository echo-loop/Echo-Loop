import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

/// v41 → v42 迁移：firstLearn v2（盲听后置）上线后，删除「仍停在 v1 盲听第一步」
/// 的存量进度行。删除后该 audio 无进度行 → plan 回退 kLatestPlanVersions
/// （firstLearn=2）→ 显示新版顺序。
///
/// 验证 5 类 fixture：
/// 1. 停在 blindListen 的 v1（firstLearn=1, stage=firstLearn, sub=blindListen）→ 删除
/// 2. 盲听过但仍在 blindListen 的 v1（同上 + blind_listen_pass_count>0）→ 删除
/// 3. 已前进到精听的 v1（firstLearn=1, stage=firstLearn, sub=intensiveListen）→ 保留
/// 4. 已进入 review 的 v1（firstLearn=1, stage=review0）→ 保留
/// 5. 进行到第 3 步的 v2（firstLearn=2, stage=firstLearn, sub=blindListen）→ 保留（安全点）
void main() {
  test('v41→v42 删除仍停在 v1 盲听首步的进度行，不误删进行中的 v2', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v41_to_v42_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV41Fixture(file);

    final db = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    addTearDown(db.close);

    // 触发迁移并读取剩余行
    final remaining = await db
        .customSelect(
          'SELECT audio_item_id FROM learning_progresses ORDER BY audio_item_id',
        )
        .get();
    final remainingIds = remaining
        .map((r) => r.data['audio_item_id'] as String)
        .toSet();

    // 删除的两类
    expect(
      remainingIds,
      isNot(contains('v1-blind-fresh')),
      reason: 'v1 停在盲听首步 → 删除',
    );
    expect(
      remainingIds,
      isNot(contains('v1-blind-passed')),
      reason: 'v1 盲听过几遍但仍在盲听步 → 同样删除',
    );

    // 保留的三类
    expect(remainingIds, contains('v1-intensive'), reason: 'v1 已前进到精听 → 保留');
    expect(
      remainingIds,
      contains('v1-in-review'),
      reason: 'v1 已进入 review → 保留',
    );
    expect(
      remainingIds,
      contains('v2-blind-step3'),
      reason: '进行到第 3 步的 v2 同样是 firstLearn:blindListen，但有真实进度 → 必须保留',
    );

    expect(remainingIds.length, 3);
  });
}

Future<void> _createV41Fixture(File file) async {
  await seedCurrentSchema(file);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('DROP TABLE learning_progresses');
    // 最小 v41 schema：仅含 v42 迁移读写的列（含 plan_versions_json）。
    // 其它表缺失无妨——beforeOpen 的补列逻辑会守表存在后跳过。
    raw.execute('''
      CREATE TABLE learning_progresses (
        audio_item_id TEXT NOT NULL PRIMARY KEY,
        current_stage TEXT NOT NULL DEFAULT 'firstLearn',
        current_sub_stage TEXT NOT NULL DEFAULT 'blindListen',
        blind_listen_pass_count INTEGER NOT NULL DEFAULT 0,
        plan_versions_json TEXT NOT NULL DEFAULT '{}',
        updated_at INTEGER NOT NULL
      );
    ''');

    final now = DateTime(2026, 6, 17).millisecondsSinceEpoch;
    const v1Json =
        '{"firstLearn":1,"review0":1,"review1":1,"review2":1,"review4":1,'
        '"review7":1,"review14":1,"review28":1}';
    const v2Json =
        '{"firstLearn":2,"review0":2,"review1":2,"review2":2,"review4":2,'
        '"review7":2,"review14":2,"review28":2}';

    // (id, stage, sub, blindPassCount, json)
    final fixtures = <(String, String, String, int, String)>[
      ('v1-blind-fresh', 'firstLearn', 'blindListen', 0, v1Json),
      ('v1-blind-passed', 'firstLearn', 'blindListen', 3, v1Json),
      ('v1-intensive', 'firstLearn', 'intensiveListen', 0, v1Json),
      ('v1-in-review', 'review0', 'reviewDifficultPractice', 0, v1Json),
      ('v2-blind-step3', 'firstLearn', 'blindListen', 0, v2Json),
    ];
    for (final (id, stage, sub, passCount, json) in fixtures) {
      raw.execute(
        '''
        INSERT INTO learning_progresses (
          audio_item_id, current_stage, current_sub_stage,
          blind_listen_pass_count, plan_versions_json, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [id, stage, sub, passCount, json, now],
      );
    }

    raw.execute('PRAGMA user_version = 41');
  } finally {
    raw.close();
  }
}
