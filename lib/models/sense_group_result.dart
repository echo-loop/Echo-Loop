/// 意群拆分结果模型（双粒度：中等 + 细粒度）
///
/// 存储 AI 返回的两种粒度意群列表。
/// 中等粒度为自然口语节奏的分割，细粒度让结构更清晰。
library;

/// 意群拆分结果
class SenseGroupResult {
  /// 中等粒度意群
  final List<String> medium;

  /// 细粒度意群
  final List<String> fine;

  const SenseGroupResult({required this.medium, required this.fine});

  /// 从 API 响应 JSON 反序列化
  factory SenseGroupResult.fromJson(Map<String, dynamic> json) {
    final medium = (json['medium'] as List? ?? [])
        .map((e) => e as String)
        .toList();
    final fine = (json['fine'] as List? ?? []).map((e) => e as String).toList();
    return SenseGroupResult(medium: medium, fine: fine);
  }

  /// 两种粒度的分割是否相同
  bool get areBothEqual {
    if (medium.length != fine.length) return false;
    for (var i = 0; i < medium.length; i++) {
      if (medium[i] != fine[i]) return false;
    }
    return true;
  }

  /// 序列化为 JSON（用于 SQLite 缓存）
  Map<String, dynamic> toJson() => {'medium': medium, 'fine': fine};
}
