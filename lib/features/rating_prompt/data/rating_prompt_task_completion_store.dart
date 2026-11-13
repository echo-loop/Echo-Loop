import 'package:shared_preferences/shared_preferences.dart';

/// 保存本机最近一次正常完成学习任务的时间。
///
/// 只记录时间，不记录任务类型：评分提醒只关心“刚刚是否完成过任务”。
/// 存在本机偏好里，备份恢复时会被跳过（`rating_prompt_` 前缀）。
class RatingPromptTaskCompletionStore {
  /// 创建基于应用偏好设置的任务完成时间存储。
  RatingPromptTaskCompletionStore(this._preferences);

  static const _lastCompletedKey = 'rating_prompt_last_task_completed_ms_v1';

  final SharedPreferences _preferences;

  /// 读取最近一次任务完成时间；缺失或损坏时视为没有完成记录。
  DateTime? readLastCompletedAt() {
    final timestamp = _preferences.getInt(_lastCompletedKey);
    if (timestamp == null || timestamp <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// 记录一次正常完成的任务。
  Future<bool> recordCompletion(DateTime time) =>
      _preferences.setInt(_lastCompletedKey, time.millisecondsSinceEpoch);
}
