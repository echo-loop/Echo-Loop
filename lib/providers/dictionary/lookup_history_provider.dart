/// 手动查词历史 Provider
///
/// 历史存于 Drift，与词表互不依赖：退出查词页释放词表后历史仍保留。
/// 手写而非 `@Riverpod` 生成，原因同 [SavedWordList]：生成器无法解析 drift 数据类。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart' as db;
import '../../database/providers.dart';

/// 最近查询列表（最多 20 条，最近优先；上限由 DAO 的 watchRecent 保证）
final lookupHistoryProvider =
    StreamProvider.autoDispose<List<db.LookupHistory>>(
      (ref) => ref.watch(lookupHistoryDaoProvider).watchRecent(),
    );
