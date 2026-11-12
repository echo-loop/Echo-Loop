/// 学习内容文字偏好 Provider（字号、粗细）
///
/// 单一真相源：设置页修改、字幕列表渲染都读写这一份。
/// 启动期从已注入的 SharedPreferences 同步读取，避免首帧先按默认字号渲染再跳变；
/// 未注入时（部分测试环境）回退为异步加载。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/provider_override_error.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../features/user_preferences/domain/user_preferences_sync_events.dart';
import '../models/subtitle_text_prefs.dart';
import '../services/app_logger.dart';

export '../models/subtitle_text_prefs.dart';

part 'subtitle_text_prefs_provider.g.dart';

/// 字号倍率持久化 key（同时是云端偏好快照的写回入口，见 LocalUserPreferencesStore）。
const subtitleFontSizePercentKey = 'subtitle_font_size_percent';

/// 字重百分比持久化 key（整数，如 100 表示 100%）。
const subtitleFontWeightPercentKey = 'subtitle_font_weight_percent';

const _logTag = 'SubtitleTextPrefs';

@riverpod
class SubtitleTextPrefsNotifier extends _$SubtitleTextPrefsNotifier {
  /// 加载代次：用户修改后作废在途的异步加载，防止旧值覆盖新值。
  int _loadGeneration = 0;

  @override
  SubtitleTextPrefs build() {
    final generation = ++_loadGeneration;
    try {
      return _readFromPrefs(ref.read(sharedPreferencesProvider));
    } catch (error) {
      if (!isProviderNotOverriddenError(error)) rethrow;
      _loadAsync(generation);
      return const SubtitleTextPrefs();
    }
  }

  SubtitleTextPrefs _readFromPrefs(SharedPreferences prefs) {
    return SubtitleTextPrefs.fromStored(
      fontSizePercent: prefs.getInt(subtitleFontSizePercentKey),
      fontWeightPercent: prefs.getInt(subtitleFontWeightPercentKey),
    );
  }

  Future<void> _loadAsync(int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (generation != _loadGeneration || !ref.mounted) return;
    state = _readFromPrefs(prefs);
  }

  /// 设置字号百分比（吸附到最近档位）并持久化。
  Future<void> setFontSizePercent(int percent) async {
    final snapped = snapSubtitleFontSizePercent(percent);
    _loadGeneration++;
    state = SubtitleTextPrefs(
      fontSizePercent: snapped,
      fontWeightPercent: state.fontWeightPercent,
    );
    AppLogger.log(_logTag, 'setFontSizePercent: $percent → $snapped');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(subtitleFontSizePercentKey, snapped);
    userPreferencesSyncEvents.notifyLocalChange();
  }

  /// 设置字重百分比（吸附到最近档位）并持久化。
  Future<void> setFontWeightPercent(int percent) async {
    final snapped = snapSubtitleFontWeightPercent(percent);
    _loadGeneration++;
    state = SubtitleTextPrefs(
      fontSizePercent: state.fontSizePercent,
      fontWeightPercent: snapped,
    );
    AppLogger.log(_logTag, 'setFontWeightPercent: $percent → $snapped');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(subtitleFontWeightPercentKey, snapped);
    userPreferencesSyncEvents.notifyLocalChange();
  }
}
