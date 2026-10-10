/// 词典设置 Provider
///
/// 持久化默认词典源与禁用集合（SharedPreferences）。
/// 业务规则集中在此（状态变更单一入口）：
/// ① 只有 `canBeDisabled` 的源才能进禁用集合；
/// ② 禁用当前默认源时，默认源自动回退到注册表中第一个仍启用的源（local 优先）。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../../models/dictionary/dictionary_settings.dart';
import '../../services/dictionary/dictionary_source.dart';
import 'dictionary_registry.dart';

part 'dictionary_settings_provider.g.dart';

const _spKey = 'dictionary_settings';

/// 词典设置 Notifier
@Riverpod(keepAlive: true)
class DictionarySettingsNotifier extends _$DictionarySettingsNotifier {
  @override
  DictionarySettings build() {
    // SharedPreferences 已在 main() 预热并注入，可同步读取——
    // 首次 build 即拿到真实设置，避免「先返缺省 local、再异步加载」的冷启动竞态。
    final prefs = ref.watch(sharedPreferencesProvider);
    final jsonStr = prefs.getString(_spKey);
    if (jsonStr != null) {
      try {
        return DictionarySettings.fromJson(
          json.decode(jsonStr) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('DictionarySettings: 解析失败: $e');
      }
    }
    return DictionarySettings();
  }

  /// 设置默认词典源
  Future<void> setDefault(String id) async {
    if (state.defaultSourceId == id) return;
    await _persist(state.copyWith(defaultSourceId: id));
  }

  /// 设置查词时是否自动播放发音。
  Future<void> setAutoSpeakOnLookup(bool enabled) async {
    if (state.autoSpeakOnLookup == enabled) return;
    await _persist(state.copyWith(autoSpeakOnLookup: enabled));
  }

  /// 设置网页词典广告过滤开关。
  Future<void> setAdFilteringEnabled(bool enabled) async {
    if (state.adFilteringEnabled == enabled) return;
    await _persist(state.copyWith(adFilteringEnabled: enabled));
  }

  /// 启用/禁用某词典源
  ///
  /// 禁用前校验该源 `canBeDisabled`；禁用当前默认源时默认自动回退。
  Future<void> setDisabled(String id, bool disabled) async {
    final sources = ref.read(dictionarySourcesProvider);
    if (disabled) {
      final source = _findById(sources, id);
      if (source == null || !source.canBeDisabled) return; // 规则①
    }

    final next = {...state.disabledIds};
    if (disabled) {
      next.add(id);
    } else {
      next.remove(id);
    }

    var newSettings = state.copyWith(disabledIds: next);

    // 规则②：禁用了当前默认源 → 回退到第一个仍启用的源
    if (disabled && id == state.defaultSourceId) {
      final fallback = sources
          .firstWhere((s) => !next.contains(s.id), orElse: () => sources.first)
          .id;
      newSettings = newSettings.copyWith(defaultSourceId: fallback);
    }

    await _persist(newSettings);
  }

  Future<void> _persist(DictionarySettings settings) async {
    state = settings;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_spKey, json.encode(settings.toJson()));
    } catch (e) {
      debugPrint('DictionarySettings: 保存失败: $e');
    }
  }

  DictionarySource? _findById(List<DictionarySource> sources, String id) {
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }
}
