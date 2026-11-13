/// 账户用量与额度，来自后端 `GET /api/v1/me/usage`。
///
/// 额度的唯一来源是后端；客户端只负责把已用量换算成展示用的百分比。
class AccountUsage {
  const AccountUsage({
    required this.plan,
    required this.periodStart,
    required this.resetAt,
    required this.features,
  });

  /// 解析后端 `/api/v1/me/usage` 的响应体。
  ///
  /// 外部输入在此校验，结构不符时抛出 [FormatException]，不返回默认值掩盖问题。
  /// 后端新增的未知功能会被忽略，避免旧客户端因此崩溃。
  factory AccountUsage.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('Usage response must be a JSON object');
    }
    final plan = json['plan'];
    final period = json['period'];
    final resetAt = json['resetAt'];
    final features = json['features'];
    if (plan is! String ||
        period is! String ||
        resetAt is! String ||
        features is! Map<String, Object?>) {
      throw const FormatException('Usage response has an invalid shape');
    }

    final usageByFeature = <UsageFeature, FeatureUsage>{};
    for (final entry in features.entries) {
      final feature = UsageFeature.fromApiKey(entry.key);
      if (feature == null) continue;
      usageByFeature[feature] = FeatureUsage.fromJson(entry.value);
    }

    return AccountUsage(
      plan: plan,
      periodStart: _parsePeriodStart(period),
      resetAt: DateTime.parse(resetAt),
      features: usageByFeature,
    );
  }

  /// 套餐标识，例如 `free`。
  final String plan;

  /// 额度周期的起始月份（只使用年与月）。
  final DateTime periodStart;

  /// 额度重置时间（UTC 时刻）。
  final DateTime resetAt;

  /// 后端返回的功能用量；缺失的功能不在此出现，UI 应跳过而不是补零。
  final Map<UsageFeature, FeatureUsage> features;

  static DateTime _parsePeriodStart(String period) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(period);
    if (match == null) {
      throw const FormatException('Usage period must be YYYY-MM');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) {
      throw const FormatException('Usage period month is out of range');
    }
    return DateTime(year, month);
  }
}

/// 客户端认识的计费功能。[apiKey] 与后端 `features` 的键一一对应。
enum UsageFeature {
  dictionary('dictionary'),
  translate('translate'),
  analyze('analyze'),
  senseGroups('sense_groups'),
  transcription('transcription'),
  chat('chat'),
  retellReview('retell_review'),
  tts('tts');

  const UsageFeature(this.apiKey);

  final String apiKey;

  /// 按枚举声明顺序返回，展示顺序由客户端决定，与后端返回顺序无关。
  static UsageFeature? fromApiKey(String apiKey) {
    for (final feature in values) {
      if (feature.apiKey == apiKey) return feature;
    }
    return null;
  }
}

/// 单个功能的额度与已用量。
class FeatureUsage {
  const FeatureUsage({required this.limit, required this.used});

  /// 后端用 `limit: -1` 表示不限量（付费套餐），此时 [limit] 为 `null`。
  static const _unlimitedLimitValue = -1;

  factory FeatureUsage.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('Feature usage must be a JSON object');
    }
    final limit = json['limit'];
    final used = json['used'];
    if (limit is! int ||
        used is! int ||
        used < 0 ||
        (limit < 0 && limit != _unlimitedLimitValue)) {
      throw const FormatException('Feature usage has an invalid shape');
    }
    return FeatureUsage(
      limit: limit == _unlimitedLimitValue ? null : limit,
      used: used,
    );
  }

  /// 额度上限；`null` 表示不限量。
  final int? limit;
  final int used;

  bool get isUnlimited => limit == null;

  /// 已用量达到或超过额度（包括额度为 0 的情况）。不限量永远不会用完。
  bool get isExhausted {
    final limit = this.limit;
    return limit != null && used >= limit;
  }

  /// 展示用百分比，范围 0–100；不限量时为 `null`，UI 不应展示进度条。
  ///
  /// 只要用过一次就至少显示 1%，避免 1/2000 这类小比例被取整成 0% 而看起来没用过；
  /// 未满额时最高显示 99%，避免 199/200 被四舍五入成「100%」却仍可继续使用。
  int? get percent {
    final limit = this.limit;
    if (limit == null) return null;
    if (isExhausted) return 100;
    if (used == 0) return 0;
    return (used * 100 / limit).round().clamp(1, 99);
  }
}
