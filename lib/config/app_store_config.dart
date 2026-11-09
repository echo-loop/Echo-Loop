/// App Store 配置。
///
/// 集中管理 iOS 商店链接，避免设置页和更新检查逻辑散落 App ID。
const appStoreAppId = '6760324074';

/// iOS App Store 评价页链接。
///
/// 使用 `itms-apps` 让 iOS 直接打开 App Store 客户端的写评价页面。
final appStoreReviewUri = Uri.parse(
  'itms-apps://itunes.apple.com/app/id$appStoreAppId?action=write-review',
);

/// iOS App Store 应用详情页链接。
final appStoreProductUri = Uri.parse(
  'https://apps.apple.com/app/id$appStoreAppId',
);

/// Google Play 包名，与 Android `applicationId` 保持一致。
const googlePlayPackageName = 'app.echoloop';

/// Google Play 应用详情页链接，用于引导 Play 包用户写评价。
///
/// 使用 `market://` 让已安装的 Play 商店直接打开应用页。
final googlePlayReviewUri = Uri.parse(
  'market://details?id=$googlePlayPackageName',
);
