import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_logger.dart';
import '../../onboarding_survey/providers/onboarding_survey_provider.dart';
import '../../user_preferences/data/local_user_preferences_store.dart';
import '../../user_preferences/domain/user_preferences_document.dart';
import '../../user_preferences/domain/user_preferences_sync_events.dart';
import '../../user_preferences/providers/user_preferences_sync_providers.dart';
import 'daily_check_in_share_provider.dart';

/// 展示去重与云同步由业务层管理，弹窗只报告已经展示的事实。
class DailyShareDialogPresentation {
  DailyShareDialogPresentation({
    required this.preferences,
    required this.currentUserId,
    required this.synchronize,
  });

  final SharedPreferences preferences;
  final String? Function() currentUserId;
  final Future<void> Function(String userId) synchronize;
  bool isOpen = false;
  String? _shownUserId;
  String? _shownDate;

  Future<bool> canAutoShow(String userId, String date) async {
    if (_shownUserId == userId && _shownDate == date) return false;
    await synchronize(userId);
    if (currentUserId() != userId) return false;
    final shown = preferences.getString(
      LocalUserPreferencesStore.dailyShareDateKey(userId),
    );
    return shown == null ||
        !isValidPreferenceDate(shown) ||
        shown.compareTo(date) < 0;
  }

  void didShow(String userId, String date) {
    _shownUserId = userId;
    _shownDate = date;
    unawaited(_rememberShown(userId, date));
  }

  Future<void> _rememberShown(String userId, String date) async {
    try {
      if (currentUserId() != userId) return;
      // 先写账号独立的本地记录，不能让慢网络拖延跨重启去重。
      await _writeShownDate(userId, date);
      await synchronize(userId);
      if (currentUserId() != userId) return;
      // 首次绑定账号可能应用旧快照；同步结束后再合并一次，避免覆盖本次展示。
      await _writeShownDate(userId, date);
    } on Object catch (error, stackTrace) {
      // 展示已经成功，记录失败不能让弹窗操作失败；进程内记录仍可避免重复。
      AppLogger.log('DailyShare', '保存分享展示记录失败: $error\n$stackTrace');
    }
  }

  Future<void> _writeShownDate(String userId, String date) async {
    final key = LocalUserPreferencesStore.dailyShareDateKey(userId);
    final previous = preferences.getString(key);
    if (previous == null ||
        !isValidPreferenceDate(previous) ||
        previous.compareTo(date) < 0) {
      await preferences.setString(key, date);
      userPreferencesSyncEvents.notifyLocalChange();
    }
  }
}

final dailyShareDialogPresentationProvider =
    Provider<DailyShareDialogPresentation>(
      (ref) => DailyShareDialogPresentation(
        preferences: ref.read(sharedPreferencesProvider),
        currentUserId: () =>
            ref.mounted ? ref.read(dailyShareUserIdProvider) : null,
        synchronize: (userId) => ref
            .read(userPreferencesSyncServiceProvider)
            .onSessionChanged(userId),
      ),
    );
