import 'package:drift/drift.dart';

import 'audio_items.dart';

/// 视频字幕遮罩设置表（按视频记住开关、位置与大小）。
///
/// 只在用户操作遮罩（开关、拖动、调整大小）后才写入；没有记录即视为“关闭 +
/// 底部居中默认位置”，导入视频时不预建记录。随视频删除级联清理，只存本机。
@DataClassName('VideoSubtitleMaskRecord')
class VideoSubtitleMasks extends Table {
  /// 视频 ID，主键 + 外键关联 audio_items.id
  TextColumn get audioItemId =>
      text().references(AudioItems, #id, onDelete: KeyAction.cascade)();

  /// 遮罩是否开启
  BoolColumn get enabled => boolean()();

  /// 遮罩位置与大小：相对去黑边后实际画面的归一化坐标（0~1）
  RealColumn get rectLeft => real()();
  RealColumn get rectTop => real()();
  RealColumn get rectWidth => real()();
  RealColumn get rectHeight => real()();

  /// 最近一次用户修改时间
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {audioItemId};
}
