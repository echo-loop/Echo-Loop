/// 客户端远程配置模型。
///
/// 远程配置只承载 App 运行时需要的 resolved config；feature 的说明、owner、
/// 国家启停规则留在后端 registry 中维护，避免客户端 payload 膨胀。
library;

enum RemoteFeature {
  /// 从网盘导入总入口；当前 provider 只有百度网盘，但开关不绑定具体 provider。
  cloudDriveImport,
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
  const RemoteConfigFeatures({required this.cloudDriveImport});

  final RemoteFeatureConfig cloudDriveImport;

  static const defaults = RemoteConfigFeatures(
    cloudDriveImport: RemoteFeatureConfig(enabled: false),
  );

  factory RemoteConfigFeatures.fromJson(Object? json) {
    if (json is! Map) return defaults;
    return RemoteConfigFeatures(
      cloudDriveImport: RemoteFeatureConfig.fromJson(
        json['cloudDriveImport'],
        enabled: defaults.cloudDriveImport.enabled,
      ),
    );
  }

  bool isEnabled(RemoteFeature feature) {
    return switch (feature) {
      RemoteFeature.cloudDriveImport => cloudDriveImport.enabled,
    };
  }

  Map<String, Object?> toJson() => {
    'cloudDriveImport': cloudDriveImport.toJson(),
  };
}

class RemoteConfig {
  const RemoteConfig({
    required this.version,
    required this.ttlSeconds,
    required this.context,
    required this.features,
  });

  static const currentVersion = 1;
  static const defaultTtlSeconds = 3600;

  static const defaults = RemoteConfig(
    version: currentVersion,
    ttlSeconds: defaultTtlSeconds,
    context: RemoteConfigContext(),
    features: RemoteConfigFeatures.defaults,
  );

  final int version;
  final int ttlSeconds;
  final RemoteConfigContext context;
  final RemoteConfigFeatures features;

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
    );
  }

  bool isEnabled(RemoteFeature feature) => features.isEnabled(feature);

  Map<String, Object?> toJson() => {
    'version': version,
    'ttlSeconds': ttlSeconds,
    'context': context.toJson(),
    'features': features.toJson(),
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
