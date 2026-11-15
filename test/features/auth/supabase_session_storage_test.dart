import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:echo_loop/features/auth/supabase_session_storage.dart';

const _globalUrl = 'https://znjgowxhqutmekzbbxbm.supabase.co';
const _chinaUrl = 'https://supabase.echo-loop.cn';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('legacySupabaseSessionKeyForUrl', () {
    test('与 supabase_flutter 2.18.3 按域名生成的 key 一致', () {
      expect(
        legacySupabaseSessionKeyForUrl(_globalUrl),
        'sb-znjgowxhqutmekzbbxbm-auth-token',
      );
      expect(
        legacySupabaseSessionKeyForUrl(_chinaUrl),
        'sb-supabase-auth-token',
      );
    });
  });

  group('supabaseAuthClientOptions', () {
    test('会话使用与端点无关的固定 key', () async {
      final options = supabaseAuthClientOptions();
      final storage = options.localStorage;

      expect(storage, isA<SharedPreferencesLocalStorage>());
      expect(
        (storage as SharedPreferencesLocalStorage).persistSessionKey,
        supabaseSessionStorageKey,
      );
    });
  });

  group('migrateSupabaseSessionStorage', () {
    test('复制当前端点的旧会话到固定 key，并删除所有旧会话 key', () async {
      SharedPreferences.setMockInitialValues({
        'sb-supabase-auth-token': 'china-session',
        'sb-znjgowxhqutmekzbbxbm-auth-token': 'global-session',
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateSupabaseSessionStorage(prefs: prefs, currentUrl: _chinaUrl);

      expect(prefs.getString(supabaseSessionStorageKey), 'china-session');
      expect(prefs.containsKey('sb-supabase-auth-token'), isFalse);
      expect(prefs.containsKey('sb-znjgowxhqutmekzbbxbm-auth-token'), isFalse);
      expect(
        prefs.getInt(supabaseSessionStorageVersionKey),
        currentSupabaseSessionStorageVersion,
      );
    });

    test('当前端点没有旧会话时，不恢复另一端点的会话', () async {
      SharedPreferences.setMockInitialValues({
        'sb-znjgowxhqutmekzbbxbm-auth-token': 'global-session',
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateSupabaseSessionStorage(prefs: prefs, currentUrl: _chinaUrl);

      expect(prefs.containsKey(supabaseSessionStorageKey), isFalse);
      expect(prefs.containsKey('sb-znjgowxhqutmekzbbxbm-auth-token'), isFalse);
    });

    test('固定 key 已存在时不覆盖，只清理旧 key', () async {
      SharedPreferences.setMockInitialValues({
        supabaseSessionStorageKey: 'already-migrated',
        'sb-supabase-auth-token': 'stale-china-session',
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateSupabaseSessionStorage(prefs: prefs, currentUrl: _chinaUrl);

      expect(prefs.getString(supabaseSessionStorageKey), 'already-migrated');
      expect(prefs.containsKey('sb-supabase-auth-token'), isFalse);
    });

    test('版本已记录时不再执行，旧 key 保持不动', () async {
      SharedPreferences.setMockInitialValues({
        supabaseSessionStorageVersionKey: currentSupabaseSessionStorageVersion,
        'sb-supabase-auth-token': 'china-session',
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateSupabaseSessionStorage(prefs: prefs, currentUrl: _chinaUrl);

      expect(prefs.containsKey(supabaseSessionStorageKey), isFalse);
      expect(prefs.getString('sb-supabase-auth-token'), 'china-session');
    });

    test('迁移后两个端点读取同一份会话', () async {
      SharedPreferences.setMockInitialValues({
        'sb-znjgowxhqutmekzbbxbm-auth-token': 'global-session',
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateSupabaseSessionStorage(prefs: prefs, currentUrl: _globalUrl);

      // 固定 key 与 URL 无关：切到中国区端点后，同一 storage 仍读到同一会话。
      // 与 Supabase.initialize 一致：读取前必须先初始化 storage。
      final storage = supabaseAuthClientOptions().localStorage!;
      await storage.initialize();
      expect(await storage.accessToken(), 'global-session');
    });
  });
}
