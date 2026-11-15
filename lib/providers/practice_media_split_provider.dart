import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../models/practice_media_split.dart';
import '../services/app_logger.dart';

export '../models/practice_media_split.dart';

/// 视频尺寸的本地偏好；所有学习任务与随心听共用一份，调整一次处处生效。
class PracticeMediaSplitNotifier extends Notifier<PracticeMediaSplit> {
  static const stackedStorageKey = 'practice_media_split_stacked_fraction';
  static const sideBySideStorageKey =
      'practice_media_split_side_by_side_fraction';

  static const _logTag = 'PracticeMediaLayout';

  Future<void> _pendingWrite = Future<void>.value();

  @override
  PracticeMediaSplit build() {
    final preferences = ref.read(sharedPreferencesProvider);
    return PracticeMediaSplit(
      stackedVideoFraction: _readFraction(preferences, stackedStorageKey),
      sideBySideVideoFraction: _readFraction(preferences, sideBySideStorageKey),
    );
  }

  /// 记住某个分栏方向的视频比例；传 null 恢复默认尺寸。
  ///
  /// 写入按调用顺序串行，避免连续拖动时旧值覆盖新值。
  Future<void> setVideoFraction(PracticeMediaSplitAxis axis, double? fraction) {
    if (fraction != null && !_isValidFraction(fraction)) {
      throw ArgumentError.value(fraction, 'fraction', '必须在 (0, 1) 区间内');
    }
    if (state.fractionFor(axis) == fraction) return Future<void>.value();
    state = state.withFraction(axis, fraction);

    final preferences = ref.read(sharedPreferencesProvider);
    final key = _storageKeyFor(axis);
    final write = _pendingWrite.then((_) async {
      try {
        final saved = fraction == null
            ? await preferences.remove(key)
            : await preferences.setDouble(key, fraction);
        if (!saved) {
          AppLogger.log(_logTag, '写入视频尺寸偏好失败: axis=${axis.name}');
        }
      } catch (error, stackTrace) {
        AppLogger.log(_logTag, '写入视频尺寸偏好失败: axis=${axis.name}, $error');
        AppLogger.log(_logTag, stackTrace.toString());
      }
    });
    _pendingWrite = write;
    return write;
  }

  static String _storageKeyFor(PracticeMediaSplitAxis axis) => switch (axis) {
    PracticeMediaSplitAxis.stacked => stackedStorageKey,
    PracticeMediaSplitAxis.sideBySide => sideBySideStorageKey,
  };

  /// 非法的历史值视为未设置，回落默认尺寸。
  static double? _readFraction(SharedPreferences preferences, String key) {
    final value = preferences.getDouble(key);
    return value != null && _isValidFraction(value) ? value : null;
  }

  static bool _isValidFraction(double value) =>
      value.isFinite && value > 0 && value < 1;
}

final practiceMediaSplitProvider =
    NotifierProvider<PracticeMediaSplitNotifier, PracticeMediaSplit>(
      PracticeMediaSplitNotifier.new,
    );
