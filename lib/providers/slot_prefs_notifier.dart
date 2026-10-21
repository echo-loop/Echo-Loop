/// 「按槽位」偏好 Notifier 基类
///
/// 复用各子阶段 typed 偏好 store 的公共逻辑:按槽位读写并从本地存储重载
/// 偏好并写 SharedPreferences。子类只需提供:SP key、单偏好的编/解码、空偏好,以及
/// 各自的细粒度 setter(在 [updateSlot] 之上拼)。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/slot_prefs.dart';
import '../services/app_logger.dart';
import '../features/user_preferences/domain/user_preferences_sync_events.dart';
import 'learning_settings_provider.dart' show sharedPreferencesProvider;

/// 按槽位偏好 Notifier 基类。[P] 为单槽位偏好(全字段可空、值相等)。
abstract class SlotPrefsNotifier<P> extends Notifier<SlotPrefs<P>> {
  /// 整份偏好表的 SharedPreferences key。
  String get spKey;

  /// 无 app 级 SharedPreferences override 时使用的启动初值。
  ProviderListenable<SlotPrefs<P>> get initialProvider;

  /// 该子阶段的空偏好(全 null)。
  P get emptyPrefs;

  /// 单槽位偏好 → JSON。
  Map<String, dynamic> encodePrefs(P prefs);

  /// 从当前 SharedPreferences 读取整份偏好。
  SlotPrefs<P> loadFromPrefs() {
    try {
      return readPrefs(ref.read(sharedPreferencesProvider));
    } on UnimplementedError {
      return ref.read(initialProvider);
    }
  }

  SlotPrefs<P> readPrefs(SharedPreferences preferences);

  @override
  SlotPrefs<P> build() => loadFromPrefs();

  /// 云端写回 SharedPreferences 后同步刷新内存状态。
  void reloadFromPrefs() => state = loadFromPrefs();

  /// 取某槽位偏好(无则空偏好)。
  P prefsFor(String slot) => state.maybe(slot) ?? emptyPrefs;

  /// 更新某槽位偏好并写盘;值未变化时跳过。
  Future<void> updateSlot(String slot, P next) async {
    if (state.maybe(slot) == next) return;
    state = state.withSlot(slot, next);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(spKey, json.encode(state.toJson(encodePrefs)));
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (e) {
      AppLogger.log('SlotPrefs', '写 SP 失败 key=$spKey: $e');
    }
  }
}
