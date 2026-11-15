import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/video_subtitle_masks.dart';

part 'video_subtitle_mask_dao.g.dart';

/// 视频字幕遮罩设置 DAO
@DriftAccessor(tables: [VideoSubtitleMasks])
class VideoSubtitleMaskDao extends DatabaseAccessor<AppDatabase>
    with _$VideoSubtitleMaskDaoMixin {
  VideoSubtitleMaskDao(super.db);

  /// 获取指定视频的遮罩设置；用户从未操作过时返回 null。
  Future<VideoSubtitleMaskRecord?> getByAudioId(String audioItemId) {
    return (select(
      videoSubtitleMasks,
    )..where((t) => t.audioItemId.equals(audioItemId))).getSingleOrNull();
  }

  /// 保存遮罩设置（插入或更新）
  Future<void> save(VideoSubtitleMasksCompanion entry) {
    return into(videoSubtitleMasks).insertOnConflictUpdate(entry);
  }
}
