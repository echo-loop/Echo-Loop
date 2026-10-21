/// 提醒设置状态管理 Provider
///
/// 使用 riverpod_generator 生成 keepAlive Notifier，
/// 通过 SharedPreferences 持久化提醒开关和时间设置。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../models/reminder_settings.dart';
import '../services/app_logger.dart';
import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../features/user_preferences/domain/user_preferences_sync_events.dart';

part 'reminder_settings_provider.g.dart';

const _spKey = 'reminder_settings';

/// 提醒设置 Notifier
///
/// `build()` 优先同步读取已初始化的 SP，独立容器下异步回退加载。
/// 外部通过 [update] 更新设置，自动持久化并同步 state。
@Riverpod(keepAlive: true)
class ReminderSettingsNotifier extends _$ReminderSettingsNotifier {
  int _loadGeneration = 0;

  @override
  ReminderSettings build() {
    final generation = ++_loadGeneration;
    try {
      return _readFromPrefs(ref.read(sharedPreferencesProvider));
    } on UnimplementedError {
      _loadFromPreferences(generation);
      return const ReminderSettings();
    }
  }

  ReminderSettings _readFromPrefs(SharedPreferences prefs) {
    final jsonStr = prefs.getString(_spKey);
    if (jsonStr == null) return const ReminderSettings();
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return ReminderSettings.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('ReminderSettings: 加载设置失败: $e');
    }
    return const ReminderSettings();
  }

  /// 云端写回 SharedPreferences 后同步刷新内存状态。
  void reloadFromPrefs() {
    final generation = ++_loadGeneration;
    try {
      state = _readFromPrefs(ref.read(sharedPreferencesProvider));
    } on UnimplementedError {
      _loadFromPreferences(generation);
    }
  }

  Future<void> _loadFromPreferences(int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation == _loadGeneration) state = _readFromPrefs(prefs);
    } catch (error) {
      debugPrint('ReminderSettings: 加载设置失败: $error');
    }
  }

  /// 更新设置并持久化
  Future<void> update(ReminderSettings settings) async {
    _loadGeneration++;
    state = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_spKey, json.encode(settings.toJson()));
      userPreferencesSyncEvents.notifyLocalChange();
      AppLogger.log(
        'ReminderSettings',
        'saved savedEnabled=${settings.savedReviewReminderEnabled} '
            'time=${settings.formattedTime} '
            'perAudioEnabled=${settings.perAudioReminderEnabled}',
      );
    } catch (e) {
      AppLogger.log('ReminderSettings', 'update persist failed error=$e');
      debugPrint('ReminderSettings: 保存设置失败: $e');
    }
    ref.read(analyticsServiceProvider).track(Events.reminderUpdated, {
      EventParams.reminderEnabled: settings.savedReviewReminderEnabled,
      EventParams.reminderTime: settings.formattedTime,
    });
  }
}
