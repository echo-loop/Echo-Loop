/// 用户地区的缓存状态入口。
///
/// 使用方只读取 [isChinaUserProvider]，不会重新读取 Storefront、系统地区或
/// Client Config；刷新只由 App 冷启动和回前台的生命周期入口发起。
library;

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/client_distribution.dart';
import '../../services/app_logger.dart';
import '../../services/runtime_endpoint_router.dart';
import '../remote_config/remote_config.dart';
import '../remote_config/remote_config_providers.dart';
import '../subscription/services/purchase_service.dart';
import '../subscription/services/revenuecat_purchase_service.dart'
    show purchaseServiceProvider;
import 'user_region.dart';

const _logTag = 'UserRegion';

/// 当前支付渠道 seam；测试可替换而无需依赖宿主平台。
final userRegionPaymentChannelProvider = Provider<ClientPaymentChannel>(
  (ref) => clientPaymentChannel,
);

/// 当前服务端点路由器；测试可注入隔离的路由状态。
final userRegionEndpointRouterProvider = Provider<RuntimeEndpointRouter>(
  (ref) => runtimeEndpointRouter,
);

/// 系统地区读取 seam；生产读取 OS locale，测试可注入固定值或异常。
final userRegionDeviceCountryCodeProvider = Provider<String? Function()>(
  (ref) =>
      () => PlatformDispatcher.instance.locale.countryCode,
);

/// 当前用户地区的缓存状态。
final userRegionProvider =
    StateNotifierProvider<UserRegionController, UserRegionState>((ref) {
      final endpointRouter = ref.watch(userRegionEndpointRouterProvider);
      final controller = UserRegionController(
        readPurchaseService: () => ref.read(purchaseServiceProvider),
        readDeviceCountryCode: ref.read(userRegionDeviceCountryCodeProvider),
        isAppleStoreChannel:
            ref.read(userRegionPaymentChannelProvider) ==
            ClientPaymentChannel.appleStore,
        initialRemoteConfig: ref.read(remoteConfigProvider),
      );
      var previousIsChinaUser = controller.isChinaUser;
      final removeEndpointListener = controller.addListener((state) {
        final previous = previousIsChinaUser;
        final regionChanged = state.isChinaUser != previous;
        previousIsChinaUser = state.isChinaUser;
        endpointRouter.updateFromUserRegion(isChinaUser: state.isChinaUser);
        if (regionChanged) {
          AppLogger.log(
            _logTag,
            'isChinaUser changed from=$previous to=${state.isChinaUser}; '
            'forcing client config refresh',
          );
          unawaited(
            ref.read(remoteConfigProvider.notifier).refreshIfStale(force: true),
          );
        }
      }, fireImmediately: true);
      ref.onDispose(removeEndpointListener);
      // Client Config 的网络请求完全由已有 controller 调度。远端值真正改变后，
      // 这里只重算已缓存证据，不重复访问 Storefront 或系统 region。
      ref.listen<RemoteConfig>(remoteConfigProvider, (_, next) {
        controller.updateClientConfig(next);
      });
      return controller;
    });

/// 给 CDN、下载器等业务侧使用的最简接口；读取不会触发刷新。
final isChinaUserProvider = Provider<bool>((ref) {
  return ref.watch(userRegionProvider.select((state) => state.isChinaUser));
});

/// 负责聚合三项地区证据并缓存最终结果。
class UserRegionController extends StateNotifier<UserRegionState> {
  UserRegionController({
    required PurchaseService Function() readPurchaseService,
    required String? Function() readDeviceCountryCode,
    required bool isAppleStoreChannel,
    required RemoteConfig initialRemoteConfig,
    DateTime Function()? now,
  }) : _readPurchaseService = readPurchaseService,
       _readDeviceCountryCode = readDeviceCountryCode,
       _isAppleStoreChannel = isAppleStoreChannel,
       _now = now ?? DateTime.now,
       super(
         UserRegionState.resolve(
           storefront: isAppleStoreChannel
               ? const UserRegionSourceResult.pending()
               : const UserRegionSourceResult.skipped(),
           deviceRegion: _readDeviceResult(readDeviceCountryCode),
           clientConfig: _clientConfigResult(initialRemoteConfig),
           isRefreshing: false,
         ),
       ) {
    _logResult('initialized');
  }

  final PurchaseService Function() _readPurchaseService;
  final String? Function() _readDeviceCountryCode;
  final bool _isAppleStoreChannel;
  final DateTime Function() _now;
  Future<void>? _refreshInFlight;

  /// 当前唯一地区结论，供 provider 适配层检测地区是否发生变化。
  bool get isChinaUser => state.isChinaUser;

  /// 刷新 Storefront 与系统地区；并发的启动/resume 调用复用同一个任务。
  Future<void> refresh(UserRegionRefreshTrigger trigger) {
    final existing = _refreshInFlight;
    if (existing != null) {
      AppLogger.log(_logTag, 'refresh joined trigger=${trigger.name}');
      return existing;
    }
    final refresh = _refresh(trigger);
    _refreshInFlight = refresh;
    return refresh.whenComplete(() => _refreshInFlight = null);
  }

  /// Client Config 已由其自身节流策略刷新后，只重算这一项缓存证据。
  void updateClientConfig(RemoteConfig config) {
    final previousCountryCode = state.clientConfig.countryCode;
    final previousIsChinaUser = state.isChinaUser;
    state = state.copyWith(clientConfig: _clientConfigResult(config));
    _logResult(
      'clientConfigUpdated previousCountry=${previousCountryCode ?? "unknown"} '
      'previousIsChinaUser=$previousIsChinaUser',
    );
  }

  Future<void> _refresh(UserRegionRefreshTrigger trigger) async {
    state = state.copyWith(
      deviceRegion: _readDeviceResult(_readDeviceCountryCode),
      isRefreshing: true,
    );
    AppLogger.log(
      _logTag,
      'refresh start trigger=${trigger.name} '
      'appleStoreChannel=$_isAppleStoreChannel '
      'device=${state.deviceRegion}',
    );

    final storefront = await _readStorefrontResult();
    state = state.copyWith(
      storefront: storefront,
      isRefreshing: false,
      lastRefreshedAt: _now(),
    );
    _logResult('refreshComplete trigger=${trigger.name}');
  }

  Future<UserRegionSourceResult> _readStorefrontResult() async {
    if (!_isAppleStoreChannel) {
      AppLogger.log(_logTag, 'storefront skipped: nonAppleStoreChannel');
      return const UserRegionSourceResult.skipped();
    }
    try {
      final countryCode = await _readPurchaseService().storefrontCountryCode();
      return UserRegionSourceResult(
        status: UserRegionSourceStatus.available,
        countryCode: countryCode,
      );
    } catch (error, stackTrace) {
      AppLogger.log(_logTag, 'storefront failed: $error');
      AppLogger.log(_logTag, stackTrace.toString());
      return const UserRegionSourceResult.failed();
    }
  }

  void _logResult(String event) {
    AppLogger.log(
      _logTag,
      '$event storefront=${state.storefront} '
      'device=${state.deviceRegion} clientConfig=${state.clientConfig} '
      'isChinaUser=${state.isChinaUser} '
      'matched=${state.matchedSources.map((source) => source.name).join(",")}',
    );
  }
}

/// 系统 locale 不可靠时仅使该策略失败，不影响 Storefront 与 Client Config。
UserRegionSourceResult _readDeviceResult(String? Function() reader) {
  try {
    return UserRegionSourceResult(
      status: UserRegionSourceStatus.available,
      countryCode: reader(),
    );
  } catch (error, stackTrace) {
    AppLogger.log(_logTag, 'device region failed: $error');
    AppLogger.log(_logTag, stackTrace.toString());
    return const UserRegionSourceResult.failed();
  }
}

UserRegionSourceResult _clientConfigResult(RemoteConfig config) {
  return UserRegionSourceResult(
    status: UserRegionSourceStatus.available,
    countryCode: config.context.countryCode,
  );
}
