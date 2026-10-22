import 'package:package_info_plus/package_info_plus.dart';

import '../../../config/client_distribution.dart';
import '../../../database/daos/daily_study_record_dao.dart';
import '../../../services/app_logger.dart';
import '../data/rating_prompt_attempt_store.dart';
import '../domain/rating_prompt_policy.dart';
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
  static const _logTag = 'RatingPrompt';

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
    if (_requestInFlight || !_isEnabled() || !canPresent()) return;
    _requestInFlight = true;
    try {
      final now = _clock();
      final lastAttempt = _attemptStore.readLastAttempt();
      if (lastAttempt != null && now.difference(lastAttempt) < _cooldown) {
        AppLogger.log(_logTag, 'skip reason=cooldown');
        return;
      }

      final installTime = _packageInfo.installTime;
      final installedFromStore = _isStoreInstall();
      final firstCountedDate = lastAttempt == null
          ? _dateOnly(installTime ?? now)
          : _nextCalendarDate(_dateOnly(lastAttempt));
      final today = _dateOnly(now);
      final effectiveStudyDays = await _countEffectiveStudyDays(
        firstCountedDate,
        today,
      );
      final facts = RatingPromptFacts(
        now: now,
        installTime: installTime,
        effectiveStudyDays: effectiveStudyDays,
        event: event,
        isStoreInstall: installedFromStore,
      );
      if (!_policy.allows(facts)) {
        AppLogger.log(
          _logTag,
          'skip reason=conditions installTime=${installTime != null} '
          'effectiveDays=$effectiveStudyDays store=$installedFromStore '
          'event=${event.name}',
        );
        return;
      }

      // 查询期间可能切页、进入后台或关闭远程开关，失效请求不得消费冷却。
      if (!_isEnabled() || !canPresent()) {
        AppLogger.log(_logTag, 'skip reason=eligibility_expired');
        return;
      }

      // 必须先记尝试再调用系统；失败也进入冷却，避免重复打扰用户。
      final recorded = await _attemptStore.recordAttempt(now);
      if (!recorded) {
        AppLogger.log(_logTag, 'skip reason=attempt_persist_failed');
        return;
      }

      // 落盘同样是异步边界；尚未调用系统时撤回本次记录。
      if (!_isEnabled() || !canPresent()) {
        final restored = await _attemptStore.restoreAttempt(lastAttempt);
        AppLogger.log(
          _logTag,
          'skip reason=eligibility_expired cooldownRestored=$restored',
        );
        return;
      }

      AppLogger.log(_logTag, 'request event=${event.name}');
      await _reviewGateway.requestReview();
    } catch (error, stackTrace) {
      AppLogger.log(_logTag, 'request failed error=$error\n$stackTrace');
    } finally {
      _requestInFlight = false;
    }
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
