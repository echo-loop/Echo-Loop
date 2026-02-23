import 'package:drift/drift.dart';

import 'audio_items.dart';
import 'tags.dart';

/// 音频-标签关联表（Junction 表）
class AudioItemTags extends Table {
  /// 标签 ID，外键关联 tags.id
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  /// 音频 ID，外键关联 audio_items.id
  TextColumn get audioItemId =>
      text().references(AudioItems, #id, onDelete: KeyAction.cascade)();

  /// 添加时间
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tagId, audioItemId};
}
