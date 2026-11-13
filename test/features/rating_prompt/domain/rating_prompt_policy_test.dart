import 'package:echo_loop/features/rating_prompt/domain/rating_prompt_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 22, 12);
  final installTime = DateTime(2026, 10, 15, 12);
  const rules = RatingPromptRules.defaults;

  RatingPromptBlockReason? evaluate({
    DateTime? install,
    bool missingInstallTime = false,
    int checkInDays = 3,
    bool storeInstall = true,
    bool remoteEnabled = true,
    DateTime? lastAttempt,
    bool withRecentTask = true,
    DateTime? lastTaskCompletedAt,
  }) => evaluateRatingPrompt(
    lastTaskCompletedAt:
        lastTaskCompletedAt ??
        (withRecentTask ? now.subtract(const Duration(minutes: 1)) : null),
    rules: rules,
    now: now,
    isRemoteEnabled: remoteEnabled,
    isStoreInstall: storeInstall,
    installTime: missingInstallTime ? null : install ?? installTime,
    lastAttempt: lastAttempt,
    checkInDays: checkInDays,
  );

  group('evaluateRatingPrompt', () {
    test('恰好满 7 天且达到 3 个打卡日的商店安装用户可以请求', () {
      expect(evaluate(), isNull);
    });

    test('按固定顺序返回第一条未满足的条件', () {
      expect(
        evaluate(remoteEnabled: false, storeInstall: false, checkInDays: 0),
        RatingPromptBlockReason.remoteDisabled,
      );
      expect(
        evaluate(storeInstall: false, checkInDays: 0),
        RatingPromptBlockReason.notStoreInstall,
      );
      expect(
        evaluate(missingInstallTime: true, checkInDays: 0),
        RatingPromptBlockReason.installTimeUnknown,
      );
      expect(
        evaluate(
          install: now.subtract(const Duration(days: 6)),
          checkInDays: 0,
        ),
        RatingPromptBlockReason.installTooRecent,
      );
      expect(
        evaluate(
          lastAttempt: now.subtract(const Duration(days: 1)),
          checkInDays: 0,
        ),
        RatingPromptBlockReason.inCooldown,
      );
      expect(
        evaluate(checkInDays: 2),
        RatingPromptBlockReason.notEnoughCheckInDays,
      );
    });

    test('没有最近 10 分钟内的任务完成时不请求，且排在打卡天数之后检查', () {
      expect(
        evaluate(withRecentTask: false),
        RatingPromptBlockReason.noRecentTask,
      );
      expect(
        evaluate(withRecentTask: false, checkInDays: 0),
        RatingPromptBlockReason.notEnoughCheckInDays,
      );
    });

    test('任务完成时间超过 10 分钟不请求，恰好 10 分钟内可以请求', () {
      expect(
        evaluate(
          lastTaskCompletedAt: now.subtract(const Duration(minutes: 11)),
        ),
        RatingPromptBlockReason.noRecentTask,
      );
      expect(
        evaluate(
          lastTaskCompletedAt: now.subtract(const Duration(minutes: 10)),
        ),
        isNull,
      );
    });

    test('任务完成时间晚于当前时间（时钟回拨）视为无效', () {
      expect(
        evaluate(lastTaskCompletedAt: now.add(const Duration(minutes: 1))),
        RatingPromptBlockReason.noRecentTask,
      );
    });

    test('安装时间位于未来时视为未满 7 天', () {
      expect(
        evaluate(install: now.add(const Duration(days: 1))),
        RatingPromptBlockReason.installTooRecent,
      );
    });

    test('距上次请求满 120 天后冷却结束，只要其他条件满足即可再次请求', () {
      expect(
        evaluate(lastAttempt: now.subtract(const Duration(days: 119))),
        RatingPromptBlockReason.inCooldown,
      );
      expect(
        evaluate(lastAttempt: now.subtract(const Duration(days: 120))),
        isNull,
      );
    });
  });

  group('ratingPromptCooldownRemaining', () {
    test('从未请求时没有冷却', () {
      expect(
        ratingPromptCooldownRemaining(
          rules: rules,
          now: now,
          lastAttempt: null,
        ),
        isNull,
      );
    });

    test('返回距冷却结束的剩余时长', () {
      expect(
        ratingPromptCooldownRemaining(
          rules: rules,
          now: now,
          lastAttempt: now.subtract(const Duration(days: 20)),
        ),
        const Duration(days: 100),
      );
    });
  });
}
