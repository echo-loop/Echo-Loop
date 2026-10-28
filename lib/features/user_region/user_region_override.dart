/// 开发者选项：手动指定服务地区（中国区 / 全球区），便于调试。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/regional_service_endpoints.dart';
import '../../services/app_logger.dart';

/// 服务地区的手动覆盖选项；[auto] 表示按系统 Region + Config API 自动判定。
enum UserRegionOverride {
  auto,
  china,
  global;

  /// 覆盖对应的固定区域；[auto] 返回 null。
  ServiceEndpointRegion? get forcedRegion => switch (this) {
    UserRegionOverride.auto => null,
    UserRegionOverride.china => ServiceEndpointRegion.china,
    UserRegionOverride.global => ServiceEndpointRegion.global,
  };
}

const _overrideKey = 'developer_user_region_override';

/// 服务地区覆盖的持久化存储。
///
/// 地区在启动时固定到本进程，所以修改后需重启 App 才会生效。
class UserRegionOverrideStore {
  const UserRegionOverrideStore();

  /// 读取已保存的覆盖值；未保存或值无效时返回 [UserRegionOverride.auto]。
  Future<UserRegionOverride> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_overrideKey);
    return UserRegionOverride.values.firstWhere(
      (value) => value.name == saved,
      orElse: () => UserRegionOverride.auto,
    );
  }

  /// 保存覆盖值；[UserRegionOverride.auto] 直接删除键，恢复自动判定。
  Future<void> save(UserRegionOverride value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == UserRegionOverride.auto) {
      await prefs.remove(_overrideKey);
    } else {
      await prefs.setString(_overrideKey, value.name);
    }
    AppLogger.log('UserRegion', 'developer override saved=${value.name}');
  }
}

/// 覆盖存储 seam；测试可注入。
final userRegionOverrideStoreProvider = Provider<UserRegionOverrideStore>(
  (ref) => const UserRegionOverrideStore(),
);

/// 已保存的覆盖值，供开发者选项界面展示；保存后需 invalidate 刷新。
final userRegionOverrideProvider = FutureProvider<UserRegionOverride>(
  (ref) => ref.watch(userRegionOverrideStoreProvider).load(),
);
