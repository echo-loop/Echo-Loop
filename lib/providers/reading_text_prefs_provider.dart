/// 学习内容文字偏好 Provider（字号）
///
/// 单一真相源：设置页修改、字幕列表渲染都读写这一份。
/// 启动期从已注入的 SharedPreferences 同步读取，避免首帧先按默认字号渲染再跳变；
/// 未注入时（部分测试环境）回退为异步加载。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../models/reading_text_prefs.dart';
import '../services/app_logger.dart';

export '../models/reading_text_prefs.dart';

part 'reading_text_prefs_provider.g.dart';

/// 字号倍率持久化 key。
const _fontScaleKey = 'reading_font_scale';

const _logTag = 'ReadingTextPrefs';

@riverpod
class ReadingTextPrefsNotifier extends _$ReadingTextPrefsNotifier {
  /// 加载代次：用户修改后作废在途的异步加载，防止旧值覆盖新值。
  int _loadGeneration = 0;

  @override
  ReadingTextPrefs build() {
    final generation = ++_loadGeneration;
    try {
      return _readFromPrefs(ref.read(sharedPreferencesProvider));
    } on UnimplementedError {
      _loadAsync(generation);
      return const ReadingTextPrefs();
    }
  }

  ReadingTextPrefs _readFromPrefs(SharedPreferences prefs) {
    return ReadingTextPrefs.fromStored(scale: prefs.getDouble(_fontScaleKey));
  }

  Future<void> _loadAsync(int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (generation != _loadGeneration) return;
    state = _readFromPrefs(prefs);
  }

  /// 设置字号倍率（吸附到最近档位）并持久化。
  Future<void> setFontScale(double scale) async {
    final snapped = snapReadingFontScale(scale);
    _loadGeneration++;
    state = ReadingTextPrefs(fontScale: snapped);
    AppLogger.log(_logTag, 'setFontScale: $scale → $snapped');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, snapped);
  }
}
