/// 全文盲听 用户偏好 Provider（按槽位）
///
/// 「默认值 + 记住用户修改 + 重开回显」的单一真相源,按**槽位**(子阶段 × 轮次)存储,
/// 轮次独立。槽位形如 `blindListen:firstLearn` / `blindListen:review2`。
///
/// 入口弹窗、播放器内 🔧 面板、播放器初始化都按槽位读写**这一份**,无第二份拷贝、
/// 无翻译层、无有损通道。采用手动 Notifier + 启动期 override 注入(对齐
/// [lib/providers/learning_settings_provider.dart])。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/blind_listen_prefs.dart';
import '../models/blind_listen_settings.dart';
import '../models/intensive_listen_settings.dart'
    show PauseMode, ShadowingControlMode;
import '../models/slot_prefs.dart';
import 'slot_prefs_notifier.dart';

export '../models/blind_listen_prefs.dart';

/// 整份偏好表的 SharedPreferences key。
const _spKey = 'blind_listen_prefs_v1';

/// 同步从 SP 预读整份按槽位偏好,供 main() 启动期 override 注入。
SlotPrefs<BlindListenPrefs> blindListenPrefsFromPrefsSync(
  SharedPreferences prefs,
) {
  final raw = prefs.getString(_spKey);
  if (raw == null) return const SlotPrefs.empty();
  try {
    return SlotPrefs.fromJson(json.decode(raw), BlindListenPrefs.fromJson);
  } catch (_) {
    return const SlotPrefs.empty();
  }
}

/// 同步从 SP 预读的偏好初值,由 main() 通过 override 注入(默认空)。
final initialBlindListenPrefsProvider = Provider<SlotPrefs<BlindListenPrefs>>(
  (ref) => const SlotPrefs.empty(),
);

/// 全文盲听 偏好 Notifier(按槽位)。
class BlindListenPrefsNotifier extends SlotPrefsNotifier<BlindListenPrefs> {
  @override
  String get spKey => _spKey;

  @override
  ProviderListenable<SlotPrefs<BlindListenPrefs>> get initialProvider =>
      initialBlindListenPrefsProvider;

  @override
  BlindListenPrefs get emptyPrefs => const BlindListenPrefs.empty();

  @override
  Map<String, dynamic> encodePrefs(BlindListenPrefs prefs) => prefs.toJson();

  @override
  SlotPrefs<BlindListenPrefs> readPrefs(SharedPreferences preferences) =>
      blindListenPrefsFromPrefsSync(preferences);

  /// 按当前难度算出的 [smartSpeed],叠加该槽位偏好得到完整设置。
  BlindListenSettings resolve(String slot, {required double smartSpeed}) =>
      prefsFor(slot).resolve(smartSpeed: smartSpeed);

  /// 目标段长(分段):偏好未设时回退 [smartSeconds]。
  int resolveTargetSeconds(String slot, {required int smartSeconds}) =>
      prefsFor(slot).targetSeconds ?? smartSeconds;

  Future<void> setTargetSeconds(String slot, int value) =>
      updateSlot(slot, prefsFor(slot).copyWith(targetSeconds: value));

  Future<void> setPlaybackSpeed(String slot, double value) =>
      updateSlot(slot, prefsFor(slot).copyWith(playbackSpeed: value));

  Future<void> setPauseMode(String slot, PauseMode value) =>
      updateSlot(slot, prefsFor(slot).copyWith(pauseMode: value));

  Future<void> setFixedPauseSeconds(String slot, int value) =>
      updateSlot(slot, prefsFor(slot).copyWith(fixedPauseSeconds: value));

  Future<void> setPauseMultiplier(String slot, double value) =>
      updateSlot(slot, prefsFor(slot).copyWith(pauseMultiplier: value));

  Future<void> setControlMode(String slot, ShadowingControlMode value) =>
      updateSlot(slot, prefsFor(slot).copyWith(controlMode: value));

  Future<void> setRepeatCount(String slot, int value) =>
      updateSlot(slot, prefsFor(slot).copyWith(repeatCount: value));
}

/// 把 [old]→[next] 的设置改动按槽位写入偏好(只写**真正变化**的字段)。
///
/// 供播放器 🔧 面板 / 入口弹窗复用:每次面板交互只改一个字段,故只会把该字段
/// 从「未设(用默认)」变成具体值,不冻结未碰过的智能默认。
void persistBlindSettingsDiff(
  BlindListenPrefsNotifier notifier,
  String slot,
  BlindListenSettings old,
  BlindListenSettings next,
) {
  if (next.playbackSpeed != old.playbackSpeed) {
    notifier.setPlaybackSpeed(slot, next.playbackSpeed);
  }
  if (next.pauseMode != old.pauseMode) {
    notifier.setPauseMode(slot, next.pauseMode);
  }
  if (next.fixedPauseSeconds != old.fixedPauseSeconds) {
    notifier.setFixedPauseSeconds(slot, next.fixedPauseSeconds);
  }
  if (next.pauseMultiplier != old.pauseMultiplier) {
    notifier.setPauseMultiplier(slot, next.pauseMultiplier);
  }
  if (next.controlMode != old.controlMode) {
    notifier.setControlMode(slot, next.controlMode);
  }
  if (next.repeatCount != old.repeatCount) {
    notifier.setRepeatCount(slot, next.repeatCount);
  }
}

/// 全文盲听 偏好 Provider 入口。
final blindListenPrefsProvider =
    NotifierProvider<BlindListenPrefsNotifier, SlotPrefs<BlindListenPrefs>>(
      BlindListenPrefsNotifier.new,
    );
