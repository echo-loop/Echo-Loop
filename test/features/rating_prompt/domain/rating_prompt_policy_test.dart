import 'package:echo_loop/features/rating_prompt/domain/rating_prompt_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = RatingPromptPolicy.defaultPolicy;
  final now = DateTime(2026, 10, 22, 12);
  final installTime = DateTime(2026, 10, 15, 12);

  RatingPromptFacts facts({
    DateTime? install,
    bool missingInstallTime = false,
    int effectiveDays = 3,
    RatingPromptEvent event = RatingPromptEvent.retellCompleted,
    bool storeInstall = true,
  }) => RatingPromptFacts(
    now: now,
    installTime: missingInstallTime ? null : install ?? installTime,
    effectiveStudyDays: effectiveDays,
    event: event,
    isStoreInstall: storeInstall,
  );

  group('RatingPromptPolicy', () {
    test('允许恰好满 7 天且达到 3 个有效学习日的商店安装用户', () {
      expect(policy.allows(facts()), isTrue);
    });

    test('任一组内条件不满足时不触发', () {
      expect(
        policy.allows(facts(install: now.subtract(const Duration(days: 6)))),
        isFalse,
      );
      expect(policy.allows(facts(effectiveDays: 2)), isFalse);
      expect(policy.allows(facts(storeInstall: false)), isFalse);
    });

    test('只接受已完成的跟读或复述事件', () {
      expect(
        policy.allows(facts(event: RatingPromptEvent.shadowingCompleted)),
        isTrue,
      );
    });

    test('安装时间缺失或位于未来时不触发', () {
      expect(policy.allows(facts(missingInstallTime: true)), isFalse);
      expect(
        policy.allows(facts(install: now.add(const Duration(days: 1)))),
        isFalse,
      );
    });

    test('多个规则组之间使用 OR', () {
      const additionalGroup = RatingPromptRuleGroup(
        minimumInstallAge: Duration(days: 30),
        minimumEffectiveStudyDays: 1,
        events: {RatingPromptEvent.retellCompleted},
      );
      const multiGroupPolicy = RatingPromptPolicy(
        groups: [
          RatingPromptRuleGroup(
            minimumInstallAge: Duration(days: 7),
            minimumEffectiveStudyDays: 3,
            events: {RatingPromptEvent.shadowingCompleted},
          ),
          additionalGroup,
        ],
      );

      expect(
        multiGroupPolicy.allows(
          facts(
            install: now.subtract(const Duration(days: 30)),
            effectiveDays: 1,
          ),
        ),
        isTrue,
      );
      expect(
        multiGroupPolicy.allows(
          facts(
            install: now.subtract(const Duration(days: 30)),
            effectiveDays: 1,
            storeInstall: false,
          ),
        ),
        isFalse,
      );
    });
  });
}
