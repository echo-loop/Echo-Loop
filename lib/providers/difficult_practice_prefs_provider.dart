/// 难句补练 / 收藏句复习 用户偏好 Provider（按槽位）
///
/// 「默认值 + 记住用户修改 + 重开回显」的单一真相源,按**槽位**(子阶段 × 轮次)存储,
/// 轮次独立。难句补练与收藏句复习共用 [DifficultPracticeSettings] 模型,故共用本 store——
/// 难句补练用槽位 `reviewDifficultPractice:<轮次>`,收藏句复习用固定槽位
/// `bookmarkReview:none`(不绑复习轮次)。
///
/// 入口弹窗、播放器内 🔧 面板、播放器初始化都按槽位读写**这一份**,无第二份拷贝、
/// 无翻译层、无有损通道。采用手动 Notifier + 启动期 override 注入(对齐
/// [lib/providers/intensive_listen_prefs_provider.dart])。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/difficult_practice_prefs.dart';
import '../models/difficult_practice_settings.dart';
import '../models/intensive_listen_settings.dart';
import '../models/slot_prefs.dart';
import 'slot_prefs_notifier.dart';

export '../models/difficult_practice_prefs.dart';

/// 整份偏好表的 SharedPreferences key。
const _spKey = 'difficult_practice_prefs_v1';

/// 同步从 SP 预读整份按槽位偏好,供 main() 启动期 override 注入。
SlotPrefs<DifficultPracticePrefs> difficultPracticePrefsFromPrefsSync(
  SharedPreferences prefs,
) {
  final raw = prefs.getString(_spKey);
  if (raw == null) return const SlotPrefs.empty();
  try {
    return SlotPrefs.fromJson(
      json.decode(raw),
      DifficultPracticePrefs.fromJson,
    );
  } catch (_) {
    return const SlotPrefs.empty();
  }
}

/// 同步从 SP 预读的偏好初值,由 main() 通过 override 注入(默认空)。
final initialDifficultPracticePrefsProvider =
    Provider<SlotPrefs<DifficultPracticePrefs>>(
      (ref) => const SlotPrefs.empty(),
    );

/// 难句补练 / 收藏句复习 偏好 Notifier(按槽位)。
class DifficultPracticePrefsNotifier
    extends SlotPrefsNotifier<DifficultPracticePrefs> {
  @override
  String get spKey => _spKey;

  @override
  ProviderListenable<SlotPrefs<DifficultPracticePrefs>> get initialProvider =>
      initialDifficultPracticePrefsProvider;

  @override
  DifficultPracticePrefs get emptyPrefs => const DifficultPracticePrefs.empty();

  @override
  Map<String, dynamic> encodePrefs(DifficultPracticePrefs prefs) =>
      prefs.toJson();

  @override
  SlotPrefs<DifficultPracticePrefs> readPrefs(SharedPreferences preferences) =>
      difficultPracticePrefsFromPrefsSync(preferences);

  /// 按当前难度算出的 [smartSpeed],叠加该槽位偏好得到完整设置。
  DifficultPracticeSettings resolve(
    String slot, {
    required double smartSpeed,
  }) => prefsFor(slot).resolve(smartSpeed: smartSpeed);

  Future<void> setControlMode(String slot, ShadowingControlMode value) =>
      updateSlot(slot, prefsFor(slot).copyWith(controlMode: value));

  Future<void> setBlindListenRepeatCount(String slot, int value) =>
      updateSlot(slot, prefsFor(slot).copyWith(blindListenRepeatCount: value));

  Future<void> setShadowReadingRepeatCount(String slot, int value) =>
      updateSlot(
        slot,
        prefsFor(slot).copyWith(shadowReadingRepeatCount: value),
      );

  Future<void> setPauseMode(String slot, PauseMode value) =>
      updateSlot(slot, prefsFor(slot).copyWith(pauseMode: value));

  Future<void> setFixedPauseSeconds(String slot, int value) =>
      updateSlot(slot, prefsFor(slot).copyWith(fixedPauseSeconds: value));

  Future<void> setPauseMultiplier(String slot, double value) =>
      updateSlot(slot, prefsFor(slot).copyWith(pauseMultiplier: value));

  Future<void> setPlaybackSpeed(String slot, double value) =>
      updateSlot(slot, prefsFor(slot).copyWith(playbackSpeed: value));
}

/// 把 [old]→[next] 的设置改动按槽位写入偏好(只写**真正变化**的字段)。
///
/// 供入口弹窗 / 播放器 🔧 面板复用:每次交互只改一个字段,故只会把该字段
/// 从「未设(用默认)」变成具体值,不冻结未碰过的智能默认。
void persistDifficultSettingsDiff(
  DifficultPracticePrefsNotifier notifier,
  String slot,
  DifficultPracticeSettings old,
  DifficultPracticeSettings next,
) {
  if (next.controlMode != old.controlMode) {
    notifier.setControlMode(slot, next.controlMode);
  }
  if (next.blindListenRepeatCount != old.blindListenRepeatCount) {
    notifier.setBlindListenRepeatCount(slot, next.blindListenRepeatCount);
  }
  if (next.shadowReadingRepeatCount != old.shadowReadingRepeatCount) {
    notifier.setShadowReadingRepeatCount(slot, next.shadowReadingRepeatCount);
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
  if (next.playbackSpeed != old.playbackSpeed) {
    notifier.setPlaybackSpeed(slot, next.playbackSpeed);
  }
}

/// 难句补练 / 收藏句复习 偏好 Provider 入口。
final difficultPracticePrefsProvider =
    NotifierProvider<
      DifficultPracticePrefsNotifier,
      SlotPrefs<DifficultPracticePrefs>
    >(DifficultPracticePrefsNotifier.new);
