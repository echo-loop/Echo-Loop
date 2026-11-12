import 'package:drift/drift.dart';

/// 手动查词历史表
///
/// 记录查词页内成功打开的有效词条，最近查询优先，最多保留 [kLookupHistoryLimit] 条。
/// 与本地词表完全独立：历史不依赖词表是否加载，也不参与收藏或云同步。
class LookupHistories extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 归一化后的查询词（小写），同一词只保留一条
  TextColumn get word => text().unique()();

  /// 最近一次成功查询的时间
  DateTimeColumn get lookedUpAt => dateTime()();
}

/// 查词历史保留条数上限
const kLookupHistoryLimit = 20;
