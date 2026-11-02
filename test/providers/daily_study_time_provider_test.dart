import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/daily_study_time_provider.dart';

import '../helpers/mock_providers.dart';

/// 首次 build 立即返回 0；之后的 [getTodayStudyTime] 调用挂在 [refreshGate] 上，
/// 用于在 refresh 的 await 期间控制 provider 的生命周期。
class _GatedRefreshStudyTimeService extends FakeStudyTimeService {
  final Completer<int> refreshGate = Completer<int>();
  int _calls = 0;

  @override
  Future<int> getTodayStudyTime() {
    _calls++;
    return _calls == 1 ? Future<int>.value(0) : refreshGate.future;
  }
}

void main() {
  group('DailyStudyTime.refresh', () {
    test('provider 保持存活时，refresh 完成后写入最新学习秒数', () async {
      final service = _GatedRefreshStudyTimeService();
      final container = ProviderContainer(
        overrides: [studyTimeServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(dailyStudyTimeProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(dailyStudyTimeProvider.future);

      final refreshing = container
          .read(dailyStudyTimeProvider.notifier)
          .refresh();
      service.refreshGate.complete(42);
      await refreshing;

      expect(container.read(dailyStudyTimeProvider).value, 42);
    });

    test('refresh 等待期间 provider 被销毁，完成时不应抛出 Ref 已销毁异常', () async {
      final service = _GatedRefreshStudyTimeService();
      final container = ProviderContainer(
        overrides: [studyTimeServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      // 调用方（学习会话结束）只 fire-and-forget 调用 refresh，不监听 provider；
      // 关闭唯一监听后 autoDispose 销毁 notifier，而 refresh 仍在 await 中。
      final sub = container.listen(dailyStudyTimeProvider, (_, __) {});
      await container.read(dailyStudyTimeProvider.future);

      final refreshing = container
          .read(dailyStudyTimeProvider.notifier)
          .refresh();
      sub.close();
      // 让 autoDispose 完成销毁后再让 refresh 的 await 返回。
      await Future<void>.delayed(Duration.zero);
      service.refreshGate.complete(42);

      await expectLater(refreshing, completes);
    });
  });
}
