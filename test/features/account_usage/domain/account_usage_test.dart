import 'package:echo_loop/features/account_usage/domain/account_usage.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _usageBody({Map<String, Object?>? features}) => {
  'plan': 'free',
  'period': '2026-11',
  'resetAt': '2026-12-01T00:00:00.000Z',
  'features':
      features ??
      {
        'dictionary': {'limit': 15, 'used': 0, 'remaining': 15},
        'translate': {'limit': 15, 'used': 2, 'remaining': 13},
      },
};

void main() {
  group('AccountUsage.fromJson', () {
    test('解析套餐、周期与各功能用量', () {
      final usage = AccountUsage.fromJson(_usageBody());

      expect(usage.plan, 'free');
      expect(usage.periodStart, DateTime(2026, 11));
      expect(usage.resetAt, DateTime.utc(2026, 12));
      expect(usage.features[UsageFeature.translate]?.used, 2);
      expect(usage.features[UsageFeature.translate]?.limit, 15);
    });

    test('忽略后端新增的未知功能，缺失的功能不出现在结果中', () {
      final usage = AccountUsage.fromJson(
        _usageBody(
          features: {
            'future_feature': {'limit': 1, 'used': 0},
            'tts': {'limit': 2000, 'used': 10},
          },
        ),
      );

      expect(usage.features.keys, [UsageFeature.tts]);
    });

    test('周期不是 YYYY-MM 或月份越界时抛出 FormatException', () {
      final body = _usageBody()..['period'] = '2026-13';

      expect(
        () => AccountUsage.fromJson(body),
        throwsA(isA<FormatException>()),
      );
    });

    test('limit 为 -1 表示不限量，不抛异常', () {
      final usage = AccountUsage.fromJson(
        _usageBody(
          features: {
            'dictionary': {'limit': -1, 'used': 102},
          },
        ),
      );

      final dictionary = usage.features[UsageFeature.dictionary]!;
      expect(dictionary.isUnlimited, isTrue);
      expect(dictionary.isExhausted, isFalse);
      expect(dictionary.percent, isNull);
      expect(dictionary.used, 102);
    });

    test('limit 为除 -1 以外的负数时抛出 FormatException', () {
      final body = _usageBody(
        features: {
          'chat': {'limit': -2, 'used': 0},
        },
      );

      expect(
        () => AccountUsage.fromJson(body),
        throwsA(isA<FormatException>()),
      );
    });

    test('功能用量为负数时抛出 FormatException，不静默修正', () {
      final body = _usageBody(
        features: {
          'chat': {'limit': 5, 'used': -1},
        },
      );

      expect(
        () => AccountUsage.fromJson(body),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('FeatureUsage.percent', () {
    test('未使用为 0%，额度为 0 或已超出为 100%', () {
      expect(const FeatureUsage(limit: 15, used: 0).percent, 0);
      expect(const FeatureUsage(limit: 0, used: 0).percent, 100);
      expect(const FeatureUsage(limit: 1, used: 125).percent, 100);
    });

    test('使用过但不足 1% 时至少显示 1%', () {
      expect(const FeatureUsage(limit: 2000, used: 1).percent, 1);
    });

    test('未满额时最高显示 99%，避免 199/200 被取整成 100%', () {
      expect(const FeatureUsage(limit: 200, used: 199).percent, 99);
      expect(const FeatureUsage(limit: 200, used: 200).percent, 100);
    });

    test('按比例四舍五入', () {
      expect(const FeatureUsage(limit: 15, used: 2).percent, 13);
    });
  });
}
