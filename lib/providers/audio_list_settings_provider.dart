// 音频列表排序设置 Provider
//
// 管理音频视图的排序方式，独立于 audioLibraryProvider。
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/user_preferences/domain/user_preferences_sync_events.dart';
import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;

part 'audio_list_settings_provider.g.dart';

/// 音频列表排序方式持久化存储键
const _audioSortTypeKey = 'audio_list_sort_type';

/// 音频排序方式
///
/// - [custom]：保持调用方传入的顺序（社区合集按 junction sortOrder 的情况下用）
/// - [nameAsc] / [nameDesc]：按名称升降
/// - [dateAsc] / [dateDesc]：按 `addedDate`（本地添加时间）升降 —— 用户自建场景
/// - [originalDateAsc] / [originalDateDesc]：按 `originalDate`（社区原始发布日期）升降
enum AudioSortType {
  custom,
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  originalDateAsc,
  originalDateDesc,
}

/// 把持久化字符串解析为 [AudioSortType]
///
/// null（未存过）或非法值统一回退到默认 [AudioSortType.dateDesc]。
AudioSortType audioSortTypeFromName(String? raw) {
  if (raw == null) return AudioSortType.dateDesc;
  try {
    return AudioSortType.values.byName(raw);
  } catch (_) {
    return AudioSortType.dateDesc;
  }
}

/// 音频列表设置状态
class AudioListSettingsState {
  /// 排序方式
  final AudioSortType sortType;

  const AudioListSettingsState({this.sortType = AudioSortType.dateDesc});

  AudioListSettingsState copyWith({AudioSortType? sortType}) {
    return AudioListSettingsState(sortType: sortType ?? this.sortType);
  }
}

@riverpod
class AudioListSettings extends _$AudioListSettings {
  int _loadGeneration = 0;

  @override
  AudioListSettingsState build() {
    final generation = ++_loadGeneration;
    try {
      return _readFromPrefs(ref.read(sharedPreferencesProvider));
    } on UnimplementedError {
      _loadSortType(generation);
      return const AudioListSettingsState();
    }
  }

  AudioListSettingsState _readFromPrefs(SharedPreferences prefs) {
    return AudioListSettingsState(
      sortType: audioSortTypeFromName(prefs.getString(_audioSortTypeKey)),
    );
  }

  /// 云端写回 SharedPreferences 后同步刷新内存状态。
  void reloadFromPrefs() {
    final generation = ++_loadGeneration;
    try {
      state = _readFromPrefs(ref.read(sharedPreferencesProvider));
    } on UnimplementedError {
      _loadSortType(generation);
    }
  }

  Future<void> _loadSortType(int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (generation != _loadGeneration) return;
    state = AudioListSettingsState(
      sortType: audioSortTypeFromName(prefs.getString(_audioSortTypeKey)),
    );
  }

  /// 设置并持久化排序方式
  Future<void> setSortType(AudioSortType type) async {
    _loadGeneration++;
    state = state.copyWith(sortType: type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioSortTypeKey, type.name);
    userPreferencesSyncEvents.notifyLocalChange();
  }
}
