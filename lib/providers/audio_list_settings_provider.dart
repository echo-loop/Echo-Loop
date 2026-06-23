// 音频列表排序设置 Provider
//
// 管理音频视图的排序方式，独立于 audioLibraryProvider。
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'audio_list_settings_provider.g.dart';

/// 音频列表排序方式持久化存储键
const _audioSortTypeKey = 'audio_list_sort_type';

/// 音频排序方式
///
/// - [custom]：保持调用方传入的顺序（官方合集按 junction sortOrder 的情况下用）
/// - [nameAsc] / [nameDesc]：按名称升降
/// - [dateAsc] / [dateDesc]：按 `addedDate`（本地添加时间）升降 —— 用户自建场景
/// - [originalDateAsc] / [originalDateDesc]：按 `originalDate`（官方原始发布日期）升降
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
  @override
  AudioListSettingsState build() {
    // 异步恢复持久化的排序方式（prefs 为真相源，autoDispose 重建后会重新读回）
    _loadSortType();
    return const AudioListSettingsState();
  }

  /// 从 SharedPreferences 恢复上次选择的排序方式
  ///
  /// 非法或缺省值回退到默认 [AudioSortType.dateDesc]。
  Future<void> _loadSortType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state.copyWith(
        sortType: audioSortTypeFromName(prefs.getString(_audioSortTypeKey)),
      );
    } catch (_) {
      // 读取失败（如 prefs 不可用）：保持默认排序
    }
  }

  /// 设置并持久化排序方式
  Future<void> setSortType(AudioSortType type) async {
    state = state.copyWith(sortType: type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioSortTypeKey, type.name);
  }
}
