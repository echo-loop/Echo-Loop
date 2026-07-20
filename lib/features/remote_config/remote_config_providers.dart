/// 远程配置 Riverpod 入口。
///
/// main() 在启动期完成一次加载，并通过 [initialRemoteConfigProvider] 注入。
/// 业务代码只读取 feature 级 provider，不直接依赖 HTTP 或缓存细节。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/package_info_provider.dart';
import '../../services/app_logger.dart';
import '../../services/refresh_coordinator.dart';
import '../onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'remote_config.dart';
import 'remote_config_service.dart';

const _remoteConfigRetryDelay = Duration(minutes: 5);

final initialRemoteConfigProvider = Provider<RemoteConfig>(
  (ref) => RemoteConfig.defaults,
);

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService.create(
    prefs: ref.watch(sharedPreferencesProvider),
    appVersion: readAppVersion(ref),
  );
});

final remoteConfigProvider =
    StateNotifierProvider<RemoteConfigController, RemoteConfig>((ref) {
      return RemoteConfigController(
        readService: () => ref.read(remoteConfigServiceProvider),
        initialConfig: ref.watch(initialRemoteConfigProvider),
      );
    });

final remoteFeatureEnabledProvider = Provider.family<bool, RemoteFeature>((
  ref,
  feature,
) {
  return ref.watch(remoteConfigProvider).isEnabled(feature);
});

/// 远程配置运行期刷新控制器。
class RemoteConfigController extends StateNotifier<RemoteConfig> {
  /// 创建远程配置控制器。
  RemoteConfigController({
    required RemoteConfigService Function() readService,
    required RemoteConfig initialConfig,
    DateTime Function()? now,
    RefreshCoordinator<String, RemoteConfig>? refreshCoordinator,
  }) : _readService = readService,
       _now = now ?? DateTime.now,
       _refresh =
           refreshCoordinator ??
           RefreshCoordinator<String, RemoteConfig>(now: now ?? DateTime.now),
       super(initialConfig);

  final RemoteConfigService Function() _readService;
  final DateTime Function() _now;
  final RefreshCoordinator<String, RemoteConfig> _refresh;

  Timer? _refreshTimer;
  bool _active = false;

  /// App 进入前台时启动 TTL 驱动的 one-shot 刷新循环。
  void startPeriodicRefresh() {
    _active = true;
    unawaited(refreshIfStale());
  }

  /// App 进入后台或 controller 销毁时停止前台刷新循环。
  void stopPeriodicRefresh() {
    _active = false;
    _cancelRefreshTimer();
  }

  /// 按远程配置 TTL 刷新；并发调用复用同一个请求。
  Future<void> refreshIfStale({bool force = false}) async {
    try {
      final service = _readService();
      final run = await _refresh.run(
        key: 'client',
        force: force,
        lastRefreshedAt: service.lastFetchedAt,
        throttleWindow: Duration(seconds: state.ttlSeconds),
        refresh: service.fetchRemote,
      );
      switch (run) {
        case RefreshCompleted<RemoteConfig>(:final result):
          state = result;
        case RefreshThrottled<RemoteConfig>():
          AppLogger.log('RemoteConfig', 'refresh skipped: ttl not expired');
      }
    } catch (error, stackTrace) {
      AppLogger.log('RemoteConfig', 'refresh failed: $error');
      AppLogger.log('RemoteConfig', stackTrace.toString());
    } finally {
      if (_active) _scheduleNextRefresh();
    }
  }

  void _scheduleNextRefresh() {
    _cancelRefreshTimer();
    DateTime? fetchedAt;
    try {
      fetchedAt = _readService().lastFetchedAt;
    } catch (error) {
      AppLogger.log('RemoteConfig', 'schedule read service failed: $error');
    }
    final ttl = Duration(seconds: state.ttlSeconds);
    final nextAt = fetchedAt == null ? _now() : fetchedAt.add(ttl);
    final remaining = nextAt.difference(_now());
    final delay = remaining <= Duration.zero
        ? _remoteConfigRetryDelay
        : remaining;
    _refreshTimer = Timer(delay, () {
      _refreshTimer = null;
      if (_active) unawaited(refreshIfStale());
    });
  }

  void _cancelRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    stopPeriodicRefresh();
    super.dispose();
  }
}
