/// 系统 Region 的读取入口与中国区判定。
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_logger.dart';
import '../../services/runtime_endpoint_router.dart';
import 'user_region.dart';

/// 系统 Region 读取 seam；测试可注入固定国家码。
final userRegionDeviceCountryCodeProvider = Provider<String? Function()>(
  (ref) =>
      () => PlatformDispatcher.instance.locale.countryCode,
);

/// 当前服务端点路由器；测试可注入隔离的路由状态。
final userRegionEndpointRouterProvider = Provider<RuntimeEndpointRouter>(
  (ref) => runtimeEndpointRouter,
);

/// 唯一依据系统 Region 国家码同步判定中国区；未知或无效值使用全球区。
final isChinaUserProvider = Provider<bool>((ref) {
  try {
    final countryCode = ref.watch(userRegionDeviceCountryCodeProvider)();
    return isChinaSystemRegion(countryCode);
  } catch (error, stackTrace) {
    AppLogger.log('UserRegion', 'system Region read failed: $error');
    AppLogger.log('UserRegion', stackTrace.toString());
    return false;
  }
});
