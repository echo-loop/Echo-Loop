import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../database/providers.dart';
import '../../services/app_logger.dart';
import 'review_statistics_repository.dart';

part 'review_statistics_provider.g.dart';

@riverpod
class ReviewStatisticsNotifier extends _$ReviewStatisticsNotifier {
  ReviewStatisticsScope _scope = ReviewStatisticsScope.all;

  @override
  Future<ReviewStatistics> build() => _load(source: 'initial');

  ReviewStatisticsScope get scope => _scope;

  /// 加载统计并保留完整失败上下文，便于从应用日志定位数据库或数据异常。
  Future<ReviewStatistics> _load({required String source}) async {
    try {
      return await ReviewStatisticsRepository(ref.read(appDatabaseProvider))
          .load(now: DateTime.now(), scope: _scope);
    } catch (error, stackTrace) {
      AppLogger.log(
        'ReviewStatistics',
        '加载失败：source=$source, scope=${_scope.name}, '
            'error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> setScope(ReviewStatisticsScope scope) async {
    if (_scope == scope) return;
    _scope = scope;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _load(source: 'scopeChanged'));
    // 加载期间页面可能已离开、provider 已销毁，此时不得再写 state。
    if (!ref.mounted) return;
    state = result;
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(() => _load(source: 'refresh'));
    if (!ref.mounted) return;
    state = result;
  }
}
