import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/providers.dart';

part 'daily_study_time_provider.g.dart';

/// 今日学习时长 Provider（秒）
///
/// 从 SQLite 读取今日累计学习秒数。
/// 每次进入/退出学习模式后刷新。
@riverpod
class DailyStudyTime extends _$DailyStudyTime {
  @override
  Future<int> build() async {
    return ref.read(studyTimeServiceProvider).getTodayStudyTime();
  }

  /// 手动刷新今日学习时长。
  ///
  /// 调用方通常不监听本 provider（学习会话结束时 fire-and-forget），
  /// await 期间 provider 可能已被 autoDispose 销毁，因此写回前必须检查 [ref.mounted]。
  Future<void> refresh() async {
    state = const AsyncLoading();
    final seconds = await ref.read(studyTimeServiceProvider).getTodayStudyTime();
    if (!ref.mounted) return;
    state = AsyncData(seconds);
  }
}
