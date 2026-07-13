import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/services/ai_quota_limit_store.dart';

void main() {
  late SharedPreferences prefs;
  late AiQuotaLimitStore store;

  const userId = 'user-1';
  const feature = PremiumFeature.aiTranslation;
  final now = DateTime.utc(2026, 7, 13, 6);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = AiQuotaLimitStore(prefs);
  });

  test('记录 resetAt 后在 reset 前阻断请求', () async {
    await store.recordResetAt(
      userId,
      feature,
      now.add(const Duration(days: 1)),
    );

    expect(store.isBlocked(userId, feature, now: now), isTrue);
    expect(store.activeResetAt(userId, feature, now: now), isNotNull);
  });

  test('resetAt 过期后不阻断，clearExpiredResets 会清除记录', () async {
    await store.recordResetAt(
      userId,
      feature,
      now.subtract(const Duration(minutes: 1)),
    );

    expect(store.isBlocked(userId, feature, now: now), isFalse);

    await store.clearExpiredResets(userId, now: now);

    expect(store.activeResetAt(userId, feature, now: now), isNull);
  });

  test('clearAllResets 清除所有功能 reset，但保留提醒节流时间', () async {
    await withClock(Clock.fixed(now), () async {
      await store.recordResetAt(
        userId,
        feature,
        now.add(const Duration(days: 1)),
      );
      await store.markReminderShown(userId, feature);
    });

    await store.clearAllResets(userId);

    expect(store.activeResetAt(userId, feature, now: now), isNull);
    expect(store.shouldShowReminder(userId, feature, now: now), isFalse);
  });

  test('quota 提醒两周内不重复展示，超过两周后允许展示', () async {
    await store.markReminderShown(userId, feature, now: now);

    expect(
      store.shouldShowReminder(
        userId,
        feature,
        now: now.add(const Duration(days: 13, hours: 23)),
      ),
      isFalse,
    );
    expect(
      store.shouldShowReminder(
        userId,
        feature,
        now: now.add(const Duration(days: 14)),
      ),
      isTrue,
    );
  });

  test('quota 提醒按用户全局节流，不按功能重复弹', () async {
    await store.markReminderShown(userId, feature, now: now);

    expect(
      store.shouldShowReminder(
        userId,
        PremiumFeature.aiAnalysis,
        now: now.add(const Duration(days: 1)),
      ),
      isFalse,
    );
  });
}
