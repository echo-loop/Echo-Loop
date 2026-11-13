import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/backend_dio.dart';
import '../../../services/runtime_endpoint_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/account_usage_api.dart';
import '../domain/account_usage.dart';

final accountUsageApiProvider = Provider<AccountUsageRemoteDataSource>((ref) {
  final dio = createAuthenticatedBackendDio(
    tokenCoordinator: ref.read(supabaseTokenCoordinatorProvider),
    endpointRouter: runtimeEndpointRouter,
    apiLogTag: 'ACCOUNT_USAGE',
  );
  ref.onDispose(() => dio.close(force: true));
  return AccountUsageApi(dio);
});

/// 用量页的数据：进入页面时加载一次，不轮询。
///
/// `autoDispose` 保证离开页面后释放缓存，下次打开重新请求，数据不会陈旧。
/// 关闭自动重试：失败后由用户点击「重试」重新加载。
final accountUsageProvider = FutureProvider.autoDispose<AccountUsage?>((
  ref,
) async {
  final userId = ref.watch(
    supabaseSessionProvider.select((session) => session.value?.user.id),
  );
  if (userId == null) return null;
  return ref.read(accountUsageApiProvider).getUsage();
}, retry: (_, _) => null);
