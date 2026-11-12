/// PostHog 生产事件白名单。
///
/// 业务层保留历史埋点调用与本地使用统计；仅此处列出的高价值事件会发送到
/// PostHog，避免低价值交互持续产生远端数据。
library;

import 'models/event_names.dart';

abstract final class PostHogEventPolicy {
  static const Set<String> _allowedEvents = <String>{
    Events.learningStart,
    Events.blindListenComplete,
    Events.intensiveListenComplete,
    Events.listenRepeatComplete,
    Events.retellComplete,
    Events.difficultPracticeComplete,
    Events.firstLearnComplete,
    Events.collectionCreate,
    Events.communityCollectionEnroll,
    Events.onboardingSurveyCompleted,
    Events.notificationSystemResult,
    Events.asrInferenceCrashSuspected,
    Events.stageAdvance,
    Events.retellSkipped,
    Events.bookmarkReviewComplete,
    Events.flashcardComplete,
    Events.translationSucceeded,
    Events.analysisSucceeded,
    Events.senseGroupSucceeded,
    Events.wordAnalysisSucceeded,
    Events.transcriptionComplete,
    Events.subtitleEditorOpened,
    Events.subtitleUploaded,
    Events.subscriptionPageViewed,
    Events.subscriptionCheckoutStarted,
    Events.subscriptionPurchaseResult,
    Events.chatTurnResult,
    Events.dailyGoalCheckedIn,
  };

  /// 判断事件是否允许发送到 PostHog。
  static bool shouldCapture(String name) => _allowedEvents.contains(name);
}
