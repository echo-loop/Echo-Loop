/// 每日学习目标打卡的全局 UI 宿主：监听打卡事件并弹出 toast。
///
/// 放在 AppStartupGate 之外，保证启动门禁期间也持续监听，不会丢失事件。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/daily_goal_check_in/providers/daily_goal_check_in_provider.dart';
import '../features/daily_goal_check_in/providers/daily_check_in_share_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/app_logger.dart';
import 'daily_goal_toast.dart';

class DailyGoalCheckInPresenter extends ConsumerStatefulWidget {
  const DailyGoalCheckInPresenter({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DailyGoalCheckInPresenter> createState() =>
      _DailyGoalCheckInPresenterState();
}

class _DailyGoalCheckInPresenterState
    extends ConsumerState<DailyGoalCheckInPresenter> {
  ProviderSubscription<DailyGoalCheckIn?>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<DailyGoalCheckIn?>(
      dailyGoalCheckInProvider,
      (_, next) {
        if (next == null) return;
        // 打卡事件可能发生在页面 build 期间，推迟到帧结束再取 overlay。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _present(next);
        });
      },
    );
  }

  void _present(DailyGoalCheckIn checkIn) {
    // 与 AppNoticePresenter 相同：builder 的 context 在 Navigator 之上，
    // 必须从根 overlay 取 l10n 与主题。
    final overlayState = rootNavigatorKey.currentState?.overlay;
    final overlayContext = overlayState?.context;
    if (overlayState == null || overlayContext == null) {
      AppLogger.log('DailyGoalCheckIn', 'toast skipped: overlay not ready');
      return;
    }
    final l10n = AppLocalizations.of(overlayContext);
    if (l10n == null) {
      AppLogger.log('DailyGoalCheckIn', 'toast skipped: l10n unavailable');
      return;
    }
    // toast 本身无法确认是否真正渲染，这里记录的是已交给根 overlay 的时刻。
    AppLogger.log(
      'DailyGoalCheckIn',
      'toast requested goalMinutes=${checkIn.goalMinutes}',
    );
    showDailyGoalCompletedToast(
      overlayState: overlayState,
      message: l10n.dailyGoalCompletedToast(checkIn.goalMinutes),
      brightness: Theme.of(overlayContext).brightness,
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 常驻持有准备状态，学习页面被覆盖时也能继续下载和渲染。
    ref.watch(dailyCheckInShareProvider);
    return widget.child;
  }
}
