import 'dart:async';

/// 用户偏好写入本地后的进程内通知。
///
/// 同步服务合并通知后再读取完整快照。云端回写直接更新 SharedPreferences，
/// 不会触发此事件，因此不会形成同步回环。
class UserPreferencesSyncEvents {
  final StreamController<void> _controller = StreamController<void>.broadcast(
    sync: true,
  );

  Stream<void> get changes => _controller.stream;

  void notifyLocalChange() => _controller.add(null);
}

final userPreferencesSyncEvents = UserPreferencesSyncEvents();
