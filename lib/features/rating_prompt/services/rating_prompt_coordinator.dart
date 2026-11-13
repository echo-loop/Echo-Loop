import 'package:package_info_plus/package_info_plus.dart';

import '../../../config/client_distribution.dart';
import '../../../database/daos/daily_study_record_dao.dart';
import '../../../services/app_logger.dart';
import '../data/rating_prompt_attempt_store.dart';
import '../data/rating_prompt_task_completion_store.dart';
import '../domain/rating_prompt_policy.dart';
import '../domain/rating_prompt_status.dart';
import 'in_app_review_gateway.dart';

/// 管理评分提醒的条件检查、冷却记录、防重入及原生请求。
///
/// 评分 API 不会返回“用户已提交评价”的结果，因此任何一次平台请求尝试都会
/// 启动冷却。调用方只应在用户回到学习或收藏首页时调用 [maybeRequest]，
/// 学习过程中不得调用。
class RatingPromptCoordinator {
  /// 创建评分提醒协调器，并允许注入时间和商店来源以稳定验证规则。
  RatingPromptCoordinator({
    required PackageInfo packageInfo,
    required DailyStudyRecordDao studyRecordDao,
    required RatingPromptAttemptStore attemptStore,
    required RatingPromptTaskCompletionStore taskCompletionStore,
    required InAppReviewGateway reviewGateway,
    required bool Function() isEnabled,
    RatingPromptRules rules = RatingPromptRules.defaults,
    bool Function()? storeInstallCheck,
    DateTime Function()? clock,
  }) : _packageInfo = packageInfo,
       _studyRecordDao = studyRecordDao,
       _attemptStore = attemptStore,
       _taskCompletionStore = taskCompletionStore,
       _reviewGateway = reviewGateway,
       _isEnabled = isEnabled,
       _rules = rules,
       _storeInstallCheck = storeInstallCheck,
       _clock = clock ?? DateTime.now;

  /// 评分提醒相关日志的标签；开发者选项据此筛选自动触发记录。
  static const logTag = 'RatingPrompt';

  final PackageInfo _packageInfo;
  final DailyStudyRecordDao _studyRecordDao;
  final RatingPromptAttemptStore _attemptStore;
  final RatingPromptTaskCompletionStore _taskCompletionStore;
  final InAppReviewGateway _reviewGateway;

  /// 每次检查都读取最新远程开关，允许刷新后立即停止尚未发起的请求。
  final bool Function() _isEnabled;
  final RatingPromptRules _rules;
  final bool Function()? _storeInstallCheck;
  final DateTime Function() _clock;

  bool _requestInFlight = false;

  /// 条件满足时请求系统评分；否则记录未请求的原因。
  ///
  /// [canPresent] 由调用方提供，每次异步等待后复查页面可见性与前台状态。
  /// 平台调用失败时记录日志并吞并异常，避免影响主页面。
  Future<void> maybeRequest({required bool Function() canPresent}) async {
    if (_requestInFlight) {
      AppLogger.log(logTag, 'skip reason=in_flight');
      return;
    }
    if (!canPresent()) {
      AppLogger.log(logTag, 'skip reason=not_presentable');
      return;
    }
    _requestInFlight = true;
    try {
      final status = await inspect();
      // 未满足条件是每次回到首页的常态，不逐次打日志；结论可在开发者选项的状态弹窗查看。
      if (status.blockReason != null) return;

      // 统计查询期间可能切页、进入后台或关闭远程开关，失效请求不得消费冷却。
      if (!_stillEligible(canPresent)) {
        AppLogger.log(logTag, 'skip reason=eligibility_expired');
        return;
      }

      // 必须先记录再调用系统；失败也进入冷却，避免重复打扰用户。
      final recorded = await _attemptStore.recordAttempt(status.now);
      if (!recorded) {
        AppLogger.log(logTag, 'skip reason=attempt_persist_failed');
        return;
      }

      // 落盘同样是异步边界；尚未调用系统时撤回本次记录。
      if (!_stillEligible(canPresent)) {
        final restored = await _attemptStore.restoreAttempt(status.lastAttempt);
        AppLogger.log(
          logTag,
          'skip reason=eligibility_expired cooldownRestored=$restored',
        );
        return;
      }

      AppLogger.log(logTag, 'request');
      await _reviewGateway.requestReview();
    } catch (error, stackTrace) {
      AppLogger.log(logTag, 'request failed error=$error\n$stackTrace');
    } finally {
      _requestInFlight = false;
    }
  }

  /// 只读查询当前条件快照，供开发者选项展示，也供 [maybeRequest] 判定。
  ///
  /// 不写入冷却、不请求系统评分、不占用防重入标记，因此可以在任意时刻调用。
  Future<RatingPromptStatus> inspect() async {
    final now = _clock();
    final lastAttempt = _attemptStore.readLastAttempt();
    final installTime = _packageInfo.installTime;
    // 有过请求时从上次请求后的下一个自然日开始计数，避免重复计算已消费的打卡日。
    final countedFrom = lastAttempt == null
        ? _dateOnly(installTime ?? now)
        : _nextCalendarDate(_dateOnly(lastAttempt));
    final checkInDays = await _countCheckInDays(countedFrom, _dateOnly(now));
    return RatingPromptStatus(
      now: now,
      rules: _rules,
      isRemoteEnabled: _isEnabled(),
      isStoreInstall: _isStoreInstall(),
      installerStore: _packageInfo.installerStore,
      installTime: installTime,
      lastAttempt: lastAttempt,
      countedFrom: countedFrom,
      checkInDays: checkInDays,
      lastTaskCompletedAt: _taskCompletionStore.readLastCompletedAt(),
    );
  }

  bool _stillEligible(bool Function() canPresent) =>
      _isEnabled() && canPresent();

  DateTime _dateOnly(DateTime date) {
    final localDate = date.toLocal();
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  /// 返回下一个本地自然日，避免夏令时切换时按 24 小时推进落在当天。
  DateTime _nextCalendarDate(DateTime date) =>
      DateTime(date.year, date.month, date.day + 1);

  /// 统计区间内完成每日目标打卡的天数。打卡由学习时长达到目标时写入，同一天只写一次。
  Future<int> _countCheckInDays(DateTime start, DateTime end) async {
    if (start.isAfter(end)) return 0;
    final records = await _studyRecordDao.getBetween(start, end);
    return records
        .where((record) => record.checkedInGoalMinutes != null)
        .length;
  }

  bool _isStoreInstall() {
    final storeInstallCheck = _storeInstallCheck;
    if (storeInstallCheck != null) return storeInstallCheck();

    return switch ((
      clientPlatformName(),
      clientDistribution,
      _packageInfo.installerStore,
    )) {
      ('ios', ClientDistribution.appStore, 'com.apple') => true,
      ('android', ClientDistribution.play, 'com.android.vending') => true,
      _ => false,
    };
  }
}
