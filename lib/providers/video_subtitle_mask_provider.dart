import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/providers.dart';
import '../models/video_subtitle_mask.dart';
import '../services/app_logger.dart';

export '../models/video_subtitle_mask.dart';

const _logTag = 'VideoSubtitleMask';

/// 按视频记住的字幕遮罩设置。
///
/// 数据库是唯一持久化来源：没有记录时视为“关闭 + 底部居中默认位置”，只有
/// 用户开关或调整遮罩时才写入。同一视频的随心听、学习任务与句子讲解页共用
/// 同一个实例；离开所有页面后释放，下次进入重新从数据库读取。
final videoSubtitleMaskProvider = AsyncNotifierProvider.autoDispose
    .family<VideoSubtitleMaskNotifier, VideoSubtitleMask, String>(
      VideoSubtitleMaskNotifier.new,
    );

class VideoSubtitleMaskNotifier extends AsyncNotifier<VideoSubtitleMask> {
  VideoSubtitleMaskNotifier(this.audioItemId);

  final String audioItemId;

  /// 保存序号：只有最近一次保存失败时才回退，避免旧请求覆盖新状态。
  int _saveGeneration = 0;

  @override
  Future<VideoSubtitleMask> build() async {
    try {
      // watch：切换数据库（演示模式、恢复备份）后重新读取，不再写入旧库。
      final record = await ref
          .watch(videoSubtitleMaskDaoProvider)
          .getByAudioId(audioItemId);
      if (record == null) return const VideoSubtitleMask();
      final values = [
        record.rectLeft,
        record.rectTop,
        record.rectWidth,
        record.rectHeight,
      ];
      // 非有限数值会让布局出错；保留开关状态，位置回退到默认值。
      if (!values.every((value) => value.isFinite)) {
        AppLogger.log(
          _logTag,
          '✗ 遮罩位置数据非法，使用默认位置 audio=$audioItemId values=$values',
        );
        return VideoSubtitleMask(enabled: record.enabled);
      }
      return VideoSubtitleMask(
        enabled: record.enabled,
        rect: VideoSubtitleMask.clampRect(
          Rect.fromLTWH(
            record.rectLeft,
            record.rectTop,
            record.rectWidth,
            record.rectHeight,
          ),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        _logTag,
        '✗ 读取遮罩设置失败 audio=$audioItemId: $error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> toggleEnabled() =>
      _save((current) => current.copyWith(enabled: !current.enabled));

  /// 提交拖动 / 缩放后的位置（归一化坐标）。
  Future<void> setRect(Rect rect) => _save(
    (current) => current.copyWith(rect: VideoSubtitleMask.clampRect(rect)),
  );

  /// 先更新界面再写库。
  ///
  /// 这里是用户操作的处理边界（调用方以 unawaited 触发）：写库失败时回退到
  /// 修改前的状态并记录日志，不再向外抛出，避免成为未处理的异步异常。
  Future<void> _save(
    VideoSubtitleMask Function(VideoSubtitleMask current) update,
  ) async {
    final current = state.value;
    // 尚未读出已保存的设置时不接受修改，避免用默认值覆盖用户记录。
    if (current == null) return;
    final next = update(current);
    if (next == current) return;
    final generation = ++_saveGeneration;
    state = AsyncData(next);
    try {
      await ref
          .read(videoSubtitleMaskDaoProvider)
          .save(
            VideoSubtitleMasksCompanion.insert(
              audioItemId: audioItemId,
              enabled: next.enabled,
              rectLeft: next.rect.left,
              rectTop: next.rect.top,
              rectWidth: next.rect.width,
              rectHeight: next.rect.height,
              updatedAt: DateTime.now(),
            ),
          );
      AppLogger.log(
        _logTag,
        'save audio=$audioItemId enabled=${next.enabled} '
        'rect=${next.rect.left.toStringAsFixed(3)},'
        '${next.rect.top.toStringAsFixed(3)},'
        '${next.rect.width.toStringAsFixed(3)}x'
        '${next.rect.height.toStringAsFixed(3)}',
      );
    } catch (error, stackTrace) {
      final isLatestSave = generation == _saveGeneration;
      if (ref.mounted && isLatestSave) state = AsyncData(current);
      AppLogger.log(
        _logTag,
        '✗ 保存遮罩设置失败 audio=$audioItemId reverted=$isLatestSave: '
        '$error\n$stackTrace',
      );
    }
  }
}
