/// 远程配置本地缓存。
///
/// 缓存使用后端下发的 ttlSeconds 控制有效期；网络失败时允许读取过期缓存，
/// 避免配置服务短暂不可用导致入口抖动。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'remote_config.dart';

const _remoteConfigPayloadKey = 'remote_config_payload_v1';
const _remoteConfigFetchedAtKey = 'remote_config_fetched_at_ms_v1';

class RemoteConfigStore {
  const RemoteConfigStore(this._prefs);

  final SharedPreferences _prefs;

  /// 返回最近一次成功写入远程配置的时间。
  DateTime? readFetchedAt() {
    final fetchedAtMs = _prefs.getInt(_remoteConfigFetchedAtKey);
    if (fetchedAtMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);
  }

  RemoteConfig? readCached({DateTime? now, bool allowExpired = false}) {
    final raw = _prefs.getString(_remoteConfigPayloadKey);
    final fetchedAt = readFetchedAt();
    if (raw == null || fetchedAt == null) return null;

    final decoded = jsonDecode(raw);
    final config = RemoteConfig.fromJson(decoded);
    if (allowExpired) return config;

    final elapsed = (now ?? DateTime.now()).difference(fetchedAt);
    if (elapsed <= Duration(seconds: config.ttlSeconds)) {
      return config;
    }
    return null;
  }

  Future<void> write(RemoteConfig config, {DateTime? now}) async {
    await _prefs.setString(
      _remoteConfigPayloadKey,
      jsonEncode(config.toJson()),
    );
    await _prefs.setInt(
      _remoteConfigFetchedAtKey,
      (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }
}
