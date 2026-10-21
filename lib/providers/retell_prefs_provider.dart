/// 段落复述 用户偏好 Provider（按槽位）
///
/// 「默认值 + 记住用户修改 + 重开回显」的单一真相源,按槽位(retell × 轮次)存储、轮次独立。
/// 入口弹窗、播放器内 🔧 面板、播放器初始化都按槽位读写这一份。仿
/// [intensive_listen_prefs_provider.dart]。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/intensive_listen_settings.dart'
    show PauseMode, ShadowingControlMode;
import '../models/retell_prefs.dart';
import '../models/retell_settings.dart';
import '../models/slot_prefs.dart';
import 'slot_prefs_notifier.dart';

export '../models/retell_prefs.dart';

/// 整份偏好表的 SharedPreferences key。
const _spKey = 'retell_prefs_v1';

/// 同步从 SP 预读整份按槽位偏好,供 main() 启动期 override 注入。
SlotPrefs<RetellPrefs> retellPrefsFromPrefsSync(SharedPreferences prefs) {
  final raw = prefs.getString(_spKey);
  if (raw == null) return const SlotPrefs.empty();
  try {
    return SlotPrefs.fromJson(json.decode(raw), RetellPrefs.fromJson);
  } catch (_) {
    return const SlotPrefs.empty();
  }
}

/// 同步从 SP 预读的偏好初值,由 main() 通过 override 注入(默认空)。
final initialRetellPrefsProvider = Provider<SlotPrefs<RetellPrefs>>(
  (ref) => const SlotPrefs.empty(),
);

/// 段落复述 偏好 Notifier(按槽位)。
class RetellPrefsNotifier extends SlotPrefsNotifier<RetellPrefs> {
  @override
  String get spKey => _spKey;

  @override
  ProviderListenable<SlotPrefs<RetellPrefs>> get initialProvider =>
      initialRetellPrefsProvider;

  @override
  RetellPrefs get emptyPrefs => const RetellPrefs.empty();

  @override
  Map<String, dynamic> encodePrefs(RetellPrefs prefs) => prefs.toJson();

  @override
  SlotPrefs<RetellPrefs> readPrefs(SharedPreferences preferences) =>
      retellPrefsFromPrefsSync(preferences);

  /// 按当前难度算出的 [smartSpeed]/[smartRatio],叠加该槽位偏好得到完整设置。
  RetellSettings resolve(
    String slot, {
    required double smartSpeed,
    required KeywordRatio smartRatio,
  }) => prefsFor(slot).resolve(smartSpeed: smartSpeed, smartRatio: smartRatio);

  /// 目标段长:偏好未设时回退 [smartSeconds]。
  int resolveTargetSeconds(String slot, {required int smartSeconds}) =>
      prefsFor(slot).targetSeconds ?? smartSeconds;

  Future<void> setPlaybackSpeed(String slot, double value) =>
      updateSlot(slot, prefsFor(slot).copyWith(playbackSpeed: value));

  Future<void> setPauseMode(String slot, PauseMode value) =>
      updateSlot(slot, prefsFor(slot).copyWith(pauseMode: value));

  Future<void> setFixedPauseSeconds(String slot, int value) =>
      updateSlot(slot, prefsFor(slot).copyWith(fixedPauseSeconds: value));

  Future<void> setPauseMultiplier(String slot, double value) =>
      updateSlot(slot, prefsFor(slot).copyWith(pauseMultiplier: value));

  Future<void> setKeywordMethod(String slot, KeywordMethod value) =>
      updateSlot(slot, prefsFor(slot).copyWith(keywordMethod: value));

  Future<void> setKeywordRatio(String slot, KeywordRatio value) =>
      updateSlot(slot, prefsFor(slot).copyWith(keywordRatio: value));

  Future<void> setControlMode(String slot, ShadowingControlMode value) =>
      updateSlot(slot, prefsFor(slot).copyWith(controlMode: value));

  Future<void> setRepeatCount(String slot, int value) =>
      updateSlot(slot, prefsFor(slot).copyWith(repeatCount: value));

  Future<void> setTargetSeconds(String slot, int value) =>
      updateSlot(slot, prefsFor(slot).copyWith(targetSeconds: value));
}

/// 把 [old]→[next] 的复述设置改动按槽位写入偏好(只写真正变化的字段)。
///
/// 不含 autoPlayRecordingAfterCompletion(走全局学习设置)。
void persistRetellSettingsDiff(
  RetellPrefsNotifier notifier,
  String slot,
  RetellSettings old,
  RetellSettings next,
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
  if (next.keywordMethod != old.keywordMethod) {
    notifier.setKeywordMethod(slot, next.keywordMethod);
  }
  if (next.keywordRatio != old.keywordRatio) {
    notifier.setKeywordRatio(slot, next.keywordRatio);
  }
  if (next.controlMode != old.controlMode) {
    notifier.setControlMode(slot, next.controlMode);
  }
  if (next.repeatCount != old.repeatCount) {
    notifier.setRepeatCount(slot, next.repeatCount);
  }
}

/// 段落复述 偏好 Provider 入口。
final retellPrefsProvider =
    NotifierProvider<RetellPrefsNotifier, SlotPrefs<RetellPrefs>>(
      RetellPrefsNotifier.new,
    );
