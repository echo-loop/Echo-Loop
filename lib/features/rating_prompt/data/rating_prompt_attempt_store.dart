import 'package:shared_preferences/shared_preferences.dart';

/// 保存本机最近一次原生评分请求时间。
///
/// 操作系统不提供用户是否成功提交评价的可靠结果，因此这里记录的是
/// “请求尝试时间”，而非“评价完成时间”。
class RatingPromptAttemptStore {
  /// 创建基于应用偏好设置的请求时间存储。
  RatingPromptAttemptStore(this._preferences);

  static const _lastAttemptKey = 'rating_prompt_last_attempt_ms_v1';

  final SharedPreferences _preferences;

  /// 读取最近一次请求时间；损坏或缺失的数据视为从未请求。
  DateTime? readLastAttempt() {
    final timestamp = _preferences.getInt(_lastAttemptKey);
    if (timestamp == null || timestamp <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// 请求在落盘期间失效且尚未调用系统时，恢复此前的设备冷却。
  Future<bool> restoreAttempt(DateTime? previous) => previous == null
      ? _preferences.remove(_lastAttemptKey)
      : _preferences.setInt(_lastAttemptKey, previous.millisecondsSinceEpoch);

  /// 在调用系统评分 API 之前持久化时间，避免失败或进程中断造成重复请求。
  Future<bool> recordAttempt(DateTime time) =>
      _preferences.setInt(_lastAttemptKey, time.millisecondsSinceEpoch);
}
