import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/auth_config.dart' as auth_config;
import '../../providers/startup_bootstrap_provider.dart';

/// 提供给认证、订阅与更新依赖图的响应式 Supabase 可用状态。
///
/// 状态直接派生自标准启动 provider，避免静态 ValueNotifier 与启动 Future
/// 之间出现不同步。未配置或初始化失败均为不可用，调用方维持匿名降级语义。
final supabaseSdkReadyProvider = Provider<bool>((ref) {
  if (!ref.watch(supabaseAuthConfiguredProvider)) return false;
  return ref.watch(thirdPartyStartupProvider).valueOrNull?.isSupabaseReady ??
      false;
});

/// 当前进程所选 Supabase URL 与 publishable key 是否完整。
final supabaseAuthConfiguredProvider = Provider<bool>((ref) {
  return auth_config.isAuthConfiguredForUrl(
    ref.read(supabaseUrlForThisRunProvider),
  );
});
