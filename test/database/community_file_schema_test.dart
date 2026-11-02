import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// 社区文件不可用状态的 schema 契约测试。
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
  });

  tearDown(() async {
    await database.close();
  });

  test('community_unavailable_at 可为空并能持久化时间', () async {
    final unavailableAt = DateTime(2026, 9, 22);
    await database.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('audio-1'),
        name: const Value('Community file'),
        addedDate: Value(unavailableAt),
        updatedAt: Value(unavailableAt),
        communityUnavailableAt: Value(unavailableAt),
      ),
    );

    final row = await database.audioItemDao.getById('audio-1');
    expect(row?.communityUnavailableAt, unavailableAt);

    final columns = await database
        .customSelect('PRAGMA table_info(audio_items)')
        .get();
    final unavailableColumn = columns.firstWhere(
      (column) => column.data['name'] == 'community_unavailable_at',
    );
    expect(unavailableColumn.data['notnull'], 0);
  });
}
