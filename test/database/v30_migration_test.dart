import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// v30 schema 基线行为验证：
/// - `audio_path` 允许为 NULL
/// - `is_audio_downloaded` 列已移除
/// - 插入时不写 audioPath / transcriptPath → 两列都是 null，语义为"未下载"
///
/// 不测"从 v29 升级到 v30"的真实升级路径（需要 Drift schema snapshot 基础设施），
/// 这里只锁住新 schema 的对外契约，避免后续代码再把它改回 NOT NULL。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
  });

  tearDown(() async {
    await db.close();
  });

  test('audioItems 插入时 audioPath=null + transcriptPath=null 不报错', () async {
    final now = DateTime(2026, 4, 19);
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('oc-1'),
        name: const Value('社区占位'),
        addedDate: Value(now),
        updatedAt: Value(now),
        remoteAudioId: const Value('r-1'),
        audioSha256: const Value('sha-1'),
      ),
    );

    final row = await db.audioItemDao.getById('oc-1');
    expect(row, isNotNull);
    expect(row!.audioPath, isNull);
    expect(row.transcriptPath, isNull);
    expect(row.remoteAudioId, 'r-1');
  });

  test('更新 audioPath 从 null → 非 null（模拟下载完成）', () async {
    final now = DateTime(2026, 4, 19);
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('oc-1'),
        name: const Value('社区占位'),
        addedDate: Value(now),
        updatedAt: Value(now),
        remoteAudioId: const Value('r-1'),
        audioSha256: const Value('sha-1'),
      ),
    );
    await (db.update(db.audioItems)..where((t) => t.id.equals('oc-1'))).write(
      AudioItemsCompanion(
        audioPath: const Value('audios/official/sha-1.m4a'),
        transcriptPath: const Value('transcripts/official_oc-1.srt'),
        updatedAt: Value(now),
      ),
    );

    final row = await db.audioItemDao.getById('oc-1');
    expect(row!.audioPath, 'audios/official/sha-1.m4a');
    expect(row.transcriptPath, 'transcripts/official_oc-1.srt');
  });

  test('is_audio_downloaded 列已不存在（用 raw SQL 查 pragma 验证）', () async {
    final rows = await db.customSelect('PRAGMA table_info(audio_items)').get();
    final names = rows.map((r) => r.data['name'] as String).toSet();
    expect(
      names.contains('is_audio_downloaded'),
      isFalse,
      reason: 'v30 schema 不应再有 is_audio_downloaded 列',
    );
    // audio_path 的 notnull 字段应为 0（nullable）
    final audioPathRow = rows.firstWhere((r) => r.data['name'] == 'audio_path');
    expect(audioPathRow.data['notnull'], 0, reason: 'audio_path 必须 nullable');
  });
}
