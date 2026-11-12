import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/lookup_histories.dart';

part 'lookup_history_dao.g.dart';

/// 手动查词历史 DAO
///
/// 写入时在同一事务内完成去重刷新与超量裁剪，保证任何时刻表内不超过上限。
@DriftAccessor(tables: [LookupHistories])
class LookupHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$LookupHistoryDaoMixin {
  LookupHistoryDao(super.db);

  /// 监听最近查询（按查询时间倒序，最多 [kLookupHistoryLimit] 条）。
  Stream<List<LookupHistory>> watchRecent() {
    return (select(lookupHistories)
          ..orderBy([
            (t) => OrderingTerm.desc(t.lookedUpAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(kLookupHistoryLimit))
        .watch();
  }

  /// 记录一次成功查询：同词只刷新时间，超出上限的最旧记录被删除。
  Future<void> record(String word, DateTime lookedUpAt) {
    return transaction(() async {
      await into(lookupHistories).insert(
        LookupHistoriesCompanion.insert(word: word, lookedUpAt: lookedUpAt),
        onConflict: DoUpdate(
          (old) => LookupHistoriesCompanion(lookedUpAt: Value(lookedUpAt)),
          target: [lookupHistories.word],
        ),
      );
      final keptIds =
          await (selectOnly(lookupHistories)
                ..addColumns([lookupHistories.id])
                ..orderBy([
                  OrderingTerm.desc(lookupHistories.lookedUpAt),
                  OrderingTerm.desc(lookupHistories.id),
                ])
                ..limit(kLookupHistoryLimit))
              .map((row) => row.read(lookupHistories.id)!)
              .get();
      await (delete(lookupHistories)..where((t) => t.id.isNotIn(keptIds))).go();
    });
  }

  /// 清空全部查询历史。
  Future<void> clear() => delete(lookupHistories).go();
}
