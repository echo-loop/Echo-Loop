import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../../services/app_logger.dart';

class MediaTrimSplitNotifier extends Notifier<double?> {
  static const storageKey = 'media_trim_side_by_side_left_fraction';
  Future<void> _pendingWrite = Future<void>.value();

  @override
  double? build() {
    final fraction = ref.read(sharedPreferencesProvider).getDouble(storageKey);
    return fraction != null && fraction.isFinite && fraction > 0 && fraction < 1
        ? fraction
        : null;
  }

  Future<void> setFraction(double? fraction) {
    if (fraction != null &&
        (!fraction.isFinite || fraction <= 0 || fraction >= 1)) {
      throw ArgumentError.value(fraction, 'fraction', '必须在 (0, 1) 区间内');
    }
    if (state == fraction) return Future<void>.value();
    state = fraction;
    AppLogger.log(
      'MediaTrimLayout',
      fraction == null
          ? '恢复默认分栏宽度'
          : '保存分栏宽度: fraction=${fraction.toStringAsFixed(3)}',
    );
    final preferences = ref.read(sharedPreferencesProvider);
    final write = _pendingWrite.then((_) async {
      try {
        final saved = fraction == null
            ? await preferences.remove(storageKey)
            : await preferences.setDouble(storageKey, fraction);
        if (!saved) AppLogger.log('MediaTrimLayout', '写入分栏偏好失败');
      } on Exception catch (error, stackTrace) {
        AppLogger.log('MediaTrimLayout', '写入分栏偏好失败: $error\n$stackTrace');
      }
    });
    _pendingWrite = write;
    return write;
  }
}

final mediaTrimSplitProvider =
    NotifierProvider<MediaTrimSplitNotifier, double?>(
      MediaTrimSplitNotifier.new,
    );
