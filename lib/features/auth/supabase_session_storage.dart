/// Supabase 登录会话的本地存储策略。
///
/// 全球区与中国区域名指向同一个 Supabase 项目，token 在两边都有效。
/// supabase_flutter 默认按域名生成存储 key，导致同一账号的会话被拆成两份：
/// 切换端点后启动会恢复另一份旧会话，表现为登录账号变化。这里统一使用与
/// 端点无关的固定 key，并在首次升级时把当前端点的旧会话迁移过来。
///
/// 当前不处理 Web 端迁移：Web 上会话存于 window.localStorage，本迁移只读写
/// SharedPreferences，因此 Web 用户升级后需要重新登录一次。
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_logger.dart';

/// 所有端点共享的会话存储 key，与域名无关。
const supabaseSessionStorageKey = 'sb-echo-loop-auth-token';

/// 记录会话存储迁移进度的 key。
const supabaseSessionStorageVersionKey = 'supabase_session_storage_version';

/// 当前会话存储迁移版本；升级存储策略时递增。
const currentSupabaseSessionStorageVersion = 1;

/// 生成 Supabase 客户端选项，所有端点都使用同一个会话 key。
FlutterAuthClientOptions supabaseAuthClientOptions() {
  return FlutterAuthClientOptions(
    localStorage: SharedPreferencesLocalStorage(
      persistSessionKey: supabaseSessionStorageKey,
    ),
  );
}

/// supabase_flutter 2.18.3 按域名生成的旧会话 key。
///
/// 规则必须与 SDK 保持一致；由单元测试锁定，升级 SDK 时会暴露变化。
String legacySupabaseSessionKeyForUrl(String url) {
  return 'sb-${Uri.parse(url).host.split('.').first}-auth-token';
}

/// 把当前端点的旧会话迁移到固定 key，并清理所有旧会话 key。
///
/// 安全约束：只复制当前端点的旧会话，绝不恢复其他端点的会话。
/// 迁移可重复执行：固定 key 已存在时不覆盖，只清理残留的旧 key。
Future<void> migrateSupabaseSessionStorage({
  required SharedPreferences prefs,
  required String currentUrl,
}) async {
  final storedVersion = prefs.getInt(supabaseSessionStorageVersionKey) ?? 0;
  if (storedVersion >= currentSupabaseSessionStorageVersion) {
    return;
  }

  final legacyKeys = _legacySessionKeys(prefs);
  final currentLegacyKey = legacySupabaseSessionKeyForUrl(currentUrl);
  var copied = false;
  if (!prefs.containsKey(supabaseSessionStorageKey)) {
    final legacySession = prefs.getString(currentLegacyKey);
    if (legacySession != null) {
      copied = await prefs.setString(supabaseSessionStorageKey, legacySession);
    }
  }

  for (final key in legacyKeys) {
    await prefs.remove(key);
  }
  await prefs.setInt(
    supabaseSessionStorageVersionKey,
    currentSupabaseSessionStorageVersion,
  );

  // 只记录是否迁移与清理数量，不记录 token、邮箱或 userId。
  AppLogger.log(
    'Supabase',
    'session storage migrated copied=$copied removedLegacy=${legacyKeys.length}',
  );
}

/// 所有旧版按域名生成的会话 key（不含固定 key 本身）。
List<String> _legacySessionKeys(SharedPreferences prefs) {
  return prefs
      .getKeys()
      .where(
        (key) =>
            key != supabaseSessionStorageKey &&
            key.startsWith('sb-') &&
            key.endsWith('-auth-token'),
      )
      .toList(growable: false);
}
