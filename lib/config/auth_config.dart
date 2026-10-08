// 认证配置
//
// 通过 `--dart-define` 注入 Supabase 与 Google OAuth 凭据。
// SUPABASE_URL 提供全球入口，CHINA_SUPABASE_URL 提供中国用户入口。
// 各环境通过 `--dart-define-from-file` 或 CI/Release 编译参数注入。
// 当前地区所选 URL 或 publishable key 缺失时跳过 Supabase 初始化，
// 登录相关功能不可用但 app 仍可匿名运行。
library;

/// Supabase 项目 URL（如 https://xxx.supabase.co）。
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

/// 中国用户使用的 Supabase Auth 入口，例如 EdgeOne 加速域名。
const chinaSupabaseUrl = String.fromEnvironment('CHINA_SUPABASE_URL');

/// Supabase publishable key（公开可暴露的客户端密钥）。
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// Google OAuth Web Client ID，仅 Android 平台用作 `serverClientId`。
/// iOS / macOS 不接 Google 登录，无需配。
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

/// 按当前启动时的地区快照选择 Supabase 地址。
///
/// 中国地址未配置时返回 null，避免中国用户静默回退到全球地址。
String? supabaseUrlForRegion({
  required bool isChinaUser,
  String? globalUrl,
  String? chinaUrl,
}) {
  final selectedUrl =
      (isChinaUser ? chinaUrl ?? chinaSupabaseUrl : globalUrl ?? supabaseUrl)
          .trim();
  return selectedUrl.isEmpty ? null : selectedUrl;
}

/// 判断所选 Supabase 地址与公开客户端 key 是否都已配置。
bool isAuthConfiguredForUrl(String? url, {String? publishableKey}) {
  return (url?.trim().isNotEmpty ?? false) &&
      (publishableKey ?? supabasePublishableKey).trim().isNotEmpty;
}
