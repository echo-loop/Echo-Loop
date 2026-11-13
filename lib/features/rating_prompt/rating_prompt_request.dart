import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_logger.dart';
import 'rating_prompt_providers.dart';
import 'services/rating_prompt_coordinator.dart';

/// 回到学习或收藏首页时检查并请求评分提醒。
///
/// 协调器不可用或平台调用失败只记录日志，不影响主页面。
/// [canPresent] 由调用方提供，协调器在每次异步等待后复查，确保弹窗只出现在用户仍停留的首页。
Future<void> requestRatingOnHome(
  WidgetRef ref, {
  required bool Function() canPresent,
}) async {
  try {
    await ref
        .read(ratingPromptCoordinatorProvider)
        .maybeRequest(canPresent: canPresent);
  } catch (error, stackTrace) {
    AppLogger.log(
      RatingPromptCoordinator.logTag,
      'coordinator unavailable error=$error\n$stackTrace',
    );
  }
}
