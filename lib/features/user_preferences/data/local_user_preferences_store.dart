import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/bookmark_review_settings.dart';
import '../../../models/dictionary/dictionary_settings.dart';
import '../../../models/favorite_review_settings.dart';
import '../../../models/reminder_settings.dart';
import '../../../providers/learning_settings_provider.dart';
import '../domain/user_preferences_document.dart';

/// 将当前仍使用的用户偏好映射到同步文档；设备/开发状态不在此白名单中。
class LocalUserPreferencesStore {
  LocalUserPreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  static const syncMetadataKey = 'user_preferences_sync_state_v1';

  static const _practiceKeys = <String, String>{
    'intensiveListen': 'intensive_listen_prefs_v2',
    'blindListen': 'blind_listen_prefs_v1',
    'retell': 'retell_prefs_v1',
    'difficultPractice': 'difficult_practice_prefs_v1',
  };

  static const _learningDefaults = <String, bool>{
    LearningSettingsKeys.autoSkipRetell: false,
    LearningSettingsKeys.autoExpandCachedAnnotation: true,
    LearningSettingsKeys.autoShowAiExplanation: true,
    LearningSettingsKeys.autoShowAiAnalysis: true,
    LearningSettingsKeys.autoShowAiTranslation: true,
    LearningSettingsKeys.autoShowAiSenseGroups: false,
    LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: false,
    LearningSettingsKeys.listenAndRepeatRatingEnabled: true,
    LearningSettingsKeys.retellRatingEnabled: true,
  };

  UserPreferencesDocument capture() {
    final appearance = <String, Object?>{
      'themeMode': _preferences.getString('theme_mode') ?? 'system',
      'locale': _preferences.getString('locale') ?? 'system',
      'nativeLanguage': _preferences.getString('native_language') ?? 'zh-CN',
    };
    final learning = <String, Object?>{
      for (final entry in _learningDefaults.entries)
        _learningFieldName(entry.key):
            _preferences.getBool(entry.key) ?? entry.value,
    };
    final storedThreshold = _preferences.getInt('silence_threshold_seconds');
    final playback = <String, Object?>{
      'skipSilenceEnabled':
          _preferences.getBool('skip_silence_enabled') ?? true,
      'silenceThresholdSeconds': (storedThreshold ?? 2).clamp(1, 10),
      'wordHighlightEnabled':
          _preferences.getBool('word_highlight_enabled') ?? true,
      'aiTranscriptionAutoMergeEnabled':
          _preferences.getBool('ai_transcription_auto_merge_enabled') ?? true,
    };

    final practice = <String, Object?>{
      for (final entry in _practiceKeys.entries)
        entry.key: _readJsonObject(_preferences.getString(entry.value)),
    };
    final review = <String, Object?>{
      'bookmark': _readJsonObject(
        _preferences.getString('bookmark_review_settings_v1'),
        fallback: const BookmarkReviewSettings().toJson(),
      ),
      'favorites': _readJsonObject(
        _preferences.getString('favorite_review_settings_v1') ??
            _preferences.getString('bookmark_review_settings_v1') ??
            _preferences.getString('favorite_vocabulary_review_settings_v1'),
        fallback: const FavoriteReviewSettings().toJson(),
      ),
    };
    final dictionary = _readJsonObject(
      _preferences.getString('dictionary_settings'),
      fallback: DictionarySettings().toJson(),
    );
    final reminders = _readJsonObject(
      _preferences.getString('reminder_settings'),
      fallback: const ReminderSettings().toJson(),
    );
    final lists = <String, Object?>{
      'audioSortType':
          _preferences.getString('audio_list_sort_type') ?? 'dateDesc',
    };

    return UserPreferencesDocument({
      'appearance': appearance,
      'learning': learning,
      'playback': playback,
      'practice': practice,
      'review': review,
      'dictionary': dictionary,
      'reminders': reminders,
      'lists': lists,
    });
  }

  /// 把云端快照写回本地偏好存储。调用方随后刷新 Provider 内存状态。
  Future<void> apply(UserPreferencesDocument document) async {
    final groups = document.preferences;
    final appearance = _group(groups, 'appearance');
    await _writeString('theme_mode', appearance['themeMode'], 'system');
    await _writeString('locale', appearance['locale'], 'system');
    await _writeString(
      'native_language',
      appearance['nativeLanguage'],
      'zh-CN',
    );

    final learning = _group(groups, 'learning');
    for (final entry in _learningDefaults.entries) {
      await _writeBool(
        entry.key,
        learning[_learningFieldName(entry.key)],
        entry.value,
      );
    }

    final playback = _group(groups, 'playback');
    await _writeBool(
      'skip_silence_enabled',
      playback['skipSilenceEnabled'],
      true,
    );
    await _writeInt(
      'silence_threshold_seconds',
      playback['silenceThresholdSeconds'],
      2,
      minimum: 1,
      maximum: 10,
    );
    await _writeBool(
      'word_highlight_enabled',
      playback['wordHighlightEnabled'],
      true,
    );
    await _writeBool(
      'ai_transcription_auto_merge_enabled',
      playback['aiTranscriptionAutoMergeEnabled'],
      true,
    );

    final practice = _group(groups, 'practice');
    for (final entry in _practiceKeys.entries) {
      await _writeJsonObject(entry.value, practice[entry.key]);
    }

    final review = _group(groups, 'review');
    await _writeJsonObject(
      'bookmark_review_settings_v1',
      review['bookmark'],
      fallback: const BookmarkReviewSettings().toJson(),
    );
    await _writeJsonObject(
      'favorite_review_settings_v1',
      review['favorites'],
      fallback: const FavoriteReviewSettings().toJson(),
    );
    await _writeJsonObject(
      'dictionary_settings',
      groups['dictionary'],
      fallback: DictionarySettings().toJson(),
    );
    await _writeJsonObject(
      'reminder_settings',
      groups['reminders'],
      fallback: const ReminderSettings().toJson(),
    );
    await _writeString(
      'audio_list_sort_type',
      _group(groups, 'lists')['audioSortType'],
      'dateDesc',
    );
  }

  static const _learningFieldNames = <String, String>{
    LearningSettingsKeys.autoSkipRetell: 'autoSkipRetell',
    LearningSettingsKeys.autoExpandCachedAnnotation:
        'autoExpandCachedAnnotation',
    LearningSettingsKeys.autoShowAiExplanation: 'autoShowAiExplanation',
    LearningSettingsKeys.autoShowAiAnalysis: 'autoShowAiAnalysis',
    LearningSettingsKeys.autoShowAiTranslation: 'autoShowAiTranslation',
    LearningSettingsKeys.autoShowAiSenseGroups: 'autoShowAiSenseGroups',
    LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion:
        'autoPlayRetellRecordingAfterCompletion',
    LearningSettingsKeys.listenAndRepeatRatingEnabled:
        'listenAndRepeatRatingEnabled',
    LearningSettingsKeys.retellRatingEnabled: 'retellRatingEnabled',
  };

  static String _learningFieldName(String storageKey) =>
      _learningFieldNames[storageKey] ?? storageKey;

  static Map<String, Object?> _group(Map<String, Object?> groups, String name) {
    final value = groups[name];
    return value is Map ? _toStringObjectMap(value) : <String, Object?>{};
  }

  static Map<String, Object?> _readJsonObject(
    String? raw, {
    Map<String, Object?> fallback = const {},
  }) {
    if (raw == null) return Map<String, Object?>.from(fallback);
    try {
      final value = jsonDecode(raw);
      if (value is Map) return _toStringObjectMap(value);
    } on FormatException {
      // 损坏的单项偏好回退该项默认值，不影响其它设置同步。
    }
    return Map<String, Object?>.from(fallback);
  }

  static Map<String, Object?> _toStringObjectMap(Map source) {
    final result = <String, Object?>{};
    for (final entry in source.entries) {
      final key = entry.key;
      if (key is String) result[key] = entry.value;
    }
    return result;
  }

  Future<void> _writeString(String key, Object? value, String fallback) async {
    await _preferences.setString(key, value is String ? value : fallback);
  }

  Future<void> _writeBool(String key, Object? value, bool fallback) async {
    await _preferences.setBool(key, value is bool ? value : fallback);
  }

  Future<void> _writeInt(
    String key,
    Object? value,
    int fallback, {
    required int minimum,
    required int maximum,
  }) async {
    final number = value is int ? value : fallback;
    await _preferences.setInt(key, number.clamp(minimum, maximum));
  }

  Future<void> _writeJsonObject(
    String key,
    Object? value, {
    Map<String, Object?> fallback = const {},
  }) async {
    final object = value is Map ? _toStringObjectMap(value) : fallback;
    await _preferences.setString(key, jsonEncode(object));
  }
}
