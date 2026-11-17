import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../../services/app_logger.dart';

/// 字幕编辑页左右分栏中左栏（画面 + 波形）占可用宽度的比例；null 表示自动适配。
///
/// 与学习任务页的视频比例分开保存：两边左栏内容不同，共用会互相干扰。
class SubtitleEditorSplitNotifier extends Notifier<double?> {
  static const storageKey = 'subtitle_editor_side_by_side_media_fraction';
  static const _logTag = 'SubtitleEditorLayout';

  Future<void> _pendingWrite = Future<void>.value();

  @override
  double? build() {
    final value = ref.read(sharedPreferencesProvider).getDouble(storageKey);
    // 非法的历史值视为未设置，回落自动适配。
    return value != null && _isValidFraction(value) ? value : null;
  }

  /// 记住左栏比例；传 null 恢复自动适配。写入按调用顺序串行，避免旧值覆盖新值。
  Future<void> setMediaFraction(double? fraction) {
    if (fraction != null && !_isValidFraction(fraction)) {
      throw ArgumentError.value(fraction, 'fraction', '必须在 (0, 1) 区间内');
    }
    if (state == fraction) return Future<void>.value();
    state = fraction;
    AppLogger.log(
      _logTag,
      fraction == null
          ? '恢复自动分栏宽度'
          : '保存分栏宽度: fraction=${fraction.toStringAsFixed(3)}',
    );
    final preferences = ref.read(sharedPreferencesProvider);
    final write = _pendingWrite.then((_) async {
      try {
        final saved = fraction == null
            ? await preferences.remove(storageKey)
            : await preferences.setDouble(storageKey, fraction);
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

final subtitleEditorSplitProvider =
    NotifierProvider<SubtitleEditorSplitNotifier, double?>(
      SubtitleEditorSplitNotifier.new,
    );
