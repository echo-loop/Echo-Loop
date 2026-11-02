import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/features/podcast/podcast_repository.dart';

void main() {
  group('podcastRepositoryProvider 生命周期', () {
    test('无监听者时仓库仍存活，后台刷新中途不会因 Ref 销毁而失败', () async {
      // 仓库持有 Ref 并在后台刷新的 await 之后继续读取 provider，
      // 因此必须与 app 作用域同生命周期，不能因无人监听而 autoDispose。
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(podcastRepositoryProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.exists(podcastRepositoryProvider), isTrue);
    });
  });
}
