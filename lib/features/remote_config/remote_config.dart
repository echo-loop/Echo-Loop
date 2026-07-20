/// 客户端远程配置模型。
///
/// 远程配置只承载 App 运行时需要的 resolved config；feature 的说明、owner、
/// 国家启停规则留在后端 registry 中维护，避免客户端 payload 膨胀。
library;

enum RemoteFeature {
  /// 从网盘导入总入口；当前 provider 只有百度网盘，但开关不绑定具体 provider。
  cloudDriveImport,

  /// 商店包 Paywall 是否展示切换到 Web 支付的兜底入口。
  showStoreWebCheckoutFallback,

  /// 是否显示 AI 聊天助手入口；全球默认开启，远程配置可一键关闭。
  aiChatAssistant,
}

class RemoteConfigContext {
  const RemoteConfigContext({
    this.countryCode = 'US',
    this.platform = '',
    this.channel = '',
  });

  final String countryCode;
  final String platform;
  final String channel;

  factory RemoteConfigContext.fromJson(Object? json) {
    if (json is! Map) return const RemoteConfigContext();
    return RemoteConfigContext(
      countryCode: _readString(json, 'countryCode') ?? 'US',
      platform: _readString(json, 'platform') ?? '',
      channel: _readString(json, 'channel') ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'countryCode': countryCode,
    'platform': platform,
    'channel': channel,
  };
}

class RemoteFeatureConfig {
  const RemoteFeatureConfig({required this.enabled});

  final bool enabled;

  factory RemoteFeatureConfig.fromJson(Object? json, {required bool enabled}) {
    if (json is! Map) return RemoteFeatureConfig(enabled: enabled);
    return RemoteFeatureConfig(enabled: _readBool(json, 'enabled') ?? enabled);
  }

  Map<String, Object?> toJson() => {'enabled': enabled};
}

class RemoteConfigFeatures {
  const RemoteConfigFeatures({
    this.cloudDriveImport = const RemoteFeatureConfig(enabled: false),
    this.showStoreWebCheckoutFallback = const RemoteFeatureConfig(
      enabled: false,
    ),
    this.aiChatAssistant = const RemoteFeatureConfig(enabled: true),
  });

  final RemoteFeatureConfig cloudDriveImport;
  final RemoteFeatureConfig showStoreWebCheckoutFallback;
  final RemoteFeatureConfig aiChatAssistant;

  static const defaults = RemoteConfigFeatures();

  factory RemoteConfigFeatures.fromJson(Object? json) {
    if (json is! Map) return defaults;
    return RemoteConfigFeatures(
      cloudDriveImport: RemoteFeatureConfig.fromJson(
        json['cloudDriveImport'],
        enabled: defaults.cloudDriveImport.enabled,
      ),
      showStoreWebCheckoutFallback: RemoteFeatureConfig.fromJson(
        json['showStoreWebCheckoutFallback'],
        enabled: defaults.showStoreWebCheckoutFallback.enabled,
      ),
      aiChatAssistant: RemoteFeatureConfig.fromJson(
        json['aiChatAssistant'],
        enabled: defaults.aiChatAssistant.enabled,
      ),
    );
  }

  bool isEnabled(RemoteFeature feature) {
    return switch (feature) {
      RemoteFeature.cloudDriveImport => cloudDriveImport.enabled,
      RemoteFeature.showStoreWebCheckoutFallback =>
        showStoreWebCheckoutFallback.enabled,
      RemoteFeature.aiChatAssistant => aiChatAssistant.enabled,
    };
  }

  Map<String, Object?> toJson() => {
    'cloudDriveImport': cloudDriveImport.toJson(),
    'showStoreWebCheckoutFallback': showStoreWebCheckoutFallback.toJson(),
    'aiChatAssistant': aiChatAssistant.toJson(),
  };
}

/// AI 转录入口的远程限制。
class RemoteTranscriptionLimits {
  const RemoteTranscriptionLimits({
    this.maxDurationSeconds = defaultMaxDurationSeconds,
    this.maxUploadBytes = defaultMaxUploadBytes,
  });

  /// 默认允许 30 分钟音频发起云端转录。
  static const defaultMaxDurationSeconds = 30 * 60;

  /// 默认允许最大 50MB 音频发起云端转录。
  static const defaultMaxUploadBytes = 50 * 1024 * 1024;

  static const defaults = RemoteTranscriptionLimits();

  final int maxDurationSeconds;
  final int maxUploadBytes;

  factory RemoteTranscriptionLimits.fromJson(Object? json) {
    if (json is! Map) return defaults;
    return RemoteTranscriptionLimits(
      maxDurationSeconds:
          _readPositiveInt(json, 'maxDurationSeconds') ??
          defaultMaxDurationSeconds,
      maxUploadBytes:
          _readPositiveInt(json, 'maxUploadBytes') ?? defaultMaxUploadBytes,
    );
  }

  int get maxDurationMinutesForDisplay =>
      (maxDurationSeconds / Duration.secondsPerMinute).ceil();

  int get maxUploadMegabytesForDisplay =>
      (maxUploadBytes / (1024 * 1024)).ceil();

  Map<String, Object?> toJson() => {
    'maxDurationSeconds': maxDurationSeconds,
    'maxUploadBytes': maxUploadBytes,
  };
}

class RemoteConfig {
  const RemoteConfig({
    required this.version,
    required this.ttlSeconds,
    required this.context,
    required this.features,
    this.transcriptionLimits = RemoteTranscriptionLimits.defaults,
  });

  static const currentVersion = 1;
  static const defaultTtlSeconds = 3600;

  static const defaults = RemoteConfig(
    version: currentVersion,
    ttlSeconds: defaultTtlSeconds,
    context: RemoteConfigContext(),
    features: RemoteConfigFeatures.defaults,
    transcriptionLimits: RemoteTranscriptionLimits.defaults,
  );

  final int version;
  final int ttlSeconds;
  final RemoteConfigContext context;
  final RemoteConfigFeatures features;
  final RemoteTranscriptionLimits transcriptionLimits;

  factory RemoteConfig.fromJson(Object? json) {
    if (json is! Map) return defaults;
    final version = _readInt(json, 'version') ?? currentVersion;
    if (version != currentVersion) return defaults;
    final ttlSeconds = _readInt(json, 'ttlSeconds') ?? defaultTtlSeconds;
    return RemoteConfig(
      version: version,
      ttlSeconds: ttlSeconds > 0 ? ttlSeconds : defaultTtlSeconds,
      context: RemoteConfigContext.fromJson(json['context']),
      features: RemoteConfigFeatures.fromJson(json['features']),
      transcriptionLimits: RemoteTranscriptionLimits.fromJson(
        _readMap(json, 'limits')?['transcription'],
      ),
    );
  }

  bool isEnabled(RemoteFeature feature) => features.isEnabled(feature);

  Map<String, Object?> toJson() => {
    'version': version,
    'ttlSeconds': ttlSeconds,
    'context': context.toJson(),
    'features': features.toJson(),
    'limits': {'transcription': transcriptionLimits.toJson()},
  };
}

String? _readString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

bool? _readBool(Map<Object?, Object?> json, String key) {
  final value = json[key];
  return value is bool ? value : null;
}

int? _readInt(Map<Object?, Object?> json, String key) {
  final value = json[key];
  return value is int ? value : null;
}

int? _readPositiveInt(Map<Object?, Object?> json, String key) {
  final value = _readInt(json, key);
  return value != null && value > 0 ? value : null;
}

Map<Object?, Object?>? _readMap(Map<Object?, Object?> json, String key) {
  final value = json[key];
  return value is Map<Object?, Object?> ? value : null;
}
