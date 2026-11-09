/// 每日学习目标打卡 Provider
///
/// 每次学习时长写入成功后判定当天是否首次达标；达标时把 [DailyGoalCheckIn]
/// 写入 state，由全局 presenter 监听并弹出 toast。
///
/// 打卡是否已完成记录在 `daily_study_records.checked_in_goal_minutes` 中，
/// 判定与去重都在数据库条件 UPDATE 里完成，因此重启、切库或重复写入都不会
/// 重复打卡。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/providers.dart';
import '../../../providers/learning_settings_provider.dart';
import '../../../providers/study_stats_provider.dart';
import '../../../services/app_logger.dart';
import '../../../services/study_time_service.dart';

/// 一次打卡成功事件。
///
/// 每次打卡都创建新实例且不覆写 `==`，保证监听方每次都能收到变化，
/// 即使两天的目标分钟数相同。
class DailyGoalCheckIn {
  const DailyGoalCheckIn({required this.date, required this.goalMinutes});

  /// 打卡所属的日期。
  final DateTime date;

  /// 打卡时的每日学习目标（分钟）。
  final int goalMinutes;
}

final dailyGoalCheckInProvider =
    NotifierProvider<DailyGoalCheckInNotifier, DailyGoalCheckIn?>(
      DailyGoalCheckInNotifier.new,
    );

class DailyGoalCheckInNotifier extends Notifier<DailyGoalCheckIn?> {
  Future<void> _pendingCheckIns = Future<void>.value();
  @override
  DailyGoalCheckIn? build() {
    final service = ref.watch(studyTimeServiceProvider);
    final subscription = service.studySessionRecorded.listen((eventDate) {
      _pendingCheckIns = _pendingCheckIns.then((_) async {
        if (!ref.mounted) return;
        await _checkInIfGoalReached(service, eventDate);
      });
    });
    ref.onDispose(subscription.cancel);
    return null;
  }

  /// 等待已提交时长对应的打卡判定，返回首页时避免读到尚未落库的标记。
  Future<void> settlePendingCheckIns() async {
    await Future<void>.value();
    await _pendingCheckIns;
  }

  Future<void> _checkInIfGoalReached(
    StudyTimeService service,
    DateTime eventDate,
  ) async {
    final goalMinutes = ref.read(learningSettingsProvider).dailyGoalMinutes;
    try {
      final checkedIn = await service.tryCheckInDailyGoal(
        goalMinutes: goalMinutes,
        date: eventDate,
      );
      if (!ref.mounted ||
          !checkedIn ||
          service != ref.read(studyTimeServiceProvider)) {
        return;
      }
      AppLogger.log(
        'DailyGoalCheckIn',
        'event=checked_in goalMinutes=$goalMinutes',
      );
      state = DailyGoalCheckIn(date: eventDate, goalMinutes: goalMinutes);
      // 时长写入时学习页统计已刷新过，打卡标记晚于那次刷新落库，需要再刷新一次。
      await ref.read(studyStatsProvider.notifier).refresh();
    } catch (error, stackTrace) {
      // 打卡是附加提示，失败不能影响学习流程，因此只记日志。
      AppLogger.log(
        'DailyGoalCheckIn',
        'check_in.failed error=$error\n$stackTrace',
      );
    }
  }
}
