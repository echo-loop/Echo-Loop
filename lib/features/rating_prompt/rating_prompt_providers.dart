import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../remote_config/remote_config.dart';
import '../remote_config/remote_config_providers.dart';
import '../../providers/package_info_provider.dart';
import '../onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../../services/app_logger.dart';
import 'data/rating_prompt_attempt_store.dart';
import 'data/rating_prompt_task_completion_store.dart';
import 'domain/rating_prompt_status.dart';
import 'services/in_app_review_gateway.dart';
import 'services/rating_prompt_coordinator.dart';

/// 原生评分请求适配器，可在测试中替换为 fake。
final inAppReviewGatewayProvider = Provider<InAppReviewGateway>((ref) {
  return PluginInAppReviewGateway();
});

/// 最近一次正常完成学习任务的时间存储；各任务的完成点写入，评分检查读取。
final ratingPromptTaskCompletionStoreProvider =
    Provider<RatingPromptTaskCompletionStore>((ref) {
      return RatingPromptTaskCompletionStore(
        ref.watch(sharedPreferencesProvider),
      );
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
    taskCompletionStore: ref.watch(ratingPromptTaskCompletionStoreProvider),
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

/// 记录一次正常完成的学习任务，供评分提醒判断“刚刚是否完成过任务”。
///
/// 只在用户正常结束任务时调用（中途退出不记录）。记录失败只写日志，不影响学习流程。
Future<void> recordRatingTaskCompletion(
  RatingPromptTaskCompletionStore Function() readStore,
) async {
  try {
    await readStore().recordCompletion(DateTime.now());
  } catch (error, stackTrace) {
    AppLogger.log(
      RatingPromptCoordinator.logTag,
      'task completion record failed error=$error\n$stackTrace',
    );
  }
}
