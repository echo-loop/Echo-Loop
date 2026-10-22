import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../../services/backend_dio.dart';
import '../../../services/runtime_endpoint_router.dart';
import '../data/user_onboarding_api.dart';
import '../data/user_onboarding_sync_service.dart';
import 'onboarding_survey_provider.dart';

/// 认证 API 与本地问卷存储的同步组合入口。
final onboardingSyncProvider = Provider<OnboardingSync>((ref) {
  final preferences = ref.read(sharedPreferencesProvider);
  final dio = createAuthenticatedBackendDio(
    tokenCoordinator: ref.read(supabaseTokenCoordinatorProvider),
    endpointRouter: runtimeEndpointRouter,
    apiLogTag: 'USER_ONBOARDING',
    // API 默认日志会打印答案请求体；这里只保留同步服务的脱敏结果日志。
    apiLogPrint: (_) {},
  );
  final service = UserOnboardingSyncService(
    remote: UserOnboardingApi(dio),
    storage: ref.read(onboardingStorageProvider),
    preferences: preferences,
  );
  ref.onDispose(() {
    service.dispose();
    dio.close(force: true);
  });
  return service;
});
