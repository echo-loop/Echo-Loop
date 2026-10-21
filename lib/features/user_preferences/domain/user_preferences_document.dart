import 'package:collection/collection.dart';

/// 用户偏好 API 的 schemaVersion 1 文档。
typedef UserPreferencesJson = Map<String, Object?>;

class UserPreferencesDocument {
  UserPreferencesDocument(UserPreferencesJson preferences)
    : preferences = _cloneObject(preferences);

  static const schemaVersion = 1;
  static const empty = UserPreferencesDocument._({});

  const UserPreferencesDocument._(this.preferences);

  final UserPreferencesJson preferences;

  UserPreferencesDocument copyWith({UserPreferencesJson? preferences}) =>
      UserPreferencesDocument(preferences ?? this.preferences);

  UserPreferencesJson toJson() => {
    'schemaVersion': schemaVersion,
    'preferences': _cloneObject(preferences),
  };

  static UserPreferencesDocument fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Preference document must be an object');
    }
    final version = value['schemaVersion'];
    if (version != schemaVersion) {
      throw const FormatException('Unsupported preference schema version');
    }
    final rawPreferences = value['preferences'];
    if (rawPreferences is! Map) {
      throw const FormatException('Preference groups must be an object');
    }
    return UserPreferencesDocument(_cloneObject(rawPreferences));
  }

  /// 把 local 相对 base 的新增或修改合并到 remote。
  ///
  /// 缺失的本地 map key 不视为删除：旧客户端可能不认识服务端新增字段，
  /// 且现有偏好 UI 没有删除单个字段的操作。这样更新已知值时能保留未知值。
  static UserPreferencesDocument mergeLocalChanges({
    required UserPreferencesDocument base,
    required UserPreferencesDocument local,
    required UserPreferencesDocument remote,
  }) {
    return UserPreferencesDocument(
      _mergeObject(base.preferences, local.preferences, remote.preferences),
    );
  }

  static bool hasLocalChanges({
    required UserPreferencesDocument base,
    required UserPreferencesDocument local,
  }) {
    final merged = _mergeObject(
      base.preferences,
      local.preferences,
      base.preferences,
    );
    return !const DeepCollectionEquality().equals(merged, base.preferences);
  }
}

UserPreferencesJson _cloneObject(Map source) {
  final result = <String, Object?>{};
  for (final entry in source.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const FormatException('Preference object keys must be strings');
    }
    result[key] = _cloneJsonValue(entry.value);
  }
  return result;
}

Object? _cloneJsonValue(Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw const FormatException('Preference numbers must be finite');
    }
    return value;
  }
  if (value is List) {
    return value.map(_cloneJsonValue).toList(growable: false);
  }
  if (value is Map) return _cloneObject(value);
  throw const FormatException('Preference value is not JSON-compatible');
}

UserPreferencesJson _mergeObject(
  Map<String, Object?> base,
  Map<String, Object?> local,
  Map<String, Object?> remote,
) {
  final result = _cloneObject(remote);
  for (final entry in local.entries) {
    final key = entry.key;
    final localValue = entry.value;
    final baseHasValue = base.containsKey(key);
    final baseValue = base[key];
    if (baseHasValue &&
        const DeepCollectionEquality().equals(baseValue, localValue)) {
      continue;
    }

    final remoteValue = result[key];
    if (localValue is Map) {
      final baseMap = baseValue is Map
          ? _cloneObject(baseValue)
          : <String, Object?>{};
      final remoteMap = remoteValue is Map
          ? _cloneObject(remoteValue)
          : <String, Object?>{};
      result[key] = _mergeObject(baseMap, _cloneObject(localValue), remoteMap);
    } else {
      result[key] = _cloneJsonValue(localValue);
    }
  }
  return result;
}
