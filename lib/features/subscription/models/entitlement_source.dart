/// 订阅来源渠道。
///
/// 表示「当前有效权益是从哪个平台购买的」，与 App 当前运行平台解耦。
/// 用于把「管理订阅」入口指向订阅**实际来源**平台，而非当前运行平台
/// （例如 Apple 订阅在 Android 上登录，管理入口应打开苹果的网页订阅管理页）。
///
/// 不引入 RevenueCat / Supabase 等第三方类型，保持领域层纯净。
library;

/// 订阅来源渠道。
enum EntitlementSource {
  /// Apple App Store（含 Mac App Store），经 RevenueCat 聚合。
  apple,

  /// Google Play，经 RevenueCat 聚合。
  google,

  /// Paddle（Web / direct 结账）。
  paddle,

  /// 来源未知：老缓存无来源字段、后端未返回，或 store 值无法识别。
  /// 客户端据此回退到「按当前平台渠道」的旧逻辑。
  unknown,
}

/// 后端 `/api/entitlements` 的 `source` 字符串 → [EntitlementSource]。
///
/// 后端值域为 `apple` / `google` / `paddle`；null、空串或未知值一律映射为
/// [EntitlementSource.unknown]，保证解析永不抛错。
EntitlementSource entitlementSourceFromApi(String? raw) {
  switch (raw) {
    case 'apple':
      return EntitlementSource.apple;
    case 'google':
      return EntitlementSource.google;
    case 'paddle':
      return EntitlementSource.paddle;
    default:
      return EntitlementSource.unknown;
  }
}

/// 本地缓存持久化用的名称 → [EntitlementSource]（容错，未知→unknown）。
EntitlementSource entitlementSourceFromName(String? name) {
  return EntitlementSource.values.where((e) => e.name == name).firstOrNull ??
      EntitlementSource.unknown;
}
