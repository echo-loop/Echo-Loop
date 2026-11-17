import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../services/app_logger.dart';

/// 左右分栏页面中左栏占可用宽度比例的本地偏好；null 表示使用页面默认宽度。
///
/// 字幕编辑页、剪辑页等各自继承并使用独立的存储键：各页左栏内容不同，
/// 共用一份比例会互相干扰。
abstract class SideBySideSplitFractionNotifier extends Notifier<double?> {
  SideBySideSplitFractionNotifier(this._storageKey, this._logTag);

  final String _storageKey;
  final String _logTag;

  Future<void> _pendingWrite = Future<void>.value();

  @override
  double? build() {
    final value = ref.read(sharedPreferencesProvider).getDouble(_storageKey);
    // 非法的历史值视为未设置，回落默认宽度。
    return value != null && _isValidFraction(value) ? value : null;
  }

  /// 记住左栏比例；传 null 恢复默认宽度。写入按调用顺序串行，避免旧值覆盖新值。
  Future<void> setFraction(double? fraction) {
    if (fraction != null && !_isValidFraction(fraction)) {
      throw ArgumentError.value(fraction, 'fraction', '必须在 (0, 1) 区间内');
    }
    if (state == fraction) return Future<void>.value();
    state = fraction;
    AppLogger.log(
      _logTag,
      fraction == null
          ? '恢复默认分栏宽度'
          : '保存分栏宽度: fraction=${fraction.toStringAsFixed(3)}',
    );
    final preferences = ref.read(sharedPreferencesProvider);
    final write = _pendingWrite.then((_) async {
      try {
        final saved = fraction == null
            ? await preferences.remove(_storageKey)
            : await preferences.setDouble(_storageKey, fraction);
        if (!saved) AppLogger.log(_logTag, '写入分栏宽度偏好失败');
      } on Exception catch (error, stackTrace) {
        AppLogger.log(_logTag, '写入分栏宽度偏好失败: $error\n$stackTrace');
      }
    });
    _pendingWrite = write;
    return write;
  }

  static bool _isValidFraction(double value) =>
      value.isFinite && value > 0 && value < 1;
}
