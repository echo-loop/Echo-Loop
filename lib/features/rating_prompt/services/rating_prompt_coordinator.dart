import 'package:package_info_plus/package_info_plus.dart';

import '../../../config/client_distribution.dart';
import '../../../database/daos/daily_study_record_dao.dart';
import '../../../services/app_logger.dart';
import '../data/rating_prompt_attempt_store.dart';
import '../domain/rating_prompt_policy.dart';
import '../domain/rating_prompt_status.dart';
import 'in_app_review_gateway.dart';

/// 管理评分邀请的资格检查、冷却、防重入及原生请求。
///
/// 评分 API 不会返回“用户已提交评价”的结果，因此任何一次平台请求尝试都会
/// 启动 120 天冷却。此协调器只在练习页面完成并返回学习计划页后调用。
class RatingPromptCoordinator {
  /// 创建评分邀请协调器，并允许注入时间和商店来源以稳定验证规则。
  RatingPromptCoordinator({
    required PackageInfo packageInfo,
    required DailyStudyRecordDao studyRecordDao,
    required RatingPromptAttemptStore attemptStore,
    required InAppReviewGateway reviewGateway,
    required bool Function() isEnabled,
    RatingPromptPolicy policy = RatingPromptPolicy.defaultPolicy,
    bool Function()? storeInstallCheck,
    DateTime Function()? clock,
  }) : _packageInfo = packageInfo,
       _studyRecordDao = studyRecordDao,
       _attemptStore = attemptStore,
       _reviewGateway = reviewGateway,
       _isEnabled = isEnabled,
       _policy = policy,
       _storeInstallCheck = storeInstallCheck,
       _clock = clock ?? DateTime.now;

  static const _cooldown = Duration(days: 120);
  static const _effectiveDayThreshold = 10 * 60 * 1000;
  /// 评分邀请相关日志的标签；开发者选项据此筛选自动触发记录。
  static const logTag = 'RatingPrompt';

  final PackageInfo _packageInfo;
  final DailyStudyRecordDao _studyRecordDao;
  final RatingPromptAttemptStore _attemptStore;
  final InAppReviewGateway _reviewGateway;

  /// 每次检查都读取最新远程开关，允许刷新后立即停止尚未发起的请求。
  final bool Function() _isEnabled;
  final RatingPromptPolicy _policy;
  final bool Function()? _storeInstallCheck;
  final DateTime Function() _clock;

  bool _requestInFlight = false;

  /// 在确认完成一次跟读或复述后检查条件并尝试请求系统评分。
  ///
  /// [canPresent] 由页面提供，每次异步等待后复查原页面可见性与前台状态。
  /// 评分服务不可用或平台调用失败时记录日志并吞并异常，避免影响学习流程。
  Future<void> maybeRequest(
    RatingPromptEvent event, {
    required bool Function() canPresent,
  }) async {
    if (!_isEnabled()) {
      AppLogger.log(logTag, 'skip reason=remote_disabled');
      return;
    }
    if (!canPresent()) {
      AppLogger.log(logTag, 'skip reason=not_presentable');
      return;
    }
    if (_requestInFlight) {
      AppLogger.log(logTag, 'skip reason=in_flight');
      return;
    }
    _requestInFlight = true;
    try {
      final now = _clock();
      final lastAttempt = _attemptStore.readLastAttempt();
      if (_cooldownRemaining(now, lastAttempt) != null) {
        AppLogger.log(logTag, 'skip reason=cooldown');
        return;
      }

      final status = await _readStatus(now: now, lastAttempt: lastAttempt);
      if (!status.allowsEvent(event)) {
        AppLogger.log(
          logTag,
          'skip reason=conditions installTime=${status.installTime != null} '
          'effectiveDays=${status.effectiveStudyDays} '
          'store=${status.isStoreInstall} event=${event.name}',
        );
        return;
      }

      // 查询期间可能切页、进入后台或关闭远程开关，失效请求不得消费冷却。
      if (!_isEnabled() || !canPresent()) {
        AppLogger.log(logTag, 'skip reason=eligibility_expired');
        return;
      }

      // 必须先记尝试再调用系统；失败也进入冷却，避免重复打扰用户。
      final recorded = await _attemptStore.recordAttempt(now);
      if (!recorded) {
        AppLogger.log(logTag, 'skip reason=attempt_persist_failed');
        return;
      }

      // 落盘同样是异步边界；尚未调用系统时撤回本次记录。
      if (!_isEnabled() || !canPresent()) {
        final restored = await _attemptStore.restoreAttempt(lastAttempt);
        AppLogger.log(
          logTag,
          'skip reason=eligibility_expired cooldownRestored=$restored',
        );
        return;
      }

      AppLogger.log(logTag, 'request event=${event.name}');
      await _reviewGateway.requestReview();
    } catch (error, stackTrace) {
      AppLogger.log(logTag, 'request failed error=$error\n$stackTrace');
    } finally {
      _requestInFlight = false;
    }
  }

  /// 只读查询当前评分邀请条件，供开发者选项展示。
  ///
  /// 不写入冷却、不请求系统评分、不占用防重入标记，因此可以在任意时刻调用。
  Future<RatingPromptStatus> inspect() async {
    final now = _clock();
    return _readStatus(now: now, lastAttempt: _attemptStore.readLastAttempt());
  }

  /// 组装条件快照；[maybeRequest] 与 [inspect] 共用，避免两处规则分叉。
  Future<RatingPromptStatus> _readStatus({
    required DateTime now,
    required DateTime? lastAttempt,
  }) async {
    final installTime = _packageInfo.installTime;
    // 有过请求时从上次请求后的下一个自然日开始计数，避免重复计算已消费的学习日。
    final countedFrom = lastAttempt == null
        ? _dateOnly(installTime ?? now)
        : _nextCalendarDate(_dateOnly(lastAttempt));
    final effectiveStudyDays = await _countEffectiveStudyDays(
      countedFrom,
      _dateOnly(now),
    );
    return RatingPromptStatus(
      now: now,
      isRemoteEnabled: _isEnabled(),
      isStoreInstall: _isStoreInstall(),
      installerStore: _packageInfo.installerStore,
      installTime: installTime,
      lastAttempt: lastAttempt,
      cooldownRemaining: _cooldownRemaining(now, lastAttempt),
      countedFrom: countedFrom,
      effectiveStudyDays: effectiveStudyDays,
      policy: _policy,
    );
  }

  Duration? _cooldownRemaining(DateTime now, DateTime? lastAttempt) {
    if (lastAttempt == null) return null;
    final remaining = _cooldown - now.difference(lastAttempt);
    return remaining > Duration.zero ? remaining : null;
  }

  DateTime _dateOnly(DateTime? date) {
    final localDate = date?.toLocal() ?? _clock();
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  /// 返回下一个本地自然日，避免夏令时切换时按 24 小时推进落在当天。
  DateTime _nextCalendarDate(DateTime date) =>
      DateTime(date.year, date.month, date.day + 1);

  Future<int> _countEffectiveStudyDays(DateTime start, DateTime end) async {
    if (start.isAfter(end)) return 0;
    final records = await _studyRecordDao.getBetween(start, end);
    return records
        .where(
          (record) => record.studyTimeMilliseconds >= _effectiveDayThreshold,
        )
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
