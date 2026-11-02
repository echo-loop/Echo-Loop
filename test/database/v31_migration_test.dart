import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// v31 schema 基线行为验证：
/// - `audio_items.original_date` 列存在且可空
/// - 插入时不写 originalDate → 默认 null
/// - 写入 DateTime 后可读回相同值
///
/// 升级路径（v30→v31 ALTER TABLE ADD COLUMN）依赖 Drift 的 customStatement，
/// 真实升级过程不在此测试覆盖（需要 schema snapshot 基础设施）。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
  });

  tearDown(() async {
    await db.close();
  });

  test('插入 originalDate=null 不报错，读回仍是 null', () async {
    final now = DateTime(2026, 4, 20);
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('a1'),
        name: const Value('用户自建'),
        addedDate: Value(now),
        updatedAt: Value(now),
      ),
    );
    final row = await db.audioItemDao.getById('a1');
    expect(row, isNotNull);
    expect(row!.originalDate, isNull);
  });

  test('写入 originalDate 后可读回相同时间点', () async {
    final now = DateTime(2026, 4, 20);
    final original = DateTime.utc(2020, 5, 1);
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('a2'),
        name: const Value('VOA'),
        addedDate: Value(now),
        updatedAt: Value(now),
        remoteAudioId: const Value('r-1'),
        originalDate: Value(original),
      ),
    );
    final row = await db.audioItemDao.getById('a2');
    // Drift 存 unix 秒，读回变本地时区，但代表同一时刻
    expect(row!.originalDate!.toUtc(), original);
  });

  test('pragma table_info 包含 original_date 且 nullable', () async {
    final rows = await db.customSelect('PRAGMA table_info(audio_items)').get();
    final byName = {for (final r in rows) r.data['name'] as String: r.data};
    expect(
      byName.containsKey('original_date'),
      isTrue,
      reason: 'v31 schema 必须包含 original_date 列',
    );
    expect(
      byName['original_date']!['notnull'],
      0,
      reason: 'original_date 必须 nullable',
    );
  });
}
