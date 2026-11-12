/// 词典设置模型
///
/// 记录用户的默认词典源与被禁用的可选源集合，通过 SharedPreferences 持久化。
/// 存数据源 `id` 字符串而非 enum——enum 与「可插拔」冲突（加源要改 enum），
/// 字符串 id + resolve 时兜底未知 id，天然向前兼容。
///
/// 本模型为纯数据：不感知「哪些源可禁用 / 默认回退」等业务规则，
/// 那些规则由 Notifier 结合数据源注册表实施。
library;

import 'dart:collection';

/// 词典设置
class DictionarySettings {
  /// 默认词典源 id（打开查词弹窗时默认选中）
  final String defaultSourceId;

  /// 被用户禁用的源 id 集合（仅含可禁用的源）
  final Set<String> disabledIds;

  /// 查词面板打开或切换到新词时是否自动播放发音
  final bool autoSpeakOnLookup;

  /// 是否在网页词典中启用通用广告过滤
  final bool adFilteringEnabled;

  /// 手动查词详情是否自动展开 AI 查词。
  ///
  /// 默认关闭：AI 查词消耗免费额度，自动请求会在用户未主动要求时扣减额度。
  final bool autoShowAiOnLookup;

  /// 手动查词详情打开时是否自动朗读单词（仅作用于查词页，与词典面板的 [autoSpeakOnLookup] 独立）。
  final bool autoSpeakOnLookupPage;

  /// 默认源 id 缺省值
  static const defaultId = 'local';

  DictionarySettings({
    this.defaultSourceId = defaultId,
    Set<String> disabledIds = const {},
    this.autoSpeakOnLookup = true,
    this.adFilteringEnabled = false,
    this.autoShowAiOnLookup = false,
    this.autoSpeakOnLookupPage = true,
  }) : disabledIds = UnmodifiableSetView(Set.of(disabledIds));

  DictionarySettings copyWith({
    String? defaultSourceId,
    Set<String>? disabledIds,
    bool? autoSpeakOnLookup,
    bool? adFilteringEnabled,
    bool? autoShowAiOnLookup,
    bool? autoSpeakOnLookupPage,
  }) => DictionarySettings(
    defaultSourceId: defaultSourceId ?? this.defaultSourceId,
    disabledIds: disabledIds ?? this.disabledIds,
    autoSpeakOnLookup: autoSpeakOnLookup ?? this.autoSpeakOnLookup,
    adFilteringEnabled: adFilteringEnabled ?? this.adFilteringEnabled,
    autoShowAiOnLookup: autoShowAiOnLookup ?? this.autoShowAiOnLookup,
    autoSpeakOnLookupPage: autoSpeakOnLookupPage ?? this.autoSpeakOnLookupPage,
  );

  Map<String, dynamic> toJson() => {
    'defaultSourceId': defaultSourceId,
    'disabledIds': disabledIds.toList(),
    'autoSpeakOnLookup': autoSpeakOnLookup,
    'adFilteringEnabled': adFilteringEnabled,
    'autoShowAiOnLookup': autoShowAiOnLookup,
    'autoSpeakOnLookupPage': autoSpeakOnLookupPage,
  };

  /// 防御性解析：字段缺失/类型不符回退缺省
  factory DictionarySettings.fromJson(Map<String, dynamic> json) {
    final rawDefault = json['defaultSourceId'];
    final rawDisabled = json['disabledIds'];
    final rawAutoSpeak = json['autoSpeakOnLookup'];
    final rawAdFilteringEnabled = json['adFilteringEnabled'];
    final rawAutoShowAiOnLookup = json['autoShowAiOnLookup'];
    final rawAutoSpeakOnLookupPage = json['autoSpeakOnLookupPage'];
    return DictionarySettings(
      defaultSourceId: rawDefault is String && rawDefault.isNotEmpty
          ? rawDefault
          : defaultId,
      disabledIds: rawDisabled is List
          ? rawDisabled.whereType<String>().toSet()
          : const {},
      autoSpeakOnLookup: rawAutoSpeak is bool ? rawAutoSpeak : true,
      adFilteringEnabled: rawAdFilteringEnabled is bool
          ? rawAdFilteringEnabled
          : false,
      autoShowAiOnLookup: rawAutoShowAiOnLookup is bool
          ? rawAutoShowAiOnLookup
          : false,
      autoSpeakOnLookupPage: rawAutoSpeakOnLookupPage is bool
          ? rawAutoSpeakOnLookupPage
          : true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DictionarySettings &&
          runtimeType == other.runtimeType &&
          defaultSourceId == other.defaultSourceId &&
          _setEquals(disabledIds, other.disabledIds) &&
          autoSpeakOnLookup == other.autoSpeakOnLookup &&
          adFilteringEnabled == other.adFilteringEnabled &&
          autoShowAiOnLookup == other.autoShowAiOnLookup &&
          autoSpeakOnLookupPage == other.autoSpeakOnLookupPage;

  @override
  int get hashCode => Object.hash(
    defaultSourceId,
    Object.hashAllUnordered(disabledIds),
    autoSpeakOnLookup,
    adFilteringEnabled,
    autoShowAiOnLookup,
    autoSpeakOnLookupPage,
  );

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
