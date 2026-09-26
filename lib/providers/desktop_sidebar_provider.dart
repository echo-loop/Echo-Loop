import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../services/app_logger.dart';

/// 宽屏侧栏是否展开的本地偏好。
class DesktopSidebarExpandedNotifier extends Notifier<bool> {
  static const storageKey = 'desktop_sidebar_expanded';

  Future<void> _pendingWrite = Future<void>.value();

  @override
  bool build() {
    return ref.read(sharedPreferencesProvider).getBool(storageKey) ?? true;
  }

  /// 更新侧栏展开状态，并按顺序持久化，避免快速切换时旧写入覆盖新值。
  Future<void> setExpanded(bool expanded) {
    if (state == expanded) return Future<void>.value();
    state = expanded;

    final preferences = ref.read(sharedPreferencesProvider);
    final write = _pendingWrite.then((_) async {
      try {
        final saved = await preferences.setBool(storageKey, expanded);
        if (!saved) {
          AppLogger.log('SidebarPreference', '写入侧栏偏好失败');
        }
      } catch (error, stackTrace) {
        AppLogger.log('SidebarPreference', '写入侧栏偏好失败: $error');
        AppLogger.log('SidebarPreference', stackTrace.toString());
      }
    });
    _pendingWrite = write;
    return write;
  }
}

final desktopSidebarExpandedProvider =
    NotifierProvider<DesktopSidebarExpandedNotifier, bool>(
      DesktopSidebarExpandedNotifier.new,
    );
