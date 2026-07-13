/// AI quota 本地状态 Provider。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../services/ai_quota_limit_store.dart';
import 'subscription_controller.dart';
import 'subscription_identity.dart';

/// AI quota 本地持久化入口。
final aiQuotaLimitStoreProvider = Provider<AiQuotaLimitStore>((ref) {
  return AiQuotaLimitStore(ref.read(sharedPreferencesProvider));
});

/// 监听会员状态，会员生效时清除当前用户的 quota reset 记录。
final aiQuotaLimitCleanupProvider = Provider<void>((ref) {
  ref.listen(subscriptionControllerProvider, (previous, next) {
    if (!next.isActive) return;
    final userId = ref.read(subscriptionIdentityProvider).userId;
    if (userId == null) return;
    unawaited(ref.read(aiQuotaLimitStoreProvider).clearAllResets(userId));
  }, fireImmediately: true);
});
