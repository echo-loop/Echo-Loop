/// AI 后端月度免费额度的本地状态。
///
/// 后端仍是额度裁决的唯一真相；本地只记录后端返回的 `resetAt`，在重置前
/// 避免重复访问 API，并记录 quota 提醒弹窗的最近确认时间。
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_logger.dart';
import '../models/premium_feature.dart';

/// quota 提醒的最小展示间隔。
const aiQuotaReminderCooldown = Duration(days: 14);

/// AI quota 本地持久化。
class AiQuotaLimitStore {
  AiQuotaLimitStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'ai_quota_limit_v1';

  /// 当前 reset 时间；过期或不存在时返回 null。
  DateTime? activeResetAt(
    String userId,
    PremiumFeature feature, {
    DateTime? now,
  }) {
    final entry = _entry(userId, feature);
    final resetAt = _parseDate(entry['resetAt']);
    if (resetAt == null) return null;
    final current = now ?? clock.now();
    return resetAt.isAfter(current.toUtc()) ? resetAt : null;
  }

  /// 是否应阻止后端请求。
  bool isBlocked(String userId, PremiumFeature feature, {DateTime? now}) {
    return activeResetAt(userId, feature, now: now) != null;
  }

  /// 记录后端返回的 quota reset 时间。
  Future<void> recordResetAt(
    String userId,
    PremiumFeature feature,
    DateTime resetAt,
  ) async {
    final all = _readAll();
    final user = Map<String, dynamic>.from(all[userId] as Map? ?? {});
    final entry = Map<String, dynamic>.from(user[feature.name] as Map? ?? {});
    entry['resetAt'] = resetAt.toUtc().toIso8601String();
    user[feature.name] = entry;
    all[userId] = user;
    await _writeAll(all);
  }

  /// 清除某功能的 reset 时间，保留提醒节流时间。
  Future<void> clearReset(String userId, PremiumFeature feature) async {
    final all = _readAll();
    final user = Map<String, dynamic>.from(all[userId] as Map? ?? {});
    final entry = Map<String, dynamic>.from(user[feature.name] as Map? ?? {});
    if (!entry.containsKey('resetAt')) return;
    entry.remove('resetAt');
    user[feature.name] = entry;
    all[userId] = user;
    await _writeAll(all);
  }

  /// 清除当前用户所有已过期 reset 记录。
  Future<void> clearExpiredResets(String userId, {DateTime? now}) async {
    final all = _readAll();
    final rawUser = all[userId];
    if (rawUser is! Map) return;
    final user = Map<String, dynamic>.from(rawUser);
    var changed = false;
    final current = (now ?? clock.now()).toUtc();
    for (final feature in PremiumFeature.values) {
      final rawEntry = user[feature.name];
      if (rawEntry is! Map) continue;
      final entry = Map<String, dynamic>.from(rawEntry);
      final resetAt = _parseDate(entry['resetAt']);
      if (resetAt != null && !resetAt.isAfter(current)) {
        entry.remove('resetAt');
        user[feature.name] = entry;
        changed = true;
      }
    }
    if (!changed) return;
    all[userId] = user;
    await _writeAll(all);
  }

  /// 会员生效时清除当前用户所有 reset 记录。
  Future<void> clearAllResets(String userId) async {
    final all = _readAll();
    final rawUser = all[userId];
    if (rawUser is! Map) return;
    final user = Map<String, dynamic>.from(rawUser);
    var changed = false;
    for (final feature in PremiumFeature.values) {
      final rawEntry = user[feature.name];
      if (rawEntry is! Map) continue;
      final entry = Map<String, dynamic>.from(rawEntry);
      if (entry.remove('resetAt') != null) {
        user[feature.name] = entry;
        changed = true;
      }
    }
    if (!changed) return;
    all[userId] = user;
    await _writeAll(all);
  }

  /// quota 提醒弹窗是否已过冷却期。
  bool shouldShowReminder(
    String userId,
    PremiumFeature feature, {
    DateTime? now,
  }) {
    final lastShownAt = _lastReminderAt(userId);
    if (lastShownAt == null) return true;
    final current = (now ?? clock.now()).toUtc();
    return current.difference(lastShownAt) >= aiQuotaReminderCooldown;
  }

  /// 记录用户已处理 quota 提醒。
  Future<void> markReminderShown(
    String userId,
    PremiumFeature feature, {
    DateTime? now,
  }) async {
    final all = _readAll();
    final user = Map<String, dynamic>.from(all[userId] as Map? ?? {});
    user['lastReminderAt'] = (now ?? clock.now()).toUtc().toIso8601String();
    all[userId] = user;
    await _writeAll(all);
  }

  DateTime? _lastReminderAt(String userId) {
    final rawUser = _readAll()[userId];
    if (rawUser is! Map) return null;
    return _parseDate(rawUser['lastReminderAt']);
  }

  Map<String, dynamic> _entry(String userId, PremiumFeature feature) {
    final rawUser = _readAll()[userId];
    if (rawUser is! Map) return const {};
    final rawEntry = rawUser[feature.name];
    if (rawEntry is! Map) return const {};
    return Map<String, dynamic>.from(rawEntry);
  }

  Map<String, dynamic> _readAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      AppLogger.log('AiQuotaLimit', '解析失败，回退空: $e');
    }
    return {};
  }

  Future<void> _writeAll(Map<String, dynamic> all) {
    return _prefs.setString(_key, jsonEncode(all));
  }

  DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
