import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/features/rating_prompt/data/rating_prompt_task_completion_store.dart';
import 'package:echo_loop/features/rating_prompt/rating_prompt_providers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('未记录过任务完成时返回 null', () async {
    final store = RatingPromptTaskCompletionStore(
      await SharedPreferences.getInstance(),
    );

    expect(store.readLastCompletedAt(), isNull);
  });

  test('记录的完成时间可以读回，并覆盖旧记录', () async {
    final store = RatingPromptTaskCompletionStore(
      await SharedPreferences.getInstance(),
    );
    final first = DateTime(2026, 11, 13, 9, 0);
    final second = DateTime(2026, 11, 13, 9, 30);

    await store.recordCompletion(first);
    expect(store.readLastCompletedAt(), first);

    await store.recordCompletion(second);
    expect(store.readLastCompletedAt(), second);
  });

  test('记录失败的任务完成不会抛出异常，也不影响学习流程', () async {
    await expectLater(
      recordRatingTaskCompletion(() => throw StateError('prefs unavailable')),
      completes,
    );
  });
}
