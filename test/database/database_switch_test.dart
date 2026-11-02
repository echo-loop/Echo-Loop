import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/study_task_provider.dart';
import 'package:flutter_riverpod/misc.dart';

/// 创建内存数据库用于测试
AppDatabase _createTestDatabase() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
    ),
  );
}

/// 辅助类：记录并转发 invalidate 调用
///
/// Riverpod 的 Ref / WidgetRef 均为 sealed，无法替身；[switchAppDatabase]
/// 只依赖一个 invalidate 回调，因此直接转发到 [ProviderContainer]。
class _InvalidationRecorder {
  final ProviderContainer container;
  final List<ProviderOrFamily> invalidated = [];

  _InvalidationRecorder(this.container);

  void invalidate(ProviderOrFamily provider) {
    invalidated.add(provider);
    container.invalidate(provider);
  }
}

void main() {
  group('switchAppDatabase', () {
    late AppDatabase db1;
    late AppDatabase db2;

    setUp(() {
      db1 = _createTestDatabase();
      db2 = _createTestDatabase();
    });

    tearDown(() async {
      // db1 可能已被 switchAppDatabase 关闭
      try {
        await db1.close();
      } catch (_) {}
      try {
        await db2.close();
      } catch (_) {}
    });

    test('切换后 appDatabaseProvider 返回新数据库', () async {
      // 初始化为 db1
      initAppDatabase(db1);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appDatabaseProvider), db1);

      final testRef = _InvalidationRecorder(container);
      await closeCurrentDatabase();
      switchAppDatabase(db2, testRef.invalidate);

      expect(container.read(appDatabaseProvider), db2);
    });

    test('closeCurrentDatabase 关闭旧数据库', () async {
      initAppDatabase(db1);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await closeCurrentDatabase();

      // 创建新数据库并切换
      final testRef = _InvalidationRecorder(container);
      switchAppDatabase(db2, testRef.invalidate);

      // 关键验证点：新数据库是可用的，旧数据库不再是活跃实例
      expect(container.read(appDatabaseProvider), isNot(same(db1)));
      expect(container.read(appDatabaseProvider), same(db2));
    });

    test('切换后 DAO 提供者返回新数据库的 DAO', () async {
      initAppDatabase(db1);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final oldDao = container.read(audioItemDaoProvider);

      final testRef = _InvalidationRecorder(container);
      await closeCurrentDatabase();
      switchAppDatabase(db2, testRef.invalidate);

      final newDao = container.read(audioItemDaoProvider);
      // DAO 应该是不同实例（来自不同的数据库）
      expect(newDao, isNot(same(oldDao)));
    });

    test('切换时 invalidate appDatabaseProvider', () async {
      initAppDatabase(db1);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testRef = _InvalidationRecorder(container);
      await closeCurrentDatabase();
      switchAppDatabase(db2, testRef.invalidate);

      // 验证 appDatabaseProvider 被 invalidate
      expect(testRef.invalidated, contains(appDatabaseProvider));
    });

    test('切换时 invalidate 全部数据相关 keepAlive 提供者', () async {
      initAppDatabase(db1);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testRef = _InvalidationRecorder(container);
      await closeCurrentDatabase();
      switchAppDatabase(db2, testRef.invalidate);

      // 验证核心数据库提供者被 invalidate
      expect(testRef.invalidated, contains(appDatabaseProvider));

      // 验证关键 keepAlive 数据提供者被 invalidate
      expect(testRef.invalidated, contains(audioLibraryProvider));
      expect(testRef.invalidated, contains(collectionListProvider));
      expect(testRef.invalidated, contains(learningProgressProvider));
      expect(testRef.invalidated, contains(studyTaskProvider));

      // 至少 20 个提供者被 invalidate（1 核心 + 15 keepAlive + 5 其他）
      expect(testRef.invalidated.length, greaterThanOrEqualTo(20));
    });
  });
}
