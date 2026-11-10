import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../remote_config/remote_config.dart';
import '../remote_config/remote_config_providers.dart';
import '../../providers/package_info_provider.dart';
import '../onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'data/rating_prompt_attempt_store.dart';
import 'domain/rating_prompt_status.dart';
import 'services/in_app_review_gateway.dart';
import 'services/rating_prompt_coordinator.dart';

/// 原生评分请求适配器，可在测试中替换为 fake。
final inAppReviewGatewayProvider = Provider<InAppReviewGateway>((ref) {
  return PluginInAppReviewGateway();
});

/// 评分邀请协调器。
final ratingPromptCoordinatorProvider = Provider<RatingPromptCoordinator>((
  ref,
) {
  return RatingPromptCoordinator(
    packageInfo: ref.watch(packageInfoProvider),
    studyRecordDao: ref.watch(dailyStudyRecordDaoProvider),
    attemptStore: RatingPromptAttemptStore(
      ref.watch(sharedPreferencesProvider),
    ),
    reviewGateway: ref.watch(inAppReviewGatewayProvider),
    isEnabled: () =>
        ref.read(remoteFeatureEnabledProvider(RemoteFeature.inAppReview)),
  );
});

/// 开发者选项中展示的评价提醒条件快照；每次订阅（打开弹窗）时重新计算。
final ratingPromptStatusProvider =
    FutureProvider.autoDispose<RatingPromptStatus>(
      (ref) => ref.read(ratingPromptCoordinatorProvider).inspect(),
    );
