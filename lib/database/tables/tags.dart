import 'package:drift/drift.dart';

/// 标签表
class Tags extends Table {
  /// UUID 主键
  TextColumn get id => text()();

  /// 标签名称
  TextColumn get name => text()();

  /// 标签颜色值（存储 Flutter Color.value）
  IntColumn get color => integer()();

  /// 创建时间
  DateTimeColumn get createdDate => dateTime()();

  /// 最后修改时间
  DateTimeColumn get updatedAt => dateTime()();

  /// 软删除标记
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 同步状态
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
