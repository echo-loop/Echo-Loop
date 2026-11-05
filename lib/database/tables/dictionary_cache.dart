import 'package:drift/drift.dart';

/// 在线词典查词缓存表
///
/// 按 (dict, word) 缓存后端 `/api/v1/dictionary/{dict}` 返回的词条 JSON 原文。
/// 只存 API 原文，解析在读取时进行：后端新增字段不会影响已缓存的旧行。
/// 词典数据近乎静态，不设过期时间；用户清除缓存时整表清空，随后按需重建。
class DictionaryCache extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 词典 ID（如 `en_zh-CN`），与母语一一对应
  TextColumn get dict => text()();

  /// 归一化后的查询键，与后端查询参数口径一致
  TextColumn get word => text()();

  /// 词条 JSON 原文
  TextColumn get data => text()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {dict, word},
  ];
}
